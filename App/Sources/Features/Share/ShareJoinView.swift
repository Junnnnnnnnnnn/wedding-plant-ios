import SwiftUI
import WPDomain
import WPModels
import WPNetworking

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
        /// 배우자 초대 — **수락 전에 반드시 묻는다.**
        case askingSpouse(myScheduleCount: Int)
        case failed(String)
    }

    @Published private(set) var state: State = .joining

    let shareCode: String
    /// **초대 링크가 역할을 지닌다.** `?as=spouse` 면 귀속, 아니면 조언자다.
    let asSpouse: Bool

    init(shareCode: String, asSpouse: Bool) {
        self.shareCode = shareCode
        self.asSpouse = asSpouse
    }

    func join(env: AppEnvironment, guest: GuestStore) async {
        let code = shareCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else {
            state = .failed("잘못된 공유 링크입니다.")
            return
        }

        let token = await env.tokenStore.currentToken()
        guard let token, !token.isEmpty else {
            // 로그인 후 이어서 참여할 수 있게 코드를 남겨 둔다 (웹 `setShareAfterLogin`).
            guest.shareAfterLogin = code
            state = .loginRequired
            return
        }

        // **조언자(`READ`)는 귀속이 아니다.** 남의 플랜을 같이 보며 거드는 자리라
        // 자기 플랜을 그대로 두고, 경고도 띄우지 않고 바로 참여한다.
        if asSpouse {
            // **수락 전에 반드시 묻는다.** 예전에는 열자마자 참여시켜서, 눌러 보고
            // 나서야 자기 플랜이 안 보이는 걸 알았다.
            //
            // 내가 만들어 둔 일정이 **있을 때만** 개수를 말한다 — 0 건인 사람에게
            // "일정이 안 보이게 된다" 고 하면 없는 손해를 지어내는 셈이다.
            let mine = try? await env.api.send(
                Endpoint.scheduleList(status: .normal),
                decoding: SchedulePage.self
            )
            state = .askingSpouse(myScheduleCount: mine?.total ?? 0)
            return
        }

        await performJoin(code: code, env: env, guest: guest)
    }

    /// 배우자 초대를 수락했을 때. 거절하면 참여 요청이 **나가지 않는다.**
    func confirmSpouseJoin(env: AppEnvironment, guest: GuestStore) async {
        await performJoin(
            code: shareCode.trimmingCharacters(in: .whitespaces),
            env: env,
            guest: guest
        )
    }

    private func performJoin(code: String, env: AppEnvironment, guest: GuestStore) async {
        state = .joining
        do {
            try await env.api.sendIgnoringData(
                Endpoint.joinRoom(shareCode: code, asSpouse: asSpouse)
            )
            guest.shareAfterLogin = nil
            // **귀속 캐시를 비운다.** 안 비우면 방금 배우자가 된 사람이 다음 진입에서
            // 여전히 "귀속 아님" 으로 읽혀 자기 개인 플랜(빈 화면)을 본다.
            env.boundRoom = .unknown
            env.boundRoomPlan = nil
            state = .joined
        } catch let error as APIError {
            // 401 은 여기서 직접 처리한다. 공통 처리는 토큰만 지우고 끝나서
            // 재로그인 뒤에 참여가 이어지지 않는다.
            if error.requiresReauthentication {
                guest.shareAfterLogin = code
                state = .loginRequired
                return
            }
            state = .failed(Self.message(for: error))
        } catch {
            state = .failed("플랜에 참여하지 못했습니다. 잠시 후 다시 시도해 주세요.")
        }
    }

    private static func message(for error: APIError) -> String {
        if case let .http(status, _) = error, status == 404 {
            return "존재하지 않는 공유 링크입니다. 링크를 다시 확인해 주세요."
        }
        return "플랜에 참여하지 못했습니다. 잠시 후 다시 시도해 주세요."
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
            case .failed(let message):
                FailedCard(message: message) {
                    Task { await model.join(env: env, guest: guest) }
                } onClose: {
                    onClose()
                }

            case .loginRequired:
                LoginRequiredCard(
                    // 로그인 전 초대 화면에도 같은 사실을 **미리** 단다.
                    // 로그인하고 나면 곧바로 참여가 끝나 되돌아볼 자리가 없다.
                    // 거기서는 그 사람에게 플랜이 있는지 알 수 없으므로 **개수를
                    // 말하지 않는다.**
                    spouseNotice: model.asSpouse,
                    onLogin: onLoginRequested,
                    onClose: onClose
                )

            case .askingSpouse(let count):
                SpouseJoinWarningCard(myScheduleCount: count) {
                    Task { await model.confirmSpouseJoin(env: env, guest: guest) }
                } onCancel: {
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

private struct FailedCard: View {
    var message: String
    var onRetry: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("플랜에 참여하지 못했어요")
                .font(WPFont.hak(18, .bold))
                .foregroundStyle(WPColor.textPrimary)

            Spacer().frame(height: 8)

            Text(message)
                .font(WPFont.hak(14))
                .lineSpacing(6)
                .foregroundStyle(WPColor.gray500)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 20)

            HStack(spacing: 8) {
                Button(action: onClose) {
                    Text("닫기")
                        .font(WPFont.hak(14, .bold))
                        .foregroundStyle(WPColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(WPColor.gray200, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("share.close")

                Button(action: onRetry) {
                    Text("다시 시도")
                        .font(WPFont.hak(14, .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("share.retry")
            }
        }
        .padding(24)
        .frame(maxWidth: 384)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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


/// 배우자 초대를 수락하기 전에 묻는다.
///
/// 예전에는 `/share/[code]` 가 열자마자 참여시켜서, 눌러 보고 나서야 자기 플랜이
/// 안 보이는 걸 알았다.
///
/// **"사라집니다" 라고 쓰지 말 것.** 초대 전에 만들어 둔 개인 플랜은 화면에서
/// 내려갈 뿐 지워지지 않는다 — DB 에 그대로 있고 방에서 나가면 다시 홈에 뜬다.
/// 나중에 "사라진다더니 남아 있네" 가 되면 다음 경고까지 못 믿는다.
private struct SpouseJoinWarningCard: View {
    var myScheduleCount: Int
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("신랑·신부로 참여할까요?")
                .font(WPFont.hak(18, .bold))
                .foregroundStyle(WPColor.textPrimary)

            Spacer().frame(height: 10)

            Text("수락하면 **이 방이 내 플랜이 됩니다.** 홈·캘린더·예산이 전부 이 방을 보게 돼요.")
                .font(WPFont.hak(14))
                .lineSpacing(6)
                .foregroundStyle(WPColor.gray500)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // **일정이 있을 때만 개수를 말한다.** 0 건인 사람에게 "일정이 안 보이게
            // 된다" 고 하면 없는 손해를 지어내는 셈이다.
            if myScheduleCount > 0 {
                Spacer().frame(height: 12)
                Text("지금 만들어 둔 일정 \(myScheduleCount)건은 화면에서 내려가요. 지워지지는 않고, 방에서 나가면 다시 보입니다.")
                    .font(WPFont.hak(13))
                    .lineSpacing(5)
                    .foregroundStyle(WPColor.fgSubtle)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }

            Spacer().frame(height: 22)

            Button(action: onConfirm) {
                Text("신랑·신부로 참여하기")
                    .font(WPFont.hak(15, .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("share.spouse.confirm")

            Spacer().frame(height: 10)

            // 거절하면 **참여 요청이 나가지 않는다.**
            Button(action: onCancel) {
                Text("아니요, 돌아갈게요")
                    .font(WPFont.hak(14))
                    .foregroundStyle(WPColor.gray400)
                    .padding(8)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("share.spouse.cancel")
        }
        .padding(24)
        .frame(maxWidth: 340)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
        .padding(.horizontal, 20)
    }
}
