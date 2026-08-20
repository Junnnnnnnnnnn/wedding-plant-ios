import Combine
import Foundation
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 웹 `app/chat/[chatRoomId]/page.tsx` 이식.
///
/// 기록은 REST(`/plan/chat/{id}`)로 받고, 실시간 메시지는 소켓(`/chat`)으로 주고받는다.
///
/// - Important: **내가 보낸 메시지도 서버가 되돌려 주는 것만 화면에 넣는다.**
///   낙관적으로 먼저 추가하면 서버 에코와 겹쳐 같은 메시지가 두 번 보인다 (웹과 동일).
@MainActor
final class ChatViewModel: ObservableObject {

    @Published var loading = true
    @Published var roomName = "플랜톡"
    @Published var members: [Member] = []
    @Published var lines: [ChatLine] = []
    @Published var input = ""
    @Published var connected = false
    @Published var sessionExpired = false
    @Published var errorMessage: String?
    @Published var loadingMore = false
    @Published private(set) var hasMore = true

    let chatRoomId: Int

    private var socket: ChatSocket?
    private var myId: String?
    private var page = 1
    private var socketMessageCounter = 0

    init(chatRoomId: Int) {
        self.chatRoomId = chatRoomId
    }

    var memberNames: String {
        members.isEmpty ? "대화 중인 멤버" : members.map(\.name).joined(separator: ", ")
    }

    var canSend: Bool { !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    // MARK: - 로딩

    func start(env: AppEnvironment) async {
        let token = await env.tokenStore.currentToken()
        guard let token, !token.isEmpty else {
            loading = false
            sessionExpired = true
            return
        }
        myId = JWTDecoder.planUserId(from: token)

        await load(env: env)
        connectSocket(env: env)
    }

    private func load(env: AppEnvironment) async {
        loading = true
        page = 1

        let info = try? await env.api.send(
            Endpoint.chatInfo(chatRoomId: chatRoomId),
            decoding: ChatRoomInfo.self
        )
        if let info {
            if !info.name.isEmpty { roomName = info.name }
            members = info.memberList
        }

        let history = try? await env.api.send(
            Endpoint.chatHistory(chatRoomId: chatRoomId, page: 1, count: ChatTimeline.pageSize),
            decoding: ChatHistoryPage.self
        )
        let items = history?.list ?? []
        lines = ChatTimeline.lines(from: items, myId: myId)
        hasMore = ChatTimeline.hasMore(receivedCount: items.count)
        loading = false
    }

    /// 위로 스크롤했을 때 이전 페이지를 앞에 붙인다.
    func loadMore(env: AppEnvironment) async {
        guard !loading, !loadingMore, hasMore else { return }
        loadingMore = true
        defer { loadingMore = false }

        let next = page + 1
        let history = try? await env.api.send(
            Endpoint.chatHistory(chatRoomId: chatRoomId, page: next, count: ChatTimeline.pageSize),
            decoding: ChatHistoryPage.self
        )
        let items = history?.list ?? []
        page = next
        lines = ChatTimeline.prepend(ChatTimeline.lines(from: items, myId: myId), to: lines)
        hasMore = ChatTimeline.hasMore(receivedCount: items.count)
    }

    /// 소켓이 끊겨 있던 동안 놓친 메시지를 REST 로 메운다.
    private func syncMissed(env: AppEnvironment) async {
        let history = try? await env.api.send(
            Endpoint.chatHistory(chatRoomId: chatRoomId, page: 1, count: ChatTimeline.pageSize),
            decoding: ChatHistoryPage.self
        )
        guard let items = history?.list, !items.isEmpty else { return }
        lines = ChatTimeline.merge(lines, ChatTimeline.lines(from: items, myId: myId))
    }

    // MARK: - 소켓

    private func connectSocket(env: AppEnvironment) {
        // 데모(스크린샷) 모드에는 붙을 서버가 없다. 재연결만 돌면서 배터리를 쓴다.
        guard !env.isDemo else { return }

        let socket = ChatSocket(baseURL: env.baseURL, tokenStore: env.tokenStore)
        socket.onEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case let .message(payload):
                append(payload: payload)
            case let .roomList(payload):
                applyRoomList(payload)
            case let .serverError(message):
                errorMessage = message
            case .reconnected:
                Task { await self.syncMissed(env: env) }
            }
        }
        socket.$connected
            .receive(on: RunLoop.main)
            .assign(to: &$connected)

        self.socket = socket
        socket.connect(chatRoomId: chatRoomId, userId: myId ?? "")
    }

    /// 화면이 다시 보일 때. 백그라운드에 오래 있다 오면 소켓이 죽어 있을 수 있다.
    func onForeground() {
        socket?.ensureConnected()
    }

    func leave() {
        socket?.release()
        socket = nil
    }

    private func append(payload: String) {
        guard let data = payload.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(SocketChatPayload.self, from: data)
        else { return }

        socketMessageCounter += 1
        let line = ChatTimeline.line(
            from: decoded,
            myId: myId,
            fallbackId: "sock-\(socketMessageCounter)"
        )
        // 같은 id 가 이미 있으면 넣지 않는다 (재연결 시 중복 방지).
        guard !lines.contains(where: { $0.id == line.id }) else { return }
        lines.append(line)
    }

    /// 방 인원이 전원 접속이면 안 읽음 표시를 모두 지운다.
    private func applyRoomList(_ payload: String) {
        guard let data = payload.data(using: .utf8),
              let rooms = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
        else { return }

        let mine = rooms.first { room in
            String(describing: room["name"] ?? "") == String(chatRoomId)
        }
        guard let mine else { return }
        let count = intValue(mine["count"])
        lines = ChatTimeline.clearUnreadIfEveryoneJoined(
            lines,
            connectedCount: count,
            memberCount: members.count
        )
    }

    /// 접속자 수는 숫자로도 문자열로도 온다.
    private func intValue(_ value: Any?) -> Int {
        switch value {
        case let number as Int: return number
        case let number as Double: return Int(number)
        case let text as String: return Int(text) ?? 0
        default: return 0
        }
    }

    // MARK: - 보내기 · 이름 변경

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        socket?.send(text: text)
        input = ""
    }

    func rename(to name: String, env: AppEnvironment) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            try await env.api.sendIgnoringData(
                Endpoint.renameChatRoom(chatRoomId: chatRoomId, name: trimmed)
            )
            roomName = trimmed
        } catch {
            errorMessage = "채팅방 이름 변경에 실패했습니다. 다시 시도해 주세요."
        }
    }
}
