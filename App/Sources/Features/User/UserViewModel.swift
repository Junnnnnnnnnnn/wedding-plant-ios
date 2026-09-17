import Combine
import Foundation
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 웹 `app/user/page.tsx` + `app/components/SettingsPage.tsx` 이식.
///
/// 프로필(이름·결혼식 날짜·예산)을 보여주고 수정한다.
@MainActor
final class UserViewModel: ObservableObject {
    @Published var loading = true
    @Published var loggedIn = false
    @Published var name = ""
    @Published var date: KstDate = KstDate.today()
    /// 만 원 단위. 문자열로 들고 있다 저장 시 숫자로 바꾼다.
    @Published var budget = ""
    @Published var saving = false
    /// 저장 성공 직후 2초간 버튼이 "저장되었어요" 로 바뀐다 (웹과 동일)
    @Published var saved = false
    @Published var errorMessage: String?
    /// 탈퇴 진행 중. 버튼을 두 번 누르는 것을 막는다.
    @Published var withdrawing = false
    @Published var withdrawError: String?

    var dDayLabel: String { PlanRules.dDayLabel(weddingDate: date) }

    // MARK: - 로딩

    func load(env: AppEnvironment, guest: GuestStore) async {
        let token = await env.tokenStore.currentToken()
        guard let token, !token.isEmpty else {
            loading = false
            loggedIn = false
            name = guest.name
            date = guest.weddingDate ?? KstDate.today()
            budget = guest.budget.map(String.init) ?? ""
            return
        }

        loggedIn = true
        loading = true
        defer { loading = false }

        // 화면이 스피너를 직접 그리므로 전역 오버레이는 띄우지 않는다.
        let user = try? await env.api.send(Endpoint.user(), decoding: PlanUser.self)

        let serverName = user?.name?.trimmingCharacters(in: .whitespaces) ?? ""
        name = serverName.isEmpty ? guest.name : serverName
        date = user?.weddingDate.flatMap { KstDate(dateString: $0) } ?? guest.weddingDate ?? KstDate.today()
        // 예산은 0도 유효한 값이라 `?? 기본값` 으로 뭉개면 안 된다.
        if let value = user?.budget {
            budget = String(value)
        } else {
            budget = guest.budget.map(String.init) ?? ""
        }
    }

    // MARK: - 입력

    func setName(_ value: String) {
        name = String(value.prefix(20))
        errorMessage = nil
    }

    func setBudget(_ value: String) {
        // 숫자만. 음수·소수는 애초에 들어올 수 없다.
        budget = String(value.filter(\.isNumber).prefix(9))
        errorMessage = nil
    }

    // MARK: - 저장

    /// 프로필 저장.
    ///
    /// **`PATCH /plan/user` 가 아니라 `POST /plan/setting` 을 쓴다.**
    /// PATCH 는 `requiredAgreementDate`·`adAgreementDate` 를 둘 다 문자열 필수로 검증하는데,
    /// GET 응답에는 두 필드가 없어 null 을 보내면 항상 400 이었고, `adAgreementDate` 를 채우면
    /// 마케팅에 동의하지 않은 사용자에게도 수신 동의가 기록된다.
    /// `/plan/setting` 은 같은 값을 갱신하면서 `adAgreementDate` 생략을 허용한다.
    /// (웹·안드로이드와 동일한 우회다. 백엔드가 PATCH 를 고치는 것이 근본 해결이다)
    func save(env: AppEnvironment, guest: GuestStore) async {
        guard !saving else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorMessage = "이름을 입력해 주세요."
            return
        }

        let token = await env.tokenStore.currentToken()
        guard let token, !token.isEmpty else {
            // 게스트는 로컬 저장으로 끝낸다.
            guest.save(name: trimmedName, budget: Int(budget), weddingDate: date)
            saved = true
            errorMessage = nil
            return
        }

        saving = true
        errorMessage = nil
        defer { saving = false }

        let request = PlanSettingRequest(
            weddingDate: date.dateString,
            budget: Int(budget) ?? 0,
            name: trimmedName,
            // GET 응답에 동의 일자가 없어 오늘 날짜로 보낸다 (웹·안드로이드와 동일).
            requiredAgreementDate: KstDate.todayString(),
            // 마케팅 동의는 여기서 바꾸지 않는다. 생략하면 기존 값이 유지된다.
            adAgreementDate: nil
        )

        do {
            try await env.api.sendIgnoringData(Endpoint.createSetting(request))
            // 로컬 사본도 맞춰 둔다 (게스트 → 로그인 이관 로직이 이 값을 본다)
            guest.save(name: trimmedName, budget: Int(budget), weddingDate: date)
            saved = true
        } catch {
            errorMessage = "저장하지 못했습니다. 잠시 후 다시 시도해 주세요."
        }
    }

    // MARK: - 회원 탈퇴

    /// 계정을 지운다. 성공하면 로그아웃까지 끝낸 상태로 돌아온다.
    ///
    /// **앱 화면 안에서 삭제가 끝나야 한다** — "메일로 요청하세요" 는 심사 반려 사유이고,
    /// 개인정보처리방침에도 이 경로가 적혀 있다.
    ///
    /// 순서가 중요하다. 기기 토큰 해제(`DELETE /plan/user/device-token`)는 JWT 를 요구하므로
    /// **토큰을 지우기 전에** 부른다. 로그아웃과 같은 순서다.
    ///
    /// - Returns: 성공 여부. 실패하면 화면이 그대로 남아 다시 시도할 수 있다.
    @discardableResult
    func withdraw(env: AppEnvironment, push: PushService, guest: GuestStore) async -> Bool {
        guard !withdrawing else { return false }
        withdrawing = true
        withdrawError = nil
        defer { withdrawing = false }

        // 기기 토큰 해제가 **먼저**다. 탈퇴한 뒤에는 그 JWT 로 어떤 API 도 통과하지
        // 못해 해제가 401 로 실패하고, 서버에는 이 기기가 남아 알림이 계속 간다.
        await push.unregisterBeforeSignOut(env: env)

        do {
            try await env.api.sendIgnoringData(Endpoint.withdraw())
        } catch {
            // 해제는 이미 끝났지만 계정은 남는다. 다음 실행 때 다시 등록되므로
            // 알림이 영영 끊기지는 않는다.
            withdrawError = "탈퇴하지 못했습니다. 잠시 후 다시 시도해 주세요."
            return false
        }

        await env.signOut()
        guest.clear()
        return true
    }

    /// 저장 완료 표시는 2초 뒤 원래대로 돌아간다 (웹과 동일).
    func startSavedResetTimer() async {
        try? await Task.sleep(for: .seconds(2))
        saved = false
    }
}
