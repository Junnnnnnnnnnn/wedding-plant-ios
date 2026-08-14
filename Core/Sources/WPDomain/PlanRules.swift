import Foundation
import WPUtils

/// 웹에 흩어져 있던 순수 판정 로직을 한곳에 모은 것.
///
/// 안드로이드 `domain/PlanRules.kt` 와 **같은 값을 내야 한다.** 세 앱(웹·안드로이드·iOS)이
/// 같은 화면을 그리는 것이 목표이므로, 라벨 문자열과 색상 인덱스까지 일치해야 한다.
/// UI·네트워크 의존이 없어 Windows 에서 전부 유닛테스트로 검증된다.
public enum PlanRules {

    // MARK: - D-Day

    /// 결혼식까지 남은 일수. 지났으면 음수. 날짜가 없으면 nil.
    public static func dDay(weddingDate: KstDate?, now: Date = Date()) -> Int? {
        weddingDate?.daysFromToday(now: now)
    }

    /// 웹 `dDayLabel` 과 **문자열까지 동일**해야 한다.
    ///
    /// 날짜 미설정 `"날짜 설정"` · 남음 `"D-120"` · 당일 `"D-Day"` · 지남 `"D+3"`
    public static func dDayLabel(weddingDate: KstDate?, now: Date = Date()) -> String {
        guard let days = dDay(weddingDate: weddingDate, now: now) else { return "날짜 설정" }
        if days > 0 { return "D-\(days)" }
        if days == 0 { return "D-Day" }
        return "D+\(abs(days))"
    }

    // MARK: - 일정 상태

    public enum DateStatus: String, Sendable, CaseIterable {
        case upcoming
        case soon
        case today
        case past

        /// 뱃지에 찍히는 문구. 웹과 동일.
        public var label: String {
            switch self {
            case .upcoming: return "예정"
            case .soon: return "임박"
            case .today: return "D-day"
            case .past: return "지남"
            }
        }
    }

    /// 웹 `getDateStatusLabel()` — 시작일과 오늘(KST) 비교.
    ///
    /// 날짜가 없거나 파싱 실패하면 `.upcoming` (웹과 동일하게 예외를 던지지 않는다).
    public static func dateStatus(startDate: String?, now: Date = Date()) -> DateStatus {
        guard let raw = startDate, let date = KstDate(dateString: raw) else { return .upcoming }
        let diff = date.daysFromToday(now: now)
        if diff < 0 { return .past }
        if diff == 0 { return .today }
        if diff <= 5 { return .soon }
        return .upcoming
    }

    public static func isStartDatePast(_ startDate: String?, now: Date = Date()) -> Bool {
        dateStatus(startDate: startDate, now: now) == .past
    }

    // MARK: - 카테고리 색상

    /// 웹 `getCategoryColor()` 의 파스텔 팔레트. 0xRRGGBB.
    public static let categoryColors: [UInt32] = [
        0xFFE4E9, 0xE8DDF5, 0xD5F0E5, 0xFFF0D6, 0xD4EBF7, 0xFFE5D9,
    ]

    /// 카테고리명 해시로 파스텔 색을 고른다. 같은 이름은 항상 같은 색.
    ///
    /// 웹과 **완전히 동일한 색**이 나와야 하므로 JS 의 32비트 정수 오버플로 동작을 그대로 재현한다.
    ///
    /// ```js
    /// hash = (hash << 5) - hash + charCode; hash |= 0;   // Int32 로 wrap
    /// index = Math.abs(hash) % colors.length;
    /// ```
    ///
    /// 두 가지가 핵심이다.
    /// 1. `Int32` 오버플로 연산(`&<<` `&-` `&+`)을 써야 한다. 그냥 `<<`/`+` 면 크래시하거나 값이 달라진다.
    /// 2. `Math.abs(-2147483648)` 은 JS 에서 `2147483648` 이다. `Int32` 로 abs 를 취하면 오버플로하므로
    ///    `Int64` 로 넓힌 뒤 abs 를 적용한다.
    /// 3. JS 의 `charCodeAt` 은 **UTF-16 코드 유닛**이므로 `unicodeScalars` 가 아니라 `utf16` 을 순회한다.
    public static func categoryColorHex(_ categoryName: String) -> UInt32 {
        var hash: Int32 = 0
        for unit in categoryName.utf16 {
            hash = (hash &<< 5) &- hash &+ Int32(unit)
        }
        let index = Int(abs(Int64(hash)) % Int64(categoryColors.count))
        return categoryColors[index]
    }

    // MARK: - 예산

    /// 예산 사용률(%). 총예산이 0 이하면 0. **100 을 넘어도 그대로 반환**한다(웹과 동일).
    public static func budgetUsagePercent(total: Double, used: Double) -> Int {
        guard total > 0 else { return 0 }
        return Int((used / total) * 100)
    }

    /// 진행바 너비용 — 0...100 으로 클램프.
    public static func budgetUsagePercentClamped(total: Double, used: Double) -> Int {
        min(max(budgetUsagePercent(total: total, used: used), 0), 100)
    }
}
