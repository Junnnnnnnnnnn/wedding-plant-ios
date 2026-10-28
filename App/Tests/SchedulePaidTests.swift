import XCTest
import WPDomain
import WPModels
import WPNetworking
@testable import WeddingPlant

/// 서버의 `isPaid` 는 저장된 결제 칸이 아니라 "완료이거나 결제 칸 체크" 계산값이다 — Android 7523938(2026-10-28 QA DET-02).
/// 가짜 서버가 백엔드 `isSchedulePaid()` 와 같이 계산해 돌려준다. 결제한 적 없는 완료 일정(저장된 칸 false)으로 본다.
@MainActor
final class SchedulePaidTests: XCTestCase {
    private func environment(_ server: PaidServer) -> AppEnvironment {
        let store = InMemoryTokenStore(token: DemoData.token), base = URL(string: "https://example.test")!
        return AppEnvironment(api: APIClient(baseURL: base, transport: server, tokenStore: store), tokenStore: store, baseURL: base, isDemo: true)
    }

    private func guestStore() -> GuestStore {
        let suite = "paid-tests-" + UUID().uuidString
        return GuestStore(defaults: UserDefaults(suiteName: suite)!)
    }

    /// (1) 상세: 완료 → `예정으로 되돌리기` 직후 `예정 · 결제함` 이 뜨면 안 된다
    func testDetailUndoCompletionUsesStatusResponse() async {
        let server = PaidServer(storedPaid: false)
        let env = environment(server), guest = guestStore()
        let model = ScheduleDetailViewModel(scheduleId: 7, roomId: 1)
        await model.load(env: env, guest: guest)
        XCTAssertEqual(model.detail?.isScheduleCompleted, true)
        XCTAssertEqual(model.detail?.isPaidRaw, true, "완료라 서버 계산값은 true")
        await model.toggleStatus(env: env)
        XCTAssertEqual(model.detail?.isScheduleCompleted, false)
        XCTAssertNil(model.detail?.paymentMismatch, "결제한 적 없는 일정 — `결제함` 이 붙지 않는다")
        XCTAssertEqual(model.detail?.isPaid, false)
    }

    /// 미리 낸 계약금(저장된 칸 true)은 되돌려도 `결제함` 이 남는다
    func testDetailUndoKeepsPrepaidDeposit() async {
        let server = PaidServer(storedPaid: true)
        let env = environment(server), guest = guestStore()
        let model = ScheduleDetailViewModel(scheduleId: 7, roomId: 1)
        await model.load(env: env, guest: guest)
        await model.toggleStatus(env: env)
        XCTAssertEqual(model.detail?.paymentMismatch, .paidAhead)
    }

    /// (1) 홈 체크: 완료 카드의 체크를 풀어 예정으로 옮겨도 `결제함` 이 붙지 않는다(응답 전 낙관적 표시 포함)
    func testHomeUncheckUsesStatusResponse() async {
        let server = PaidServer(storedPaid: false)
        let env = environment(server)
        let model = MainViewModel()
        let card = ScheduleItem(id: 7, categoryName: "스드메", title: "드레스 투어", amount: 50, startDate: "2026-11-01",
                                status: .completed, isPaid: true)
        model.completed = [card]; model.completedTotal = 1
        await model.toggle(card, env: env)
        let moved = model.planned.first { $0.id == 7 }
        XCTAssertNotNil(moved)
        XCTAssertNil(moved?.paymentMismatch)
        XCTAssertEqual(moved?.isPaid, false)
    }

    /// (2) 완료한 플랜을 고쳐 저장할 때 `isPaid` 키를 보내지 않는다 — 보내면 서버에 체크로 굳는다
    func testEditingCompletedPlanDoesNotSendIsPaid() async throws {
        let server = PaidServer(storedPaid: false)
        let env = environment(server), guest = guestStore()
        let model = AddPlanViewModel(editId: 7, roomId: 1)
        await model.load(env: env, guest: guest)
        XCTAssertTrue(model.completed)
        model.title = "드레스 투어 2차"
        await model.save(env: env, guest: guest)
        let sent = await server.lastUpdateBody
        let body = try XCTUnwrap(sent)
        XCTAssertNil(body["isPaid"], "완료한 플랜은 결제 칸을 건드리지 않는다")
        XCTAssertEqual(body["title"] as? String, "드레스 투어 2차")
        let stored = await server.storedPaid
        XCTAssertFalse(stored, "서버의 결제 칸이 true 로 굳지 않았다")
    }

    /// 예정 플랜은 지금 고른 결제 칸을 그대로 보낸다
    func testEditingPlannedPlanSendsChosenIsPaid() async throws {
        let server = PaidServer(storedPaid: false, completed: false)
        let env = environment(server), guest = guestStore()
        let model = AddPlanViewModel(editId: 7, roomId: 1)
        await model.load(env: env, guest: guest)
        model.isPaid = true
        await model.save(env: env, guest: guest)
        let sent = await server.lastUpdateBody
        let body = try XCTUnwrap(sent)
        XCTAssertEqual(body["isPaid"] as? Bool, true)
    }
}

/// 백엔드처럼 `isPaid` 를 계산해 돌려주는 가짜 서버
private actor PaidServer: HTTPTransport {
    var storedPaid: Bool
    var completed: Bool
    var lastUpdateBody: [String: Any]?
    init(storedPaid: Bool, completed: Bool = true) { self.storedPaid = storedPaid; self.completed = completed }

    private var computed: Bool { completed || storedPaid }

    func send(_ request: PreparedRequest) async throws -> HTTPResponse {
        let path = request.url.path
        let json: String
        if path == "/plan/schedule/status/7" {
            let body = (try? JSONSerialization.jsonObject(with: request.body ?? Data())) as? [String: Any]
            completed = (body?["status"] as? String) == "COMPLETED"
            json = #"{"result":true,"data":{"id":7,"status":"\#(completed ? "COMPLETED" : "NORMAL")","isPaid":\#(computed)}}"#
        } else if path == "/plan/schedule/7" && request.method == .patch {
            let body = (try? JSONSerialization.jsonObject(with: request.body ?? Data())) as? [String: Any] ?? [:]
            lastUpdateBody = body
            if let paid = body["isPaid"] as? Bool { storedPaid = paid }
            json = #"{"result":true,"data":{}}"#
        } else if path == "/plan/schedule/7" {
            json = #"{"result":true,"data":{"id":7,"title":"드레스 투어","categoryName":"스드메","payType":"CREDIT","amount":50,"startDate":"2026-11-01","status":"\#(completed ? "COMPLETED" : "NORMAL")","isPaid":\#(computed)}}"#
        } else if path == "/plan/room/list" {
            json = #"{"result":true,"data":{"total":1,"list":[{"roomId":1,"budget":100,"remainingBudget":90,"planCount":1,"members":[{"planUserId":"demo-user","name":"테스트","permission":"OWNER"}]}]}}"#
        } else if path.hasPrefix("/plan/category") {
            json = #"{"result":true,"data":{"list":[{"id":1,"name":"스드메"}]}}"#
        } else {
            json = #"{"result":true,"data":{"id":"demo-user","roomId":1}}"#
        }
        return HTTPResponse(status: 200, headers: [:], body: Data(json.utf8))
    }
}
