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

    @Published var activities: [PlanActivity] = []
    @Published var planRoomId: Int?
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
    /// 이 대화방의 멤버가 아니다(서버 403 `NOT_CHAT_MEMBER`, 또는 멤버 목록에 내가 없음) — 안드로이드 `notMember`
    @Published var notMember = false
    /// 기록을 한 번이라도 받았는가. 받기 전·실패했을 때는 "없다" 고 말하지 않는다.
    @Published var historyLoaded = false

    /// 안드로이드 `ChatViewModel.NOT_MEMBER_MESSAGE` · `SHARE_FAILED_MESSAGE` · `SHARE_UNKNOWN_MESSAGE`
    static let notMemberMessage = "참여 중인 대화방이 아니에요."
    static let shareFailedMessage = "공유하지 못했어요. 잠시 후 다시 시도해 주세요."
    static let shareUnknownMessage = "전송 결과를 확인하지 못했어요. 대화방을 확인한 후 다시 시도해 주세요."

    let chatRoomId: Int

    @Published var sharingSchedule: Int?
    @Published var sharedSchedule: Int?
    @Published var shareError: String?
    private var shareTimeout: Task<Void, Never>?
    private var socket: ChatSocket?
    private var myId: String?
    private var page = 1
    private var socketMessageCounter = 0

    init(chatRoomId: Int, planRoomId: Int? = nil) {
        self.planRoomId = planRoomId
        self.chatRoomId = chatRoomId
    }

    /// 토큰의 내 id — 머리의 나·상대 얼굴을 가른다.
    var myPlanUserId: String? { myId }

    var memberNames: String {
        members.isEmpty ? "대화 중인 멤버" : members.map(\.name).joined(separator: ", ")
    }

    var canSend: Bool { connected && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

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
        // 멤버가 아닌 방에는 붙지 않는다(보낼 수 없다)
        if notMember { return }
        await loadActivities(env: env)
        connectSocket(env: env)
    }

    func load(env: AppEnvironment) async {
        loading = true
        notMember = false
        historyLoaded = false
        page = 1

        do {
            let info = try await env.api.send(Endpoint.chatInfo(chatRoomId: chatRoomId), decoding: ChatRoomInfo.self)
            if !info.name.isEmpty { roomName = info.name }
            members = info.memberList
            planRoomId = info.planUserRoomId ?? planRoomId
            // 멤버 목록에 내가 없으면 보낼 수 없다 — 까닭만 말한다(안드로이드와 같음)
            if let myId, !info.memberList.isEmpty, !info.memberList.contains(where: { $0.planUserId == myId }) {
                notMember = true; lines = []; hasMore = false; loading = false
                return
            }
        } catch let error as APIError {
            if case let .http(_, body) = error, body?.contains("NOT_CHAT_MEMBER") == true {
                notMember = true; lines = []; hasMore = false; loading = false
                return
            }
        } catch {}

        defer { loading = false }
        do {
            let history: ChatHistoryPage = try await env.api.send(Endpoint.chatHistory(chatRoomId: chatRoomId, page: 1, count: ChatTimeline.pageSize))
            lines = ChatTimeline.lines(from: history.list, myId: myId)
            hasMore = ChatTimeline.hasMore(receivedCount: history.list.count)
            historyLoaded = true
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    /// Failed pages do not advance the cursor or masquerade as the end of history.
    func loadMore(env: AppEnvironment) async {
        guard !loading, !loadingMore, hasMore else { return }
        loadingMore = true; defer { loadingMore = false }
        do {
            let next = page + 1
            let history: ChatHistoryPage = try await env.api.send(Endpoint.chatHistory(chatRoomId: chatRoomId, page: next, count: ChatTimeline.pageSize))
            lines = ChatTimeline.prepend(ChatTimeline.lines(from: history.list, myId: myId), to: lines)
            page = next; hasMore = ChatTimeline.hasMore(receivedCount: history.list.count); errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    /// Fill the entire disconnection gap, including gaps longer than one REST page.
    private func syncMissed(env: AppEnvironment) async {
        let known = Set(lines.map(\.id)); var seen = Set<String>(); var next = 1
        do {
            while !Task.isCancelled {
                let history: ChatHistoryPage = try await env.api.send(Endpoint.chatHistory(chatRoomId: chatRoomId, page: next, count: ChatTimeline.pageSize))
                let incoming = ChatTimeline.lines(from: history.list, myId: myId)
                let ids = Set(incoming.map(\.id))
                lines = ChatTimeline.merge(lines, incoming)
                if !ids.isDisjoint(with: known) || !ChatTimeline.hasMore(receivedCount: history.list.count) || ids.isSubset(of: seen) { break }
                seen.formUnion(ids); next += 1
            }
        } catch { if !Task.isCancelled { errorMessage = error.localizedDescription } }
    }

    func loadActivities(env: AppEnvironment) async {
        guard let planRoomId else { return }
        if let page: PlanActivityPage = try? await env.api.send(Endpoint.activities(roomId: planRoomId)), !Task.isCancelled { activities = page.list }
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
                if sharingSchedule != nil {
                    // 올리기가 거절됐다 — 시트에는 안드로이드·웹과 같은 문장을 낸다
                    sharingSchedule = nil; shareError = Self.shareFailedMessage; shareTimeout?.cancel()
                } else {
                    errorMessage = message
                }
            case .reconnected:
                Task { await self.syncMissed(env: env) }
            }
        }
        socket.$connected
            .receive(on: RunLoop.main)
            .assign(to: &$connected)

        self.socket = socket
        socket.connect(roomId: chatRoomId, userId: myId ?? "")
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
        if line.isMine, line.schedule?.id == sharingSchedule { completeShare() }
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
        guard connected, !text.isEmpty else { return }
        socket?.send(text: text)
        input = ""
    }

    func shareSchedule(_ id: Int) {
        guard sharingSchedule == nil else { return }
        sharedSchedule = nil; shareError = nil
        guard connected else { shareError = Self.shareFailedMessage; return }
        sharingSchedule = id
        guard socket?.sendSchedule(id, onAck: { [weak self] in self?.completeShare() }) == true else {
            sharingSchedule = nil; shareError = Self.shareFailedMessage; return
        }
        shareTimeout?.cancel()
        shareTimeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            guard let self, sharingSchedule == id else { return }
            sharingSchedule = nil; shareError = Self.shareUnknownMessage
        }
    }
    private func completeShare() {
        guard let id = sharingSchedule else { return }
        shareTimeout?.cancel(); sharingSchedule = nil; sharedSchedule = id; shareError = nil
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
