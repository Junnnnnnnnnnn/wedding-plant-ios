import XCTest
import WebKit
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
}
