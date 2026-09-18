import Combine
import Foundation
import SwiftUI
import WPDomain
import WPModels
import WPNetworking
import WPUtils

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

    /// 신랑·신부로 귀속된 방. **모든 방 화면이 이 값을 본다.**
    ///
    /// 웹은 `BoundRoomRedirect` 가 주소에 `roomId` 를 얹는 방식이라 화면마다 새는
    /// 구멍이 있었다(`/main` 에만 걸었다가 `/calendar` 로 샜고, `/add-plen` 은
    /// `roomId` 없이 열리면 새 일정이 **화면에 보이지도 않는 개인 플랜에** 저장됐다).
    /// 앱에는 주소가 없으므로 **여기 한 곳**에 두고 화면들이 읽는다 — 목록을
    /// 화면마다 복사할 일이 없다.
    @Published var boundRoom: BoundRoom.Cache = .unknown

    /// 귀속된 방 그 자체. `/plan/room/list` 가 이름·날짜·멤버를 다 주므로 방 상세
    /// 엔드포인트를 따로 부르지 않는다.
    @Published var boundRoomPlan: Plan?

    /// 귀속된 방 id. 없으면 `nil` — 그때는 각 화면이 `/plan/user` 의 방을 쓴다.
    var boundRoomId: Int? { boundRoom.roomId }

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
            env.boundRoom = .notBound
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
        // **`?as=spouse` 를 반드시 함께 읽는다.** 코드만 읽으면 배우자로 부르고도
        // 상대가 조언자로 들어온다 — 초대 링크가 역할을 지닌다.
        guard let invite = ShareLink.invite(from: url) else { return false }
        pendingShareCode = invite.storageValue
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

    /// 귀속 여부를 다시 묻는다.
    ///
    /// **캐시가 "귀속 아님" 이면 가리지 않고, 아는 방이 있으면 묻기 전에 먼저
    /// 옮긴다.** 어느 쪽이든 뒤에서 다시 물어 값을 고쳐 둔다 — 그 사이 초대를
    /// 수락했을 수 있다.
    ///
    /// 캐시하지 않으면 귀속이 **아닌 대부분의 사용자도** 방 화면에 들어올 때마다
    /// `/plan/room/list` 를 기다리는 동안 흰 막을 본다. 고치려던 것보다 나쁘다.
    func refreshBoundRoom() async {
        guard let token = await tokenStore.currentToken(), !token.isEmpty else {
            boundRoom = .notBound
            return
        }
        let planUserId = JWTDecoder.planUserId(from: token)
        guard let list = try? await api.send(Endpoint.roomList(), decoding: RoomList.self) else {
            // 못 물어봤다고 귀속을 지우지 않는다 — 아는 값이 있으면 그대로 둔다.
            if boundRoom == .unknown { boundRoom = .notBound }
            return
        }
        if let room = BoundRoom.find(in: list.list, planUserId: planUserId) {
            boundRoom = .bound(roomId: room.roomId)
            boundRoomPlan = room
        } else {
            boundRoom = .notBound
            boundRoomPlan = nil
        }
    }

    func signOut() async {
        await tokenStore.clear()
        isAuthenticated = false
        planComplete = nil
        boundRoom = .unknown
        boundRoomPlan = nil
    }
}
