import Combine
import Foundation
import WPNetworking

/// 채팅 실시간 연결. 웹 `socket.io-client` 와 **같은 프로토콜**로 붙는다.
///
/// 프레임 조립·해석은 Core 의 ``SocketIOPacket`` 이 하고, 여기서는 웹소켓과 재연결만 다룬다.
///
/// - 접속: `{API_BASE_URL}/socket.io/?EIO=4&transport=websocket` → 네임스페이스 `/chat` + `auth: { token }`
/// - 입장: `joinRoom { room, userId }` / 퇴장: `leaveRoom <roomId>`
/// - 수신/발신: `message` · 접속자 수: `roomList`
///
/// - Important: **재연결에 상한을 두지 않는다.** 웹 설정(`reconnectionAttempts: 5`)을 그대로
///   옮기면 지하철·엘리베이터처럼 잠깐 끊기는 상황에서 5번 실패한 뒤 영영 죽는다. 모바일은
///   와이파이↔셀룰러 전환이 일상이라, 지수 백오프(최대 30초) + 흔들림으로 계속 시도해야 한다.
@MainActor
final class ChatSocket: NSObject, ObservableObject {

    enum Event {
        /// 새 메시지. 인자는 원본 JSON 문자열.
        case message(String)
        /// 방 접속자 수 목록.
        case roomList(String)
        /// 서버가 보낸 오류 문구.
        case serverError(String)
        /// 끊겼다가 **다시** 붙었다. 끊긴 동안 온 메시지는 소켓으로 못 받았으므로
        /// 화면이 REST 로 최신 목록을 다시 받아 채워야 한다.
        case reconnected
    }

    /// 웹과 동일한 네임스페이스.
    private static let namespace = "/chat"

    @Published private(set) var connected = false

    var onEvent: ((Event) -> Void)?

    private let baseURL: URL
    private let tokenStore: any TokenStoring

    private var session: URLSession?
    private var task: URLSessionWebSocketTask?

    private var roomId: Int?
    private var userId: String = ""

    /// 한 번이라도 붙은 적이 있는지 — 첫 연결과 재연결을 구분한다.
    private var hasConnectedBefore = false
    private var reconnectAttempt = 0
    private var reconnectTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var closed = false

    /// 서버가 알려주는 침묵 허용 시간. 핸드셰이크 값으로 갱신된다.
    private var silenceTimeout: Duration = .seconds(45)

