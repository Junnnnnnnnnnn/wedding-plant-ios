import Foundation
import WPModels
import WPUtils

/// 달력 격자 계산. 웹 `app/calendar/page.tsx:daysInMonth` 이식.
public enum CalendarGrid {

    /// 격자는 **항상 42칸(6주)** 이다. 달마다 높이가 바뀌지 않게 하려는 웹의 선택.
    public static let cellCount = 42

    /// 요일 머리글. 첫 칸은 일요일.
    public static let weekdayLabels = ["일", "월", "화", "수", "목", "금", "토"]

    /// 앞달 패딩 + 이번 달 + 뒷달 패딩으로 42칸을 채운다.
    ///
    /// 첫 칸은 그 달 1일이 속한 주의 일요일이다.
    public static func build(year: Int, month: Int) -> [KstDate] {
        guard let first = KstDate(year: year, month: month, day: 1) else { return [] }
        let start = first.adding(days: -first.weekdayIndex)
        return (0..<cellCount).map { start.adding(days: $0) }
    }

    public static func build(cursor: KstDate) -> [KstDate] {
        build(year: cursor.year, month: cursor.month)
    }

    /// 화면에 필요한 달들 — 앞·현재·뒤.
    ///
    /// 격자에 앞뒤 달 날짜가 섞여 나오므로 그 달들도 같이 받아야 한다.
    ///
    /// - Note: 웹은 **현재 달만** 요청해서, 앞뒤 달 칸에는 플랜이 있어도 아무것도 안 뜨고
    ///   그 칸을 눌러도 "등록된 플랜이 없어요" 가 나온다. 안드로이드가 이걸 고쳤고 여기서도
    ///   같은 선택을 한다. 화면 구성은 웹과 같고, 비어 보이던 칸이 채워질 뿐이다.
    public static func monthsToFetch(cursor: KstDate) -> [(year: Int, month: Int)] {
        [-1, 0, 1].map { delta in
            let moved = cursor.firstOfMonth.addingMonths(delta)
            return (moved.year, moved.month)
        }
    }

    /// 앞·현재·뒤 달에 **고른 날의 달**까지(안드로이드 `CalendarViewModel.monthsToLoad`).
    ///
    /// 달력 아래 그날 목록은 고른 날을 보여 주는데, 앞뒤 달 칸을 눌러 두고 달을 넘기면
    /// 그 날이 받아 둔 범위 밖으로 나가 목록이 비어 보인다.
    public static func monthsToFetch(cursor: KstDate, selected: KstDate) -> [(year: Int, month: Int)] {
        var result = monthsToFetch(cursor: cursor)
        if !result.contains(where: { $0.year == selected.year && $0.month == selected.month }) {
            result.append((selected.year, selected.month))
        }
        return result
    }

    /// 그 달 합계 — 웹 `monthTotals`, 안드로이드 `UiState.monthTotals`.
    ///
    /// `byDay` 는 앞뒤 달까지 들고 있으므로 **그 달의 날짜 키만** 센다.
    /// 돈은 결제 기준(`isPaid`), 개수는 일정 수 — 두 줄이 서로 다른 것을 센다.
    public struct MonthTotals: Equatable, Sendable {
        public var spent: Double
        public var planned: Double
        public var count: Int
        public init(spent: Double = 0, planned: Double = 0, count: Int = 0) {
            self.spent = spent; self.planned = planned; self.count = count
        }
    }

    public static func monthTotals(
        byDay: [String: [CalendarPlanItem]], year: Int, month: Int
    ) -> MonthTotals {
        let prefix = String(format: "%04d-%02d-", year, month)
        var totals = MonthTotals()
        for (day, list) in byDay where day.hasPrefix(prefix) {
            for item in list {
                totals.count += 1
                let amount = item.amount ?? 0
                if item.isPaid { totals.spent += amount } else { totals.planned += amount }
            }
        }
        return totals
    }

    /// 보드 뷰 묶음 — 안드로이드 `groupForBoard`, 웹 `boardGroups`.
    ///
    /// **날짜 미정이 맨 앞**, 그 뒤로 달 순서, 묶음 안에서 완료는 아래로(지우지 않는다).
    public static func boardGroups(_ items: [ScheduleItem]) -> [(label: String, items: [ScheduleItem])] {
        var buckets: [String: [ScheduleItem]] = [:]
        for item in items {
            let key = KstDate(dateString: item.startDate ?? "")
                .map { String(format: "%04d-%02d", $0.year, $0.month) } ?? ""
            buckets[key, default: []].append(item)
        }
        let keys = buckets.keys.sorted { a, b in
            if a.isEmpty != b.isEmpty { return a.isEmpty }
            return a < b
        }
        return keys.map { key in
            let sorted = buckets[key]!.sorted { a, b in
                let ad = a.isScheduleCompleted ? 1 : 0, bd = b.isScheduleCompleted ? 1 : 0
                if ad != bd { return ad < bd }
                let at = KstDate(dateString: a.startDate ?? ""), bt = KstDate(dateString: b.startDate ?? "")
                switch (at, bt) {
                case let (x?, y?) where x != y: return x < y
                case (_?, nil): return true
                case (nil, _?): return false
                default: return a.id < b.id
                }
            }
            let label: String
            if key.isEmpty {
                label = "날짜 미정"
            } else {
                let parts = key.split(separator: "-")
                label = "\(parts[0])년 \(Int(parts[1]) ?? 0)월"
            }
            return (label, sorted)
        }
    }
}
