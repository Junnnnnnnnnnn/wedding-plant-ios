import Foundation
import WPModels
import WPUtils

/// 견적 후기 화면의 문구·계산 규칙.
///
/// **문장은 앱이 조립한다.** 서버는 남은 일수와 역할만 주고 `"D-131 신부"` 같은
/// 완성된 문구는 내려보내지 않는다 — 내려보내면 문구를 고칠 때마다 백엔드 배포에
/// 묶인다(`ActivityPanel.describe()` 와 같은 규칙).
public enum FeedRules {

    // MARK: - 작성자

    /// 웹 `FeedCard.describeAuthor()` — `"D-131 신부"`.
    ///
    /// 응답에 `planUserId` 가 없다. 이 문장이 작성자에 대해 말하는 전부다.
    public static func describeAuthor(_ post: FeedPost) -> String {
        let role: String
        switch post.authorRole {
        case "BRIDE": role = "신부"
        case "GROOM": role = "신랑"
        default: role = "예비부부"
        }

        guard let days = post.authorDDay else { return role }
        if days > 0 { return "D-\(days) \(role)" }
        if days == 0 { return "D-Day \(role)" }
        return "결혼식 \(abs(days))일 뒤 \(role)"
    }

    // MARK: - 올린 때

    /// 웹 `FeedCard.describeWhen()` — `"3일 전"`. 한 달이 넘으면 날짜로 적는다.
    ///
    /// - Parameter now: 테스트에서 고정하기 위한 기준 시각.
    public static func describeWhen(_ iso: String?, now: Date = Date()) -> String {
        guard let iso, let then = parseISO(iso) else { return "" }

        let days = Int(floor(now.timeIntervalSince(then) / 86_400))
        if days <= 0 { return "오늘" }
        if days == 1 { return "어제" }
        if days < 7 { return "\(days)일 전" }
        if days < 30 { return "\(days / 7)주 전" }

        let parts = KST.calendar.dateComponents([.year, .month, .day], from: then)
        return "\(parts.year ?? 0). \(parts.month ?? 0). \(parts.day ?? 0)."
    }

    /// 백엔드가 주는 ISO 문자열. `DateFormatter` 대신 직접 읽는다 —
    /// 기기 로케일·달력 설정에 따라 결과가 흔들리지 않게.
    private static func parseISO(_ text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: trimmed) { return date }

        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: trimmed) { return date }

        // `2026-09-18 01:23:45` 처럼 T·타임존이 없는 형태도 받는다.
        let normalized = trimmed.replacingOccurrences(of: " ", with: "T")
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: normalized + "Z") { return date }

        // 날짜만 온 경우.
        return KstDate(dateString: String(trimmed.prefix(10)))?.startOfDay
    }

    // MARK: - 지도

    /// 카카오맵 링크. **좌표가 있어야 열린다.**
    ///
    /// 목록에 지도 이미지를 깔면 금액을 세로로 훑는 흐름이 깨지고 쿼터·로딩이
    /// 붙는다. 그래서 지도는 한 단계 밖에 둔다 — 필요한 사람은 이 링크로 넘어간다.
    public static func kakaoMapLink(_ post: FeedPost) -> URL? {
        guard post.hasCoordinates, let lat = post.lat, let lng = post.lng else { return nil }
        let name = post.title.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty,
              let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        return URL(string: "https://map.kakao.com/link/map/\(encoded),\(lat),\(lng)")
    }

    // MARK: - 시세 자

    /// 금액을 자 위의 % 로 바꾼다. 웹 `FeedDetailView.scalePct()`.
    ///
    /// **자를 `p25`~`p75` 로 잡지 말 것.** 가운데 절반만 그리면 그 밖에 있는 후기가
    /// 자 밖으로 나가 눈금을 못 찍는다. 표본의 최솟값·최댓값은 모르므로 p25·p75 를
    /// **안쪽 눈금**으로 두고 양옆에 그만큼 여유를 준다.
    ///
    /// 끝에 닿아도 6~94% 안에 머물게 눌러 둔다 — 라벨이 잘리지 않는다.
    public static func scalePercent(_ value: Int, stats: FeedCategoryStats) -> Double {
        let spread = max(stats.p75 - stats.p25, 1)
        let low = stats.p25 - spread
        let high = stats.p75 + spread
        let pct = Double(value - low) / Double(max(high - low, 1)) * 100
        return min(94, max(6, pct))
    }

    // MARK: - 투표

    /// 평가는 하트가 아니라 **양방향 투표**다.
    ///
    /// 이 피드의 값어치는 "예쁘다" 가 아니라 "쓸모 있다" 에 있고, 하트는 쓸모없는
    /// 후기를 아래로 밀어내지 못한다. 한 사람이 한 표고, 마음을 바꾸면 값이 뒤집힌다.
    public enum Vote: String, Hashable, Sendable {
        case helpful = "HELPFUL"
        case notHelpful = "NOT_HELPFUL"
    }

    /// 낙관적 갱신의 결과. 요청 전에 이것부터 그리고, 응답이 오면 서버 값으로 맞춘다.
    ///
    /// **즉시 반응하지 않으면 사람들이 두 번 누른다.**
    public struct OptimisticVote: Hashable, Sendable {
        public var myVote: String?
        public var helpfulCount: Int
        /// 같은 값을 다시 누른 것 — 취소다. `DELETE` 를 보낸다.
        public var isCancel: Bool
    }

    /// 누른 뒤의 상태를 미리 계산한다.
    ///
    /// - 같은 값을 다시 누르면 **취소**(값이 사라진다).
    /// - 다른 값을 누르면 **뒤집힌다**. 행이 늘지 않는다.
    public static func applyVote(
        current: String?,
        helpfulCount: Int,
        tapped: Vote
    ) -> OptimisticVote {
        let wasHelpful = current == Vote.helpful.rawValue

        if current == tapped.rawValue {
            return OptimisticVote(
                myVote: nil,
                helpfulCount: wasHelpful ? max(0, helpfulCount - 1) : helpfulCount,
                isCancel: true
            )
        }

        var count = helpfulCount
        if wasHelpful { count = max(0, count - 1) }
        if tapped == .helpful { count += 1 }

        return OptimisticVote(myVote: tapped.rawValue, helpfulCount: count, isCancel: false)
    }
}
