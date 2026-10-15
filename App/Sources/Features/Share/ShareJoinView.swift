import SwiftUI
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 웹 `app/share/[shareCode]/page.tsx` 이식.
///
/// 공유 링크로 들어오면 `POST /plan/room/{shareCode}` 로 그 방에 참여시키고 참여 플랜 목록으로 보낸다.
/// 비로그인이면 코드를 남겨 두고 로그인 안내를 띄운다 — 로그인 직후 이어서 참여한다.
@MainActor
final class ShareJoinViewModel: ObservableObject {

    enum State: Equatable {
        /// 참여 요청 중 — 웹의 "공유 플랜 연결 중..."
        case joining
        case joined
        /// 비로그인 → 로그인 안내
        case loginRequired
        /// 신랑·신부 초대 — **수락 전에 반드시 묻는다**(안드로이드 `SpouseConfirm`).
        /// - myPlanCount: 내가 만들어 둔 일정 수. 못 셌으면 nil — 0 건이면 줄을 안 낸다.
        /// - hasSpouseSeat: 지금 다른 플랜의 신랑·신부인가. 못 알아냈으면 false — 지어내지 않는다.
        case askingSpouse(myPlanCount: Int?, hasSpouseSeat: Bool, ownerName: String?, joining: Bool)
        /// refused: 까닭이 있는 거절이라 다시 눌러도 같은 답 — "다시 시도" 를 내지 않는다.
        case failed(String, refused: Bool)
    }

    /// 안드로이드 `SpouseRules` 와 한 글자도 다르지 않게.
    static let inviteRoleRequiredMessage = "이 초대 링크는 더 이상 쓸 수 없어요. 신랑 · 신부 초대 링크를 새로 받아 주세요."
    static func joinErrorMessage(_ body: String?) -> String? {
        guard let body else { return nil }
        if body.contains("INVITE_ROLE_REQUIRED") { return inviteRoleRequiredMessage }
        if body.contains("PLAN_HAS_SPOUSE") { return "이미 신랑 · 신부가 함께하는 플랜이에요." }
        if body.contains("OWNER_HAS_SPOUSE") { return "내 플랜에 이미 신랑 · 신부가 있어요. 신랑 · 신부는 한 플랜에서만 함께할 수 있어요." }
        if body.contains("INVITER_IS_SPOUSE") { return "초대한 분은 이미 다른 플랜을 신랑 · 신부로 함께 쓰고 있어요." }
        if body.contains("PASS_ON_OWN_ROOM") { return "내 플랜에 준비 패스가 있어요. 패스는 플랜에 붙어 있어 옮겨지지 않아요 — 상대를 내 플랜에 신랑 · 신부로 초대해 주세요." }
        return nil
    }

    @Published private(set) var state: State = .joining

    let shareCode: String
    /// **초대 링크가 역할을 지닌다.** `?as=spouse` 가 없는 옛 링크는 서버에 묻지 않고 거절한다.
    let asSpouse: Bool

    init(shareCode: String, asSpouse: Bool) {
        self.shareCode = shareCode
        self.asSpouse = asSpouse
    }

    func join(env: AppEnvironment, guest: GuestStore) async {
        let code = shareCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else {
            state = .failed("잘못된 공유 링크입니다.", refused: false)
            return
        }
        // 옛 "함께 보는 사람" 링크. 로그인 뒤 이 초대로 다시 끌려오지 않게 남긴 코드도 지운다
        guard asSpouse else {
            guest.shareAfterLogin = nil
            state = .failed(Self.inviteRoleRequiredMessage, refused: true)
            return
        }
        let token = await env.tokenStore.currentToken()
        guard let token, !token.isEmpty else {
            // 로그인 후 이어서 참여할 수 있게 코드를 남겨 둔다 (웹 `setShareAfterLogin`).
            guest.shareAfterLogin = code + "?as=spouse"
            state = .loginRequired
            return
        }
        // **수락 전에 반드시 묻는다.** 개수·자리는 나란히 세고, 못 세면 줄 없이 묻는다.
        state = .askingSpouse(myPlanCount: nil, hasSpouseSeat: false, ownerName: nil, joining: false)
        async let normal = try? env.api.send(Endpoint.scheduleList(status: .normal), decoding: SchedulePage.self)
        async let done = try? env.api.send(Endpoint.scheduleList(status: .completed), decoding: SchedulePage.self)
        async let rooms = try? env.api.send(Endpoint.roomList(), decoding: RoomList.self)
        let (n, d, r) = await (normal, done, rooms)
        guard case let .askingSpouse(_, _, _, joining) = state else { return }
        let count = (n != nil && d != nil) ? (n!.list.count + d!.list.count) : nil
        let bound = r.flatMap { BoundRoom.find(in: $0.list, planUserId: JWTDecoder.planUserId(from: token)) }
        let owner = bound?.ownerName.trimmingCharacters(in: .whitespaces)
        state = .askingSpouse(myPlanCount: count, hasSpouseSeat: bound != nil, ownerName: owner?.isEmpty == false ? owner : nil, joining: joining)
    }

