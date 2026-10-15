import XCTest
import SwiftUI
import WPModels
import WPNetworking
import WPUtils
@testable import WeddingPlant

/// 둘러보기(피드·자랑하기)·신고 시트를 안드로이드 캡처와 **같은 데이터**로 찍는다.
/// - 신고·차단: Android `ModerationShotTest`(상태 없는 본문만, 폭 390)
/// - 자랑하기 목록: Android `ExploreTabShotTest`(`explore-brag`)
/// - 자랑 상세: Android `BragDetailShotTest`(`brag-detail`)
/// - 자랑하기 토글: Android `BragToggleShotTest`(`toggle-normal` · `toggle-locked`)
/// - 후기 올리기: Android `DetailActionsShotTest`(`detail-actions-sheet`, 로즈부티크 하나 · 고른 채로)
final class ExploreParityTests: XCTestCase {
    private let base = URL(string: "https://explore-parity.test")!

    @MainActor func testModerationReferenceFrames() async {
        var empty = ""
        let detail = Binding(get: { empty }, set: { empty = $0 })
        await shot(ModerationSheetBody(phase: .menu, detail: detail), "matched-moderation-menu", natural: true)
        await shot(ModerationSheetBody(phase: .menu, allowBlock: false, isChat: true, detail: detail), "matched-moderation-menu-chat", natural: true)
        await shot(ModerationSheetBody(phase: .reason, detail: detail), "matched-moderation-reason", natural: true)
        await shot(ModerationSheetBody(phase: .reason, reason: .other, detail: detail), "matched-moderation-reason-other", natural: true)
        await shot(ModerationSheetBody(phase: .block, detail: detail), "matched-moderation-block", natural: true)
        await shot(ModerationSheetBody(phase: .done, detail: detail, doneMessage: ModerationText.reportDone), "matched-moderation-done", natural: true)
    }

    @MainActor func testExploreBragReferenceFrame() async {
        let env = environment(ExploreTransport())
        await shot(VStack(spacing: 0) {
            ExploreView(initial: .brag)
            BottomTabBar(active: .constant(.explore))
        }.environmentObject(env), "matched-explore-brag", settle: 1500, bottomInset: 24)
        await shot(VStack(spacing: 0) {
            ExploreView(initial: .feed)
            BottomTabBar(active: .constant(.explore))
        }.environmentObject(env), "matched-explore-feed-v2", settle: 1500, bottomInset: 24)
    }

    @MainActor func testBragDetailReferenceFrame() async throws {
        let detail = try JSONDecoder().decode(BragDetail.self, from: Data(ExploreTransport.bragDetail.utf8))
        await shot(ZStack {
            Color.black.opacity(0.6)
            BragDetailBody(detail: detail, loading: false).padding(16).padding(.top, 48).padding(.bottom, 24)
        }.background(Color.white), "matched-brag-detail")
    }

    @MainActor func testBragToggleReferenceFrames() async {
        let status = BragMyStatus(published: false, defaultNickname: "현진 · 지수")
        await shot(VStack { BragToggleBody(status: status).padding(16); Spacer() }, "matched-toggle-normal")
        await shot(VStack { BragToggleBody(status: BragMyStatus(published: false), locked: true).padding(16); Spacer() }, "matched-toggle-locked")
        await shot(VStack { BragToggleBody(status: BragMyStatus(published: true, likeCount: 12)).padding(16); Spacer() }, "matched-toggle-on")
        await shot(BragPublishSheet(pending: false, status: status, onPublish: { _ in }, onDismiss: {}), "matched-brag-publish")
    }

    @MainActor func testFeedPostSheetReferenceFrames() async {
        for (name, initial) in [("matched-feed-post-selected", Optional(42)), ("matched-feed-post-pick", nil)] {
            // Android `DetailActionsShotTest` 는 로즈부티크 하나 — 고르는 상태는 둘을 낸다
            let env = environment(ExploreTransport(postables: initial == nil ? 2 : 1))
            await shot(ZStack(alignment: .bottom) {
                Color.black.opacity(0.5)
                FeedPostSheet(initialScheduleId: initial, onPosted: {})
                    .frame(height: 640)
                    .clipShape(.rect(topLeadingRadius: 32, topTrailingRadius: 32))
            }.environmentObject(env), name, settle: 1200)
        }
    }

    @MainActor func testFeedDetailReferenceFrames() async throws {
        let env = environment(DemoTransport())
        let feedJSON = try JSONSerialization.jsonObject(with: Data(DemoData.feed(categoryName: nil).utf8)) as! [String: Any]
        let posts = (feedJSON["data"] as! [String: Any])["list"] as! [[String: Any]]
        for (index, raw) in posts.prefix(3).enumerated() {
            let post = try JSONDecoder().decode(FeedPost.self, from: JSONSerialization.data(withJSONObject: raw))
            await shot(NavigationStack { FeedDetailView(post: post) }.environmentObject(env), "matched-feed-detail-\(index)", settle: 1500)
        }
    }

    // MARK: - 도구

