import SwiftUI

/// 최상위 화면 전환.
///
/// 로그인/게스트 진입 전에는 랜딩, 이후에는 탭 셸을 보여준다.
struct RootView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        Group {
            if env.isAuthenticated {
                MainTabShell()
            } else {
                LandingView()
            }
        }
        .tint(WPColor.primary)
    }
}

/// 웹의 `BottomTabBar` 가 붙은 화면 셸.
///
/// 각 화면이 자기 배경과 상태바 여백을 직접 처리하므로 여기서는 배치만 한다.
struct MainTabShell: View {
    @State private var tab: WPTab = .home

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
