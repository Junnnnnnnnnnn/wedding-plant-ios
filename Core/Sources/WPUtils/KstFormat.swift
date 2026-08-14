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

/// 숫자 천 단위 구분. 웹의 `toLocaleString("ko-KR")` 대응 — "1,234"
public func wpThousands(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    formatter.groupingSize = 3
    formatter.usesGroupingSeparator = true
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}
