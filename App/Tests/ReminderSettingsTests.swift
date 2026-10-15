import XCTest
import SwiftUI
import WPUtils
import WPDomain
import WPModels
import WPNetworking
@testable import WeddingPlant

final class ReminderSettingsTests: XCTestCase {
    @MainActor func testFailedAutosaveRestoresConfirmedSetting() async {
        let base = URL(string: "https://example.test")!
        let model = ReminderSettingsModel()
        let before = ReminderSetting(emailAddress: "jisoo@example.com")
        model.setting = before
        let api = APIClient(baseURL: base, transport: FailingReminderTransport(), tokenStore: InMemoryTokenStore(token: DemoData.token))
        var next = before; next.leadDays = [3, 0]
        await model.save(next, api: api)
        XCTAssertEqual(model.setting, before)
        XCTAssertFalse(model.saving); XCTAssertFalse(model.saved); XCTAssertNotNil(model.saveError)
    }
    @MainActor func testSuccessfulAutosavePersistsOnReloadAndRetainsReceiver() async throws {
        let base = URL(string: "https://example.test")!
        let transport = DemoTransport()
        let store = InMemoryTokenStore(token: DemoData.token)
        let api = APIClient(baseURL: base, transport: transport, tokenStore: store)
        let model = ReminderSettingsModel()
        model.setting = try await api.send(Endpoint.reminderSetting())
        var next = try XCTUnwrap(model.setting); next.leadDays = [3, 0]; next.hour = 12; next.email = true
        await model.save(next, api: api)
        XCTAssertEqual(model.setting, next); XCTAssertTrue(model.saved)
        let reloaded: ReminderSetting = try await api.send(Endpoint.reminderSetting())
        XCTAssertEqual(reloaded, next)
    }
}
private actor FailingReminderTransport: HTTPTransport {
    func send(_ request: PreparedRequest) async throws -> HTTPResponse {
        HTTPResponse(status: 503, headers: [:], body: Data())
    }
}

// MARK: - 채팅 · 커플 · 프로필 · 알림 · 내보내기 — 안드로이드 캡처와 같은 데이터로 그린 기준 장면

/// 안드로이드 `PortParityShotTest` · `PickPlanShotTest` · `ReleaseFixShotTest` · `ExportAndPhotoShotTest` 와 같은
/// 고정 데이터로 실제 화면/본문을 390pt 폭에 그린다. 첨부 이름은 `matched-*`.
@MainActor
final class CoupleProfileParityTests: XCTestCase {
    private static let dressItems = [
        ScheduleItem(id: 11, categoryName: "스드메", title: "드레스 투어", amount: 300, startDate: "2026-11-20"),
        ScheduleItem(id: 12, categoryName: "예식장", title: "웨딩홀 계약금", amount: 800, startDate: "2026-10-04"),
        ScheduleItem(id: 13, categoryName: "청첩장", title: "모바일 청첩장", amount: nil, startDate: nil),
    ]

    func testChatReferenceFrames() async {
        let today = KstDate.today().dateString, yesterday = KstDate.today().adding(days: -1).dateString
        func msg(_ id: Int, _ who: String, _ name: String, _ text: String, _ at: String) -> String {
            #"{"id":\#(id),"planUserId":"\#(who)","planUserName":"\#(name)","messageType":"text","text":"\#(text)","createDate":"\#(at)","unreadCount":0}"#
        }
        let history = #"{"total":4,"list":["# + [
            msg(4, "demo-user", "지수", "좋아 그럼 토요일에 보자", "\(today)T05:10:00.000Z"),
            msg(3, "p-2", "현우", "가봉 일정 잡았어!", "\(today)T05:00:00.000Z"),
            msg(2, "p-2", "현우", "드레스샵 예약 확인해 줘", "\(yesterday)T09:00:00.000Z"),
            msg(1, "demo-user", "지수", "웨딩홀 계약금 냈어", "\(yesterday)T08:00:00.000Z"),
        ].joined(separator: ",") + "]}"
        let env = Self.env { path in
            if path.hasPrefix("/plan/chat/info/30") {
                return #"{"id":30,"name":"","isCouple":true,"planUserRoomId":7,"memberList":[{"planUserId":"demo-user","name":"지수","permission":"OWNER"},{"planUserId":"p-2","name":"현우","permission":"SPOUSE"}]}"#
            }
            if path.hasPrefix("/plan/chat/30") { return history }
            if path.hasPrefix("/plan/activity/list") {
                return #"{"total":2,"list":[{"id":9,"type":"SCHEDULE_COMPLETED","actorName":"현우","targetType":"SCHEDULE","targetId":51,"targetTitle":"웨딩홀 계약금","amount":300,"createDate":"\#(today)T05:05:00.000Z"},{"id":7,"type":"SCHEDULE_CREATED","actorName":"현우","targetType":"SCHEDULE","targetId":52,"targetTitle":"본식 드레스 가봉","amount":1280,"createDate":"\#(yesterday)T08:30:00.000Z"}]}"#
            }
            return #"{"total":0,"list":[]}"#
        }
        await snapshot(ChatView(chatRoomId: 30, standalone: true, planRoomId: 7, weddingDate: KstDate.today().adding(days: 32).dateString)
            .environmentObject(env).environmentObject(PushService()), name: "matched-chat-ready", wait: 1500)
        let notMember = Self.env { path in path.hasPrefix("/plan/chat/info") ? "__403__" : #"{"total":0,"list":[]}"# }
        await snapshot(ChatView(chatRoomId: 30, standalone: true, planRoomId: 7)
            .environmentObject(notMember).environmentObject(PushService()), name: "matched-chat-not-member", wait: 1200)
    }

