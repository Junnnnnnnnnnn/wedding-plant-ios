import Foundation

/// 채팅에 첨부된 일정 카드. 웹 `ScheduleData`.
public struct ChatSchedule: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var categoryName: String
    public var title: String
    @LooseInt public var amount: Int?
    /// "YYYY-MM-DD"
    public var startDate: String?
    public var status: String
    public var location: String?

    public init(
        id: Int = 0,
        categoryName: String = "",
        title: String = "",
        amount: Int? = nil,
        startDate: String? = nil,
        status: String = "NORMAL",
        location: String? = nil
    ) {
        self.id = id
        self.categoryName = categoryName
        self.title = title
        self._amount = LooseInt(wrappedValue: amount)
        self.startDate = startDate
        self.status = status
        self.location = location
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = ChatHistoryItem.looseId(container, .id) ?? 0
        self.categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName) ?? ""
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self._amount = try container.decode(LooseInt.self, forKey: .amount)
        self.startDate = try container.decodeIfPresent(String.self, forKey: .startDate)
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? "NORMAL"
        self.location = try container.decodeIfPresent(String.self, forKey: .location)
    }
}

/// `GET /plan/chat/{chatRoomId}` 목록의 한 건.
///
/// - Important: `id` 는 서버 버전에 따라 **숫자로도, 문자열로도** 온다. 한쪽만 받으면
///   `Codable` 이 전체를 throw 해서 **메시지가 70건 있어도 채팅방이 빈 화면**이 된다
///   (안드로이드에서 실제로 겪은 버그). 그래서 둘 다 받는다.
public struct ChatHistoryItem: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var planUserId: String
    public var planUserName: String
    public var planUserProfileImageUrl: String?
    /// "text" | "schedule"
    public var messageType: String
    public var text: String?
    public var schedule: ChatSchedule?
    /// ISO 8601 **UTC**. 표시 전에 KST 로 바꿔야 9시간이 어긋나지 않는다.
    public var createDate: String
    public var unreadCount: Int

    public init(
        id: Int,
        planUserId: String = "",
        planUserName: String = "",
        planUserProfileImageUrl: String? = nil,
        messageType: String = "text",
        text: String? = nil,
        schedule: ChatSchedule? = nil,
        createDate: String = "",
        unreadCount: Int = 0
    ) {
        self.id = id
        self.planUserId = planUserId
        self.planUserName = planUserName
        self.planUserProfileImageUrl = planUserProfileImageUrl
        self.messageType = messageType
        self.text = text
        self.schedule = schedule
        self.createDate = createDate
        self.unreadCount = unreadCount
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = Self.looseId(container, .id) ?? 0
        self.planUserId = try container.decodeIfPresent(String.self, forKey: .planUserId) ?? ""
        self.planUserName = try container.decodeIfPresent(String.self, forKey: .planUserName) ?? ""
        self.planUserProfileImageUrl = try container.decodeIfPresent(
            String.self, forKey: .planUserProfileImageUrl
        )
        self.messageType = try container.decodeIfPresent(String.self, forKey: .messageType) ?? "text"
        self.text = try container.decodeIfPresent(String.self, forKey: .text)
        self.schedule = try container.decodeIfPresent(ChatSchedule.self, forKey: .schedule)
        self.createDate = try container.decodeIfPresent(String.self, forKey: .createDate) ?? ""
        self.unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0
    }

    /// 숫자·문자열 양쪽으로 오는 id 를 받아낸다.
    static func looseId<Key: CodingKey>(
        _ container: KeyedDecodingContainer<Key>,
        _ key: Key
    ) -> Int? {
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) { return value }
        if let text = try? container.decodeIfPresent(String.self, forKey: key) { return Int(text) }
        return nil
    }
}

public struct ChatHistoryPage: Codable, Hashable, Sendable {
    public var list: [ChatHistoryItem]

    public init(list: [ChatHistoryItem] = []) {
        self.list = list
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.list = try container.decodeIfPresent([ChatHistoryItem].self, forKey: .list) ?? []
    }
}

/// `GET /plan/chat/info/{chatRoomId}` 응답.
public struct ChatRoomInfo: Codable, Hashable, Sendable {
    public var id: Int?
    public var name: String
    public var memberList: [Member]

    public init(id: Int? = nil, name: String = "", memberList: [Member] = []) {
        self.id = id
        self.name = name
        self.memberList = memberList
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(Int.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.memberList = try container.decodeIfPresent([Member].self, forKey: .memberList) ?? []
    }
}
