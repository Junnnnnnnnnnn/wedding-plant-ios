import Combine
import Foundation
import SwiftUI
import WPDomain
import WPModels
import WPNetworking

/// 앱 전역 의존성 컨테이너.
///
/// 웹의 `ApiProvider` / `WeddingProvider` 에 대응한다.
@MainActor
final class AppEnvironment: ObservableObject {
    let api: APIClient
    let tokenStore: any TokenStoring
    /// 백엔드 주소. 채팅 소켓처럼 `APIClient` 를 거치지 않는 연결에 쓴다.
    let baseURL: URL
    /// 데모(목업) 모드 여부. CI 스크린샷 촬영과 프리뷰에서 true.
    let isDemo: Bool

    /// 로그인 여부. 화면 전환 판단에 쓴다.
    @Published var isAuthenticated: Bool = false

    /// 공유 링크로 들어왔을 때의 코드. 값이 있으면 참여 화면을 덮어 띄운다.
    @Published var pendingShareCode: String?

    /// 이름·결혼일·예산이 모두 채워졌는지. `nil` 이면 **아직 물어보지 않은 것**이다.
    ///
    /// 웹 `AuthRedirectToMain` 이 하는 일과 같다 — 토큰이 살아 있어도 플랜이
    /// 덜 찼으면 남은 질문을 받는 온보딩으로 보낸다.
    /// `false` 와 `nil` 을 같게 다루면 기존 사용자가 앱을 켤 때마다 온보딩을
    /// 한 번씩 보게 된다.
    @Published var planComplete: Bool?

    init(api: APIClient, tokenStore: any TokenStoring, baseURL: URL, isDemo: Bool) {
        self.api = api
        self.tokenStore = tokenStore
        self.baseURL = baseURL
        self.isDemo = isDemo
    }

    /// 실행 인자·환경에 따라 라이브 / 데모 환경을 만든다.
    static func bootstrap() -> AppEnvironment {
        let isDemo = ProcessInfo.processInfo.arguments.contains("-WPDemoMode")
            || ProcessInfo.processInfo.environment["WP_DEMO_MODE"] == "1"

        let baseURL = Self.baseURL()

        if isDemo {
            // 온보딩을 보려면 **로그인은 됐고 플랜만 덜 찬** 사람이어야 한다.
            // 예전에는 비로그인으로 시작해 랜딩의 "로그인 없이 둘러보기" 를 눌러
            // 들어갔는데, 그 입구를 없앴다(웹·안드로이드와 같음).
            let forceOnboarding = ProcessInfo.processInfo.arguments.contains("-WPForceOnboarding")

            // 비로그인 화면(공유 참여의 로그인 안내 등)을 보려면 토큰이 없어야 한다.
            let loggedOut = ProcessInfo.processInfo.arguments.contains("-WPLoggedOut")
            let store = InMemoryTokenStore(token: loggedOut ? nil : DemoData.token)
            let client = APIClient(
                baseURL: baseURL,
                transport: DemoTransport(newUser: forceOnboarding),
                tokenStore: store
            )
            let env = AppEnvironment(
                api: client,
                tokenStore: store,
                baseURL: baseURL,
                isDemo: true
            )
            env.isAuthenticated = !loggedOut
            // 데모는 네트워크를 기다리지 않고 바로 화면을 낸다.
            env.planComplete = loggedOut ? nil : !forceOnboarding
            return env
        }

        let store = KeychainTokenStore()
        let client = APIClient(baseURL: baseURL, transport: URLSessionTransport(), tokenStore: store)
        return AppEnvironment(api: client, tokenStore: store, baseURL: baseURL, isDemo: false)
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

    /// 공유 링크(Universal Link / 커스텀 스킴)를 받는다.
    ///
    /// - Returns: 공유 링크로 인식했는지. 아니면 다른 처리기가 볼 수 있게 false.
    @discardableResult
    func handle(url: URL) -> Bool {
        guard let code = ShareLink.shareCode(from: url) else { return false }
        pendingShareCode = code
        return true
    }

    /// 저장된 토큰을 읽어 로그인 상태를 갱신하고, 플랜이 다 찼는지까지 확인한다.
    func refreshAuthState() async {
        let token = await tokenStore.currentToken()
        let hasToken = !(token ?? "").isEmpty
        isAuthenticated = hasToken
        guard hasToken else {
            planComplete = nil
            return
        }
        await refreshPlanCompletion()
    }

    /// `GET /plan/user` 로 플랜 완성 여부를 다시 읽는다.
    ///
    /// - 401 이면 죽은 토큰이므로 지우고 로그인 화면으로 돌려보낸다.
    /// - 그 밖의 실패(네트워크 등)에는 **온보딩으로 보내지 않는다.** 못 물어본 것을
    ///   "안 채웠다" 로 읽으면 기존 사용자가 이름·날짜·예산을 다시 답해야 한다.
    ///   웹도 같은 이유로 실패 시 화면을 그대로 둔다.
    func refreshPlanCompletion() async {
        do {
            let user = try await api.send(Endpoint.user(), decoding: PlanUser.self)
            planComplete = PlanCompletion.isComplete(user)
        } catch let error as APIError where error.requiresReauthentication {
            await signOut()
        } catch {
            planComplete = true
        }
    }

    /// 온보딩을 마친 직후. 다시 물어보지 않도록 바로 채워 둔다.
    func markPlanComplete() {
        planComplete = true
    }

    func signOut() async {
        await tokenStore.clear()
        isAuthenticated = false
        planComplete = nil
    }
}
