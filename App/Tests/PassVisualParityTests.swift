import XCTest
import WebKit
import SwiftUI
import WPModels
import WPNetworking
@testable import WeddingPlant

final class PassVisualParityTests: XCTestCase {
    @MainActor func testBenefitFramesAtRestAndMidway() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: configuration)
        web.scrollView.contentInsetAdjustmentBehavior = .never
        let host = UIViewController(); host.view = web
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene); window.frame = web.frame; window.rootViewController = host; window.makeKeyAndVisible()
        host.view.frame = window.bounds; host.view.layoutIfNeeded()
        defer { web.stopLoading(); window.isHidden = true }
        let url = try XCTUnwrap(Bundle.main.url(forResource: "pass-intro", withExtension: "html"))
        web.loadFileURL(url, allowingReadAccessTo: Bundle.main.bundleURL)
        var ready = false
        for _ in 0..<100 {
            if (try? await web.evaluateJavaScript("typeof window.weddingPassCapture === 'function'")) as? Bool == true { ready = true; break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertTrue(ready, "Bundled pass scene must initialize without JavaScript errors")
        guard ready else { return }
        _ = try await web.evaluateJavaScript("document.documentElement.style.setProperty('--safe-top','0px'); document.documentElement.style.setProperty('--safe-bottom','0px'); true")
        // 앱은 광고가 있는 빌드에서 마무리 장면에 「광고 없이」 칩을 더한다(PassView 와 같은 스크립트)
        if AdsService.enabled { _ = try await web.evaluateJavaScript(PassView.adsChipScript + "true") }
        let moments = (0...5).map { ($0, 6600) } + [(1,2600),(2,2800),(3,2300),(4,2225)]
        for (scene, time) in moments {
            _ = try await web.callAsyncJavaScript("return await window.weddingPassCapture(scene, time)", arguments: ["scene":scene,"time":time], in: nil, contentWorld: .page)
            try await Task.sleep(for: .milliseconds(100))
            let image = try await web.takeSnapshot(configuration: nil)
            let pixelData = try XCTUnwrap(image.cgImage?.dataProvider?.data)
            let bytes = CFDataGetBytePtr(pixelData)!
            let sampled = stride(from: 0, to: CFDataGetLength(pixelData), by: 997).map { bytes[$0] }
            XCTAssertGreaterThan(Set(sampled).count, 16, "A WebKit snapshot must contain rendered pixels, not a blank surface")
            let attachment = XCTAttachment(image: image)
            attachment.name = time == 6600 ? "matched-intro-page-\(scene)" : "matched-intro-demo-\(scene)-\(time)"
            attachment.lifetime = .keepAlways; add(attachment)
            if (1...4).contains(scene) {
                let drawn = try await web.evaluateJavaScript("document.querySelector('[data-scene=\"\(scene)\"] canvas').width > 0")
                XCTAssertEqual(drawn as? Bool, true)
            }
        }
        for time in [1200,2450,4000] {
            _ = try await web.callAsyncJavaScript("return await window.weddingPassCaptureOpening(time)", arguments: ["time":time], in: nil, contentWorld: .page)
            try await Task.sleep(for: .milliseconds(100))
            let image = try await web.takeSnapshot(configuration: nil)
            let attachment = XCTAttachment(image: image); attachment.name = "matched-intro-open-\(time)"; attachment.lifetime = .keepAlways; add(attachment)
        }

    }
    /// 서류 칸·서류 보관함·요금제·새 버전 알림을 안드로이드 캡처와 같은 상태로 찍는다(네트워크 없음).
    @MainActor func testDocumentsPlansAndUpdateFrames() async throws {
        let base = URL(string: "https://docs-review.test")!
        let store = InMemoryTokenStore(token: DemoData.token)
        PassFileUploader.previewForTests = { _ in UIImage(named: "app_logo") }
        defer { PassFileUploader.previewForTests = nil }
        let card: (PassDocumentsView) -> AnyView = { view in
            AnyView(VStack(spacing: 0) { view.padding(.horizontal, 24).padding(.bottom, 18); Spacer(minLength: 0) }.padding(.top, 8).background(Color.white))
        }
        let shots: [(String, String, AnyView)] = [
            ("docs-card-locked", "locked", card(PassDocumentsView(scheduleId: 1))),
            ("docs-card-viewonly", "files", card(PassDocumentsView(scheduleId: 1))),
            ("docs-card-active", "paid-empty", card(PassDocumentsView(scheduleId: 1, canAdd: true))),
            ("docs-card-uploading", "files", card(PassDocumentsView(scheduleId: 1, canAdd: true, initiallyBusy: true))),
            ("docs-card-files", "files", card(PassDocumentsView(scheduleId: 1, canAdd: true))),
            ("docs-card-expired", "expired", card(PassDocumentsView(scheduleId: 1))),
            ("docs-card-error", "error", card(PassDocumentsView(scheduleId: 1, canAdd: true))),
            ("vault-library", "vault", AnyView(DocumentsWorkspaceView(roomId: 1))),
            ("vault-plans", "vault", AnyView(DocumentsWorkspaceView(roomId: 1, initialTab: .plans))),
            ("vault-overview", "vault", AnyView(DocumentsWorkspaceView(roomId: 1, initialTab: .overview))),
            ("vault-expired", "vault-expired", AnyView(DocumentsWorkspaceView(roomId: 1))),
            ("vault-error", "error", AnyView(DocumentsWorkspaceView(roomId: 1))),
            ("vault-empty", "vault-empty", AnyView(DocumentsWorkspaceView(roomId: 1))),
            ("vault-inspector-delete", "vault", AnyView(DocumentsWorkspaceView(roomId: 1, initialSelectedId: 11, initialConfirmDelete: true))),
            ("vault-inspector-photo", "vault", AnyView(DocumentsWorkspaceView(roomId: 1, initialSelectedId: 12))),
            ("vault-inspector-pdf", "vault", AnyView(DocumentsWorkspaceView(roomId: 1, initialSelectedId: 11))),
            ("vault-download-all", "vault", AnyView(PassDownloadView(roomId: 1))),
            ("plans-yearly", "locked", AnyView(PassPlansView(roomId: 1))),
            ("plans-lifetime", "lifetime", AnyView(PassPlansView(roomId: 1))),
            ("update-card", "locked", AnyView(UpdateDialog(onUpdate: {}, onLater: {}).background(Color(white: 0.5)))),
        ]
        for (name, mode, view) in shots {
            let env = AppEnvironment(api: APIClient(baseURL: base, transport: DocsReviewTransport(mode: mode), tokenStore: store), tokenStore: store, baseURL: base, isDemo: true)
            env.isAuthenticated = true
            let controller = UIHostingController(rootView: view.environmentObject(env).tint(WPColor.primary).environment(\.locale, Locale(identifier: "ko_KR")))
            controller.safeAreaRegions = []
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            window.rootViewController = controller; window.isHidden = false
            controller.view.frame = window.bounds; controller.view.layoutIfNeeded()
            try await Task.sleep(for: .seconds(2))
            let format = UIGraphicsImageRendererFormat(); format.scale = 3; format.opaque = true; format.preferredRange = .standard
            let image = UIGraphicsImageRenderer(size: controller.view.bounds.size, format: format).image { _ in
                controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
            window.isHidden = true
        }
    }
}

/// 안드로이드 서류·요금제 캡처와 같은 고정 데이터.
private struct DocsReviewTransport: HTTPTransport {
    let mode: String
    func send(_ request: PreparedRequest) async throws -> HTTPResponse {
        let path = request.url.path
        func ok(_ value: String) -> HTTPResponse { HTTPResponse(status: 200, body: Data(("{\"result\":true,\"data\":" + value + "}").utf8)) }
        let pdf = #"{"id":11,"fileName":"웨딩홀 계약서.pdf","contentType":"application/pdf","sizeBytes":12373196,"createdAt":"2026-09-25T03:00:00Z"}"#
        let jpg = #"{"id":12,"fileName":"웨딩홀 계약금 영수증.jpg","contentType":"image/jpeg","sizeBytes":3774873,"createdAt":"2026-09-24T03:00:00Z"}"#
        let pdf2 = #"{"id":13,"fileName":"드레스 견적서.pdf","contentType":"application/pdf","sizeBytes":245760,"createdAt":"2026-09-23T03:00:00Z"}"#
        if path.contains("/plan/pass/room/") {
            switch mode {
            case "locked": return ok(#"{"hasPass":false}"#)
            case "expired", "vault-expired": return ok(#"{"hasPass":false,"expired":true,"plan":"YEARLY"}"#)
            case "lifetime": return ok(#"{"hasPass":true,"plan":"LIFETIME","buyerName":"지수"}"#)
            default: return ok(#"{"hasPass":true,"plan":"YEARLY","buyerName":"지수","expiresAt":"2027-10-08T03:00:00Z"}"#)
            }
        }
        if path.contains("/plan/pass/file/schedule/") {
            if mode == "error" { return HTTPResponse(status: 503, body: Data()) }
            let id = path.split(separator: "/").last.map(String.init) ?? ""
            let canOpen = !["locked", "expired", "vault-expired"].contains(mode)
            let list: String
            switch mode {
            case "files": list = "[\(pdf),\(pdf2)]"
            case "expired", "vault-expired": list = id == "1" ? "[\(pdf)]" : "[]"
            case "vault": list = id == "1" ? "[\(pdf),\(jpg)]" : "[]"
            default: list = "[]"
            }
            return ok("{\"canOpen\":\(canOpen),\"roomId\":1,\"quotaBytes\":1073741824,\"usedBytes\":\(mode == "vault" ? 16148070 : 0),\"list\":\(list)}")
        }
        if path == "/plan/room/1" {
            if mode == "error" { return HTTPResponse(status: 503, body: Data()) }
            return ok(#"{"name":"","onwerName":""}"#)
        }
        if path.hasSuffix("/list") && path.contains("/plan/schedule") {
            return ok(#"{"total":2,"list":[{"id":1,"title":"웨딩홀 계약","categoryName":"예식장","startDate":"2026-10-03"},{"id":2,"title":"본식 드레스 잔금","categoryName":"드레스","startDate":"2026-10-12"}]}"#)
        }
        if path.hasSuffix("/download-all") {
            return ok(#"{"list":[{"fileName":"웨딩홀 계약서.pdf","url":"https://docs-review.test/a.pdf"},{"fileName":"웨딩홀 계약금 영수증.jpg","url":"https://docs-review.test/b.jpg"}]}"#)
        }
        if path.hasSuffix("/plan/my-invitation") { return ok(#"{"roomId":1,"hasPass":false,"canEdit":false}"#) }
        return ok("{}")
    }
}

