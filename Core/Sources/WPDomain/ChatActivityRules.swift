import Foundation
import WPModels
import WPUtils

public enum ChatActivityItem: Identifiable {
    case message(ChatLine, index: Int)
    case activity(PlanActivity)
    public var id: String { switch self { case .message(let line, _): return line.id; case .activity(let a): return "activity-\(a.id)" } }
    public var dayKey: String { switch self { case .message(let line, _): return line.dayKey; case .activity(let a): return KstInstant.kstDate(a.createDate)?.dateString ?? "" } }
}
public enum ChatActivityRules {
    public static func sentence(_ a: PlanActivity) -> String {
        let name = a.actorName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var result = "\(name.isEmpty ? "누군가" : name)님이 일정을 \(a.type == "SCHEDULE_COMPLETED" ? "완료했어요" : "추가했어요")"
        if let title = a.targetTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty { result += " · " + title }
        if a.type != "SCHEDULE_COMPLETED", let amount = a.amount, amount > 0 {
            let formatter = NumberFormatter(); formatter.locale = Locale(identifier: "ko_KR"); formatter.numberStyle = .decimal; formatter.maximumFractionDigits = 3
            result += " · \(formatter.string(from: NSNumber(value: amount)) ?? "")만원"
        }
        return result
    }
    public static func merge(messages: [ChatLine], activities: [PlanActivity], hasMore: Bool) -> [ChatActivityItem] {
        func time(_ s: String) -> TimeInterval { KstInstant.parse(s)?.timeIntervalSince1970 ?? 0 }
        let first = messages.first.map { time($0.createDate) }
        let lines = activities.filter {
            ["SCHEDULE_CREATED", "SCHEDULE_COMPLETED"].contains($0.type) && (!hasMore || first == nil || time($0.createDate) >= first!)
        }.sorted { time($0.createDate) < time($1.createDate) }
        var result: [ChatActivityItem] = []; var a = 0
        for (index, message) in messages.enumerated() {
            while a < lines.count && time(lines[a].createDate) <= time(message.createDate) { result.append(.activity(lines[a])); a += 1 }
            result.append(.message(message, index: index))
        }
        while a < lines.count { result.append(.activity(lines[a])); a += 1 }
        return result
    }
}
