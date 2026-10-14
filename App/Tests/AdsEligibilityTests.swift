import XCTest
import WPModels
import WPNetworking
import WPDomain
@testable import WeddingPlant

final class AdsEligibilityTests: XCTestCase {
    @MainActor func testPaidPlanHidesAdsAndRefreshFailureKeepsItHidden() async {
        let transport = EligibilityTransport(paid: true)
        let env = makeEnvironment(transport)
        await env.refreshAdEligibility()
        XCTAssertEqual(env.adGate, .hide)
        XCTAssertTrue(env.isMyAdRoom(7)); XCTAssertFalse(env.isMyAdRoom(8))
        await transport.fail()
        await env.refreshAdEligibility()
        XCTAssertEqual(env.adGate, .hide)
        await env.signOut()
        XCTAssertEqual(env.adGate, .unknown)
        XCTAssertFalse(AdsService.shared.ready)
    }
    @MainActor func testUnpaidAndUnknownAreDifferentAndLogoutDiscardsDelayedResult() async {
        let transport = EligibilityTransport(paid: false)
        let env = makeEnvironment(transport)
        XCTAssertEqual(env.adGate, .unknown)
        await env.refreshAdEligibility(); XCTAssertEqual(env.adGate, .show)
        await transport.delay()
        let request = Task { await env.refreshAdEligibility() }
        try? await Task.sleep(for: .milliseconds(10))
        await env.signOut()
        await request.value
        XCTAssertEqual(env.adGate, .unknown)
    }
    @MainActor private func makeEnvironment(_ transport: EligibilityTransport) -> AppEnvironment {
        let store = InMemoryTokenStore(token: DemoData.token)
        let url = URL(string: "https://example.test")!
        let env = AppEnvironment(api: APIClient(baseURL: url, transport: transport, tokenStore: store), tokenStore: store, baseURL: url, isDemo: true)
        env.isAuthenticated = true; return env
    }
}
private actor EligibilityTransport: HTTPTransport {
    let paid: Bool
    var failed = false
    var slow = false
    init(paid: Bool) { self.paid = paid }
    func fail() { failed = true }
    func delay() { slow = true }
    func send(_ request: PreparedRequest) async throws -> HTTPResponse {
        if slow { try await Task.sleep(for: .milliseconds(100)) }
        if failed { return HTTPResponse(status: 503, headers: [:], body: Data()) }
        return HTTPResponse(status: 200, headers: [:], body: Data("{\"result\":true,\"data\":{\"roomId\":7,\"hasPass\":\(paid),\"canEdit\":\(paid),\"invitation\":null}}".utf8))
    }
}
