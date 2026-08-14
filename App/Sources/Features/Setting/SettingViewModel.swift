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
        case .date, .celebration: break
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
            // 웹과 동일하게 POST 가 실패해도 main 으로 이동하되, 실패 사실은 알린다.
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        onDone()
    }
}
