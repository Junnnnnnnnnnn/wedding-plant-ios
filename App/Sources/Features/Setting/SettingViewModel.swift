import Combine
import Foundation
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 웹 `app/setting/page.tsx` 의 상태 머신 포팅.
///
/// 웹은 `showFirst/showSecond/...` boolean 8개로 단계를 표현했지만,
/// 여기서는 안드로이드와 같이 `Step` enum 하나로 정리한다.
/// (동시에 두 단계가 켜지는 버그가 원천 차단된다)
@MainActor
final class SettingViewModel: ObservableObject {

    enum Step {
        case celebration
        case date
        case budget
        case name
        case welcome
        case terms
        /// **맨 끝, 약관 동의 다음.**
        ///
        /// 이 앱의 메리트가 "신랑·신부가 같이" 인데 예전에는 초대 진입점이 홈의
        /// 작은 점선 `＋` 원 하나였고, 그마저 멤버가 나 혼자일 때만 떠서 조언자
        /// 한 명만 들어와도 사라졌다. 온보딩은 이미 한 번에 하나씩 묻는 연출이라,
        /// 여기에 한 칸을 더하면 초대가 부탁이 아니라 **절차**로 읽힌다.
        case invite
    }

    /// 초대 단계에서 고른 것. 고르기 전에는 기본 버튼이 잠긴다.
    enum InviteChoice {
        case none
        case invite
        case solo
    }

    @Published var step: Step = .celebration
    @Published var date: KstDate = KstDate.today()
    @Published var budget: String = "1000"
    @Published var name: String = ""

    @Published var agreePrivacy = false
    @Published var agreeLocation = false
    @Published var agreeThirdParty = false
    @Published var agreeMarketing = false

    @Published var submitting = false
    @Published var errorMessage: String?
    /// 서버에 이미 완성된 플랜이 있어 곧바로 main 으로 보내야 하는 경우
    @Published var inviteChoice: InviteChoice = .none
    /// 초대 링크. 초대 단계에 들어올 때 받아 둔다.
    @Published var inviteURL: String?
    @Published var inviteLoading = false
    @Published var skipToMain = false
    @Published var ready = false

    var allRequiredAgreed: Bool { agreePrivacy && agreeLocation && agreeThirdParty }
    var allAgreed: Bool { allRequiredAgreed && agreeMarketing }

    // MARK: - 초기값

    /// 웹과 동일: 토큰이 있으면 `GET /plan/user` 로 기존 값을 채우고,
    /// 이미 완성된 플랜이면 main 으로 보낸다.
    func prefill(env: AppEnvironment, guest: GuestStore) async {
        if !guest.name.isEmpty { name = guest.name }
        if let saved = guest.budget { budget = "\(saved)" }
        if let saved = guest.weddingDate { date = saved }

        let token = await env.tokenStore.currentToken()
        guard let token, !token.isEmpty else {
            ready = true
            return
        }

        // 조회 실패해도 플로우는 진행한다 (웹과 동일).
        guard let user = try? await env.api.send(Endpoint.user(), decoding: PlanUser.self) else {
            ready = true
            return
        }

        if PlanCompletion.isComplete(user) {
            skipToMain = true
            ready = true
            return
        }
        if let value = user.name, !value.trimmingCharacters(in: .whitespaces).isEmpty {
            name = value
        }
        if let value = user.budget {
            budget = "\(value)"
        }
        if let raw = user.weddingDate, let parsed = KstDate(dateString: raw) {
            date = parsed
        }
        ready = true
    }

    // MARK: - 입력

    func setBudget(_ value: String) {
        // 숫자만 허용, 최대 7자리 (웹의 type="number" 대응)
        budget = String(value.filter(\.isNumber).prefix(7))
    }

    func setName(_ value: String) {
        // 웹과 동일하게 최대 6글자
        name = String(value.prefix(6))
    }

    func toggleAgreeAll() {
        let next = !allAgreed
        agreePrivacy = next
        agreeLocation = next
        agreeThirdParty = next
        agreeMarketing = next
    }

