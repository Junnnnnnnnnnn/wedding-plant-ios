import XCTest
import SwiftUI
import WPModels
import WPNetworking
import WPDomain
@testable import WeddingPlant

/// Review artifacts from real views, isolated from production. Rendering is not a CRUD assertion.
final class AllScreenComparisonTests: XCTestCase {
    @MainActor func testScreenInventory() async throws {
        let base = URL(string: "https://screen-review.test")!
        let store = InMemoryTokenStore(token: DemoData.token)
        let suite = "screen-review-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let guest = GuestStore(defaults: defaults)
        // 안드로이드 비교 캡처는 견본 광고(`PreviewAds`)로 광고 자리를 그린다. 같은 자리를 iOS 도 보이게 한다 —
        // 실제 테스트 광고는 NO_FILL 이 올 수 있어 캡처마다 달라진다.
        AdPreview.forced = true
        defer { AdPreview.forced = false }
        let guide = GuideController()
        let push = PushService()
        let feedJSON = try JSONSerialization.jsonObject(with: Data(DemoData.feed(categoryName: nil).utf8)) as! [String: Any]
        let posts = (feedJSON["data"] as! [String: Any])["list"] as! [[String: Any]]
        let post = try JSONDecoder().decode(FeedPost.self, from: JSONSerialization.data(withJSONObject: posts[0]))
        let screens: [(String, AnyView)] = [
            ("landing", AnyView(LandingView())),
            ("home", AnyView(MainView(model: MainViewModel(), invitation: InvitationStore(), bragToggle: BragToggleViewModel()))),
            ("budget", AnyView(BudgetDetailView())),
            ("profile", AnyView(UserView())),
            ("calendar", AnyView(CalendarView())),
            ("add", AnyView(AddPlanView(onSaved: {}))),
            ("edit", AnyView(AddPlanView(editId: 1, onSaved: {}))),
            ("detail", AnyView(ScheduleDetailView(scheduleId: 1))),
            ("feed", AnyView(FeedView())),
            ("feed-detail", AnyView(FeedDetailView(post: post))),
            ("feed-post", AnyView(FeedPostSheet(onPosted: {}))),
            ("brag", AnyView(BragView())),
            ("brag-detail", AnyView(BragDetailSheet(bragId: 1))),
            ("chat", AnyView(ChatView(chatRoomId: 1, planRoomId: 1))),
            ("pick-plan", AnyView(PickPlanSheet(roomId: 1, model: ChatViewModel(chatRoomId: 1, planRoomId: 1)))),
            ("share-plan", AnyView(ShareScheduleSheet(scheduleId: 1, title: "드레스 1차 피팅"))),
            ("couple", AnyView(SpouseInviteSheet())),
            ("sort", AnyView(PlanSortSheet(selected: .dateAsc, onSelect: { _ in }))),
            ("report", AnyView(ReportContentSheet(targetType: "FEED", targetId: 1, onHidden: {}))),
            ("blocks", AnyView(NavigationStack { BlockListView() })),
            ("export", AnyView(CalendarExportSheet(roomId: 1))),
            ("documents", AnyView(NavigationStack { PassDownloadView(roomId: 1) })),
            ("schedule-documents", AnyView(PassDocumentsView(scheduleId: 1, canAdd: true))),
            ("plans", AnyView(PassPlansView(roomId: 1))),
            ("pick-empty", AnyView(PickPlanSheet(roomId: 1, model: ChatViewModel(chatRoomId: 1, planRoomId: 1)))),
            ("pick-error", AnyView(PickPlanSheet(roomId: 1, model: ChatViewModel(chatRoomId: 1, planRoomId: 1)))),
            ("documents-empty", AnyView(NavigationStack { PassDownloadView(roomId: 1) })),
            ("documents-error", AnyView(NavigationStack { PassDownloadView(roomId: 1) })),
            ("home-empty", AnyView(MainView(model: MainViewModel(), invitation: InvitationStore(), bragToggle: BragToggleViewModel()))),
            ("home-over", AnyView(MainView(model: MainViewModel(), invitation: InvitationStore(), bragToggle: BragToggleViewModel()))),
            ("docs-active", AnyView(PassDocumentsView(scheduleId: 1, canAdd: true))),
            ("docs-files", AnyView(PassDocumentsView(scheduleId: 1, canAdd: true))),
            ("docs-expired", AnyView(PassDocumentsView(scheduleId: 1, canAdd: true))),
            ("docs-error", AnyView(PassDocumentsView(scheduleId: 1, canAdd: true))),
            ("feed-post-selected", AnyView(FeedPostSheet(initialScheduleId: 11, onPosted: {})))
        ]
        for (name, view) in screens {
            let env = AppEnvironment(api: APIClient(baseURL: base, transport: ReviewTransport(mode: name), tokenStore: store), tokenStore: store, baseURL: base, isDemo: true)
            env.isAuthenticated = true
            // 앱은 로그인하면 `WeddingPlantApp` 이 광고 판정을 받는다. 여기서는 화면만 띄우므로 직접 받는다.
            await env.refreshAdEligibility()
            let root = view.environmentObject(env).environmentObject(guest).environmentObject(guide).environmentObject(push)
                .tint(WPColor.primary).environment(\.brandStatusInset, 48).environment(\.locale, Locale(identifier: "ko_KR"))
            let controller = UIHostingController(rootView: root)
            controller.safeAreaRegions = []
            let size = CGSize(width: 390, height: 844)
            let window = UIWindow(frame: CGRect(origin: .zero, size: size))
            window.rootViewController = controller; window.isHidden = false
            controller.view.frame = window.bounds; controller.view.layoutIfNeeded()
            try await Task.sleep(for: .seconds(2))
            capture(controller.view, "review-native-\(name)-top")
            let scrolls = descendants(controller.view).compactMap { $0 as? UIScrollView }
                .filter { $0.contentSize.height > $0.bounds.height + 100 && $0.bounds.height > 200 }
            if let scroll = scrolls.max(by: { $0.bounds.height < $1.bounds.height }) {
                let bottom = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
                scroll.setContentOffset(CGPoint(x: 0, y: min(650, bottom)), animated: false)
                try await Task.sleep(for: .milliseconds(400))
                capture(controller.view, "review-native-\(name)-middle")
                scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)), animated: false)
                try await Task.sleep(for: .milliseconds(400))
                capture(controller.view, "review-native-\(name)-bottom")
            }
            window.isHidden = true
        }
    }

    @MainActor private func descendants(_ view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }
    @MainActor private func capture(_ view: UIView, _ name: String) {
        let format = UIGraphicsImageRendererFormat(); format.scale = 3; format.opaque = true; format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        XCTAssertEqual(image.cgImage?.width, 1170)
        let attachment = XCTAttachment(image: image); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}