    /// 경고에서 "네, 같이 준비할게요". 경고에 "그 플랜에서는 빠지게 돼요" 줄이 떠 있었을 때만 옮기는 데 동의한 것이다.
    func confirmSpouseJoin(env: AppEnvironment, guest: GuestStore) async {
        guard case let .askingSpouse(count, seat, owner, joining) = state, !joining else { return }
        state = .askingSpouse(myPlanCount: count, hasSpouseSeat: seat, ownerName: owner, joining: true)
        await performJoin(code: shareCode.trimmingCharacters(in: .whitespaces), env: env, guest: guest, moveSeat: seat)
    }

    /// 참여하지 않고 나간다 — 로그인 뒤 다시 이 초대로 끌려오지 않게 남겨 둔 코드를 지운다.
    func abandon(guest: GuestStore) { guest.shareAfterLogin = nil }

    private func performJoin(code: String, env: AppEnvironment, guest: GuestStore, moveSeat: Bool) async {
        let asked = state
        do {
            try await env.api.sendIgnoringData(Endpoint.joinRoom(shareCode: code, asSpouse: asSpouse, moveSeat: moveSeat))
            guest.shareAfterLogin = nil
            // **귀속 캐시를 비운다.** 안 비우면 방금 배우자가 된 사람이 다음 진입에서 자기 개인 플랜(빈 화면)을 본다.
            env.boundRoom = .unknown
            env.boundRoomPlan = nil
            await env.refreshBoundRoom()
            env.roomsRevision += 1
            state = .joined
        } catch let error as APIError {
            if case .http(let status, let body) = error, status == 409 {
                // 다른 플랜의 신랑·신부인데 동의 표시 없이 갔다 — 거절이 아니라 그 줄을 붙여 경고를 다시 띄운다
                if body?.contains("SPOUSE_IN_OTHER_ROOM") == true {
                    if case let .askingSpouse(count, _, owner, _) = asked {
                        state = .askingSpouse(myPlanCount: count, hasSpouseSeat: true, ownerName: owner, joining: false)
                    } else {
                        state = .askingSpouse(myPlanCount: nil, hasSpouseSeat: true, ownerName: nil, joining: false)
                    }
                    return
                }
                if let refused = Self.joinErrorMessage(body) {
                    guest.shareAfterLogin = nil
                    state = .failed(refused, refused: true)
                    return
                }
            }
            if case .http(let status, _) = error, status == 404 {
                guest.shareAfterLogin = nil
                state = .failed("존재하지 않는 공유 링크입니다. 링크를 다시 확인해 주세요.", refused: false)
                return
            }
            if case .transport = error {
                state = .failed("네트워크 오류로 참여하지 못했습니다. 연결을 확인하고 다시 시도해 주세요.", refused: false)
                return
            }
            state = .failed("플랜에 참여하지 못했습니다. 잠시 후 다시 시도해 주세요.", refused: false)
        } catch {
            state = .failed("플랜에 참여하지 못했습니다. 잠시 후 다시 시도해 주세요.", refused: false)
        }
    }
}

