import XCTest
import WPDomain
import WPModels
import WPNetworking
import WPUtils
@testable import WeddingPlant

/// 출시 전 운영 서버 점검 — 화면이 쓰는 **뷰모델 그대로** 운영 API 에 붙여 받기 · 디코드 · 저장이 도는지 본다.
/// 10월에 운영에서만 일정 상세가 안 열렸던 것(좌표가 문자열)처럼, 데모 서버로는 안 잡히는 계약 어긋남을 잡는다.
///
/// 평소에는 건너뛴다. 돌릴 때만 QA 계정을 넘긴다(값은 코드 · 로그에 남기지 않음):
/// `TEST_RUNNER_WP_PROD_SMOKE=1 TEST_RUNNER_WP_QA_EMAIL=… TEST_RUNNER_WP_QA_PASSWORD=… xcodebuild test -only-testing:WeddingPlantTests/ProductionSmokeTests`
/// 만드는 데이터는 `QA-출시점검-…` 플랜 하나이고, 끝에서 지운다. 결제 · 공개 · 후기 올리기 · 메시지는 하지 않는다.
@MainActor
final class ProductionSmokeTests: XCTestCase {
    private static let base = URL(string: "https://api.weddingplant.app")!
    private var env: AppEnvironment!
    private let guest = GuestStore(defaults: UserDefaults(suiteName: "prod-smoke-" + UUID().uuidString)!)

    override func setUp() async throws {
        let vars = ProcessInfo.processInfo.environment
        guard vars["WP_PROD_SMOKE"] == "1", let email = vars["WP_QA_EMAIL"], let password = vars["WP_QA_PASSWORD"] else {
            throw XCTSkip("운영 점검은 WP_PROD_SMOKE=1 과 QA 계정을 넘길 때만 돈다")
        }
        let anonymous = APIClient(baseURL: Self.base, transport: URLSessionTransport())
        let login: AuthTokenResult = try await anonymous.send(Endpoint.emailLogin(email, password: password))
        let token = try XCTUnwrap(login.value, "QA 계정 로그인")
        let store = InMemoryTokenStore(token: token)
        env = AppEnvironment(api: APIClient(baseURL: Self.base, transport: URLSessionTransport(), tokenStore: store),
                             tokenStore: store, baseURL: Self.base, isDemo: false)
        env.isAuthenticated = true
    }

    /// 읽기만 하는 화면들 — 홈 · 일정(보드 · 달력) · 예산 · 피드 · 자랑하기 · 프로필 · 청첩장 칸
    func testScreensLoadAgainstProduction() async throws {
        let main = MainViewModel()
        await main.load(env: env, guest: guest)
        XCTAssertNil(main.errorMessage, "홈")

        let calendar = CalendarViewModel(roomId: main.roomIdValue.map(String.init))
        await calendar.refresh(env: env, guest: guest)
        XCTAssertNil(calendar.error, "일정")
        XCTAssertTrue(calendar.upcomingLoaded, "보드 목록을 받았다")
        XCTAssertTrue(calendar.loadedOnce, "달력 한 달을 받았다")

        // 보드에 있는 일정마다 상세를 연다 — 운영 데이터의 모양(좌표 · 금액 · 시각)이 상세 모델에 다 맞는지
        for item in calendar.upcoming.prefix(15) {
            let detail = ScheduleDetailViewModel(scheduleId: item.id, roomId: main.roomIdValue)
            await detail.load(env: env, guest: guest)
            XCTAssertNil(detail.errorMessage, "상세 \(item.id)")
            XCTAssertEqual(detail.detail?.id, item.id)
        }

        let budget = BudgetDetailViewModel(roomId: main.roomIdValue.map(String.init))
        await budget.load(env: env, guest: guest)
        XCTAssertNil(budget.errorMessage, "예산")
        XCTAssertNotNil(budget.detail)

        let feed = FeedViewModel()
        await feed.loadCategories(env: env)
        await feed.load(env: env, replace: true)
        XCTAssertNil(feed.errorMessage, "피드")
        XCTAssertNotNil(feed.myStatus, "+ 옆 작성 가능 개수(postableScheduleCount)")

        let brag = BragViewModel()
        await brag.load(env: env, replace: true)
        XCTAssertNil(brag.errorMessage, "자랑하기")

        let user = UserViewModel()
        await user.load(env: env, guest: guest)
        XCTAssertNil(user.errorMessage, "프로필")

        let invitation = InvitationStore(marksSeen: false)
        await invitation.load(env)
        XCTAssertNil(invitation.error, "청첩장 칸")
        XCTAssertNotNil(invitation.result)

        await env.refreshAdEligibility()
        XCTAssertNotEqual(env.adGate, .unknown, "광고 판정(/plan/my-invitation)")
    }

    /// 쓰는 길 — 지난 날짜 새 플랜(결제함 · 완료) → 상세 → 예정으로 되돌리기 → 지우기
    func testPastPlanRoundTripAgainstProduction() async throws {
        let main = MainViewModel()
        await main.load(env: env, guest: guest)
        let title = "QA-출시점검-\(Int(Date().timeIntervalSince1970))"

        let add = AddPlanViewModel(roomId: main.roomIdValue)
        await add.load(env: env, guest: guest)
        add.title = title
        add.category = PlanCategory(name: "스드메", type: "DEFAULT")
        add.payType = .credit
        add.amount = "1"
        add.setDate(KstDate.today().adding(days: -1))
        XCTAssertTrue(add.autoCompletePast)
        await add.save(env: env, guest: guest)
        XCTAssertNil(add.errorMessage, "저장")
        XCTAssertTrue(add.saved)

        let calendar = CalendarViewModel(roomId: main.roomIdValue.map(String.init))
        await calendar.refresh(env: env, guest: guest)
        let created = try XCTUnwrap(calendar.upcoming.first { $0.title == title }, "보드에 새 플랜")
        defer { Task { @MainActor [env, guest] in
            // 실패해도 남기지 않는다
            let cleanup = ScheduleDetailViewModel(scheduleId: created.id, roomId: main.roomIdValue)
            await cleanup.load(env: env!, guest: guest); await cleanup.delete(env: env!, guest: guest)
        } }

        let detail = ScheduleDetailViewModel(scheduleId: created.id, roomId: main.roomIdValue)
        await detail.load(env: env, guest: guest)
        XCTAssertNil(detail.errorMessage, "새 플랜 상세")
        XCTAssertEqual(detail.detail?.isScheduleCompleted, true, "지난 날짜 → 완료로 등록")
        XCTAssertEqual(detail.detail?.isPaid, true, "결제함")

        await detail.toggleStatus(env: env)
        XCTAssertNil(detail.errorMessage, "예정으로 되돌리기")
        XCTAssertEqual(detail.detail?.isScheduleCompleted, false)
        XCTAssertEqual(detail.detail?.isPaid, true, "저장된 결제 칸(true)이 남는다 — 지난 날짜 등록은 결제함으로 적었다")

        await detail.delete(env: env, guest: guest)
        XCTAssertNil(detail.errorMessage, "지우기")
        await calendar.refresh(env: env, guest: guest)
        XCTAssertNil(calendar.upcoming.first { $0.title == title }, "지운 플랜이 보드에서 빠졌다")
    }
}
