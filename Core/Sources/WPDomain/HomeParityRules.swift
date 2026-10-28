import Foundation
import WPUtils

// 홈 화면을 안드로이드 `MainScreen.kt` · `HomeInvitationEntry.kt` 와 맞추며 더한 판정.
// 기존 `PlanRules` · `InvitationRules` 의 값은 다른 화면도 쓰므로 고치지 않고 **새 함수만** 더한다.

extension PlanRules {

    /// 안드로이드 `PlanRules.TimeBucket` — 홈의 세 묶음.
    ///
    /// 이번 달(1일부터 말일) · 지난달까지(past) · 다음 달 이후와 날짜 미정(later).
    /// **오늘 이전이 아니라 이번 달 1일 이전**이 past 다(이번 달의 지난 날은 `이번 달에 할 일`).
    public enum TimeBucket: Sendable, Equatable { case thisMonth, past, later }

    public static func timeBucket(startDate: String?, today: KstDate) -> TimeBucket {
        guard let date = KstDate(dateString: startDate ?? "") else { return .later }
        if date.year < today.year || (date.year == today.year && date.month < today.month) { return .past }
        if date.year == today.year && date.month == today.month { return .thisMonth }
        return .later
    }
}

extension InvitationRules {

    // 안드로이드 `InvitationRules.HOME_ROW_*` — 예산 카드 안의 청첩장 줄(패스 없음)
    public static let homeRowTitle = "모바일 청첩장"
    public static let homeRowNote = "준비 패스를 구매하고 모바일 청첩장을 무료로 받아 보세요"
    public static let homeRowAction = "구경하기"

    /// 정원 카드 아래 줄 — 굵은 `title`, 작은 `note`, 오른쪽 단추 `action`
    public struct HomeCardText: Equatable, Sendable {
        public var title: String
        public var note: String
        public var action: String
    }

    /// 안드로이드 `dottedDate` — `2027-03-13` → `2027. 03. 13`
    public static func homeDottedDate(_ date: String) -> String { date.replacingOccurrences(of: "-", with: ". ") }

    /// 빈 정원 — 편집기에 미리 넣는 날짜·장소를 말한다(조사는 붙이지 않는다 — 예식장 이름의 받침을 모른다).
    public static func homeEmptyText(planDate: String?, planVenue: String?) -> HomeCardText {
        var known: [String] = []
        if let planDate, !planDate.isEmpty { known.append(homeDottedDate(planDate)) }
        if let venue = planVenue?.trimmingCharacters(in: .whitespacesAndNewlines), !venue.isEmpty { known.append(venue) }
        return HomeCardText(
            title: "하객 자리가 비어 있어요",
            note: known.isEmpty ? "사진 · 날짜 · 장소를 담아 하객을 맞아요" : "\(known.joined(separator: " · ")) 미리 채워 둘게요",
            action: "만들기"
        )
    }

    /// 홈에서 보이는 축하 글 한 줄 — 가장 최근 것
    public struct HomeWishLine: Equatable, Sendable {
        public var name: String
        public var message: String
    }

    /// 안드로이드 `homeMineText` — `guests` 가 nil 이면 하객 수를 모른다(받는 중 · 못 받음). 수를 말하지 않는다.
    public static func homeMineText(published: Bool, guestbookOn: Bool, guests: Int?, fresh: Int, latest: HomeWishLine?) -> HomeCardText {
        if !published { return HomeCardText(title: "청첩장이 아직 비공개예요", note: "공개하면 링크 · QR로 하객을 맞아요", action: "공개하기") }
        if !guestbookOn { return HomeCardText(title: "청첩장 공개 중", note: "댓글 관리를 꺼 둬서 축하 글은 받지 않아요", action: "보기") }
        guard let guests else { return HomeCardText(title: "청첩장 공개 중", note: "링크를 받은 누구나 볼 수 있어요", action: "보기") }
        if guests == 0 { return HomeCardText(title: "청첩장 공개 중", note: "링크나 QR 코드로 청첩장을 전해 보세요", action: "보기") }
        return HomeCardText(
            title: fresh > 0 ? "청첩장 공개 중 · 새 축하 \(fresh)" : "청첩장 공개 중 · 하객 \(guests)명",
            note: latest.map { "\($0.name) · \"\($0.message)\"" } ?? "링크를 더 보내면 정원이 더 북적여요",
            action: "보기"
        )
    }

    /// `새 축하 N` — 방명록 수 − 청첩장 칸에서 마지막으로 본 수. 둘 중 하나라도 모르면 0(Android `freshWishes`)
    public static func freshWishes(total: Int?, seen: Int?) -> Int {
        guard let total, let seen else { return 0 }
        return max(0, total - seen)
    }

    /// 안드로이드 `latestWish` — `createdAt` 이 가장 늦은 글. 시각이 없으면 받은 첫 장, 이름이 비면 `하객`,
    /// 줄바꿈은 한 줄로 편다(카드에 한 줄만 보인다).
    public static func homeLatestWish(_ wishes: [(name: String, message: String, createdAt: String)]) -> HomeWishLine? {
        let dated = wishes.filter { !$0.createdAt.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let pick = dated.max(by: { $0.createdAt < $1.createdAt }) ?? wishes.first else { return nil }
        let name = pick.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = pick.message
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return HomeWishLine(name: name.isEmpty ? "하객" : name, message: message)
    }
}
