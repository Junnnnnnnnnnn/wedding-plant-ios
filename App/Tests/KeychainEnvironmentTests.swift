import XCTest
@testable import WeddingPlant

final class KeychainEnvironmentTests: XCTestCase {
    func testBackendSessionsAreIsolatedAndSurviveStoreRecreation() async throws {
        // Unique keychain namespaces: never read or clear the user's real session.
        let suffix = UUID().uuidString
        let localURL = try XCTUnwrap(URL(string: "http://localhost:3112/test-\(suffix)"))
        let productionURL = try XCTUnwrap(URL(string: "https://api.weddingplant.app/test-\(suffix)"))
        let local = KeychainTokenStore(baseURL: localURL)
        let production = KeychainTokenStore(baseURL: productionURL)
        await local.save("local-test-session")
        let emptyProduction = await production.currentToken()
        XCTAssertNil(emptyProduction)
        await production.save("production-test-session")
        let recreatedLocal = KeychainTokenStore(baseURL: localURL)
        let recreatedProduction = KeychainTokenStore(baseURL: productionURL.appendingPathComponent(""))
        let localToken = await recreatedLocal.currentToken()
        let productionToken = await recreatedProduction.currentToken()
        XCTAssertEqual(localToken, "local-test-session")
        XCTAssertEqual(productionToken, "production-test-session")
        await production.clear()
        let localAfterProductionSignOut = await KeychainTokenStore(baseURL: localURL).currentToken()
        XCTAssertEqual(localAfterProductionSignOut, "local-test-session")
        await local.clear()
    }
}
