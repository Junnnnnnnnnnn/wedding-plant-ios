import Foundation

public struct PlanActivity: Codable, Equatable, Sendable {
    public let id: Int
    public let type: String
    public let actorName: String?
    public let targetType: String?
    public let targetId: Int?
    public let targetTitle: String?
    public let amount: Double?
    public let createDate: String
    public init(id: Int, type: String, actorName: String? = nil, targetType: String? = nil, targetId: Int? = nil, targetTitle: String? = nil, amount: Double? = nil, createDate: String = "") {
        self.id = id; self.type = type; self.actorName = actorName; self.targetType = targetType; self.targetId = targetId; self.targetTitle = targetTitle; self.amount = amount; self.createDate = createDate
    }
}
public struct PlanActivityPage: Decodable, Sendable { public let list: [PlanActivity] }
