import Foundation

/// 날짜 표시 포맷. 웹 문구와 **글자까지 동일**해야 한다.
///
/// 안드로이드 `core/time/Kst.kt` 의 `weekdayShort / formatWeddingDate / formatListDate` 와 같은 결과를 낸다.
/// `DateFormatter` 를 쓰지 않는 이유: 기기 로케일·달력 설정에 따라 출력이 흔들리기 때문.
/// 웹은 문자열을 직접 조립하므로 여기서도 그렇게 한다.
extension KstDate {

    /// "월" ~ "일"
    public var weekdayShort: String {
        let symbols = ["월", "화", "수", "목", "금", "토", "일"]
        // Calendar 의 weekday 는 1=일요일 ... 7=토요일.
        // 월요일이 0번이 되도록 5를 더해 회전시킨다. (일=1 → 6 → "일")
        let weekday = KST.calendar.component(.weekday, from: startOfDay)
        return symbols[(weekday + 5) % 7]
    }

    /// 웹 `formatWeddingDate()` — "2026년 8월 14일 (금)"
    public var weddingDateText: String {
        "\(year)년 \(month)월 \(day)일 (\(weekdayShort))"
    }

    /// 플랜 리스트용 — "2026년 8월 14일 (금요일)"
    public var listDateText: String {
        "\(year)년 \(month)월 \(day)일 (\(weekdayShort)요일)"
    }
}

extension KstDate {
    /// 해당 연·월의 일수. 날짜 휠에서 "일" 목록을 만들 때 쓴다.
    ///
    /// 윤년을 달력에 맡기므로 직접 계산하지 않는다.
    public static func daysInMonth(year: Int, month: Int) -> Int {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        let calendar = KST.calendar
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date)
        else {
            return 31
        }
        return range.count
    }
}

/// 숫자 천 단위 구분. 웹의 `toLocaleString("ko-KR")` 대응 — "1,234"
public func wpThousands(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    formatter.groupingSize = 3
    formatter.usesGroupingSeparator = true
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

// MARK: - ISO 8601 (UTC) → KST

/// 서버가 내려주는 ISO 8601 시각을 KST 로 해석한다.
///
/// `createDate` 는 `"2026-08-19T13:02:00.594Z"` 처럼 **UTC** 다.
/// 앞 10글자를 그대로 잘라 쓰면 **9시간 어긋난다** — UTC 15:00~24:00 구간은 KST 로 이미 다음 날이다.
/// 채팅 날짜 구분선이 자정 근처에서 하루 밀리는 것도 같은 원인이다.
public enum KstInstant {

    /// ISO 8601 문자열을 `Date` 로. 시간대 표기가 없으면 KST 로 간주한다.
    public static func parse(_ raw: String?) -> Date? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty else {
            return nil
        }

        // 소수점 이하 초가 있는 경우와 없는 경우 둘 다 대응한다.
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: trimmed) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: trimmed) { return date }

        // 시간대 표기가 없는 형식("2026-08-19T13:02:00") → KST 로 간주
        let naive = DateFormatter()
        naive.locale = Locale(identifier: "en_US_POSIX")
        naive.timeZone = KST.timeZone
        for format in ["yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss"] {
            naive.dateFormat = format
            if let date = naive.date(from: trimmed) { return date }
        }
        return nil
    }

    /// ISO 시각의 **KST 기준 날짜**. 채팅 날짜 구분선에 쓴다.
    ///
    /// 파싱에 실패하면 앞 10글자를 날짜로 읽어 본다(이미 "YYYY-MM-DD" 인 경우).
    public static func kstDate(_ raw: String?) -> KstDate? {
        if let date = parse(raw) {
            return KstDate.today(now: date)
        }
        return raw.flatMap { KstDate(dateString: $0) }
    }

    /// KST 기준 "오전 10:30". 안드로이드 `Kst.formatTimeKst` 와 같은 출력.
    ///
    /// 웹은 `toLocaleTimeString("ko-KR")` 이 브라우저 시간대로 알아서 바꿔 주지만
    /// 앱에서는 직접 변환해야 한다.
    public static func timeText(_ raw: String?) -> String {
        guard let date = parse(raw) else { return "" }
        let components = KST.calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return "" }

        let meridiem = hour < 12 ? "오전" : "오후"
        let display: Int
        if hour == 0 {
            display = 12
        } else if hour > 12 {
            display = hour - 12
        } else {
            display = hour
        }
        return String(format: "%@ %d:%02d", meridiem, display, minute)
    }
}