    func testPickAndShareReferenceFrames() async {
        await snapshot(PickPlanSheetBody(items: Self.dressItems), name: "matched-pick-list", height: nil)
        await snapshot(PickPlanSheetBody(items: []), name: "matched-pick-empty", height: nil)
        await snapshot(PickPlanSheetBody(items: Self.dressItems, error: ChatViewModel.shareFailedMessage), name: "matched-pick-error", height: nil)
        await snapshot(PickPlanSheetBody(items: Self.dressItems, sending: 12), name: "matched-pick-sending", height: nil)
        await snapshot(PickPlanSheetBody(items: Self.dressItems, done: 12), name: "matched-pick-done", height: nil)
        let ready = CoupleChatState.ready(chatRoomId: 30, planRoomId: 7, weddingDate: "2026-11-14", partnerName: "현우")
        await snapshot(VStack(spacing: 0) {
            ShareScheduleBody(title: "웨딩홀 계약금", couple: ready, sending: false, done: false, error: nil)
            ShareScheduleBody(title: "웨딩홀 계약금", couple: ready, sending: false, done: true, error: nil)
            ShareScheduleBody(title: "웨딩홀 계약금", couple: .solo, sending: false, done: false, error: nil)
            Spacer(minLength: 0)
        }, name: "matched-share-sheet")
    }

    func testCoupleReferenceFrames() async {
        let me = Member(planUserId: "me-1", name: "현우", permission: .owner)
        let spouse = Member(planUserId: "p-2", name: "지수", permission: .spouse)
        await snapshot(ZStack {
            WPColor.background
            Color.black.opacity(0.4)
            SpouseJoinWarningCard(myPlanCount: 3, hasSpouseSeat: true, currentSpouseOwnerName: "지수", onConfirm: {}, onCancel: {})
        }, name: "matched-spouse-seat-named")
        await snapshot(VStack {
            CoupleSection(couple: [me, spouse], myId: "me-1", boundOwner: nil, canUnlink: true, confirming: true, saving: false).padding(16)
            Spacer(minLength: 0)
        }.background(WPColor.background), name: "matched-couple-owner-confirm")
        await snapshot(VStack {
            CoupleSection(couple: [], myId: "p-2", boundOwner: "현우", canUnlink: true, confirming: false, saving: false).padding(16)
            Spacer(minLength: 0)
        }.background(WPColor.background), name: "matched-couple-spouse-leave")
        await snapshot(VStack {
            JoinFailedCard(message: ShareJoinViewModel.inviteRoleRequiredMessage, refused: true, onHome: {}, onRetry: {}).padding(.top, 8)
            Spacer(minLength: 0)
        }.background(WPColor.background), name: "matched-join-refused")
        await snapshot(ScrollView {
            SharePlanSheetBody(couple: [me, spouse], myId: "me-1", boundOwner: nil, canUnlink: true, confirming: false, saving: false,
                               loading: false, full: true, message: nil)
        }, name: "matched-share-plan-sheet")
    }

    func testProfileReferenceFrames() async throws {
        let env = Self.demoEnv()
        let suite = "parity-profile-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = UserView().environmentObject(env).environmentObject(PushService()).environmentObject(GuestStore(defaults: defaults))
        await snapshot(NavigationStack { root }, name: "matched-profile", wait: 1500, scrolls: [650, 2000])
        await snapshot(BlockListBody(list: [], loading: false), name: "matched-blocks-empty", height: nil)
        await snapshot(BlockListBody(list: [.init(id: 1, displayName: "차단한 사용자", source: "FEED"), .init(id: 2, displayName: "하늘이네", source: "BRAG")],
                                     loading: false, busyId: 2), name: "matched-blocks-list", height: nil)
    }

