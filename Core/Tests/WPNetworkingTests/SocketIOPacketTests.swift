import XCTest
@testable import WPNetworking

/// Socket.IO 프레임 처리. 여기가 틀리면 채팅이 **조용히** 안 된다 — 붙긴 붙는데
/// 메시지가 안 오거나, 서버가 연결을 끊어버린다. 그래서 프레임 하나하나를 고정한다.
final class SocketIOPacketTests: XCTestCase {

    // MARK: - 보내기

    func test_네임스페이스_접속_프레임() {
        XCTAssertEqual(
            SocketIOPacket.connect(namespace: "/chat", auth: ["token": "abc"]),
            #"40/chat,{"token":"abc"}"#
        )
    }

    func test_auth가_없으면_붙이지_않는다() {
        XCTAssertEqual(SocketIOPacket.connect(namespace: "/chat"), "40/chat")
        XCTAssertEqual(SocketIOPacket.connect(namespace: "/chat", auth: [:]), "40/chat")
    }

    func test_기본_네임스페이스는_프레임에_적지_않는다() {
        XCTAssertEqual(SocketIOPacket.connect(namespace: "/"), "40")
        XCTAssertEqual(SocketIOPacket.connect(namespace: ""), "40")
    }

    func test_슬래시가_없는_네임스페이스도_받아준다() {
        XCTAssertEqual(SocketIOPacket.connect(namespace: "chat"), "40/chat")
    }

    func test_이벤트_발신() {
        // 웹: socket.emit("joinRoom", { room: 1, userId: "u1" })
        XCTAssertEqual(
            SocketIOPacket.event(
                namespace: "/chat",
                name: "joinRoom",
                argumentsJSON: #"{"room":1,"userId":"u1"}"#
            ),
            #"42/chat,["joinRoom",{"room":1,"userId":"u1"}]"#
        )
    }

    func test_인자가_없는_이벤트() {
        XCTAssertEqual(
            SocketIOPacket.event(namespace: "/chat", name: "ping"),
            #"42/chat,["ping"]"#
        )
    }

