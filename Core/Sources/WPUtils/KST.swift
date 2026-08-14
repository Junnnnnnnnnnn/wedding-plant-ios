import Foundation

/// 한국 표준시(KST, UTC+9) 기준 날짜 처리.
///
/// 웹 `lib/utils.ts` 의 `getKstToday / getKstDate / getKstDateString / parseLocalDate` 를 옮긴 것.
/// 앱 전체에서 `Date()` 의 로컬 타임존 컴포넌트를 직접 읽는 것을 금지하고 여기를 거친다.
public enum KST {
    /// 고정 오프셋 +9시간.
    ///
    /// `TimeZone(identifier: "Asia/Seoul")` 대신 고정 오프셋을 쓰는 이유:
    /// 1. 웹 구현(`now.getTime() + 9h` 후 UTC 컴포넌트 추출)과 **정확히 동일한** 결과를 보장한다.
    /// 2. 한국은 현재 DST가 없어 미래 날짜에 대해 항상 +9로 동일하다.
    /// 3. Windows(swift-corelibs-foundation)에서 tz 데이터베이스 의존을 피할 수 있다.
    public static let secondsFromGMT = 9 * 60 * 60

    public static let timeZone = TimeZone(secondsFromGMT: secondsFromGMT)!

    public static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

/// KST 기준 달력 날짜(연·월·일). 시각 정보를 갖지 않는다.
public struct KstDate: Hashable, Sendable, Codable, Comparable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    /// 실제 존재하는 날짜만 허용한다.
    ///
    /// - Note: 웹의 `parseLocalDate` 는 `new Date(2026, 1, 30)` 처럼 존재하지 않는 날짜를
    ///         다음 달로 넘겨버렸다(2026-02-30 → 2026-03-02). 여기서는 `nil` 을 반환해
    ///         잘못된 입력이 조용히 다른 날짜로 바뀌지 않게 한다.
    public init?(year: Int, month: Int, day: Int) {
        guard (1...12).contains(month), day >= 1 else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        let calendar = KST.calendar
        guard let date = calendar.date(from: components) else { return nil }
        let roundTrip = calendar.dateComponents([.year, .month, .day], from: date)
        guard roundTrip.year == year, roundTrip.month == month, roundTrip.day == day else {
            return nil
        }
        self.year = year
        self.month = month
        self.day = day
    }

    /// `"YYYY-MM-DD"` 파싱. ISO 문자열(`"2026-08-14T09:00:00Z"`)이 와도 앞 10자만 읽는다.
    public init?(dateString: String) {
        let trimmed = dateString.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 10 else { return nil }
        let head = String(trimmed.prefix(10))
        let parts = head.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// KST 기준 오늘.
    ///
    /// - Parameter now: 테스트에서 주입 가능한 현재 시각. 기본값은 실제 현재 시각.
    public static func today(now: Date = Date()) -> KstDate {
        let components = KST.calendar.dateComponents([.year, .month, .day], from: now)
        // 유효한 Date에서 뽑아낸 컴포넌트이므로 항상 성공한다.
        return KstDate(
            year: components.year!,
            month: components.month!,
            day: components.day!
        )!
    }

    /// `"YYYY-MM-DD"` 문자열.
    public var dateString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public var description: String { dateString }

    /// 해당 날짜의 KST 자정에 해당하는 `Date`.
    public var startOfDay: Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return KST.calendar.date(from: components)!
    }

    /// `self` 에서 `other` 까지의 일수. 미래면 양수, 과거면 음수.
    public func days(until other: KstDate) -> Int {
        KST.calendar.dateComponents([.day], from: startOfDay, to: other.startOfDay).day ?? 0
    }

    /// 오늘 기준 D-day. 결혼일이 미래면 양수.
    public func daysFromToday(now: Date = Date()) -> Int {
        KstDate.today(now: now).days(until: self)
    }

    /// 일 단위 이동.
    public func adding(days: Int) -> KstDate {
        let moved = KST.calendar.date(byAdding: .day, value: days, to: startOfDay)!
        let components = KST.calendar.dateComponents([.year, .month, .day], from: moved)
        return KstDate(year: components.year!, month: components.month!, day: components.day!)!
    }

    public static func < (lhs: KstDate, rhs: KstDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

extension KstDate {
    /// KST 기준 오늘 날짜 문자열. 웹 `getKstDateString()` 대응.
    public static func todayString(now: Date = Date()) -> String {
        today(now: now).dateString
    }
}
