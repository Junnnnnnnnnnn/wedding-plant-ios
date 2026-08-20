import SwiftUI
import WPDomain

@main
struct WeddingPlantApp: App {
    @StateObject private var env = AppEnvironment.bootstrap()
    @StateObject private var guest = GuestStore()

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
                .task {
                    if !env.isDemo {
                        await env.refreshAuthState()
                    }
                    // 스크린샷·수동 확인용. 실행 인자로 공유 링크를 흉내 낸다.
                    if let code = Self.launchShareCode() {
                        env.pendingShareCode = code
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
