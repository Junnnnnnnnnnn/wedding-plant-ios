import SwiftUI
import WPDomain

@main
struct WeddingPlantApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var env = AppEnvironment.bootstrap()
    @StateObject private var guest = GuestStore()
    @StateObject private var push = PushService()

    /// `-WPShareCode ABC123` 로 넘긴 값.
    private static func launchShareCode() -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-WPShareCode"),
              arguments.indices.contains(index + 1)
        else { return nil }
        return ShareLink.shareCode(from: arguments[index + 1])
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(env)
                .environmentObject(guest)
                .environmentObject(push)
                .task {
                    if !env.isDemo {
                        AppDelegate.pushService = push
                        push.start(env: env)
                        await env.refreshAuthState()
                    }
                    // 스크린샷·수동 확인용. 실행 인자로 공유 링크를 흉내 낸다.
                    if let code = Self.launchShareCode() {
                        env.pendingShareCode = code
                    }
                }
                // 로그인 상태가 되면 알림 권한을 묻고 기기 토큰을 등록한다.
                //
                // 설치 후 첫 로그인에는 FCM 갱신 콜백이 오지 않으므로,
                // 갱신 때만 등록하면 새로 깐 기기에 알림이 영영 안 온다.
                .onChange(of: env.isAuthenticated) { _, loggedIn in
                    guard loggedIn, !env.isDemo else { return }
                    Task {
                        await push.requestAuthorizationIfNeeded()
                        await push.registerCurrentToken()
                    }
                }
                // 웹과 같은 주소(`/share/{code}`)를 Universal Link 로 받는다.
                // 실제로 동작하려면 웹 서버에 `apple-app-site-association` 이 있어야 한다.
                .onOpenURL { url in
                    env.handle(url: url)
                }
        }
    }
}
