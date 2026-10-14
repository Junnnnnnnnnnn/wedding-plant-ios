import Foundation
import WPModels
import WPUtils

extension InvitationRules {
    public static func coverSummary(_ content: InvitationContent) -> String {
        "\(content.title.isEmpty ? "제목을 적어 주세요" : content.title) · \(content.groom.isEmpty ? "신랑" : content.groom) & \(content.bride.isEmpty ? "신부" : content.bride)"
    }
    public static func sectionSummary(_ type: String, content: InvitationContent) -> String {
        let d = normalize(content.design)
        switch type {
        case "message": return content.message.split(separator: "\n").first.map(String.init) ?? "아직 비어 있어요"
        case "couple":
            let count = [d.couple.groomFather,d.couple.groomMother,d.couple.brideFather,d.couple.brideMother].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
            return count > 0 ? "부모님 성함 \(count)명" : "\(content.groom.isEmpty ? "신랑" : content.groom) · \(content.bride.isEmpty ? "신부" : content.bride)"
        case "gallery": return "사진 \(content.photos.count)장 · \(d.galleryLayout == "grid" ? "고르게" : "크고 작게")"
        case "calendar": return invitationDateLabel(content) ?? "날짜를 정해 주세요"
        case "location": return content.venue.isEmpty ? "예식장을 적어 주세요" : content.venue
        case "notice": return d.notice.body.split(separator: "\n").first.map(String.init) ?? "아직 비어 있어요"
        case "accounts":
            let n = d.accounts.filter { !$0.bank.isEmpty && !$0.number.isEmpty }.count
            return n > 0 ? "계좌 \(n)곳" : "계좌를 적어 주세요"
        default: return "하객이 남기는 축하 글"
        }
    }
    public static func invitationDateLabel(_ content: InvitationContent) -> String? {
        guard let date = content.weddingDate.flatMap({ KstDate(dateString: $0) }) else { return nil }
        let weekday = ["일","월","화","수","목","금","토"][KST.calendar.component(.weekday, from: date.startOfDay)-1]
        let parts = (content.weddingTime ?? "").split(separator: ":").compactMap { Int($0) }
        let time: String
        if parts.count == 2 { time = " \(parts[0] < 12 ? "오전" : "오후") \(parts[0] % 12 == 0 ? 12 : parts[0] % 12)시" + (parts[1] == 0 ? "" : " \(parts[1])분") } else { time = "" }
        return "\(date.year)년 \(date.month)월 \(date.day)일 \(weekday)요일" + time
    }
    public struct StudioItem: Equatable, Sendable {
        public let key, name, note: String
        public let filled, visible: Bool
    }
    public static func studioItems(_ content: InvitationContent) -> [StudioItem] {
        let d = normalize(content.design)
        var items = [StudioItem(key: "mood", name: "분위기", note: content.template == "rose" ? "로즈" : content.template == "ivory" ? "아이보리" : "가든", filled: true, visible: true),
                     StudioItem(key: "intro", name: "첫 화면", note: d.intro == "photo" ? "표지로 바로" : "정원 문이 열려요", filled: true, visible: true)]
        let words = !content.title.isEmpty && !content.groom.isEmpty && !content.bride.isEmpty
        items.append(.init(key: "cover", name: "표지", note: !words ? "제목·이름을 적어 주세요" : content.photos.isEmpty ? "사진 없음 · 정원 그림" : content.title, filled: words && !content.photos.isEmpty, visible: true))
        for section in d.sections {
            let filled: Bool
            switch section.type {
            case "message": filled = !content.message.isEmpty
            case "gallery": filled = !content.photos.isEmpty
            case "calendar": filled = content.weddingDate?.isEmpty == false
            case "location": filled = !content.venue.isEmpty
            case "notice": filled = !d.notice.body.isEmpty
            case "accounts": filled = d.accounts.contains { !$0.bank.isEmpty && !$0.number.isEmpty }
            default: filled = true
            }
            let label = sectionTypes.firstIndex(of: section.type).map { sectionLabels[$0] } ?? section.type
            let note: String
            switch section.type {
            case "gallery": note = "\(content.photos.count) / 20장 · \(d.galleryLayout == "grid" ? "고르게" : "크고 작게")"
            case "calendar": note = (content.weddingDate?.replacingOccurrences(of: "-", with: ".") ?? "날짜 미정") + (content.weddingTime.map { " " + $0 } ?? "")
            case "guestbook": note = "하객의 축하 글"
            default: note = sectionSummary(section.type, content: content)
            }
            items.append(.init(key: section.type, name: label, note: section.visible ? note : "꺼 둠", filled: filled, visible: section.visible))
        }
        return items
    }
}