    func testPaymentsAndExportReferenceFrames() async {
        let today = KstDate.today()
        let items: [(item: ScheduleItem, days: Int)] = [
            (ScheduleItem(id: 1, categoryName: "스드메", title: "드레스샵 잔금", amount: 180, startDate: today.adding(days: 2).dateString), 2),
            (ScheduleItem(id: 2, categoryName: "예식장", title: "예식장 중도금", amount: 240, startDate: today.adding(days: 6).dateString), 6),
        ]
        func label(_ raw: String?) -> String { raw.flatMap { KstDate(dateString: $0) }.map { "\($0.month)월 \($0.day)일" } ?? "" }
        await snapshot(VStack {
            PayThisWeekBody(items: items, hasPass: true, reminderText: "7일 전 · 하루 전 · 당일 오전 9시", dateLabel: label).padding(16)
            PayThisWeekBody(items: items, hasPass: false, reminderText: "7일 전 · 하루 전 · 당일 오전 9시", dateLabel: label).padding(16)
            Spacer(minLength: 0)
        }.background(WPColor.background), name: "matched-payweek")
        let month = String(today.dateString.prefix(7))
        await snapshot(CalendarExportBody(items: CalendarExport.examples, plan: nil, month: month, loading: false, busy: false,
                                          template: .budget, pdf: true, currentMonth: false), name: "matched-export-options", scrolls: [0])
        await snapshot(CalendarExportBody(items: [], plan: nil, month: month, loading: false, busy: false,
                                          template: .budget, pdf: true, sample: true), name: "matched-export-preview-pdf", scrolls: [200, 900])
        await snapshot(CalendarExportBody(items: [], plan: nil, month: month, loading: false, busy: false,
                                          template: .checklist, pdf: false, sample: true), name: "matched-export-preview-xlsx", scrolls: [900])
    }

    // MARK: 도구

    private static func env(_ respond: @escaping @Sendable (String) -> String) -> AppEnvironment {
        let base = URL(string: "https://parity.test")!, store = InMemoryTokenStore(token: DemoData.token)
        let env = AppEnvironment(api: APIClient(baseURL: base, transport: ClosureTransport(respond: respond), tokenStore: store), tokenStore: store, baseURL: base, isDemo: true)
        env.isAuthenticated = true
        return env
    }

    private static func demoEnv() -> AppEnvironment {
        let base = URL(string: "https://parity.test")!, store = InMemoryTokenStore(token: DemoData.token)
        let env = AppEnvironment(api: APIClient(baseURL: base, transport: DemoTransport(), tokenStore: store), tokenStore: store, baseURL: base, isDemo: true)
        env.isAuthenticated = true
        return env
    }

    /// height nil 이면 내용 높이만큼(시트 본문). scrolls 는 가장 큰 스크롤 영역을 그 위치로 옮겨 한 장씩 더 찍는다.
    private func snapshot<V: View>(_ view: V, name: String, height: CGFloat? = 844, wait: Int = 400, scrolls: [CGFloat] = []) async {
        let width: CGFloat = 390
        // 시트 본문(height nil)은 위에 붙여 한 화면에 그린다 — 안쪽 목록 높이는 그려진 뒤에야 정해진다
        let root = view.frame(maxWidth: .infinity, maxHeight: height == nil ? .infinity : nil, alignment: .top).background(Color.white)
            .environment(\.brandStatusInset, 48).environment(\.locale, Locale(identifier: "ko_KR")).tint(WPColor.primary)
        let controller = UIHostingController(rootView: root)
        controller.safeAreaRegions = []
        let size = CGSize(width: width, height: height ?? 844)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.frame = window.bounds; controller.view.layoutIfNeeded()
        try? await Task.sleep(for: .milliseconds(wait))
        func shot(_ suffix: String) {
            let format = UIGraphicsImageRendererFormat(); format.scale = 3; format.opaque = true; format.preferredRange = .standard
            let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true) }
            let attachment = XCTAttachment(image: image); attachment.name = name + suffix; attachment.lifetime = .keepAlways; add(attachment)
        }
        shot("")
        for (i, offset) in scrolls.enumerated() {
            func all(_ v: UIView) -> [UIView] { [v] + v.subviews.flatMap(all) }
            if let scroll = all(controller.view).compactMap({ $0 as? UIScrollView }).max(by: { $0.bounds.height < $1.bounds.height }) {
                let bottom = max(0, scroll.contentSize.height - scroll.bounds.height)
                scroll.setContentOffset(CGPoint(x: 0, y: min(offset, bottom)), animated: false)
                try? await Task.sleep(for: .milliseconds(300))
                shot("-\(i + 1)")
            }
        }
        window.isHidden = true
    }
}

private struct ClosureTransport: HTTPTransport {
    let respond: @Sendable (String) -> String
    func send(_ request: PreparedRequest) async throws -> HTTPResponse {
        let value = respond(request.url.path)
        if value == "__403__" {
            return HTTPResponse(status: 403, body: Data(#"{"result":false,"message":"참여 중인 대화방이 아니에요.","data":{"reason":"NOT_CHAT_MEMBER"},"code":"NOT_CHAT_MEMBER"}"#.utf8))
        }
        return HTTPResponse(status: 200, body: Data(("{\"result\":true,\"data\":" + value + "}").utf8))
    }
}
