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
        case permissions
        /// **맨 끝, 약관 동의 다음.**
        ///
        /// 이 앱의 메리트가 "신랑·신부가 같이" 인데 예전에는 초대 진입점이 홈의
        /// 작은 점선 `＋` 원 하나였고, 그마저 멤버가 나 혼자일 때만 떠서 조언자
        /// 한 명만 들어와도 사라졌다. 온보딩은 이미 한 번에 하나씩 묻는 연출이라,
        /// 여기에 한 칸을 더하면 초대가 부탁이 아니라 **절차**로 읽힌다.
        case invite

        /// 뒤로가기를 달지 않는 단계 — 축하·날짜(처음), 권한·초대(약관에서 저장이 이미 끝남)
        static let noBack: Set<Step> = [.celebration, .date, .permissions, .invite]
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
    /// 이 링크로 누가 신랑·신부로 들어올 수 있는가(`share-code` 의 canInvite). 이미 신랑·신부와
    /// 함께 쓰는 플랜이 있으면 false — 보낸 링크로는 아무도 못 들어와서(서버 409) 부를 카드를 잠근다.
    @Published var canInvite = true
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
        // 저장소 값은 Double 이라 그대로 넣으면 "5000.0" 이 칸에 보였습니다 — 금액(만원)은 정수 숫자 칸입니다
        if let saved = guest.budget, saved.isFinite { budget = String(Int(saved.rounded())) }
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
            budget = MoneyInput.text(value)
        }
        if let raw = user.weddingDate, let parsed = KstDate(dateString: raw) {
            date = parsed
        }
        ready = true
    }

    // MARK: - 입력

    func setBudget(_ value: String) {
        // 최대 7자리, 소수 금액도 서버 값 그대로 유지.
        budget = MoneyInput.accept(value, previous: budget, maxDigits: 7)
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
        case .date, .celebration, .permissions, .invite: break
        }
    }

    // MARK: - 저장

    /// 웹 `handleGoToMain()`.
    /// 비로그인이면 API 호출 없이 게스트 플래그만 세우고 main 으로 간다.
    func submit(env: AppEnvironment, guest: GuestStore, onDone: @escaping () -> Void) async {
        guard !submitting else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let budgetValue = Double(budget) ?? 0
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
            // 저장에 실패하면 **이동하지 않는다**(안드로이드와 같은 문장). 적은 값은 그대로 두고 다시 시도하게 한다.
            errorMessage = "설정을 저장하지 못했습니다. 네트워크 확인 후 다시 시도해 주세요."
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
        // 앞서 저장이 한 번 실패했었다면 그 문구가 다음 단계에 남지 않게 걷는다.
        errorMessage = nil
        step = .permissions
        await loadInviteURL(env: env)
    }

    // MARK: - 초대

    /// 공유 코드를 받아 링크를 만들어 둔다. 실패해도 단계는 진행한다 —
    /// **어떤 경우에도 앱으로 들어갈 수 있어야 한다.**
    func loadInviteURL(env: AppEnvironment) async {
        inviteLoading = true
        defer { inviteLoading = false }
        let code = try? await env.api.send(Endpoint.shareCode(), decoding: ShareCode.self)
        let trimmed = code?.shareCode.trimmingCharacters(in: .whitespaces) ?? ""
        canInvite = code?.canInvite ?? true
        inviteURL = trimmed.isEmpty ? nil : ShareLink.inviteURL(
            webBaseURL: AppConfig.webBaseURL,
            code: trimmed,
            // **`?as=spouse` 가 빠지면 배우자로 부르고도 상대가 READ 로 들어온다.**
            asSpouse: true
        )
        // 다시 받아 링크가 생겼으면 "링크를 불러오지 못했습니다" 를 걷는다 — 다른 까닭의 오류는 남긴다
        if inviteURL != nil, let current = errorMessage, Self.inviteLinkErrors.contains(current) { errorMessage = nil }
        // 이미 골라 둔 '부를게요' 는 풀어 둔다 — 잠긴 카드를 고른 채로 두면 버튼이 보낼 수 없는 초대를 보낸다
        if !canInvite, inviteChoice == .invite { inviteChoice = .none }
    }

    /// '초대장 보내기' 를 눌렀는데 링크가 없을 때 — 웹 `useSpouseInvite` 와 같은 문장을 띄우고 머문다.
    /// 받는 중이 아니면 한 번 더 받아 본다(잠깐 끊겼던 경우 다음 누름에 보낼 수 있게).
    func onInviteLinkMissing(env: AppEnvironment) async {
        let loading = inviteLoading
        errorMessage = loading ? Self.inviteLinkPreparing : Self.inviteLinkFailed
        if !loading { await loadInviteURL(env: env) }
    }

    func setInviteChoice(_ choice: InviteChoice) {
        inviteChoice = choice
        errorMessage = nil
    }

    /// 이미 신랑·신부가 있는 플랜(안드로이드 `SpouseRules.COUPLE_ALREADY_MESSAGE`)
    static let coupleAlreadyMessage = "이미 신랑 · 신부와 함께 쓰는 플랜이 있어요."
    /// 초대 링크를 받는 중에 '초대장 보내기' 를 눌렀을 때(웹 `useSpouseInvite` 와 같은 문장)
    static let inviteLinkPreparing = "준비 중입니다."
    /// 초대 링크를 못 받았을 때(웹 `useSpouseInvite` 와 같은 문장)
    static let inviteLinkFailed = "링크를 불러오지 못했습니다."
    private static let inviteLinkErrors: Set<String> = [inviteLinkPreparing, inviteLinkFailed]
}
