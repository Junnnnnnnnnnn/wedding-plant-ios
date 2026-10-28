import XCTest
import WPModels
import WPNetworking
@testable import WeddingPlant

final class SchedulePermissionTests: XCTestCase {
    @MainActor func testOwnerSpouseWriterAndReaderActions() async {
        for (role, canWrite, documents) in [("OWNER", true, true), ("SPOUSE", true, true), ("WRITE", true, false), ("READ", false, false)] {
            let transport = PermissionTransport(role: role)
            let store = InMemoryTokenStore(token: DemoData.token)
            let base = URL(string: "https://example.test")!
            let env = AppEnvironment(api: APIClient(baseURL: base, transport: transport, tokenStore: store), tokenStore: store, baseURL: base, isDemo: true)
            let suite = "permission-tests-" + UUID().uuidString
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let guest = GuestStore(defaults: defaults)
            let model = ScheduleDetailViewModel(scheduleId: 42, roomId: 1)
            await model.load(env: env, guest: guest)
            XCTAssertEqual(model.detail?.amount, 1.125)
            XCTAssertEqual(model.canWrite, canWrite, role)
            XCTAssertEqual(model.canSeeDocuments, documents, role)
            await model.delete(env: env, guest: guest)
            let count = await transport.deleteCount
            XCTAssertEqual(count, canWrite ? 1 : 0, role)
            XCTAssertEqual(model.deleted, canWrite, role)
        }
    }
    @MainActor func testPermissionFailureRevokesPreviouslyLoadedWriteActions() async {
        let transport = PermissionTransport(role: "OWNER")
        let store = InMemoryTokenStore(token: DemoData.token), base = URL(string: "https://example.test")!
        let env = AppEnvironment(api: APIClient(baseURL: base, transport: transport, tokenStore: store), tokenStore: store, baseURL: base, isDemo: true)
        let model = ScheduleDetailViewModel(scheduleId: 42, roomId: 1)
        let suite = "permission-tests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let guest = GuestStore(defaults: defaults)
        await model.load(env: env, guest: guest)
        XCTAssertTrue(model.canWrite)
        await transport.failPermissions()
        await model.load(env: env, guest: guest)
        XCTAssertFalse(model.canWrite)
        XCTAssertFalse(model.canSeeDocuments)
        XCTAssertNotNil(model.errorMessage)
        await model.delete(env: env, guest: guest)
        let count = await transport.deleteCount
        XCTAssertEqual(count, 0)
    }
}

/// 방이 없는 혼자 쓰는 사람의 개인 일정 — 내 전체 목록에 있으면 방장(Android `resolveAccess`). 2026-10-28 iOS QA 새 계정에서
/// 자기 일정 상세에 완료 · 수정 · 삭제가 하나도 없던 것. 운영 응답처럼 좌표가 문자열이어도 열린다.
final class SoloSchedulePermissionTests: XCTestCase {
    @MainActor func testSoloUserOwnsPersonalSchedule() async {
        let transport = SoloTransport()
        let store = InMemoryTokenStore(token: DemoData.token), base = URL(string: "https://example.test")!
        let env = AppEnvironment(api: APIClient(baseURL: base, transport: transport, tokenStore: store), tokenStore: store, baseURL: base, isDemo: true)
        let suite = "solo-permission-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = ScheduleDetailViewModel(scheduleId: 64)
        await model.load(env: env, guest: GuestStore(defaults: defaults))
        XCTAssertNil(model.errorMessage, "좌표가 문자열이어도 상세가 열린다")
        XCTAssertEqual(model.detail?.title, "QA-기본-01")
        XCTAssertTrue(model.canWrite, "내 개인 일정이면 완료 · 수정 · 삭제를 낸다")
        XCTAssertTrue(model.canSeeDocuments)
    }
}

private actor SoloTransport: HTTPTransport {
    func send(_ request: PreparedRequest) async throws -> HTTPResponse {
        let json: String
        switch request.url.path {
        case "/plan/room/list": json = #"{"result":true,"data":{"total":0,"list":[]}}"#
        case "/plan/schedule/list": json = #"{"result":true,"data":{"total":1,"list":[{"id":64,"title":"QA-기본-01","categoryName":"웨딩홀","amount":120,"status":"NORMAL"}]}}"#
        case "/plan/schedule/64": json = #"{"result":true,"data":{"id":64,"categoryName":"웨딩홀","title":"QA-기본-01","amount":120,"startDate":"2026-10-28","startTime":null,"location":"","locationLat":"0.00000000","locationLng":"0.00000000","memo":"","payType":"CREDIT","status":"NORMAL","isPaid":false}}"#
        default: json = #"{"result":true,"data":{"id":"demo-user","name":"QA"}}"#
        }
        return HTTPResponse(status: 200, headers: [:], body: Data(json.utf8))
    }
}

private actor PermissionTransport: HTTPTransport {
    let role: String
    var unavailable = false
    var deleteCount = 0
    init(role: String) { self.role = role }
    func failPermissions() { unavailable = true }
    func send(_ request: PreparedRequest) async throws -> HTTPResponse {
        if request.method == .delete {
            deleteCount += 1
            return HTTPResponse(status: 200, headers: [:], body: Data())
        }
        let json: String
        switch request.url.path {
        case "/plan/room/list":
            if unavailable { return HTTPResponse(status: 503, headers: [:], body: Data()) }
            json = "{\"result\":true,\"data\":{\"total\":1,\"list\":[{\"roomId\":1,\"budget\":100,\"remainingBudget\":90,\"planCount\":1,\"members\":[{\"planUserId\":\"demo-user\",\"name\":\"테스트\",\"permission\":\"\(role)\"}]}]}}"
        case "/plan/schedule/42":
            json = #"{"result":true,"data":{"id":42,"title":"일정","amount":1.125}}"#
        default:
            json = #"{"result":true,"data":{"id":"demo-user","roomId":1}}"#
        }
        return HTTPResponse(status: 200, headers: [:], body: Data(json.utf8))
    }
}
