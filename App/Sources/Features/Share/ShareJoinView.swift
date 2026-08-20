import SwiftUI
import WPDomain
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
        case failed(String)
    }

    @Published private(set) var state: State = .joining

    let shareCode: String

    init(shareCode: String) {
        self.shareCode = shareCode
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

        state = .joining
        do {
            try await env.api.sendIgnoringData(Endpoint.joinRoom(shareCode: code))
            guest.shareAfterLogin = nil
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
        onJoined: @escaping () -> Void,
        onLoginRequested: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        _model = StateObject(wrappedValue: ShareJoinViewModel(shareCode: shareCode))
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
                LoginRequiredCard(onLogin: onLoginRequested, onClose: onClose)

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
    var onLogin: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("공유 플랜을 보려면 로그인해 주세요")
                .font(WPFont.hak(18, .bold))
                .foregroundStyle(WPColor.textPrimary)
                .multilineTextAlignment(.center)

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
