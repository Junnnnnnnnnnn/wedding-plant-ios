import Foundation
import WPModels
import WPUtils

/// 화면에 그릴 채팅 한 줄. 웹 `Message` 이식.
public struct ChatLine: Hashable, Sendable, Identifiable {
    /// 서버 id 는 숫자지만, 소켓 페이로드에 id 가 없을 수도 있어 문자열로 통일한다.
    public var id: String
    public var senderId: String
    public var senderName: String
    public var senderImage: String?
    /// "text" | "schedule"
    public var messageType: String
    public var text: String?
    public var schedule: ChatSchedule?
    /// ISO 8601 **UTC** 원본. 날짜 구분선·시각 표시에 쓴다.
    public var createDate: String
    public var isMine: Bool
    public var unreadCount: Int

    public init(
        id: String,
        senderId: String = "",
        senderName: String = "",
        senderImage: String? = nil,
        messageType: String = "text",
        text: String? = nil,
        schedule: ChatSchedule? = nil,
        createDate: String = "",
        isMine: Bool = false,
        unreadCount: Int = 0
    ) {
        self.id = id
        self.senderId = senderId
        self.senderName = senderName
        self.senderImage = senderImage
        self.messageType = messageType
        self.text = text
        self.schedule = schedule
        self.createDate = createDate
        self.isMine = isMine
        self.unreadCount = unreadCount
    }

    /// KST 기준 날짜 문자열. 날짜 구분선을 나눌 기준이다.
    public var dayKey: String {
        KstInstant.kstDate(createDate)?.dateString ?? String(createDate.prefix(10))
    }

    /// "오전 10:30"
    public var timeText: String { KstInstant.timeText(createDate) }

    public init(history item: ChatHistoryItem, myId: String?) {
        self.init(
            id: String(item.id),
            senderId: item.planUserId,
            senderName: item.planUserName,
            senderImage: item.planUserProfileImageUrl,
            messageType: item.messageType,
            text: item.text,
            schedule: item.schedule,
            createDate: item.createDate,
            isMine: ChatTimeline.isMine(senderId: item.planUserId, myId: myId),
            unreadCount: item.unreadCount
        )
    }
}

/// 소켓으로 오는 `message` 페이로드.
///
/// - Important: **평평한 모양과 중첩된 모양이 섞여** 온다. 웹도 두 경우를 모두 읽는다 —
///   한쪽만 보면 어떤 서버 버전에서는 메시지가 빈 말풍선으로 보인다.
public struct SocketChatPayload: Decodable, Hashable, Sendable {

    /// 중첩된 모양(`{ message: { ... } }`)의 안쪽.
    public struct Nested: Decodable, Hashable, Sendable {
        public var messageType: String?
        public var text: String?
        public var schedule: ChatSchedule?
    }

    public var id: String?
    public var planUserId: String?
    public var senderId: String?
    public var planUserName: String?
    public var senderName: String?
    public var planUserProfileImageUrl: String?
    public var senderProfileImageUrl: String?
    public var messageType: String?
    public var text: String?
    public var schedule: ChatSchedule?
    public var createDate: String?
    public var unreadCount: Int?
    public var message: Nested?

    private enum CodingKeys: String, CodingKey {
        case id, planUserId, senderId, planUserName, senderName
        case planUserProfileImageUrl, senderProfileImageUrl
        case messageType, text, schedule, createDate, unreadCount, message
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // id 는 숫자로도 문자열로도 온다.
        if let number = try? container.decodeIfPresent(Int.self, forKey: .id) {
            self.id = String(number)
        } else {
            self.id = try container.decodeIfPresent(String.self, forKey: .id)
        }
        self.planUserId = try container.decodeIfPresent(String.self, forKey: .planUserId)
        self.senderId = try container.decodeIfPresent(String.self, forKey: .senderId)
        self.planUserName = try container.decodeIfPresent(String.self, forKey: .planUserName)
        self.senderName = try container.decodeIfPresent(String.self, forKey: .senderName)
        self.planUserProfileImageUrl = try container.decodeIfPresent(
            String.self, forKey: .planUserProfileImageUrl
        )
        self.senderProfileImageUrl = try container.decodeIfPresent(
            String.self, forKey: .senderProfileImageUrl
        )
        self.messageType = try container.decodeIfPresent(String.self, forKey: .messageType)
        self.text = try container.decodeIfPresent(String.self, forKey: .text)
        self.schedule = try container.decodeIfPresent(ChatSchedule.self, forKey: .schedule)
        self.createDate = try container.decodeIfPresent(String.self, forKey: .createDate)
        self.unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount)
        self.message = try container.decodeIfPresent(Nested.self, forKey: .message)
    }
}

/// 채팅 목록을 다루는 규칙 모음. UI 없이 검증할 수 있도록 여기 모아 둔다.
public enum ChatTimeline {

    /// 웹 `PAGE_SIZE`. 이보다 적게 오면 더 받을 게 없다는 뜻이다.
    public static let pageSize = 50

    public static func isMine(senderId: String, myId: String?) -> Bool {
        guard let myId = myId?.trimmingCharacters(in: .whitespaces), !myId.isEmpty else {
            return false
        }
        return senderId.trimmingCharacters(in: .whitespaces) == myId
    }

