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
              let encoded = name.addingPercentEncoding(withAllowedCharacters: linkNameAllowed)
        else { return nil }
        return URL(string: "https://map.kakao.com/link/map/\(encoded),\(lat),\(lng)")
    }

    /// 링크의 이름 칸에 그대로 둘 글자 — Android `Uri.encode` 와 같은 집합. 경로의 쉼표는 이름 · 위도 · 경도를 가르는
    /// 둘뿐이어야 해서, 제목의 `,` 는 `%2C`, `/` 는 `%2F` 로 바꿉니다(`.urlQueryAllowed` 는 둘 다 그대로 둬 위치가 어긋났습니다).
    private static let linkNameAllowed = CharacterSet(charactersIn:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-!.~'()*")

    // MARK: - 시세 자

    /// 금액을 자 위의 % 로 바꾼다. 웹 `FeedDetailView.scalePct()`.
    ///
    /// **자를 `p25`~`p75` 로 잡지 말 것.** 가운데 절반만 그리면 그 밖에 있는 후기가
    /// 자 밖으로 나가 눈금을 못 찍는다. 표본의 최솟값·최댓값은 모르므로 p25·p75 를
    /// **안쪽 눈금**으로 두고 양옆에 그만큼 여유를 준다.
    ///
    /// 끝에 닿아도 6~94% 안에 머물게 눌러 둔다 — 라벨이 잘리지 않는다.
    public static func scalePercent(_ value: Double, stats: FeedCategoryStats) -> Double {
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

    // MARK: - 카테고리 칩 (2026-10-22 — 올라온 후기에 있는 것만)

    /// 칩 줄. 서버 목록(`GET /plan/feed/categories`, 많이 올라온 순) 그대로이되, **고른 카테고리가 목록에서 빠졌으면 끝에
    /// 남겨 둔다** — 마지막 후기를 내려 칩까지 사라지면 무엇으로 걸러 보고 있는지도, `전체` 로 돌아가는 길도 안 보인다
    /// (웹 `feedCategoryChips` · 안드로이드 `FeedCategories.chips`).
    public static func chips(_ categories: [String], selected: String?) -> [String] {
        guard let selected, !categories.contains(selected) else { return categories }
        return categories + [selected]
    }

    // MARK: - 후기 사진 (최대 3장, WebP)

    public static let maxPhotos = 3
    /// 긴 변 상한(작으면 그대로)
    public static let photoMaxEdge = 1280
    /// 한 장 상한 1MB — 품질을 0.8 → 0.65 → 0.5 로 낮춰도 넘으면 거절
    public static let photoMaxBytes = 1_048_576
    public static let photoQualities: [Float] = [80, 65, 50]
    public static let photoTooLarge = "사진이 너무 커요. 다른 사진을 골라 주세요."
    public static let photoUnreadable = "이 사진은 열 수 없어요. JPG · PNG 사진으로 골라 주세요."

    /// 고른 사진 중 담을 수: 남은 칸만큼 앞에서부터. 넘게 골랐으면 안내 문장도 준다.
    public static func acceptPhotos(existing: Int, picked: Int) -> (count: Int, note: String?) {
        let available = max(0, maxPhotos - existing)
        let count = min(picked, available)
        return (count, picked > available ? "사진은 \(maxPhotos)장까지예요. 앞의 \(count)장만 담았어요." : nil)
    }

    // MARK: - 고치기 (PATCH /plan/feed/{id})

    /// 고치기 본문. 업체는 처음과 달라졌을 때만, 사진은 **보낼 키 목록이 연 순간의 키와 순서까지 다를 때만** 싣는다
    /// (생략과 null 은 서로 다른 변경이다 — 사진을 건드리지 않으면 다른 기기에서 더한 사진을 덮지 않는다).
    public static func editRequest(rating: Int, body: String, isAmountPublic: Bool, authorRole: String,
                                   initialPlace: FeedPlace?, place: FeedPlace?,
                                   baseImages: [String], images: [String]) -> FeedEditRequest {
        let placeChange: FeedEditRequest.PlaceChange
        if place == initialPlace { placeChange = .unchanged } else if let place { placeChange = .set(place) } else { placeChange = .cleared }
        return FeedEditRequest(rating: rating, body: body, isAmountPublic: isAmountPublic, authorRole: authorRole,
                               place: placeChange, images: images == baseImages ? nil : (images, baseImages))
    }

    /// 고치기 · 올리기 실패 문장(웹 `FeedPostModal` · 안드로이드 `FeedPostEditor.handleFailure`).
    public enum EditFailure {
        public static let photoRetry = "사진을 다시 올려야 해요. 한 번 더 눌러 주세요."
        public static let notEditable = "이 후기는 고칠 수 없어요. 이미 내렸거나 가려진 후기예요."
        public static let saveFailed = "저장하지 못했습니다. 잠시 후 다시 시도해 주세요."
        public static let deleteFailed = "내리지 못했습니다. 잠시 후 다시 시도해 주세요."
        public static let rebased = "다른 곳에서 이 후기의 사진이 바뀌어 지금 사진으로 다시 불러왔어요. 확인하고 한 번 더 눌러 주세요."
        public static let changedElsewhere = "다른 곳에서 이 후기를 고쳤어요. 창을 닫고 다시 열어 주세요."
        public static let slotUnavailable = "사진 보관소가 아직 연결되지 않았어요. 사진 없이 올려 주세요."
        public static let slotFailed = "사진을 올릴 자리를 받지 못했어요. 잠시 후 다시 시도해 주세요."
        public static let putFailed = "사진을 올리지 못했어요. 연결을 확인하고 다시 시도해 주세요."
        public static let photoReasons: Set<String> = ["PHOTO_NOT_UPLOADED", "PHOTO_NOT_WEBP"]
    }
}