    init(baseURL: URL, tokenStore: any TokenStoring) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        super.init()
    }

    // MARK: - 수명

    func connect(roomId: Int, userId: String) {
        self.roomId = roomId
        self.userId = userId
        closed = false
        openSocket()
    }

    /// 화면이 다시 보일 때 호출한다. 살아 있으면 아무 일도 하지 않는다.
    func ensureConnected() {
        guard !closed, roomId != nil, !connected, reconnectTask == nil else { return }
        reconnectAttempt = 0
        openSocket()
    }

    /// 방을 벗어날 때. 더 이상 재연결하지 않는다.
    func release() {
        closed = true
        leaveRoom()
        teardown()
        connected = false
    }

    // MARK: - 보내기

    func send(text: String) {
        guard let roomId else { return }
        let body = "{\"room\":\(roomId),"
            + "\"message\":\(SocketIOPacket.jsonString(text)),"
            + "\"messageType\":\"text\"}"
        write(SocketIOPacket.event(namespace: Self.namespace, name: "message", argumentsJSON: body))
    }

    private func joinRoom() {
        guard let roomId else { return }
        let body = "{\"room\":\(roomId),\"userId\":\(SocketIOPacket.jsonString(userId))}"
        write(SocketIOPacket.event(namespace: Self.namespace, name: "joinRoom", argumentsJSON: body))
    }

    private func leaveRoom() {
        guard let roomId, connected else { return }
        // 웹은 방 id 를 그대로(숫자 하나) 보낸다.
        write(SocketIOPacket.event(
            namespace: Self.namespace,
            name: "leaveRoom",
            argumentsJSON: "\(roomId)"
        ))
    }

    private func write(_ frame: String) {
        task?.send(.string(frame)) { _ in
            // 전송 실패는 곧 연결 종료로 이어지고, 재연결 루프가 알아서 처리한다.
        }
    }

    // MARK: - 연결

    private func openSocket() {
        teardown()

        guard let url = socketURL() else { return }

        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        let session = URLSession(configuration: configuration)
        let task = session.webSocketTask(with: url)
        self.session = session
        self.task = task
        task.resume()

        receiveTask = Task { [weak self] in
            await self?.receiveLoop(task)
        }
        restartWatchdog()
    }

    private func socketURL() -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = (components.scheme == "http") ? "ws" : "wss"
        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }
        components.path = path + "/socket.io/"
        // Engine.IO v4, 업그레이드 없이 바로 웹소켓 (웹도 transports: ["websocket"])
        components.queryItems = [
            URLQueryItem(name: "EIO", value: "4"),
            URLQueryItem(name: "transport", value: "websocket"),
        ]
        return components.url
    }

    private func receiveLoop(_ task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                guard !Task.isCancelled else { return }
                switch message {
                case let .string(text):
                    handle(frame: text)
                case let .data(data):
                    handle(frame: String(decoding: data, as: UTF8.self))
                @unknown default:
                    break
                }
            } catch {
                // 사용자에게 오류를 띄우지 않는다. 자동 재연결이 계속 돌고 있고,
                // 잠깐 끊길 때마다 배너가 뜨면 오히려 고장난 것처럼 보인다.
                scheduleReconnect()
                return
            }
        }
    }

    private func handle(frame: String) {
        // 무엇이든 받았다면 연결은 살아 있다.
        restartWatchdog()

        switch SocketIOPacket.decode(frame) {
        case let .open(_, pingInterval, pingTimeout):
            // 서버가 알려준 주기 + 여유. 이 시간 동안 아무것도 못 받으면 죽은 것으로 본다.
            silenceTimeout = .milliseconds(pingInterval + pingTimeout + 5_000)
            connectNamespace()

        case .ping:
            // 답하지 않으면 서버가 연결을 끊는다.
            write(SocketIOPacket.pong)

        case .connected:
            connected = true
            reconnectAttempt = 0
            // 재연결이어도 방에는 다시 들어가야 메시지를 받는다.
            joinRoom()
            if hasConnectedBefore {
                onEvent?(.reconnected)
            }
            hasConnectedBefore = true

        case .disconnected:
            connected = false
            scheduleReconnect()

        case let .event(_, name, payload):
            switch name {
            case "message": onEvent?(.message(payload))
            case "roomList": onEvent?(.roomList(payload))
            case "error": onEvent?(.serverError(unquoted(payload)))
            default: break
            }

        case let .connectError(_, message):
            connected = false
            onEvent?(.serverError(message))
            scheduleReconnect()

        case .pong, .unknown:
            break
        }
    }

    private func connectNamespace() {
        Task { [weak self] in
            guard let self else { return }
            let token = await tokenStore.currentToken()
            guard let token, !token.isEmpty else { return }
            write(SocketIOPacket.connect(namespace: Self.namespace, auth: ["token": token]))
        }
    }

    /// 서버 문자열 인자는 따옴표에 싸여 온다.
    private func unquoted(_ payload: String) -> String {
        guard let data = payload.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let text = value as? String
        else { return payload }
        return text
    }

    // MARK: - 재연결

    private func scheduleReconnect() {
        guard !closed, reconnectTask == nil else { return }
        connected = false
        reconnectAttempt += 1

        let delay = SocketBackoff.delay(attempt: reconnectAttempt)
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            reconnectTask = nil
            guard !closed else { return }
            openSocket()
        }
    }

    /// 아무 프레임도 오지 않으면 죽은 것으로 보고 다시 붙는다.
    ///
    /// - Note: 타임아웃을 무제한으로 두면 **서버가 조용히 연결을 끊었을 때 영원히 기다린다.**
    ///   앱도 살아있고 로그도 없이 메시지만 안 오는, 가장 찾기 어려운 형태의 고장이다.
    private func restartWatchdog() {
        watchdogTask?.cancel()
        let timeout = silenceTimeout
        watchdogTask = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard let self, !Task.isCancelled else { return }
            connected = false
            scheduleReconnect()
        }
    }

    private func teardown() {
        receiveTask?.cancel()
        receiveTask = nil
        watchdogTask?.cancel()
        watchdogTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
    }
}
