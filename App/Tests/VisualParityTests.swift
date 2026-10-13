import XCTest
import SwiftUI
import WPModels
import WPUtils
@testable import WeddingPlant

/// Identical data/390 dp viewport to Android ReminderSettingsShotTest.
/// These are review artifacts, not a claim of pixel equality across different font rasterizers.
final class VisualParityTests: XCTestCase {
    @MainActor func testGardenDropCrossesHeaderAndClearsAfterLanding() async throws {
        let width = 1080.0 / 2.625, size = CGSize(width: 1080.0 / 2.625, height: 2400.0 / 2.625)
        let controller = UIViewController(); controller.view.backgroundColor = .white
        let header = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 170)); header.backgroundColor = UIColor(WPColor.primary)
        controller.view.addSubview(header)
        let garden = GardenCanvas(wishes: [], demo: true, empty: false, peek: false, groom: "정우진", bride: "한채원")
        garden.frame = CGRect(x: 0, y: 182, width: width, height: width * 440 / 320)
        controller.view.addSubview(garden)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size)); window.rootViewController = controller; window.isHidden = false
        controller.view.frame = window.bounds; controller.view.layoutIfNeeded()
        defer { garden.stop(); window.isHidden = true }
        let format = UIGraphicsImageRendererFormat(); format.scale = 2.625; format.opaque = true; format.preferredRange = .standard
        func shot(_ name: String) -> UIImage {
            let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true) }
            let attachment = XCTAttachment(image: image); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
            return image
        }
        try await Task.sleep(for: .seconds(3))
        let baseline = shot("matched-garden-before")
        // Text must be visible, not merely present in the accessibility tree. A border
        // sublayer previously covered UILabel's rendered glyphs while UI tests still passed.
        let baselineCG = try XCTUnwrap(baseline.cgImage)
        XCTAssertEqual(baselineCG.bitsPerComponent, 8)
        let baselineData = try XCTUnwrap(baselineCG.dataProvider?.data)
        let bytes = CFDataGetBytePtr(baselineData)!
        var textPixels = 0
        let captureScale = format.scale
        let textTop = Int((garden.frame.maxY - 62) * captureScale)
        for y in textTop..<(textTop + Int(34 * captureScale)) { for x in Int(22 * captureScale)..<Int(340 * captureScale) {
            let offset = y * baselineCG.bytesPerRow + x * (baselineCG.bitsPerPixel / 8)
            if bytes[offset] > 160 && bytes[offset + 1] > 160 && bytes[offset + 2] > 160 { textPixels += 1 }
        } }
        XCTAssertGreaterThan(textPixels, 50, "The typed dialogue must actually render above its frame")
        func differentHeaderPixels(_ image: UIImage) -> Int {
            guard let a = baseline.cgImage, let b = image.cgImage, let ad = a.dataProvider?.data, let bd = b.dataProvider?.data else { return 0 }
            let ap = CFDataGetBytePtr(ad)!, bp = CFDataGetBytePtr(bd)!
            var count = 0
            for y in 0..<Int(160 * captureScale) { for x in 0..<min(a.width, b.width) {
                let ai = y * a.bytesPerRow + x * (a.bitsPerPixel / 8), bi = y * b.bytesPerRow + x * (b.bitsPerPixel / 8)
                if abs(Int(ap[ai])-Int(bp[bi])) + abs(Int(ap[ai+1])-Int(bp[bi+1])) + abs(Int(ap[ai+2])-Int(bp[bi+2])) > 30 { count += 1 }
            } }
            return count
        }
        try await Task.sleep(for: .milliseconds(700))
        var peak = 0
        for i in 0..<20 {
            peak = max(peak, differentHeaderPixels(shot(String(format: "matched-garden-flight-%02d", i))))
            try await Task.sleep(for: .milliseconds(120))
        }
        try await Task.sleep(for: .seconds(1))
        XCTAssertGreaterThan(peak, 40, "A flying guest must actually render over the header")
        XCTAssertLessThanOrEqual(differentHeaderPixels(shot("matched-garden-landed")), 10)
    }
    @MainActor func testBloomReferenceFrames() async {
        XCTAssertNotNil(UIImage(named: "heart_sprout.png"), "The Android brand asset must load in the completion card")
        for (name, action) in [("create", BloomAction.create), ("update", .update), ("delete", .delete)] {
            await snapshot(PlanBloomSuccess(title: "스튜디오 촬영", amount: 185, remaining: 1965, action: action, motionEnabled: false, showsBackdrop: false, onClose: {}), name: "matched-bloom-\(name)", width: 1080 / 2.625)
        }
    }
    @MainActor func testReminderDefaultAndBlockedReferenceFrames() async throws {
        let today = KstDate(dateString: "2026-09-26")!
        let titles = ["웨딩홀 최종 상담", "웨딩링 최종 선택", "드레스 피팅", "신혼여행 항공권 예약"]
        let amounts = [1800.0, 180, 75, 400]
        let payments = titles.indices.map { ScheduleItem(id: $0 + 1, categoryName: "", title: titles[$0], amount: amounts[$0], startDate: $0 == 3 ? "2026-10-03" : "2026-09-30", isPaid: false) }
        await snapshot(ReminderSettingsBody(setting: .init(emailAddress: "jisoo@example.com"), payments: payments,
            showPassBanner: false, phonePermitted: true, today: today, nowHour: 10, saved: true), name: "matched-reminders-default")
        await snapshot(ReminderSettingsBody(setting: .init(leadDays: [], hour: 18), payments: [],
            showPassBanner: true, phonePermitted: false, today: today, nowHour: 10), name: "matched-reminders-blocked")
    }
    @MainActor private func snapshot<V: View>(_ view: V, name: String, width: CGFloat = 390) async {
        let size = CGSize(width: width, height: 2400 / 2.625)
        let controller = UIHostingController(rootView: view.environment(\.brandStatusInset, 52).environment(\.locale, Locale(identifier: "ko_KR")))
        controller.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.frame = window.bounds; controller.view.layoutIfNeeded()
        try? await Task.sleep(for: .milliseconds(350))
        let format = UIGraphicsImageRendererFormat(); format.scale = 2.625; format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true) }
        XCTAssertEqual(image.cgImage?.width, Int((width * 2.625).rounded()))
        let attachment = XCTAttachment(image: image); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        window.isHidden = true
    }
}
