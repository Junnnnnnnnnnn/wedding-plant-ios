import Foundation

/// 플랜 참여자 권한.
///
/// 웹은 `"OWNER" | "WRITE" | "READ" | string` 로 열려 있으므로,
/// 알 수 없는 값이 와도 디코딩이 깨지지 않도록 enum 대신 RawRepresentable 구조체로 둔다.
public struct PlanPermission: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    // 합성 Codable은 `{"rawValue":"OWNER"}` 로 인코딩해버리므로 직접 단일 값으로 처리한다.
    public init(from decoder: any Decoder) throws {
        self.rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static let owner = PlanPermission(rawValue: "OWNER")
    public static let write = PlanPermission(rawValue: "WRITE")
    public static let read = PlanPermission(rawValue: "READ")

    public var canEdit: Bool { self == .owner || self == .write }
}

/// 플랜/채팅방 멤버.
public struct Member: Codable, Hashable, Sendable, Identifiable {
    public var planUserId: String
    public var name: String
    public var image: String?
    public var permission: PlanPermission

    public var id: String { planUserId }

    public init(
        planUserId: String,
        name: String,
        image: String? = nil,
        permission: PlanPermission
    ) {
        self.planUserId = planUserId
        self.name = name
        self.image = image
        self.permission = permission
    }
}

/// 채팅방.
///
/// `GET /plan/room/list` 의 `Plan.chatRooms` 는 `memberList` 를 포함하지만
/// `GET /plan/user` 의 `chatRooms` 는 `{ id, name }` 만 내려주므로 optional.
public struct ChatRoom: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var name: String
    public var memberList: [Member]?

    public init(id: Int, name: String, memberList: [Member]? = nil) {
        self.id = id
        self.name = name
        self.memberList = memberList
    }
}

/// 공유 플랜(방).
///
/// - Note: `onwerName` 은 백엔드 응답의 오타를 그대로 유지한 필드다(프로젝트 컨벤션).
///         읽기 편하도록 `ownerName` 계산 프로퍼티를 함께 제공한다.
public struct Plan: Codable, Hashable, Sendable, Identifiable {
    public var roomId: Int
    /// API typo maintained — 백엔드 계약이 `onwerName` 이다.
    public var onwerName: String
    public var weddingDate: String
    public var budget: Int
    public var remainingBudget: Int
    public var planCount: Int
    public var chatRooms: [ChatRoom]
    public var members: [Member]

    public var id: Int { roomId }

    /// `onwerName` 의 읽기 전용 별칭.
    public var ownerName: String { onwerName }

    public init(
        roomId: Int,
        onwerName: String,
        weddingDate: String,
        budget: Int,
        remainingBudget: Int,
        planCount: Int,
        chatRooms: [ChatRoom] = [],
        members: [Member] = []
    ) {
        self.roomId = roomId
        self.onwerName = onwerName
        self.weddingDate = weddingDate
        self.budget = budget
        self.remainingBudget = remainingBudget
        self.planCount = planCount
        self.chatRooms = chatRooms
        self.members = members
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.roomId = try container.decode(Int.self, forKey: .roomId)
        self.onwerName = try container.decodeIfPresent(String.self, forKey: .onwerName) ?? ""
        self.weddingDate = try container.decodeIfPresent(String.self, forKey: .weddingDate) ?? ""
        self.budget = try container.decodeIfPresent(Int.self, forKey: .budget) ?? 0
        self.remainingBudget = try container.decodeIfPresent(Int.self, forKey: .remainingBudget) ?? 0
        self.planCount = try container.decodeIfPresent(Int.self, forKey: .planCount) ?? 0
        self.chatRooms = try container.decodeIfPresent([ChatRoom].self, forKey: .chatRooms) ?? []
        self.members = try container.decodeIfPresent([Member].self, forKey: .members) ?? []
    }
}

/// `GET /plan/room/list` 응답 페이로드.
public struct RoomList: Codable, Hashable, Sendable {
    public var total: Int
    public var list: [Plan]

    public init(total: Int, list: [Plan] = []) {
        self.total = total
        self.list = list
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.list = try container.decodeIfPresent([Plan].self, forKey: .list) ?? []
        self.total = try container.decodeIfPresent(Int.self, forKey: .total) ?? self.list.count
    }
}
