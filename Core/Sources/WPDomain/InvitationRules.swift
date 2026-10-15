import Foundation
import WPModels
import WPUtils

public enum InvitationRules {
    public static let photoLimit = 20
    public static let sectionTypes = ["message", "couple", "gallery", "calendar", "location", "notice", "accounts", "guestbook"]
    public static let sectionLabels = ["초대의 말", "신랑 · 신부", "사진첩", "예식 일시", "오시는 길", "안내 말씀", "계좌 입력", "댓글 관리"]
    public static let accountSeats = [("groom","신랑"),("groom","아버지"),("groom","어머니"),("bride","신부"),("bride","아버지"),("bride","어머니")]
    public static func design(new: Bool = false) -> InvitationDesignBody {
        InvitationDesignBody(intro: "door", galleryLayout: "mosaic",
            sections: sectionTypes.map { InvitationSectionBody(type: $0, visible: !["couple","notice","accounts"].contains($0) || (new && $0 == "couple")) },
            couple: InvitationCoupleBody(groomRelation: "아들", brideRelation: "딸"),
            notice: InvitationNoticeBody(title: "안내 말씀"), accounts: accountSeats.map { InvitationAccountBody(side: $0.0, role: $0.1) })
    }
    public static func normalize(_ input: InvitationDesignBody?) -> InvitationDesignBody {
        guard var value = input else { return design() }
        value.intro = value.intro == "photo" ? "photo" : "door"
        value.galleryLayout = value.galleryLayout == "grid" ? "grid" : "mosaic"
        var seen = Set<String>()
        value.sections = value.sections.filter { sectionTypes.contains($0.type) && seen.insert($0.type).inserted }
        value.sections += sectionTypes.filter { !seen.contains($0) }.map { InvitationSectionBody(type: $0, visible: false) }
        value.couple.groomFather = limit(value.couple.groomFather, 20)
        value.couple.groomMother = limit(value.couple.groomMother, 20)
        value.couple.brideFather = limit(value.couple.brideFather, 20)
        value.couple.brideMother = limit(value.couple.brideMother, 20)
        value.couple.groomRelation = limit(value.couple.groomRelation, 6)
        value.couple.brideRelation = limit(value.couple.brideRelation, 6)
        value.location.address = limit(value.location.address, 120)
        value.location.guide = limit(value.location.guide, 500)
        value.notice.title = limit(value.notice.title, 30)
        value.notice.body = limit(value.notice.body, 500)
        value.accounts = accountSeats.map { side, role in
            let found = value.accounts.first { $0.side == side && $0.role == role }
            return InvitationAccountBody(side: side, role: role, name: limit(found?.name ?? "",20), bank: limit(found?.bank ?? "",20),
                number: String(limit(found?.number ?? "",30).filter { ($0.isASCII && $0.isNumber) || $0 == " " || $0 == "-" }))
        }
        return value
    }
    public static func draft() -> InvitationContent {
        InvitationContent(template: "garden", title: "우리, 결혼합니다", weddingTime: "14:00",
            message: "서로의 가장 다정한 사람이 되어\n함께 걸어가려 합니다.\n소중한 날, 함께해 주세요.", design: design(new: true))
    }
    public static func sanitize(_ input: InvitationContent) -> InvitationContent {
        var value = input
        value.template = ["garden","ivory","rose"].contains(value.template) ? value.template : "garden"
        value.title = limit(value.title,60); value.groom = limit(value.groom,20); value.bride = limit(value.bride,20)
        value.venue = limit(value.venue,100); value.message = limit(value.message,500)
        value.photos = Array(value.photos.prefix(photoLimit)); value.design = normalize(value.design)
        value.weddingDate = valid(value.weddingDate, #"^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$"#)
        if let date = value.weddingDate, KstDate(dateString: date) == nil { value.weddingDate = nil }
        value.weddingTime = valid(value.weddingTime, #"^([01]\d|2[0-3]):[0-5]\d$"#)
        return value
    }
    private static func valid(_ input: String?, _ pattern: String) -> String? {
        guard let value = input?.trimmingCharacters(in: .whitespacesAndNewlines), value.range(of: pattern, options: .regularExpression) != nil else { return nil }
        return value
    }
    public static func limit(_ input: String, _ max: Int) -> String { String(decoding: input.utf16.prefix(max), as: UTF16.self) }
    public enum GalleryRow: Equatable, Sendable {
        case mosaic(big: Int, top: Int?, bottom: Int?)
        case even(indices: [Int], perRow: Int, aspect: Double)
    }
    public static func galleryRows(count: Int, layout: String) -> [GalleryRow] {
        guard count > 0 else { return [] }
        if layout == "grid" {
            return stride(from: 0, to: count, by: 3).map { .even(indices: Array($0..<min($0 + 3, count)), perRow: 3, aspect: 1) }
        }
        var rows: [GalleryRow] = [.mosaic(big: 0, top: count > 1 ? 1 : nil, bottom: count > 2 ? 2 : nil)]
        var index = 3
        for width in [2, 3] where index < count {
            rows.append(.even(indices: Array(index..<min(index + width, count)), perRow: width, aspect: 0.8)); index += width
        }
        while index < count {
            rows.append(.even(indices: Array(index..<min(index + 2, count)), perRow: 2, aspect: 0.8)); index += 2
        }
        return rows
    }
    public static func mineLines(published: Bool, guestbookOn: Bool, guests: Int?) -> [String] {
        if !published { return ["청첩장이 완성됐어요. 아직 우리 둘만 볼 수 있어요.", "공개하면 링크를 받은 누구나 로그인 없이 볼 수 있어요.", "축하를 남긴 사람이 하나씩 이 자리를 채워요."] }
        if !guestbookOn { return ["청첩장이 열렸어요. 링크를 받은 누구나 볼 수 있어요.", "댓글 관리 칸을 꺼 둬서 하객이 축하를 남길 수 없어요.", "청첩장 고치기에서 칸을 다시 켤 수 있어요."] }
        if let guests, guests > 0 { return ["축하를 남긴 하객 \(guests)명이 정원에 와 있어요.", "하객을 누르면 남긴 축하 글을 읽을 수 있어요.", "링크를 더 보내면 정원이 더 북적여요."] }
        if guests == 0 { return ["청첩장이 열렸어요. 아직 아무도 오지 않았어요.", "링크를 받은 사람이 축하를 남기면, 이 자리에 와서 서요.", "링크나 QR 코드로 청첩장을 전해 보세요."] }
        return ["청첩장이 열렸어요. 링크를 받은 누구나 볼 수 있어요.", "링크를 받은 사람이 축하를 남기면, 이 자리에 와서 서요.", "하객을 누르면 남긴 축하 글을 읽을 수 있어요."]
    }
    public static func mineEmptySeats(published: Bool, guestbookOn: Bool, guests: Int?) -> Bool { !published || !guestbookOn || guests == 0 }
    public static func mineLabelNote(published: Bool, guests: Int?) -> String { !published ? "공개 전" : guests.map { "하객 \($0)명" } ?? "공개 중" }
    public enum StudioState { case loading, error, landing, empty, mine }
    /// 홈의 청첩장 입구 — Android `InvitationRules.homeInvite` = `studioView` 와 **같은 판정 하나**입니다.
    /// 청첩장이 있으면 패스가 끝났어도 정원 카드(`mine`)를 냅니다(패스가 끝나도 청첩장은 남습니다).
    /// 예전 iOS 는 패스가 없으면 숨겼는데, 그러면 패스가 끝난 사람만 iOS 홈에서 자기 청첩장 입구를 잃었습니다.
    public static func homeState(loaded: Bool, failed: Bool, hasInvitation: Bool, canEdit: Bool) -> StudioState {
        studioState(loaded: loaded, failed: failed, hasInvitation: hasInvitation, canEdit: canEdit)
    }
    public static func studioState(loaded: Bool, failed: Bool, hasInvitation: Bool, canEdit: Bool) -> StudioState {
        if failed { return .error }; if !loaded { return .loading }
        if hasInvitation { return .mine }; return canEdit ? .empty : .landing
    }
}
