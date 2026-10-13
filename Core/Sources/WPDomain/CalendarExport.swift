import Foundation
import WPModels
import WPUtils

public enum ExportTemplate: String, CaseIterable, Sendable {
    case checklist, budget, monthly
    public var label: String { switch self { case .checklist: return "일정 체크리스트"; case .budget: return "예산 정산표"; case .monthly: return "월별 준비표" } }
    public var description: String { switch self { case .checklist: return "해야 할 일을 날짜순으로 차근차근"; case .budget: return "예정 금액과 결제 내역을 한눈에"; case .monthly: return "달마다 준비할 일을 나누어 보기" } }
}
public struct ExportPlanInfo: Sendable {
    public let couple: String?, weddingDate: KstDate?, budget: Double?, venue: String?
    public init(couple: String?, weddingDate: KstDate?, budget: Double?, venue: String?) { self.couple = couple; self.weddingDate = weddingDate; self.budget = budget; self.venue = venue }
}
public struct ExportTotals: Equatable, Sendable {
    public let count, done, paidCount, unpaidCount, unknown, unpaidUnknown, undated: Int
    public let paid, unpaid: Double
    public var total: Double { paid + unpaid }
}
public struct ExportMonthGroup: Sendable {
    public let key, label, short: String
    public let year: Int?
    public var items: [ScheduleItem]
}
public struct ExportDoc: Sendable {
    public let items: [ScheduleItem], template: ExportTemplate, scope: String, plan: ExportPlanInfo?, today: KstDate
    public init(items: [ScheduleItem], template: ExportTemplate, scope: String, plan: ExportPlanInfo?, today: KstDate = .today()) {
        self.items = items; self.template = template; self.scope = scope; self.plan = plan; self.today = today
    }
}
public enum CalendarExport {
    public static let samplePlan = ExportPlanInfo(couple: "지수 · 민호", weddingDate: KstDate(dateString: "2027-03-13"), budget: 4000, venue: "그랜드 라온홀")
    /// The same 17 fictional schedules as Android CalendarExport.examples.
    public static var examples: [ScheduleItem] {
        func e(_ id: Int, _ category: String, _ title: String, _ amount: Double?, _ date: String?, _ time: String?, _ done: Bool, _ paid: Bool?) -> ScheduleItem {
            ScheduleItem(id: id, categoryName: category, title: title, amount: amount, startDate: date, status: .init(rawValue: done ? "COMPLETED" : "NORMAL"), isPaid: paid, startTime: time)
        }
        return [
            e(1, "예식장", "웨딩홀 계약금", 300.0, "2026-09-05", "14:00", true, true),
            e(2, "스드메", "드레스 투어", 15.0, "2026-09-12", "11:00", true, true),
            e(3, "스드메", "스튜디오 상담", nil, "2026-09-26", "16:00", true, nil),
            e(4, "스드메", "스드메 패키지 계약금", 100.0, "2026-10-04", "13:00", false, true),
            e(5, "상견례", "상견례", 45.0, "2026-10-17", "12:00", false, false),
            e(6, "예물", "예물 상담", nil, "2026-10-25", "15:30", false, nil),
            e(7, "스냅·영상", "본식 스냅 계약", 120.0, "2026-11-08", nil, false, false),
            e(8, "예물", "웨딩링 구매", 250.0, "2026-11-21", "14:00", false, false),
            e(9, "청첩장", "청첩장 주문", 38.0, "2026-12-05", nil, false, false),
            e(10, "한복", "한복 맞춤", 90.0, "2026-12-19", "11:00", false, false),
            e(11, "신혼여행", "신혼여행 항공권", 320.0, "2027-01-09", nil, false, true),
            e(12, "혼수", "혼수 가전 계약", 850.0, "2027-01-23", "10:30", false, false),
            e(13, "스드메", "드레스 가봉", nil, "2027-02-13", "14:00", false, nil),
            e(14, "부케·꽃", "부케 주문", 25.0, "2027-02-27", nil, false, false),
            e(15, "예식장", "본식 · 예식장 잔금", 1450.0, "2027-03-13", "12:30", false, false),
            e(16, "혼수", "신혼집 입주 청소", 40.0, nil, nil, false, false),
            e(17, "기타", "축가 답례 선물", nil, nil, nil, false, nil),
        ]
    }

