import XCTest
import WPDomain
import WPModels
import WPNetworking
import WPUtils
@testable import WeddingPlant

/// 지난 날짜의 새 플랜은 결제함 · 완료로 등록한다(Android 8c1068b `PastPlanRegistrationTest`, iOS 요청서 07).
/// 생성 API 는 상태를 받지 않아 만든 id 로 완료를 따로 부르고, 완료만 실패하면 다시 눌러도 **생성 POST 는 한 번**이다.
@MainActor
final class PastPlanRegistrationTests: XCTestCase {
    private func environment(_ server: PastPlanServer) -> AppEnvironment {
        let store = InMemoryTokenStore(token: DemoData.token), base = URL(string: "https://example.test")!
        return AppEnvironment(api: APIClient(baseURL: base, transport: server, tokenStore: store), tokenStore: store, baseURL: base, isDemo: true)
    }

    private func guestStore() -> GuestStore { GuestStore(defaults: UserDefaults(suiteName: "past-plan-" + UUID().uuidString)!) }

    private func newPlan(_ date: KstDate?) -> AddPlanViewModel {
        let model = AddPlanViewModel(roomId: 1)
        model.title = "드레스 계약금"
        model.category = PlanCategory(name: "스드메", type: "DEFAULT")
        model.payType = .credit
        model.amount = "50"
        if let date { model.setDate(date) } else { model.dateUndecided = true }
        return model
    }

    func testYesterdayIsCreatedPaidThenCompleted() async throws {
        let server = PastPlanServer()
        let env = environment(server), guest = guestStore()
        let model = newPlan(KstDate.today().adding(days: -1))
        await model.load(env: env, guest: guest)
        XCTAssertTrue(model.autoCompletePast)
        await model.save(env: env, guest: guest)
        XCTAssertTrue(model.saved)
        let creates = await server.createBodies
        XCTAssertEqual(creates.count, 1)
        XCTAssertEqual(creates.first?["isPaid"] as? Bool, true, "결제 칸을 켠 채 보낸다")
        let statuses = await server.statusCalls
        XCTAssertEqual(statuses, ["COMPLETED"], "만든 id(41)로 완료를 부른다")
    }

    func testTodayFutureAndUndecidedStayPlanned() async {
        for date in [KstDate.today(), KstDate.today().adding(days: 1), nil] {
            let server = PastPlanServer()
            let env = environment(server), guest = guestStore()
            let model = newPlan(date)
            await model.load(env: env, guest: guest)
            XCTAssertFalse(model.autoCompletePast)
            await model.save(env: env, guest: guest)
            XCTAssertTrue(model.saved)
            let creates = await server.createBodies, statuses = await server.statusCalls
            XCTAssertEqual(creates.first?["isPaid"] as? Bool, false)
            XCTAssertTrue(statuses.isEmpty, "\(date?.dateString ?? "미정") 은 완료하지 않는다")
        }
    }

    func testEditingPastPlanKeepsItsStatus() async {
        let server = PastPlanServer()
        let env = environment(server), guest = guestStore()
        let model = AddPlanViewModel(editId: 41, roomId: 1)
        await model.load(env: env, guest: guest)
        XCTAssertFalse(model.autoCompletePast, "고치기는 원래 상태를 둔다")
        await model.save(env: env, guest: guest)
        let statuses = await server.statusCalls
        XCTAssertTrue(statuses.isEmpty)
    }

    func testCompletionFailureRetriesOnlyCompletion() async {
        let server = PastPlanServer(failStatusTimes: 1)
        let env = environment(server), guest = guestStore()
        let model = newPlan(KstDate.today().adding(days: -3))
        await model.load(env: env, guest: guest)
        await model.save(env: env, guest: guest)
        XCTAssertFalse(model.saved)
        XCTAssertTrue(model.completionPending)
        XCTAssertEqual(model.saveButtonText, "완료 처리 다시 시도")
        XCTAssertEqual(model.errorMessage, "플랜은 등록됐지만 완료 처리하지 못했어요. 다시 누르면 등록한 플랜의 완료 처리만 재시도해요.")
        XCTAssertTrue(model.formLocked, "만든 뒤에는 폼을 고치지 않는다")

        await model.save(env: env, guest: guest)
        XCTAssertTrue(model.saved)
        XCTAssertFalse(model.completionPending)
        let creates = await server.createBodies, statuses = await server.statusCalls
        XCTAssertEqual(creates.count, 1, "생성 POST 는 한 번")
        XCTAssertEqual(statuses, ["COMPLETED", "COMPLETED"])
    }

    /// 비로그인(옛 게스트 일정)도 같은 규칙으로 기기에 적는다
    func testGuestPastPlanIsStoredCompleted() async {
        let base = URL(string: "https://example.test")!, store = InMemoryTokenStore(token: nil)
        let env = AppEnvironment(api: APIClient(baseURL: base, transport: PastPlanServer(), tokenStore: store), tokenStore: store, baseURL: base, isDemo: true)
        let guest = guestStore()
        let model = newPlan(KstDate.today().adding(days: -1))
        await model.save(env: env, guest: guest)
        XCTAssertEqual(guest.schedules.last?.isScheduleCompleted, true)
        XCTAssertEqual(guest.schedules.last?.isPaid, true)
    }
}

private actor PastPlanServer: HTTPTransport {
    var createBodies: [[String: Any]] = []
    var statusCalls: [String] = []
    private var failStatusTimes: Int
    init(failStatusTimes: Int = 0) { self.failStatusTimes = failStatusTimes }

    func send(_ request: PreparedRequest) async throws -> HTTPResponse {
        let path = request.url.path
        let body = (try? JSONSerialization.jsonObject(with: request.body ?? Data())) as? [String: Any] ?? [:]
        var status = 200
        let json: String
        if path == "/plan/schedule" && request.method == .post {
            createBodies.append(body)
            json = #"{"result":true,"data":{"id":41}}"#
        } else if path == "/plan/schedule/status/41" {
            statusCalls.append(body["status"] as? String ?? "")
            if failStatusTimes > 0 {
                failStatusTimes -= 1
                status = 500
                json = #"{"result":false,"message":"잠시 후 다시 시도해 주세요."}"#
            } else {
                json = #"{"result":true,"data":{"id":41,"status":"COMPLETED","isPaid":true}}"#
            }
        } else if path == "/plan/schedule/41" && request.method == .patch {
            json = #"{"result":true,"data":{}}"#
        } else if path == "/plan/schedule/41" {
            json = #"{"result":true,"data":{"id":41,"title":"드레스 계약금","categoryName":"스드메","payType":"CREDIT","amount":50,"startDate":"2025-12-13","status":"NORMAL","isPaid":false}}"#
        } else if path.hasPrefix("/plan/category") {
            json = #"{"result":true,"data":{"list":[{"id":1,"name":"스드메"}]}}"#
        } else if path.hasPrefix("/plan/total-amount") || path.contains("amount") {
            json = #"{"result":true,"data":{"initialCapital":1000,"totalPlannedAndUsedAmount":50}}"#
        } else {
            json = #"{"result":true,"data":{"id":"demo-user","roomId":1}}"#
        }
        return HTTPResponse(status: status, headers: [:], body: Data(json.utf8))
    }
}
