import SwiftUI

/// 최상위 화면 전환.
///
/// 로그인/게스트 진입 전에는 랜딩, 이후에는 탭 셸을 보여준다.
struct RootView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore
    @EnvironmentObject private var push: PushService
    @State private var tab: WPTab = .home

    var body: some View {
        Group {
            if env.isAuthenticated {
                MainTabShell(tab: $tab)
            } else {
                LandingView()
            }
        }
        .tint(WPColor.primary)
        // 앱이 켜져 있을 때 온 알림은 배너 대신 토스트로 (배너까지 뜨면 두 번 알리는 셈이다).
        .overlay(alignment: .top) {
            if let toast = push.toast {
                PushToast(text: toast) { push.toast = nil }
            }
        }
        // 알림을 눌러 들어온 채팅방.
        .fullScreenCover(item: pushChatBinding) { room in
            ChatView(chatRoomId: room.id)
                .environmentObject(env)
                .environmentObject(push)
        }
        // 공유 링크로 들어오면 어느 화면에 있든 참여 화면이 덮는다 (웹은 `/share/{code}` 페이지).
        .fullScreenCover(item: shareCodeBinding) { pending in
            ShareJoinView(shareCode: pending.code) {
                // 참여 성공 → 참여 플랜 목록 (웹 `router.replace("/plan-list")`)
                env.pendingShareCode = nil
                tab = .rooms
            } onLoginRequested: {
                env.pendingShareCode = nil
                env.isAuthenticated = false
            } onClose: {
                env.pendingShareCode = nil
            }
            .environmentObject(env)
            .environmentObject(guest)
        }
    }

    private var pushChatBinding: Binding<PendingChatRoom?> {
        Binding(
            get: { push.pendingChatRoomId.map(PendingChatRoom.init(id:)) },
            set: { if $0 == nil { push.pendingChatRoomId = nil } }
        )
    }

    /// `fullScreenCover(item:)` 이 Identifiable 을 요구해서 감싼다.
    private var shareCodeBinding: Binding<PendingShare?> {
        Binding(
            get: { env.pendingShareCode.map(PendingShare.init(code:)) },
            set: { if $0 == nil { env.pendingShareCode = nil } }
        )
    }
}

private struct PendingShare: Identifiable, Hashable {
    var code: String
    var id: String { code }
}

private struct PendingChatRoom: Identifiable, Hashable {
    var id: Int
}

/// 앱이 켜져 있을 때 온 알림을 위쪽에 잠깐 띄운다.
private struct PushToast: View {
    var text: String
    var onDismiss: () -> Void

    var body: some View {
        Text(text)
            .font(WPFont.hak(14, .bold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                WPColor.textPrimary.opacity(0.95),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 12, y: 6)
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onTapGesture(perform: onDismiss)
            .task {
                // 3초 뒤 자동으로 사라진다.
                try? await Task.sleep(for: .seconds(3))
                onDismiss()
            }
    }
}

/// 웹의 `BottomTabBar` 가 붙은 화면 셸.
///
/// 각 화면이 자기 배경과 상태바 여백을 직접 처리하므로 여기서는 배치만 한다.
struct MainTabShell: View {
    @Binding var tab: WPTab

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .home:
                    MainView()
                case .rooms:
                    PlanListView()
                case .settings:
                    UserView()
                case .feed:
                    // 피드는 준비중 알림만 띄우고 탭이 바뀌지 않으므로 여기 올 일이 없다.
                    MainView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomTabBar(active: $tab)
        }
        .background(WPColor.background)
    }
}