    public static func sorted(_ items: [ScheduleItem]) -> [ScheduleItem] {
        items.filter { $0.status?.rawValue != "DELETE" }.sorted {
            let lhs = dateOf($0)?.dateString ?? "9999-99-99", rhs = dateOf($1)?.dateString ?? "9999-99-99"
            if lhs != rhs { return lhs < rhs }; if $0.startTime != $1.startTime { return ($0.startTime ?? "") < ($1.startTime ?? "") }
            return $0.id < $1.id
        }
    }
    public static func dateOf(_ item: ScheduleItem) -> KstDate? { item.startDate.flatMap { KstDate(dateString: $0) } }
    public static func scope(_ items: [ScheduleItem], month: String?) -> [ScheduleItem] { sorted(items).filter { month == nil || dateOf($0)?.dateString.hasPrefix(month!) == true } }
    public static func scopeLabel(_ month: String?) -> String {
        guard let month, let date = KstDate(dateString: month + "-01") else { return "전체 기간 · 날짜 미정 포함" }
        return String(format: "%d년 %02d월", date.year, date.month)
    }
    public static func fileName(_ template: ExportTemplate, format: String, month: String?, sample: Bool) -> String { "웨딩플랜트_\(sample ? "예시_" : "")\(template.label)_\(month ?? "전체").\(format)" }
    public static func groupByMonth(_ items: [ScheduleItem]) -> [ExportMonthGroup] {
        var groups: [ExportMonthGroup] = []
        for item in sorted(items) {
            let date = dateOf(item), key = date.map { String($0.dateString.prefix(7)) } ?? "none"
            if let i = groups.firstIndex(where: { $0.key == key }) { groups[i].items.append(item) }
            else { groups.append(ExportMonthGroup(key: key, label: date.map { "\($0.year)년 \($0.month)월" } ?? "날짜 미정", short: date.map { "\($0.month)월" } ?? "미정", year: date?.year, items: [item])) }
        }
        return groups
    }
    public static func totals(_ items: [ScheduleItem]) -> ExportTotals {
        let paid = items.filter(\.isPaid), unpaid = items.filter { !$0.isPaid }
        return ExportTotals(count: items.count, done: items.filter { $0.status?.isCompleted == true }.count,
            paidCount: paid.filter { $0.amount != nil }.count, unpaidCount: unpaid.filter { $0.amount != nil }.count,
            unknown: items.filter { $0.amount == nil }.count, unpaidUnknown: unpaid.filter { $0.amount == nil }.count, undated: items.filter { dateOf($0) == nil }.count, paid: paid.reduce(0) { $0 + ($1.amount ?? 0) }, unpaid: unpaid.reduce(0) { $0 + ($1.amount ?? 0) })
    }
    public static func dday(_ doc: ExportDoc) -> Int? { guard let date = doc.plan?.weddingDate else { return nil }; let d = doc.today.days(until: date); return d < 0 ? nil : d }
    public static func won(_ n: Double) -> String { let f = NumberFormatter(); f.locale = Locale(identifier: "ko_KR"); f.numberStyle = .decimal; f.maximumFractionDigits = 3; return f.string(from: NSNumber(value: n)) ?? String(n) }
    public static func summaryStats(_ doc: ExportDoc) -> [(String, String, String)] {
        let t = totals(doc.items)
        switch doc.template {
        case .budget:
            return [("결제한 돈", won(t.paid), "만 원"), ("남은 결제", won(t.unpaid), "만 원"), doc.plan?.budget.map { ("예산 \(won($0))만 원 중 남음", won($0 - t.total), "만 원") } ?? ("합계", won(t.total), "만 원")]
        case .checklist: return [("끝낸 일", "\(t.done)", "/ \(t.count)개"), ("남은 일", "\(t.count - t.done)", "개"), ("날짜 미정", "\(t.undated)", "개")]
        case .monthly: return [("준비 기간", "\(groupByMonth(doc.items).filter { $0.year != nil }.count)", "개월"), ("일정", "\(t.count)", "개"), ("금액 합계", won(t.total), "만 원")]
        }
    }
}
/// Reject incomplete or changing pagination instead of exporting a partial plan as complete.
public struct SchedulePages {
    private var ids = Set<Int>(), items: [ScheduleItem] = [], total: Int?
    public init() {}
    public mutating func append(_ page: SchedulePage) throws -> Bool {
        guard page.total >= 0, total == nil || total == page.total else { throw ExportPageError.changed }
        guard page.list.allSatisfy({ !ids.contains($0.id) }), Set(page.list.map(\.id)).count == page.list.count else { throw ExportPageError.incomplete }
        guard items.count + page.list.count <= page.total, !page.list.isEmpty || items.count == page.total else { throw ExportPageError.incomplete }
        total = page.total; ids.formUnion(page.list.map(\.id)); items += page.list
        return items.count == page.total
    }
    public var result: [ScheduleItem] { items.filter { $0.status?.rawValue != "DELETE" } }
}
public enum ExportPageError: LocalizedError {
    case changed, incomplete
    public var errorDescription: String? { self == .changed ? "플랜이 변경됐어요. 다시 불러와 주세요." : "전체 플랜을 확인하지 못했어요." }
}