    /// 소켓 페이로드 → 화면 한 줄.
    ///
    /// - Parameters:
    ///   - fallbackId: 서버가 id 를 안 줄 때 쓸 임시 id. 호출부가 고유값을 넘긴다.
    ///   - now: 시각이 없을 때 쓸 기본값(웹도 "지금"으로 폴백한다).
    public static func line(
        from payload: SocketChatPayload,
        myId: String?,
        fallbackId: String,
        now: Date = Date()
    ) -> ChatLine {
        let senderId = firstNonEmpty(payload.planUserId, payload.senderId) ?? ""
        let senderName = firstNonEmpty(payload.planUserName, payload.senderName) ?? "알 수 없음"
        let image = firstNonEmpty(payload.planUserProfileImageUrl, payload.senderProfileImageUrl)
        let type = firstNonEmpty(payload.messageType, payload.message?.messageType) ?? "text"
        let text = firstNonEmpty(payload.text, payload.message?.text)
        let schedule = payload.schedule ?? payload.message?.schedule
        let createDate = firstNonEmpty(payload.createDate) ?? isoString(now)

        return ChatLine(
            id: firstNonEmpty(payload.id) ?? fallbackId,
            senderId: senderId,
            senderName: senderName,
            senderImage: image,
            messageType: type,
            text: text,
            schedule: schedule,
            createDate: createDate,
            isMine: isMine(senderId: senderId, myId: myId),
            unreadCount: payload.unreadCount ?? 0
        )
    }

    /// 기록 응답(최신순)을 화면 순서(오래된 것이 위)로 바꾼다.
    public static func lines(from page: [ChatHistoryItem], myId: String?) -> [ChatLine] {
        page.reversed().map { ChatLine(history: $0, myId: myId) }
    }

    /// 이미 갖고 있는 목록에 새 줄들을 합친다.
    ///
    /// **같은 id 는 먼저 있던 쪽을 남기고**, 시간 → id 순으로 다시 정렬한다.
    /// 재연결 직후 소켓으로 들어온 메시지와 REST 로 받은 메시지가 뒤섞이지 않게 하기 위함이다.
    public static func merge(_ existing: [ChatLine], _ incoming: [ChatLine]) -> [ChatLine] {
        var seen = Set<String>()
        var merged: [ChatLine] = []
        merged.reserveCapacity(existing.count + incoming.count)

        for line in existing + incoming where seen.insert(line.id).inserted {
            merged.append(line)
        }

        return merged.sorted { left, right in
            if left.createDate != right.createDate { return left.createDate < right.createDate }
            // 같은 시각이면 숫자 id 순. 임시 id 는 숫자가 아니므로 뒤로 간다.
            return sortKey(left.id) < sortKey(right.id)
        }
    }

    /// 이전 페이지를 앞에 붙인다. 이미 있는 id 는 버린다.
    public static func prepend(_ older: [ChatLine], to existing: [ChatLine]) -> [ChatLine] {
        let known = Set(existing.map(\.id))
        return older.filter { !known.contains($0.id) } + existing
    }

    /// 더 받을 이전 메시지가 있는지. 한 페이지를 꽉 채워 왔으면 더 있다고 본다.
    public static func hasMore(receivedCount: Int) -> Bool {
        receivedCount >= pageSize
    }

    /// 날짜 구분선을 그릴 위치인지. 첫 줄이거나 앞 줄과 날짜가 다르면 그린다.
    public static func showsDateHeader(_ lines: [ChatLine], at index: Int) -> Bool {
        guard lines.indices.contains(index) else { return false }
        guard index > 0 else { return true }
        return lines[index - 1].dayKey != lines[index].dayKey
    }

    /// 보낸 사람 이름을 말풍선 위에 표시할지.
    ///
    /// 내 메시지에는 안 붙이고, 같은 사람이 연달아 보내면 첫 줄에만 붙인다.
    public static func showsSenderName(_ lines: [ChatLine], at index: Int) -> Bool {
        guard lines.indices.contains(index) else { return false }
        let line = lines[index]
        guard !line.isMine else { return false }
        guard index > 0 else { return true }
        if showsDateHeader(lines, at: index) { return true }
        return lines[index - 1].senderId != line.senderId
    }

    /// "2026년 8월 20일"
    public static func dateHeaderText(_ dayKey: String) -> String {
        guard let date = KstDate(dateString: dayKey) else { return dayKey }
        return "\(date.year)년 \(date.month)월 \(date.day)일"
    }

    /// 방 인원이 **전원 접속**이면 안 읽음 표시를 모두 지운다 (웹 `roomList` 처리와 동일).
    public static func clearUnreadIfEveryoneJoined(
        _ lines: [ChatLine],
        connectedCount: Int,
        memberCount: Int
    ) -> [ChatLine] {
        guard memberCount > 0, connectedCount >= memberCount else { return lines }
        return lines.map { line in
            var updated = line
            updated.unreadCount = 0
            return updated
        }
    }

    // MARK: -

    private static func sortKey(_ id: String) -> (Int, String) {
        // 숫자 id 가 먼저(0), 임시 id 가 나중(1).
        if let number = Int(id) { return (0, String(format: "%020d", number)) }
        return (1, id)
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            guard let trimmed = value?.trimmingCharacters(in: .whitespaces),
                  !trimmed.isEmpty,
                  trimmed != "null"
            else { continue }
            return trimmed
        }
        return nil
    }

    private static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
