import Combine
import Foundation
import WPModels
import WPNetworking

/// 안드로이드 `PlanListViewModel` 대응.
@MainActor
final class PlanListViewModel: ObservableObject {
    @Published var loading = true
    @Published var rooms: [Plan] = []
    @Published var errorMessage: String?
    @Published var isGuest = false

    func load(env: AppEnvironment) async {
        let token = await env.tokenStore.currentToken()
        guard let token, !token.isEmpty else {
            // 비로그인은 API 를 부르지 않는다. 게스트가 받는 401 을 세션 만료로 오인하면 안 된다.
            loading = false
            isGuest = true
            rooms = []
            return
        }

        isGuest = false
        loading = true
        defer { loading = false }

        do {
            let page = try await env.api.send(Endpoint.roomList(), decoding: RoomList.self)
            rooms = page.list
            errorMessage = nil
        } catch {
            rooms = []
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
