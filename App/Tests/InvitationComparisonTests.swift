import XCTest
import SwiftUI
import WPModels
import WPDomain
import WPNetworking
import CoreImage
@testable import WeddingPlant

/// Android InvitationStudioShotTest / InvitationEditorShotTest와 같은 데이터와 390×844 화면.
final class InvitationComparisonTests: XCTestCase {
    @MainActor func testSavedQRCodeContainsThePublishedAddress() throws {
        XCTAssertNotNil(UIFont(name: "NotoSerif", size: 56))
        XCTAssertNotNil(UIFont(name: "NotoSerif-Italic", size: 56))
        let url = "https://weddingplant.app/invitation/example"
        XCTAssertNotNil(UIImage(named: "invitation_door.png"), "The opening animation requires the bundled door artwork")
        let image = try XCTUnwrap(InvitationQRCode.image(url)?.cgImage)
        let detector = try XCTUnwrap(CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]))
        let code = try XCTUnwrap(detector.features(in: CIImage(cgImage: image)).first as? CIQRCodeFeature)
        XCTAssertEqual(code.messageString, url)
    }
    @MainActor func testInvitationComparisonFrames() async throws {
        for focus in ["layout", "cover", "calendar", "location", "accounts", "mood", "gallery"] {
            let content = Self.content()
            let env = environment(content)
            try await capture(InvitationEditorView(saved: content, roomId: 7, initialFocus: focus).environmentObject(env), name: "editor-" + focus, top: 48)
        }
    }
    @MainActor func testStudioComparisonFrames() async throws {
        for state in ["landing", "empty", "unpublished", "published"] {
            let content = state == "landing" || state == "empty" ? nil : Self.content(published: state == "published", photoCount: 2)
            let env = environment(content, pass: state != "landing")
            try await capture(InvitationStudioView(titleSlot: AnyView(Text("피드 | 자랑하기 | 청첩장").foregroundStyle(.white)), motionEnabled: false).environmentObject(env), name: "studio-" + state, scrolls: [0, 260, 720])
        }
    }
    @MainActor func testGuestBodyComparisonFrames() async throws {
        try await capture(InvitationPreviewView(content: Self.content(), motionEnabled: false).environmentObject(environment(Self.content())), name: "preview", top: 48, bottom: 0, scrolls: [0, 700, 1300, 2100, 2800, 3500, 4500])
    }

    /// Android `inv-guest-door-opening` — 하객 화면을 열고 문이 열리는 도중(0.7초 뒤 2.4초 동안)을 여러 장 찍습니다.
    @MainActor func testGuestDoorOpeningFrames() async throws {
        let view = InvitationPreviewView(content: Self.content()).environmentObject(environment(Self.content()))
        let controller = UIHostingController(rootView: view.padding(.top, 48).background(.white).environment(\.locale, Locale(identifier: "ko_KR")))
        controller.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller; window.isHidden = false
        controller.view.frame = window.bounds; controller.view.layoutIfNeeded()
        defer { window.isHidden = true }
        let start = Date()
        for at in [1.2, 1.9, 2.6, 3.2] {
            let wait = at - Date().timeIntervalSince(start)
            if wait > 0 { try await Task.sleep(for: .milliseconds(Int(wait * 1000))) }
            let format = UIGraphicsImageRendererFormat(); format.scale = 3; format.opaque = true
            let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { _ in controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true) }
            let attachment = XCTAttachment(image: image); attachment.name = "compare-door-\(Int(at * 1000))"; attachment.lifetime = .keepAlways; add(attachment)
        }
    }

    @MainActor private func environment(_ content: InvitationContent?, pass: Bool = true) -> AppEnvironment {
        let store = InMemoryTokenStore(token: DemoData.token), base = URL(string: "https://invitation-comparison.test")!
        return AppEnvironment(api: APIClient(baseURL: base, transport: ComparisonTransport(content: content, pass: pass), tokenStore: store), tokenStore: store, baseURL: base, isDemo: true)
    }
    static func content(published: Bool = false, photoCount: Int = 3) -> InvitationContent {
        var d = InvitationRules.design(new: true)
        d.sections = InvitationRules.sectionTypes.map { .init(type: $0, visible: $0 != "notice") }
        d.couple.groomFather = "정민호"; d.couple.groomMother = "이수정"; d.couple.brideMother = "김은영"
        d.location.address = "서울 강남구 테헤란로 1"; d.location.guide = "지하철 2호선 강남역 3번 출구에서 걸어서 5분"
        d.accounts[0].bank = "국민"; d.accounts[0].number = "123-456-7890"
        d.accounts[3].bank = "신한"; d.accounts[3].number = "110-222-333444"
        let photo = Bundle.main.url(forResource: "pass_invite_portrait", withExtension: "png")?.absoluteString
        return .init(slug: "ZXhhbXBsZUB3ZWRkaW5ncGxhbnQuYXBw", template: "garden", title: "우리, 결혼합니다", bride: "한채원", groom: "정우진", weddingDate: "2026-11-14", weddingTime: "13:00", venue: "웨딩플랜트 가든홀", message: InvitationRules.draft().message, photos: (0..<photoCount).map { .init(key: "invitation/7/\($0).jpg", url: photo) }, design: d, published: published, updatedAt: "2026-10-08T05:12:33.123Z")
    }
    @MainActor private func capture<V: View>(_ view: V, name: String, top: CGFloat = 0, bottom: CGFloat = 24, scrolls: [CGFloat] = [0]) async throws {
        let controller = UIHostingController(rootView: view.padding(.top, top).padding(.bottom, bottom).background(.white).environment(\.brandStatusInset, 48).environment(\.locale, Locale(identifier: "ko_KR")))
        controller.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller; window.isHidden = false
        controller.view.frame = window.bounds; controller.view.layoutIfNeeded()
        defer { window.isHidden = true }
        try await Task.sleep(for: .seconds(4))
        func findScroll(_ view: UIView) -> UIScrollView? {
            if let scroll = view as? UIScrollView { return scroll }
            return view.subviews.compactMap { findScroll($0) }.first
        }
        for offset in scrolls {
            if offset > 0, let scroll = findScroll(controller.view) {
                scroll.setContentOffset(CGPoint(x: 0, y: min(offset, max(0, scroll.contentSize.height - scroll.bounds.height))), animated: false)
                try await Task.sleep(for: .milliseconds(400))
            }
            let format = UIGraphicsImageRendererFormat(); format.scale = 3; format.opaque = true
            let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { _ in controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true) }
            let attachment = XCTAttachment(image: image); attachment.name = "compare-\(name)-\(Int(offset))"; attachment.lifetime = .keepAlways; add(attachment)
            XCTAssertEqual(image.cgImage?.width, 1170)
            let bytes = try XCTUnwrap(image.cgImage?.dataProvider?.data)
            let ptr = CFDataGetBytePtr(bytes)!
            XCTAssertGreaterThan(Set(stride(from: 0, to: CFDataGetLength(bytes), by: 997).map { ptr[$0] }).count, 16, "A comparison must contain rendered content")
        }
    }
}

private struct ComparisonTransport: HTTPTransport {
    let content: InvitationContent?
    let pass: Bool
    func send(_ request: PreparedRequest) async throws -> HTTPResponse {
        let value: String
        if request.url.path.contains("guestbook") {
            value = #"{"total":3,"wishes":[{"id":"a1","name":"지은","message":"결혼 축하해요!","avatar":2},{"id":"a2","name":"할머니","message":"평생 지금처럼 웃으며 살아라","avatar":18},{"id":"a3","name":"민재","message":"우진아 장가 간다!","avatar":6}]}"#
        } else if request.url.path == "/plan/my-invitation" {
            let json = try content.map { String(decoding: try JSONEncoder().encode($0), as: UTF8.self) } ?? "null"
            value = "{\"roomId\":7,\"hasPass\":\(pass),\"canEdit\":\(pass),\"invitation\":\(json)}"
        } else { value = #"{"name":"지수","weddingDate":"2026-11-14","weddingVenue":"더채플앳청담","budget":4200,"roomId":7}"# }
        return HTTPResponse(status: 200, body: Data(("{\"result\":true,\"data\":" + value + "}").utf8))
    }
}