struct ShareJoinView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore

    @StateObject private var model: ShareJoinViewModel

    /// 참여에 성공했을 때. 호출부가 참여 플랜 목록으로 보낸다.
    var onJoined: () -> Void
    /// 로그인 화면으로.
    var onLoginRequested: () -> Void
    /// 닫기 — 웹은 홈으로 돌아간다.
    var onClose: () -> Void

    init(
        shareCode: String,
        asSpouse: Bool,
        onJoined: @escaping () -> Void,
        onLoginRequested: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        _model = StateObject(
            wrappedValue: ShareJoinViewModel(shareCode: shareCode, asSpouse: asSpouse)
        )
        self.onJoined = onJoined
        self.onLoginRequested = onLoginRequested
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            WPColor.background.ignoresSafeArea()

            switch model.state {
            case let .failed(message, refused):
                JoinFailedCard(message: message, refused: refused) {
                    model.abandon(guest: guest)
                    onClose()
                } onRetry: {
                    Task { await model.join(env: env, guest: guest) }
                }

            case .loginRequired:
                LoginRequiredCard(
                    // 로그인 전 초대 화면에도 같은 사실을 **미리** 단다.
                    spouseNotice: model.asSpouse,
                    onLogin: onLoginRequested,
                    onClose: onClose
                )

            case let .askingSpouse(count, seat, owner, joining):
                // 경고는 떠 있는 창이다 — 뒤는 어둡게(안드로이드 Dialog)
                Color.black.opacity(0.4).ignoresSafeArea()
                SpouseJoinWarningCard(myPlanCount: count, hasSpouseSeat: seat, currentSpouseOwnerName: owner, loading: joining) {
                    Task { await model.confirmSpouseJoin(env: env, guest: guest) }
                } onCancel: {
                    // 초대는 링크에 남아 있으니 언제든 다시 들어올 수 있다
                    model.abandon(guest: guest)
                    onClose()
                }

            case .joining, .joined:
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(WPColor.primary)
                    Text("공유 플랜 연결 중...")
                        .font(WPFont.hak(14, .bold))
                        .foregroundStyle(WPColor.gray400)
                }
            }
        }
        .accessibilityIdentifier("share.screen")
        .task { await model.join(env: env, guest: guest) }
        .onChange(of: model.state) { _, state in
            if state == .joined { onJoined() }
        }
    }
}

// MARK: - 부품

/// 참여 실패 카드 — 안드로이드 `JoinFailedCard`. 상태를 들지 않아 화면 없이 찍는다.
struct JoinFailedCard: View {
    var message: String
    var refused: Bool
    var onHome: () -> Void
    var onRetry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("플랜에 참여하지 못했어요").wpTypography(18, .bold).foregroundStyle(WPColor.textPrimary)
            // 거절 문장은 두 줄이 넘어 단어 중간에서 끊기지 않게 한다("링크/를")
            Text(message.wpKeepAll).wpTypography(14, lineHeight: 20).foregroundStyle(WPColor.gray500)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true).padding(.top, 8)
            HStack(spacing: 8) {
                Button(action: onHome) {
                    Text("홈으로").wpTypography(14, .bold).foregroundStyle(WPColor.textPrimary)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(WPColor.gray200, lineWidth: 1))
                }
                .buttonStyle(.plain).accessibilityIdentifier("share.close")
                // 까닭이 있는 거절은 다시 눌러도 같은 답이다
                if !refused {
                    Button(action: onRetry) {
                        Text("다시 시도").wpTypography(14, .bold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("share.retry")
                }
            }
            .padding(.top, 20)
        }
        .padding(24)
        .frame(maxWidth: 384)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 24)
    }
}

private struct LoginRequiredCard: View {
    /// 배우자 초대인지. 맞으면 귀속된다는 사실을 **미리** 알려 준다.
    var spouseNotice: Bool = false
    var onLogin: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("공유 플랜을 보려면 로그인해 주세요")
                .font(WPFont.hak(18, .bold))
                .foregroundStyle(WPColor.textPrimary)
                .multilineTextAlignment(.center)

            // 로그인하고 나면 곧바로 참여가 끝나 되돌아볼 자리가 없다.
            // **여기서는 개수를 말하지 않는다** — 그 사람에게 플랜이 있는지 알 수 없다.
            if spouseNotice {
                Spacer().frame(height: 10)
                Text("신랑·신부 초대예요. 수락하면 이 방이 내 플랜이 되고, 지금 만들어 둔 일정은 화면에서 내려갑니다(지워지지는 않아요).")
                    .font(WPFont.hak(13))
                    .lineSpacing(5)
                    .foregroundStyle(WPColor.fgSubtle)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer().frame(height: 20)

            Button(action: onLogin) {
                HStack(spacing: 8) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 15))
                    Text("카카오로 로그인")
                        .font(WPFont.hak(15, .bold))
                }
                .foregroundStyle(WPColor.kakaoText)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(WPColor.kakao, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("share.login")

            Spacer().frame(height: 8)

            Button(action: onClose) {
                Text("닫기")
                    .font(WPFont.hak(14, .bold))
                    .foregroundStyle(WPColor.gray500)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("share.close")
        }
        .padding(24)
        .frame(maxWidth: 384)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 24)
    }
}


