import SwiftUI
import WPDomain

/// 최상위 화면 전환.
///
/// 웹의 `GuestGate` + `AuthRedirectToMain` 이 하던 일을 여기 한 곳에서 한다.
/// 웹은 주소를 직접 칠 수 있어 화면마다 게이트가 새는 구멍이 있었지만
/// (`/main` 에만 걸었다가 `/calendar` 로 샜다), 앱은 진입이 여기 하나뿐이다.
///
/// | 상태 | 보여 주는 것 |
/// | --- | --- |
/// | 토큰 없음 | ``LandingView`` (들어오는 문) |
/// | 토큰 있고 플랜 미완성 | ``SettingView`` (온보딩 — 남은 질문) |
/// | 토큰 있고 플랜 완성 | ``MainTabShell`` |
/// | 아직 물어보는 중 | 브랜드 화면 |
///
/// **`planComplete == nil` 을 `false` 와 같게 다루지 말 것.** 못 물어본 것을
/// "안 채웠다" 로 읽으면 기존 사용자가 앱을 켤 때마다 온보딩을 본다.
struct RootView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore
    @EnvironmentObject private var push: PushService
    @State private var tab: WPTab = .home
    /// 가이드는 **하단 탭바까지 덮어야** 하는데 탭바가 화면 바깥이라,
    /// 오버레이는 여기서 그리고 화면들은 띄우라는 신호만 올려보낸다.
    @StateObject private var guide = GuideController()
    @StateObject private var guideAnchors = GuideAnchors()

    var body: some View {
        Group {
            if !env.isAuthenticated {
                LandingView()
            } else if env.planComplete == false {
                // 온보딩은 셸(탭바)을 달지 않는다 — 중간에 홈으로 새면 안 된다.
                SettingView { env.markPlanComplete() }
            } else if env.planComplete == true {
                MainTabShell(tab: $tab)
            } else {
                AuthSplash()
            }
        }
        .environmentObject(guide)
        .environment(\.guideAnchors, guideAnchors)
        .overlay {
            if guide.visible {
                GuideOverlay(steps: guide.steps, anchors: guideAnchors) { guide.close() }
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
            ShareJoinView(shareCode: pending.code, asSpouse: pending.asSpouse) {
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
            get: {
                // **저장 값에 역할이 함께 실려 있다.** 코드만 읽으면 배우자 초대가
                // 조언자 초대로 조용히 바뀐다.
                env.pendingShareCode
                    .flatMap(ShareLink.Invite.init(storageValue:))
                    .map { PendingShare(code: $0.code, asSpouse: $0.asSpouse) }
            },
            set: { if $0 == nil { env.pendingShareCode = nil } }
        )
    }
}

/// 토큰은 있는데 플랜을 아직 못 물어본 짧은 사이.
///
/// 여기서 홈을 먼저 그리면 온보딩이 필요한 사람에게 빈 화면이 한 번 스쳤다가
/// 바뀐다. 반대로 "일정이 없어요" 같은 빈 상태를 말하지도 않는다 —
/// 아직 아무것도 모르는 상태다.
private struct AuthSplash: View {
    var body: some View {
        ZStack {
            WPColor.background.ignoresSafeArea()
            AppLogo(size: 56)
                .opacity(0.5)
        }
        .accessibilityIdentifier("root.splash")
    }
}

private struct PendingShare: Identifiable, Hashable {
    var code: String
    var asSpouse: Bool
    var id: String { asSpouse ? "\(code)?as=spouse" : code }
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
                    FeedView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomTabBar(active: $tab)
        }
        .background(WPColor.background)
    }
}
