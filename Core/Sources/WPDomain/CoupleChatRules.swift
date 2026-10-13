import Foundation
import WPModels
import WPUtils

public enum CoupleChatState: Equatable, Sendable {
    case loading, error, solo, unavailable
    case ready(chatRoomId: Int, planRoomId: Int, weddingDate: String?, partnerName: String?)
}
public enum CoupleChatRules {
    public static func pick(_ rooms: [Plan], myId: String?) -> CoupleChatState {
        let mine = rooms.filter { room in
            guard let myId, let me = room.members.first(where: { same($0.planUserId, myId) }) else { return true }
            return isCouple(me.permission)
        }
        for room in mine {
            if let chat = room.chatRooms.first(where: \.isCouple) {
                let partner = room.members.first { !same($0.planUserId, myId) && isCouple($0.permission) }
                let name = partner?.name.trimmingCharacters(in: .whitespacesAndNewlines)
                return .ready(chatRoomId: chat.id, planRoomId: room.roomId, weddingDate: room.weddingDate, partnerName: name?.isEmpty == false ? name : nil)
            }
        }
        return mine.contains { $0.members.contains { $0.permission.rawValue.uppercased() == "SPOUSE" } } ? .unavailable : .solo
    }
    public static func describeWeddingDay(_ date: String?, today: KstDate = .today()) -> String? {
        guard let date = date.flatMap({ KstDate(dateString: $0) }) else { return nil }
        let days = today.days(until: date), md = "\(date.month)월 \(date.day)일"
        return days > 0 ? "결혼식까지 \(days)일 · \(md)" : days == 0 ? "오늘 결혼식 · \(md)" : "결혼한 지 \(-days)일 · \(md)"
    }
    private static func isCouple(_ permission: PlanPermission) -> Bool { ["OWNER", "SPOUSE"].contains(permission.rawValue.uppercased()) }
    private static func same(_ a: String?, _ b: String?) -> Bool {
        guard let a, let b else { return false }
        let lhs = a.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), rhs = b.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !lhs.isEmpty && !rhs.isEmpty && lhs == rhs
    }
}