/// 신랑·신부 초대를 수락하기 **전에** 무슨 일이 일어나는지 알린다 — 안드로이드 `SpouseJoinWarningDialog`
/// (웹 `SpouseJoinWarningModal`). **지워진다고 쓰지 않는다** — 그대로 있고 그만두면 다시 보인다.
/// 초대한 사람 이름은 알 길이 없어 "초대한 사람의" 로 적는다.
struct SpouseJoinWarningCard: View {
    var myPlanCount: Int?
    var hasSpouseSeat: Bool = false
    var currentSpouseOwnerName: String?
    var loading: Bool = false
    var onConfirm: () -> Void
    var onCancel: () -> Void

    private var seatBody: String {
        let owner = currentSpouseOwnerName?.trimmingCharacters(in: .whitespaces) ?? ""
        return owner.isEmpty
            ? "지금 신랑 · 신부로 함께하는 플랜이 있어요. 다른 플랜에 신랑 · 신부로 참여하면 그 플랜에서는 빠지게 돼요."
            : "지금은 \(owner)님 플랜의 신랑 · 신부예요. 다른 플랜에 신랑 · 신부로 참여하면 \(owner)님 플랜에서는 빠지게 돼요."
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    Text("지금부터 초대한 사람의 플랜을\n같이 쓰게 돼요").wpTypography(16, .bold, lineHeight: 23)
                        .foregroundStyle(WPColor.stone900).multilineTextAlignment(.center)
                    Text("신랑 · 신부는 플랜 하나를 함께 씁니다. 홈 · 플랜 보드 · 예산이 모두 초대한 사람의 플랜으로 바뀌고, 같이 고칠 수 있어요.".wpKeepAll)
                        .wpTypography(14, lineHeight: 22).foregroundStyle(WPColor.stone700).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true).padding(.top, 12)
                    // 내가 만든 게 실제로 있을 때만 개수를 말한다
                    if let myPlanCount, myPlanCount > 0 {
                        warn("내가 만들어 둔 일정 \(myPlanCount)건은 화면에서 보이지 않게 돼요", "지워지는 건 아니에요. 함께하기를 그만두면 다시 보여요.")
                    }
                    if hasSpouseSeat { warn("신랑 · 신부는 한 플랜에서만 할 수 있어요", seatBody) }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = ceil($0) }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: contentHeight)
            Button(action: onConfirm) {
                Text(loading ? "참여하는 중..." : "네, 같이 준비할게요").wpTypography(14, .semibold).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(WPColor.primary.opacity(loading ? 0.7 : 1), in: Capsule())
            }
            .buttonStyle(.plain).allowsHitTesting(!loading).padding(.top, 24).accessibilityIdentifier("share.spouse.confirm")
            Button(action: onCancel) {
                Text("아직 아니요").wpTypography(14, .semibold).foregroundStyle(WPColor.stone700)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(Color.white, in: Capsule())
                    .overlay(Capsule().stroke(WPColor.stone300, lineWidth: 2))
            }
            .buttonStyle(.plain).allowsHitTesting(!loading).padding(.top, 10).accessibilityIdentifier("share.spouse.cancel")
        }
        .padding(.horizontal, 20).padding(.vertical, 24)
        .frame(maxWidth: 384)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    @State private var contentHeight: CGFloat = 400

    private func warn(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.wpKeepAll).wpTypography(13, .bold, lineHeight: 20).foregroundStyle(WPColor.warnTitle)
                .fixedSize(horizontal: false, vertical: true)
            Text(body.wpKeepAll).wpTypography(12, lineHeight: 18).foregroundStyle(WPColor.warnBody)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(WPColor.warnBg, in: RoundedRectangle(cornerRadius: 12))
        .padding(.top, 16)
    }
}
