import Foundation
import WPModels
import WPNetworking
import WPUtils

/// Foreground subscriptions. Background delivery is handled by APNs/FCM.
@MainActor final class InAppNotifications: ObservableObject {
    @Published private(set) var unread: [Int: Int] = [:]
    var unreadCount: Int { unread.values.reduce(0, +) }
    private var streams: [String: Task<Void, Never>] = [:]
    private var streamIDs: [String: UUID] = [:]
    private var lastEvent: [Int: Date] = [:]
    private var generation = UUID()
    private var refreshID = UUID()
    private var account: String?
    private weak var env: AppEnvironment?
    private weak var push: PushService?
    func start(env: AppEnvironment, push: PushService) async {
        self.env = env; self.push = push
        guard !env.isDemo, env.isAuthenticated, let token = await env.tokenStore.currentToken(), let me = JWTDecoder.planUserId(from: token) else { stop(); return }
        if account != me { stop(); account = me }
        push.sseIsLive = { [weak self] room in self?.lastEvent[room].map { Date().timeIntervalSince($0) < 90 } ?? false }
        ensure(path: "/plan/notification/user", room: nil)
        await refresh()
    }
    func stop() {
        generation = UUID(); refreshID = UUID()
        streams.values.forEach { $0.cancel() }; streams.removeAll(); streamIDs.removeAll(); lastEvent.removeAll(); unread.removeAll(); account = nil
        push?.sseIsLive = nil
    }
    func markRead(_ room: Int?) { guard let room else { return }; unread[room] = 0 }
    func refresh() async {
        guard let env, account != nil else { return }
        let requestID = UUID(); refreshID = requestID; let currentGeneration = generation
        do {
            let user: PlanUser = try await env.api.send(Endpoint.user())
            guard requestID == refreshID, currentGeneration == generation else { return }
            let rooms = Set((user.chatRooms ?? []).filter { ($0.memberCount ?? 2) > 1 }.map(\.id))
            for path in Array(streams.keys) where path.hasPrefix("/plan/notification/chat/") {
                if let room = Int(path.split(separator: "/").last ?? ""), !rooms.contains(room) { streams.removeValue(forKey: path)?.cancel(); lastEvent.removeValue(forKey: room); unread.removeValue(forKey: room) }
            }
            for room in rooms {
                ensure(path: "/plan/notification/chat/\(room)", room: room)
                if let count: Int = try? await env.api.send(Endpoint.unreadCount(roomId: room)) {
                    guard requestID == refreshID, currentGeneration == generation else { return }
                    unread[room] = push?.currentChatRoomId == room ? 0 : count
                }
            }
        } catch { /* Keep known rooms and counts during transient failures. */ }
    }
    private func ensure(path: String, room: Int?) {
        guard streams[path] == nil else { return }
        let currentGeneration = generation
        let streamID = UUID(); streamIDs[path] = streamID
        streams[path] = Task { [weak self] in
            guard let self else { return }
            await listen(path: path, room: room, expectedGeneration: currentGeneration)
            if generation == currentGeneration && streamIDs[path] == streamID { streams.removeValue(forKey: path); streamIDs.removeValue(forKey: path); if let room { lastEvent.removeValue(forKey: room) } }
        }
    }
    private func listen(path: String, room: Int?, expectedGeneration: UUID) async {
        var attempts = 0
        while !Task.isCancelled, generation == expectedGeneration, let env {
            do {
                guard let token = await env.tokenStore.currentToken(), JWTDecoder.planUserId(from: token) == account else { return }
                let url = env.baseURL.appendingPathComponent(path)
                var request = URLRequest(url: url, timeoutInterval: 100)
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                if http.statusCode == 401 || http.statusCode == 403 { return }
                guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
                var parser = SSEParser()
                for try await byte in bytes {
                    try Task.checkCancellation()
                    guard generation == expectedGeneration else { return }
                    if let value = parser.consume(byte) {
                        attempts = 0
                        if let room { lastEvent[room] = Date() }
                        receive(value, room: room)
                    }
                }
            } catch is CancellationError { return }
            catch { if Task.isCancelled { return } }
            if let room { lastEvent.removeValue(forKey: room) }
            attempts += 1; guard attempts <= 6 else { return }
            do { try await Task.sleep(for: .seconds(min(60, 3 * (1 << (attempts - 1))))) } catch { return }
        }
    }
    private func receive(_ raw: String, room: Int?) {
        guard let root = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any] else { return }
        if root["type"] as? String == "CHAT_ROOMS_CHANGED" {
            env?.roomsRevision += 1
            Task { await env?.refreshBoundRoom(); await refresh() }
            return
        }
        guard let room, root["type"] as? String != "keep-alive", let data = root["data"] as? [String: Any], data["planUserId"] as? String != account, push?.currentChatRoomId != room else { return }
        let sender = data["planUserName"] as? String ?? "새 메시지"
        var message = data["text"] as? String ?? "메시지가 도착했습니다."
        if data["messageType"] as? String == "schedule", let schedule = data["schedule"] as? [String: Any] {
            message = "플랜을 공유했어요! [\(schedule["categoryName"] as? String ?? "")] \(schedule["title"] as? String ?? "")"
        }
        unread[room, default: 0] += 1; push?.toast = "\(sender): \(message)"
    }
}
