import XCTest
import WPModels
import WPUtils
@testable import WPDomain

final class ExportActivityTests: XCTestCase {
    func testWorkbookArtifactsForIndependentReaderValidation() throws {
        let items = [ScheduleItem(id: 1, categoryName: "=기타*", title: "=SUM(1,2) & <확인>", amount: 1234, startDate: "2026-10-13", status: .completed, isPaid: false), ScheduleItem(id: 2, categoryName: "여행", title: "예약", amount: 50, startDate: "2026-11-01"), ScheduleItem(id: 3, categoryName: "기타", title: "날짜 미정", amount: nil)]
        for template in ExportTemplate.allCases {
            let doc = ExportDoc(items: items, template: template, scope: "전체 기간 · 날짜 미정 포함", plan: nil, today: KstDate(dateString: "2026-10-13")!)
            let data = CalendarWorkbook.data(doc)
            XCTAssertEqual(Array(data.prefix(4)), [0x50,0x4b,0x03,0x04])
            // Optional artifact output lets CI validate OOXML with an independent ZIP/XML reader.
            if let directory = ProcessInfo.processInfo.environment["WP_EXPORT_ARTIFACTS"] {
                try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
                try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent(template.rawValue + ".xlsx"))
            }
        }
    }
    func testActivitiesOnlyIncludeCreatedAndCompletedAndPreserveMessageOrder() {
        let messages = [ChatLine(id: "m1", createDate: "2026-10-13T10:00:00+09:00"), ChatLine(id: "m2", createDate: "2026-10-13T11:00:00+09:00")]
        let activities = [PlanActivity(id: 1, type: "SCHEDULE_CREATED", createDate: "2026-10-13T09:00:00+09:00"), PlanActivity(id: 2, type: "BUDGET_UPDATED", createDate: "2026-10-13T10:30:00+09:00"), PlanActivity(id: 3, type: "SCHEDULE_COMPLETED", createDate: "2026-10-13T11:00:00+09:00")]
        XCTAssertEqual(ChatActivityRules.merge(messages: messages, activities: activities, hasMore: true).map(\.id), ["m1", "activity-3", "m2"])
        XCTAssertEqual(ChatActivityRules.merge(messages: messages, activities: activities, hasMore: false).map(\.id), ["activity-1", "m1", "activity-3", "m2"])
    }
    func testActivitySentenceDoesNotAddMoneyForCompletion() {
        XCTAssertEqual(ChatActivityRules.sentence(.init(id: 1, type: "SCHEDULE_COMPLETED", actorName: " 지수 ", targetTitle: "계약", amount: 1500)), "지수님이 일정을 완료했어요 · 계약")
        XCTAssertEqual(ChatActivityRules.sentence(.init(id: 2, type: "SCHEDULE_CREATED", actorName: "", amount: 1234.125)), "누군가님이 일정을 추가했어요 · 1,234.125만원")
    }
    func testExportSortScopeAndPaidTotals() {
        let items = [ScheduleItem(id: 1, categoryName: "기타", title: "미정", amount: nil), ScheduleItem(id: 2, categoryName: "예식", title: "완료", amount: 120, startDate: "2026-10-13", status: .completed, isPaid: false), ScheduleItem(id: 3, categoryName: "예식", title: "예정", amount: 50, startDate: "2026-09-20", isPaid: false), ScheduleItem(id: 4, categoryName: "삭제", title: "삭제", status: .init(rawValue: "DELETE"))]
        XCTAssertEqual(CalendarExport.sorted(items).map(\.id), [3,2,1])
        XCTAssertEqual(CalendarExport.scope(items, month: "2026-10").map(\.id), [2])
        let t = CalendarExport.totals(CalendarExport.sorted(items))
        XCTAssertEqual(t.paid, 120); XCTAssertEqual(t.unpaid, 50); XCTAssertEqual(t.unknown, 1); XCTAssertEqual(t.unpaidUnknown, 1)
        XCTAssertEqual(CalendarExport.groupByMonth(items).map(\.key), ["2026-09", "2026-10", "none"])
        XCTAssertEqual(CalendarExport.fileName(.budget, format: "pdf", month: nil, sample: false), "웨딩플랜트_예산 정산표_전체.pdf")
    }
    func testPaginationRejectsDuplicatesChangingTotalsAndPrematureEnd() throws {
        let one = ScheduleItem(id: 1, categoryName: "", title: "A"), two = ScheduleItem(id: 2, categoryName: "", title: "B")
        var p = SchedulePages(); XCTAssertFalse(try p.append(.init(total: 2, list: [one])))
        XCTAssertThrowsError(try p.append(.init(total: 2, list: [one])))
        XCTAssertThrowsError(try p.append(.init(total: 3, list: [two])))
        XCTAssertThrowsError(try p.append(.init(total: 2, list: [])))
        XCTAssertTrue(try p.append(.init(total: 2, list: [two]))); XCTAssertEqual(p.result.map(\.id), [1,2])
    }
}