private struct ReviewTransport: HTTPTransport {
    let mode: String
    let demo = DemoTransport()
    func send(_ request: PreparedRequest) async throws -> HTTPResponse {
        let path = request.url.path
        func ok(_ value: String) -> HTTPResponse { HTTPResponse(status: 200, body: Data(("{\"result\":true,\"data\":" + value + "}").utf8)) }
        if path == "/plan/moderation/block/list" { return ok("[]") }
        if path.hasSuffix("/download-all") {
            if mode == "documents-error" { return HTTPResponse(status: 503, body: Data()) }
            if mode == "documents-empty" { return ok(#"{"list":[]}"#) }
            return ok(#"{"list":[{"fileName":"웨딩홀 계약서.pdf","url":"https://screen-review.test/contract.pdf"},{"fileName":"영수증.jpg","url":"https://screen-review.test/receipt.jpg"}]}"#)
        }
        if (mode == "pick-empty" || mode == "home-empty") && path.contains("/schedule") { return ok(#"{"total":0,"list":[]}"#) }
        if mode == "pick-error" && path.contains("/schedule") { return HTTPResponse(status: 503, body: Data()) }
        if mode == "home-over" && path.contains("total-amount") { return ok(#"{"totalAmount":1000,"usedAmount":2068,"remainingAmount":-1068}"#) }
        if mode.hasPrefix("docs-") && path.contains("/plan/pass/room/") { return ok(mode == "docs-expired" ? #"{"hasPass":false}"# : #"{"hasPass":true,"plan":"YEARLY","buyerName":"지수"}"#) }
        if mode.hasPrefix("docs-") && path.contains("/plan/pass/file/schedule/") {
            if mode == "docs-error" { return HTTPResponse(status: 503, body: Data()) }
            let files = mode == "docs-files" || mode == "docs-expired" ? #"[{"id":1,"fileName":"웨딩홀 계약서.pdf","contentType":"application/pdf","sizeBytes":24576}]"# : "[]"
            return ok("{\"canOpen\":\(mode != "docs-expired"),\"roomId\":1,\"quotaBytes\":1073741824,\"usedBytes\":24576,\"list\":\(files)}")
        }
        return try await demo.send(request)
    }
}