    @MainActor private func environment(_ transport: any HTTPTransport) -> AppEnvironment {
        let store = InMemoryTokenStore(token: DemoData.token)
        let env = AppEnvironment(api: APIClient(baseURL: base, transport: transport, tokenStore: store), tokenStore: store, baseURL: base, isDemo: true)
        env.isAuthenticated = true
        return env
    }

    @MainActor private func shot<V: View>(_ view: V, _ name: String, natural: Bool = false, settle: Int = 400, bottomInset: CGFloat = 0) async {
        let suite = "explore-parity-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = view.padding(.bottom, bottomInset).background(.white)
            .environmentObject(GuestStore(defaults: defaults)).environmentObject(GuideController()).environmentObject(PushService())
            .tint(WPColor.primary).environment(\.brandStatusInset, 48).environment(\.locale, Locale(identifier: "ko_KR"))
        let controller = UIHostingController(rootView: root)
        controller.safeAreaRegions = []
        var size = CGSize(width: 390, height: 844)
        if natural { size.height = ceil(controller.sizeThatFits(in: CGSize(width: 390, height: 2000)).height) }
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller; window.isHidden = false
        controller.view.frame = window.bounds; controller.view.layoutIfNeeded()
        try? await Task.sleep(for: .milliseconds(settle))
        let format = UIGraphicsImageRendererFormat(); format.scale = 3; format.opaque = true; format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        window.isHidden = true
    }
}

/// Android 목 서버(`ExploreTabShotTest` · `DetailActionsShotTest`)와 같은 응답.
private struct ExploreTransport: HTTPTransport {
    var postables = 1
    static let bragDetail = #"""
    {"bragId":7,"nickname":"웹지수 커플","weddingDate":"2027-05-15","dday":226,"totalBudget":5000,"usedAmount":1240,"plannedAmount":860,
     "planCount":5,"doneCount":2,"categories":["예식장","스드메","신혼여행","예물","청첩장"],"likeCount":12,"liked":false,"isMine":false,
     "categoryChart":[{"categoryName":"예식장","usedAmount":800},{"categoryName":"스드메","usedAmount":300},{"categoryName":"예물","usedAmount":90},
                      {"categoryName":"신혼여행","usedAmount":40},{"categoryName":"청첩장","usedAmount":10}],
     "items":[{"id":1,"categoryName":"예식장","title":"웨딩홀 계약금","amount":800,"startDate":"2026-10-04","status":"COMPLETED","isPaid":true,"location":"그랜드홀"},
              {"id":2,"categoryName":"스드메","title":"스튜디오 촬영","amount":300,"startDate":"2026-11-20","status":"NORMAL","isPaid":false},
              {"id":3,"categoryName":"신혼여행","title":"푸꾸옥 호텔","amount":560,"startDate":"2027-05-17","status":"NORMAL","isPaid":false,"location":"Phu Quoc","lat":0,"lng":0},
              {"id":4,"categoryName":"예물","title":"반지","amount":90,"startDate":"2026-12-01","status":"COMPLETED","isPaid":true},
              {"id":5,"categoryName":"청첩장","title":"모바일 청첩장","amount":10,"status":"NORMAL","isPaid":false}]}
    """#

    func send(_ request: PreparedRequest) async throws -> HTTPResponse {
        let path = request.url.path
        let value: String
        switch true {
        case path.hasPrefix("/plan/brag/my"): value = #"{"published":true,"bragId":9,"likeCount":12}"#
        case path.hasPrefix("/plan/brag/list"):
            value = #"{"total":34,"list":[{"bragId":1,"nickname":"현진 · 지수","weddingDate":"2026-11-14","dday":38,"totalBudget":4200,"usedAmount":1350,"plannedAmount":2100,"planCount":12,"doneCount":5,"categories":["웨딩홀","드레스"],"likeCount":18}]}"#
        case path.hasPrefix("/plan/feed/my/status"): value = #"{"postCount":2,"receivedHelpfulCount":5,"postableScheduleCount":1}"#
        case path.hasPrefix("/plan/feed/list"):
            value = #"{"total":128,"list":[{"id":1,"categoryName":"드레스","title":"라움 아트","amount":280,"isAmountPublic":true,"region":"서울 강남구"},{"id":2,"categoryName":"웨딩홀","title":"더채플앳청담","amount":3200,"isAmountPublic":true,"region":"서울 강남구"}]}"#
        case path.hasPrefix("/plan/feed/postable"):
            let rose = #"{"scheduleId":42,"categoryName":"드레스","title":"본식 드레스 잔금","amount":280,"location":"로즈부티크"}"#
            let ring = #"{"scheduleId":43,"categoryName":"예물","title":"반지 상담","amount":180}"#
            value = "{\"list\":[" + (postables > 1 ? rose + "," + ring : rose) + "]}"
        default: value = #"{"total":0,"list":[]}"#
        }
        return HTTPResponse(status: 200, body: Data(("{\"result\":true,\"data\":" + value + "}").utf8))
    }
}
