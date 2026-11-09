import Foundation
import WPModels
import WPUtils

/// 청첩장 주인의 축하 글 보기 · 고치기 · 지우기(2026-11-09 사용자 승인 시안 `weddingplant-guestbook`).
/// 안드로이드 `ui/invitation` 과 같은 문구 · 같은 판정이어야 한다 — 두 앱의 주인이 같은 청첩장을 고친다.
public extension InvitationRules {
    static let guestbookNameLimit = 20
    static let guestbookMessageLimit = 120
    static let guestbookSearchPlaceholder = "이름 또는 축하 내용으로 찾아보세요"
    static let guestbookDeleteConfirm = "이 축하 글을 지울까요? 되돌릴 수 없어요."
    static let guestbookAlreadyDeleted = "이미 지워진 글이에요."
    static let guestbookEmpty = "아직 축하 글이 없어요"

    /// 검색은 받은 글 안에서만 한다(서버 검색 API 가 없다). 공백만 적으면 거르지 않는다 —
    /// 칸을 지운 순간 목록이 통째로 사라지면 "다 지워졌나" 로 읽힌다.
    static func filterWishes(_ wishes: [InvitationWish], query: String) -> [InvitationWish] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return wishes }
        return wishes.filter { $0.name.lowercased().contains(q) || $0.message.lowercased().contains(q) }
    }

    /// 새 글부터. 시각이 없는 글은 받은 순서대로 맨 뒤에 둔다(서버 순서를 흐트러뜨리지 않게 안정 정렬).
    static func newestFirst(_ wishes: [InvitationWish]) -> [InvitationWish] {
        wishes.enumerated().sorted { l, r in
            let a = KstInstant.parse(l.element.createdAt), b = KstInstant.parse(r.element.createdAt)
            switch (a, b) {
            case let (a?, b?): return a == b ? l.offset < r.offset : a > b
            case (_?, nil): return true
            case (nil, _?): return false
            default: return l.offset < r.offset
            }
        }.map(\.element)
    }

    /// `11월 9일` — 남긴 날을 KST 로 센다(기기 시간대를 타지 않게). 시각을 못 읽으면 빈 글자.
    static func wishDateLabel(_ createdAt: String) -> String {
        guard let date = KstInstant.kstDate(createdAt) else { return "" }
        return "\(date.month)월 \(date.day)일"
    }

    /// 고친 이름 · 글을 앞뒤 공백을 떼고 본다. 통과하면 nil, 아니면 칸 아래에 보일 한 줄.
    static func validateWish(name: String, message: String) -> String? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let m = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if n.isEmpty { return "이름을 적어 주세요." }
        if n.count > guestbookNameLimit { return "이름은 \(guestbookNameLimit)자까지 적을 수 있어요." }
        if m.isEmpty { return "축하 글을 적어 주세요." }
        if m.count > guestbookMessageLimit { return "축하 글은 \(guestbookMessageLimit)자까지 적을 수 있어요." }
        return nil
    }

    /// 내 청첩장 정원 아래 줄 — `축하 글 N개`. 수를 모르면 수를 말하지 않는다.
    static func guestbookRowTitle(total: Int?) -> String {
        guard let total else { return "축하 글" }
        return "축하 글 \(total)개"
    }

    /// 주인 줄을 눌러 열 수 있는지 — 공개 중이어야 하객 글이 있다. 0개여도 연다(빈 안내를 보여 준다).
    static func guestbookOpenable(published: Bool) -> Bool { published }
}
