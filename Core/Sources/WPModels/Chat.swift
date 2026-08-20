import Foundation

/// 채팅 메시지.
///
/// - Important: `id` 는 **숫자**다. `String` 으로 디코딩하면 `Codable` 이 전체를 throw 해서
///   **메시지가 70건 있어도 채팅방이 빈 화면으로** 보인다. 안드로이드에서 실제로 겪은 버그다.
public struct ChatMessage: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var planUserId: String
    public var text: String
    /// 서버가 내려주는 ISO 8601 **UTC** 시각. 표시 전에 KST 로 변환해야 한다(`KstInstant`).
    public var createDate: String?
    public var name: String?
    public var image: String?

    public init(
        id: Int,
        planUserId: String,
        text: String,
        createDate: String? = nil,
        name: String? = nil,
        image: String? = nil
    ) {
        self.id = id
        self.planUserId = planUserId
        self.text = text
        self.createDate = createDate
        self.name = name
        self.image = image
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.planUserId = try container.decodeIfPresent(String.self, forKey: .planUserId) ?? ""
        self.text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        self.createDate = try container.decodeIfPresent(String.self, forKey: .createDate)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.image = try container.decodeIfPresent(String.self, forKey: .image)
    }
}

/// 방 멤버 목록 응답.
///
/// - Important: `/plan/user/room/member/{code}` 는 배열 키가 `list` 일 때도, `members` 일 때도 있다.
///   **둘 다 방어**해야 한다.
public struct MemberListPage: Codable, Hashable, Sendable {
    public var list: [Member]

    public init(list: [Member] = []) {
        self.list = list
    }

    private enum CodingKeys: String, CodingKey {
        case list, members
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try container.decodeIfPresent([Member].self, forKey: .list) {
            self.list = value
        } else {
            self.list = try container.decodeIfPresent([Member].self, forKey: .members) ?? []
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(list, forKey: .list)
    }
}

/// 백엔드가 보내는 푸시 페이로드 (`notification` 없이 `data` 만).
///
/// **값은 전부 문자열이다.** `chatRoomId` 도 `1` 이 아니라 `"1"`.
public struct PushPayload: Hashable, Sendable {
    public var chatRoomId: Int?
    public var senderName: String
    public var body: String

    public init(userInfo: [AnyHashable: Any]) {
        let raw = userInfo["chatRoomId"]
        if let text = raw as? String {
            chatRoomId = Int(text)
        } else {
            chatRoomId = raw as? Int
        }
        senderName = userInfo["senderName"] as? String ?? ""
        body = userInfo["body"] as? String ?? ""
    }
}
