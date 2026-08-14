import Combine
import Foundation
import SwiftUI
import WPNetworking

/// 앱 전역 의존성 컨테이너.
///
/// 웹의 `ApiProvider` / `WeddingProvider` 에 대응한다.
@MainActor
final class AppEnvironment: ObservableObject {
    let api: APIClient
    let tokenStore: any TokenStoring
    /// 데모(목업) 모드 여부. CI 스크린샷 촬영과 프리뷰에서 true.
    let isDemo: Bool

    /// 로그인 여부. 화면 전환 판단에 쓴다.
    @Published var isAuthenticated: Bool = false

    init(api: APIClient, tokenStore: any TokenStoring, isDemo: Bool) {
        self.api = api
        self.tokenStore = tokenStore
        self.isDemo = isDemo
    }

    /// 실행 인자·환경에 따라 라이브 / 데모 환경을 만든다.
    static func bootstrap() -> AppEnvironment {
        let isDemo = ProcessInfo.processInfo.arguments.contains("-WPDemoMode")
            || ProcessInfo.processInfo.environment["WP_DEMO_MODE"] == "1"

        let baseURL = Self.baseURL()

        if isDemo {
            // 랜딩·설정 플로우를 처음부터 보려면 비로그인 + 빈 사용자로 시작해야 한다.
            // (기본 데모 유저는 플랜이 완성돼 있어 설정 화면이 곧바로 메인으로 넘어간다)
            let forceOnboarding = ProcessInfo.processInfo.arguments.contains("-WPForceOnboarding")

            let store = InMemoryTokenStore(token: DemoData.token)
            let client = APIClient(
                baseURL: baseURL,
                transport: DemoTransport(newUser: forceOnboarding),
                tokenStore: store
            )
            let env = AppEnvironment(api: client, tokenStore: store, isDemo: true)
            env.isAuthenticated = !forceOnboarding
            return env
        }

        let store = KeychainTokenStore()
        let client = APIClient(baseURL: baseURL, transport: URLSessionTransport(), tokenStore: store)
        return AppEnvironment(api: client, tokenStore: store, isDemo: false)
    }

    /// 백엔드 주소. Info.plist 의 `API_BASE_URL`(xcconfig 주입)을 우선 사용한다.
    private static func baseURL() -> URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !raw.trimmingCharacters(in: .whitespaces).isEmpty,
           let url = URL(string: raw) {
            return url
        }
        // 설정이 없으면 시뮬레이터에서 로컬 백엔드를 본다.
        return URL(string: "http://localhost:3111")!
    }

    /// 저장된 토큰을 읽어 로그인 상태를 갱신한다.
    func refreshAuthState() async {
        let token = await tokenStore.currentToken()
        isAuthenticated = !(token ?? "").isEmpty
    }

    func signOut() async {
        await tokenStore.clear()
        isAuthenticated = false
    }
}