    func test_따옴표와_줄바꿈은_이스케이프한다() {
        // 사용자가 보낸 메시지에 따옴표가 있으면 프레임이 깨진다.
        XCTAssertEqual(SocketIOPacket.jsonString(#"큰"따옴표"#), #""큰\"따옴표""#)
        XCTAssertEqual(SocketIOPacket.jsonString("줄\n바꿈"), #""줄\n바꿈""#)
        XCTAssertEqual(SocketIOPacket.jsonString(#"역\슬래시"#), #""역\\슬래시""#)
    }

    func test_퇴장_프레임() {
        XCTAssertEqual(SocketIOPacket.disconnect(namespace: "/chat"), "41/chat")
    }

    func test_PONG은_숫자_3() {
        XCTAssertEqual(SocketIOPacket.pong, "3")
    }

    // MARK: - 받기

    func test_핸드셰이크() {
        let packet = SocketIOPacket.decode(
            #"0{"sid":"abc123","upgrades":[],"pingInterval":25000,"pingTimeout":20000}"#
        )
        guard case let .open(sessionId, interval, timeout) = packet else {
            return XCTFail("open 이 아님: \(packet)")
        }
        XCTAssertEqual(sessionId, "abc123")
        XCTAssertEqual(interval, 25000)
        XCTAssertEqual(timeout, 20000)
    }

    func test_핸드셰이크에_주기가_없으면_기본값() {
        guard case let .open(_, interval, timeout) = SocketIOPacket.decode(#"0{"sid":"x"}"#) else {
            return XCTFail("open 이 아님")
        }
        XCTAssertEqual(interval, 25000)
        XCTAssertEqual(timeout, 20000)
    }

    func test_핑과_퐁() {
        XCTAssertEqual(SocketIOPacket.decode("2"), .ping)
        XCTAssertEqual(SocketIOPacket.decode("3"), .pong)
    }

    func test_접속_응답() {
        XCTAssertEqual(
            SocketIOPacket.decode(#"40/chat,{"sid":"xyz"}"#),
            .connected(namespace: "/chat")
        )
        // 기본 네임스페이스
        XCTAssertEqual(SocketIOPacket.decode(#"40{"sid":"xyz"}"#), .connected(namespace: "/"))
    }

    func test_이벤트_수신() {
        let packet = SocketIOPacket.decode(
            #"42/chat,["message",{"id":7,"text":"안녕"}]"#
        )
        guard case let .event(namespace, name, payload) = packet else {
            return XCTFail("event 가 아님: \(packet)")
        }
        XCTAssertEqual(namespace, "/chat")
        XCTAssertEqual(name, "message")
        // 인자는 원본 JSON 그대로 넘어와야 모델 디코더가 읽을 수 있다.
        let object = (try? JSONSerialization.jsonObject(with: Data(payload.utf8))) as? [String: Any]
        XCTAssertEqual(object?["id"] as? Int, 7)
        XCTAssertEqual(object?["text"] as? String, "안녕")
    }

    func test_배열_인자_이벤트() {
        let packet = SocketIOPacket.decode(#"42/chat,["roomList",[{"name":"1","count":2}]]"#)
        guard case let .event(_, name, payload) = packet else {
            return XCTFail("event 가 아님")
        }
        XCTAssertEqual(name, "roomList")
        let array = (try? JSONSerialization.jsonObject(with: Data(payload.utf8))) as? [[String: Any]]
        XCTAssertEqual(array?.count, 1)
        XCTAssertEqual(array?.first?["count"] as? Int, 2)
    }

    func test_문자열_인자_이벤트() {
        // 서버는 `error` 를 문자열 하나로 보낸다.
        guard case let .event(_, name, payload) = SocketIOPacket.decode(
            #"42/chat,["error","방을 찾을 수 없습니다."]"#
        ) else {
            return XCTFail("event 가 아님")
        }
        XCTAssertEqual(name, "error")
        XCTAssertEqual(payload, #""방을 찾을 수 없습니다.""#)
    }

    func test_인자가_없는_이벤트_수신() {
        guard case let .event(_, name, payload) = SocketIOPacket.decode(#"42/chat,["reload"]"#) else {
            return XCTFail("event 가 아님")
        }
        XCTAssertEqual(name, "reload")
        XCTAssertEqual(payload, "null")
    }

    func test_접속_오류() {
        XCTAssertEqual(
            SocketIOPacket.decode(#"44/chat,{"message":"Unauthorized"}"#),
            .connectError(namespace: "/chat", message: "Unauthorized")
        )
    }

    func test_해석하지_못한_프레임은_unknown() {
        XCTAssertEqual(SocketIOPacket.decode("9zzz"), .unknown(raw: "9zzz"))
        XCTAssertEqual(SocketIOPacket.decode(""), .unknown(raw: ""))
    }

    // MARK: - 프레임 쪼개기

    func test_네임스페이스_분리() {
        var result = SocketIOPacket.splitNamespace(#"/chat,["a"]"#)
        XCTAssertEqual(result.namespace, "/chat")
        XCTAssertEqual(result.payload, #"["a"]"#)

        // 네임스페이스가 생략되면 기본값
        result = SocketIOPacket.splitNamespace(#"["a"]"#)
        XCTAssertEqual(result.namespace, "/")
        XCTAssertEqual(result.payload, #"["a"]"#)

        // 페이로드가 없는 경우
        result = SocketIOPacket.splitNamespace("/chat")
        XCTAssertEqual(result.namespace, "/chat")
        XCTAssertEqual(result.payload, "")
    }

    func test_메시지_본문에_쉼표가_있어도_네임스페이스는_한_번만_자른다() {
        let result = SocketIOPacket.splitNamespace(#"/chat,["message",{"text":"a,b,c"}]"#)
        XCTAssertEqual(result.namespace, "/chat")
        XCTAssertEqual(result.payload, #"["message",{"text":"a,b,c"}]"#)
    }

    // MARK: - 왕복

    func test_보낸_이벤트를_그대로_다시_읽을_수_있다() {
        let frame = SocketIOPacket.event(
            namespace: "/chat",
            name: "message",
            argumentsJSON: #"{"room":1,"message":"따옴표 \" 포함","messageType":"text"}"#
        )
        guard case let .event(namespace, name, payload) = SocketIOPacket.decode(frame) else {
            return XCTFail("왕복 실패: \(frame)")
        }
        XCTAssertEqual(namespace, "/chat")
        XCTAssertEqual(name, "message")
        let object = (try? JSONSerialization.jsonObject(with: Data(payload.utf8))) as? [String: Any]
        XCTAssertEqual(object?["message"] as? String, #"따옴표 " 포함"#)
    }
}

/// 재연결 대기 시간. 상한을 두면 안 된다는 규칙을 코드로 고정한다.
final class SocketBackoffTests: XCTestCase {

    func test_1초에서_시작해_두_배씩_늘어난다() {
        XCTAssertEqual(SocketBackoff.delay(attempt: 1, jitter: 0), 1, accuracy: 0.001)
        XCTAssertEqual(SocketBackoff.delay(attempt: 2, jitter: 0), 2, accuracy: 0.001)
        XCTAssertEqual(SocketBackoff.delay(attempt: 3, jitter: 0), 4, accuracy: 0.001)
        XCTAssertEqual(SocketBackoff.delay(attempt: 5, jitter: 0), 16, accuracy: 0.001)
    }

    func test_30초를_넘지_않는다() {
        XCTAssertEqual(SocketBackoff.delay(attempt: 6, jitter: 0), 30, accuracy: 0.001)
        XCTAssertEqual(SocketBackoff.delay(attempt: 100, jitter: 0), 30, accuracy: 0.001)
        // 아주 큰 값에서도 오버플로 없이 30초
        XCTAssertEqual(SocketBackoff.delay(attempt: 10_000, jitter: 0), 30, accuracy: 0.001)
    }

    func test_시도_횟수에_상한이_없다() {
        // 200번째 시도도 유한한 값을 돌려줘야 한다 — 포기하지 않는다는 뜻.
        let delay = SocketBackoff.delay(attempt: 200, jitter: 0.5)
        XCTAssertTrue(delay.isFinite)
        XCTAssertEqual(delay, 45, accuracy: 0.001)
    }

    func test_흔들림은_최대_50퍼센트() {
        XCTAssertEqual(SocketBackoff.delay(attempt: 1, jitter: 0.5), 1.5, accuracy: 0.001)
        // 범위를 벗어난 값은 잘라낸다
        XCTAssertEqual(SocketBackoff.delay(attempt: 1, jitter: 9), 1.5, accuracy: 0.001)
        XCTAssertEqual(SocketBackoff.delay(attempt: 1, jitter: -9), 1, accuracy: 0.001)
    }

    func test_0이나_음수_시도는_첫_시도로_본다() {
        XCTAssertEqual(SocketBackoff.delay(attempt: 0, jitter: 0), 1, accuracy: 0.001)
        XCTAssertEqual(SocketBackoff.delay(attempt: -3, jitter: 0), 1, accuracy: 0.001)
    }

    func test_무작위_흔들림도_범위_안에_있다() {
        for _ in 0..<50 {
            let delay = SocketBackoff.delay(attempt: 3)
            XCTAssertGreaterThanOrEqual(delay, 4)
            XCTAssertLessThanOrEqual(delay, 6)
        }
    }
}