    func isAgreed(_ doc: TermsDoc) -> Bool {
        switch doc {
        case .privacy: return agreePrivacy
        case .location: return agreeLocation
        case .thirdParty: return agreeThirdParty
        case .marketing: return agreeMarketing
        }
    }

    func setAgreed(_ doc: TermsDoc, _ value: Bool) {
        switch doc {
        case .privacy: agreePrivacy = value
        case .location: agreeLocation = value
        case .thirdParty: agreeThirdParty = value
        case .marketing: agreeMarketing = value
        }
    }

    // MARK: - 단계 이동

    func advanceFromCelebration() {
        if step == .celebration { step = .date }
    }

    func goTo(_ next: Step) {
        step = next
    }

    func back() {
        switch step {
        // welcome 은 2.5초 뒤 자동으로 terms 로 넘어가므로, 뒤로 가면 곧바로 되돌아온다.
        // 그래서 terms 의 이전 단계는 name 으로 건너뛴다.
        case .terms: step = .name
        case .welcome: step = .name
        case .name: step = .budget
        case .budget: step = .date
        // **초대 단계에는 뒤로가기를 달지 않는다** — 저장이 이미 끝난 뒤라
        // 되돌아갈 곳이 없다.
        case .date, .celebration, .invite: break
        }
    }

    // MARK: - 저장

    /// 웹 `handleGoToMain()`.
    /// 비로그인이면 API 호출 없이 게스트 플래그만 세우고 main 으로 간다.
    func submit(env: AppEnvironment, guest: GuestStore, onDone: @escaping () -> Void) async {
        guard !submitting else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let budgetValue = Int(budget) ?? 0
        let agreementDate = KstDate.todayString()

        guest.save(name: trimmedName, budget: budgetValue, weddingDate: date)
        guest.saveAgreement(
            requiredAgreementDate: agreementDate,
            adAgreementDate: agreeMarketing ? agreementDate : nil
        )

        let token = await env.tokenStore.currentToken()
        guard let token, !token.isEmpty else {
            onDone()
            return
        }

        submitting = true
        defer { submitting = false }

        let request = PlanSettingRequest(
            weddingDate: date.dateString,
            budget: budgetValue,
            name: trimmedName,
            requiredAgreementDate: agreementDate,
            adAgreementDate: agreeMarketing ? agreementDate : nil
        )

        do {
            try await env.api.sendIgnoringData(Endpoint.createSetting(request))
        } catch {
            // 웹과 동일하게 POST 가 실패해도 진행하되, 실패 사실은 알린다.
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            onDone()
            return
        }

        // **저장이 성공한 뒤에야 초대 단계를 연다.**
        //
        // 초대를 약관 앞으로 옮기지 말 것. 방과 공유 코드는 카카오 로그인 때 이미
        // 만들어져 링크 자체는 그때도 유효하지만, 비어 있는 건 방이 아니라
        // **내용**이다 — 날짜·예산·이름은 바로 위 `POST /plan/setting` 에서만
        // 저장된다. 앞에 두면 (1) 초대받은 사람이 빈 플랜에 들어오고,
        // (2) 필수·제3자 제공 동의를 받기 전에 접근 권한을 주는 링크가 나가고,
        // (3) 초대만 보내고 약관에서 이탈하면 상대가 영영 빈 플랜에 남는다.
        step = .invite
        await loadInviteURL(env: env)
    }

    // MARK: - 초대

    /// 공유 코드를 받아 링크를 만들어 둔다. 실패해도 단계는 진행한다 —
    /// **어떤 경우에도 앱으로 들어갈 수 있어야 한다.**
    func loadInviteURL(env: AppEnvironment) async {
        inviteLoading = true
        defer { inviteLoading = false }
        guard let code = try? await env.api.send(Endpoint.shareCode(), decoding: ShareCode.self)
        else { return }
        inviteURL = ShareLink.inviteURL(
            webBaseURL: AppConfig.webBaseURL,
            code: code.shareCode,
            // **`?as=spouse` 가 빠지면 배우자로 부르고도 상대가 READ 로 들어온다.**
            asSpouse: true
        )
    }
}
