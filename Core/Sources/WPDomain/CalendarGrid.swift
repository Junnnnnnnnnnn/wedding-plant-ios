import Foundation
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
}
