import SwiftUI

/// 최상위 화면 전환.
///
/// 로그인/게스트 진입 전에는 온보딩, 이후에는 탭 셸을 보여준다.
struct RootView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        Group {
            if env.isAuthenticated {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .background(WP.background)
        .tint(WP.accent)
    }
}

/// 웹의 `BottomTabBar` 에 대응. 홈 / 참여 플랜 / 설정 3개 탭.
struct MainTabView: View {
    var body: some View {
        TabView {
            MainView()
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }
                .accessibilityIdentifier("tab.home")

            PlanListView()
                .tabItem {
                    Label("참여 플랜", systemImage: "person.2.fill")
                }
                .accessibilityIdentifier("tab.planList")

            UserView()
                .tabItem {
                    Label("설정", systemImage: "gearshape.fill")
                }
                .accessibilityIdentifier("tab.user")
        }
    }
}
