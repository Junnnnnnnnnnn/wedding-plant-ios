import XCTest
import PDFKit
import WPDomain
import WPModels
import WPUtils
@testable import WeddingPlant

final class CalendarPDFTests: XCTestCase {
    @MainActor func testAllTemplatesProduceReadableMultipagePDFWithoutDroppingSchedules() throws {
        let items = (1...80).map { index in
            ScheduleItem(id: index, categoryName: "웨딩홀", title: String(format: "일정검증%03d", index), amount: 1.125,
                         startDate: index == 80 ? nil : "2026-10-13", status: index.isMultiple(of: 2) ? .completed : .planned)
        }
        for template in ExportTemplate.allCases {
            let doc = ExportDoc(items: items, template: template, scope: "전체 기간", plan: ExportPlanInfo(couple: "우진 · 채원", weddingDate: KstDate(dateString: "2026-10-13"), budget: 1000.5, venue: "바다 앞 예식장"))
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
            defer { try? FileManager.default.removeItem(at: url) }
            try CalendarPDF().write(doc, to: url)
            let pdf = try XCTUnwrap(PDFDocument(url: url))
            XCTAssertGreaterThan(pdf.pageCount, 1)
            XCTAssertEqual(pdf.page(at: 0)?.bounds(for: .mediaBox).size, CGSize(width: 842, height: 595))
            let text = (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")
            for item in items { XCTAssertTrue(text.contains(item.title), "\(template): \(item.title) missing") }
            XCTAssertTrue(text.contains("날짜 미정"))
            if template != .checklist { XCTAssertTrue(text.contains("1.125")) }
            let attachment = XCTAttachment(contentsOfFile: url); attachment.name = "parity-\(template.rawValue)-80-items"; attachment.lifetime = .keepAlways; add(attachment)
            if let page = pdf.page(at: 0) {
                let image = page.thumbnail(of: CGSize(width: 1684, height: 1190), for: .mediaBox)
                let shot = XCTAttachment(image: image); shot.name = "pdf-\(template.rawValue)-first-page"; shot.lifetime = .keepAlways; add(shot)
            }
        }
    }
}
