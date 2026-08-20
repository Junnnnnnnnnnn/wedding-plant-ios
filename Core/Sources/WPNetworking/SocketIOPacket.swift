import Foundation

/// Socket.IO v4(Engine.IO v4) 프레임 인코딩/디코딩.
///
/// 웹은 `socket.io-client`, 안드로이드는 `socket.io-client-java` 를 쓴다. iOS 는 외부 의존성 없이
/// `URLSessionWebSocketTask` 위에 프로토콜을 직접 얹는다 — 그래서 **이 파일이 프로토콜의 전부**다.
/// 순수 문자열 처리라 Windows 에서도 테스트된다.
///
/// 프레임 모양 (웹소켓 텍스트 한 줄):
/// ```
/// 0{"sid":"...","pingInterval":25000}   Engine.IO OPEN (서버 → 클라)
/// 2 / 3                                 PING / PONG
/// 40/chat,{"token":"..."}               CONNECT (네임스페이스 + auth)
/// 40/chat,{"sid":"..."}                 CONNECT 응답
/// 42/chat,["message",{...}]             EVENT
/// 44/chat,{"message":"..."}             CONNECT_ERROR
/// ```
/// 앞 글자는 Engine.IO 타입, `4`(message) 뒤에 Socket.IO 타입이 붙는다.
public enum SocketIOPacket {

    /// 서버에서 받은 프레임을 해석한 결과.
    public enum Inbound: Hashable, Sendable {
        /// Engine.IO 핸드셰이크. `pingInterval` 은 ms.
        case open(sessionId: String, pingIntervalMillis: Int, pingTimeoutMillis: Int)
        /// 서버가 살아있는지 묻는다. 반드시 ``pong`` 으로 답해야 연결이 유지된다.
        case ping
        case pong
        /// 네임스페이스 접속 성공.
        case connected(namespace: String)
        case disconnected(namespace: String)
        /// `["이벤트이름", 인자...]` — 인자는 원본 JSON 문자열로 넘긴다.
        case event(namespace: String, name: String, payload: String)
        case connectError(namespace: String, message: String)
        /// 해석하지 못한 프레임. 무시해도 되지만 로그용으로 남긴다.
        case unknown(raw: String)
    }

    // MARK: - 보내기

    /// `3` — 서버 PING 에 대한 응답.
    public static let pong = "3"

    /// 네임스페이스 접속. `auth` 는 JSON 객체 문자열이며 생략 가능하다.
    ///
    /// 웹은 `io(url + "/chat", { auth: { token } })` 로 붙는다. 그 auth 가 여기 payload 다.
    public static func connect(namespace: String, auth: [String: String]? = nil) -> String {
        var frame = "40" + normalized(namespace)
        if let auth, !auth.isEmpty {
            frame += "," + jsonObject(auth)
        }
        return frame
    }

    /// 이벤트 발신. `argumentsJSON` 은 **인자 하나**를 나타내는 JSON 문자열이다.
    public static func event(namespace: String, name: String, argumentsJSON: String) -> String {
        "42" + normalized(namespace) + ",[" + jsonString(name) + "," + argumentsJSON + "]"
    }

    /// 인자가 없는 이벤트.
    public static func event(namespace: String, name: String) -> String {
        "42" + normalized(namespace) + ",[" + jsonString(name) + "]"
    }

    /// 네임스페이스에서 나가기.
    public static func disconnect(namespace: String) -> String {
        "41" + normalized(namespace)
    }

    // MARK: - 받기

    public static func decode(_ raw: String) -> Inbound {
        guard let first = raw.first else { return .unknown(raw: raw) }
        let rest = String(raw.dropFirst())

        switch first {
        case "0":
            let object = jsonDictionary(rest)
            return .open(
                sessionId: object["sid"] as? String ?? "",
                // 값이 없으면 Engine.IO 기본값을 쓴다.
                pingIntervalMillis: intValue(object["pingInterval"]) ?? 25_000,
                pingTimeoutMillis: intValue(object["pingTimeout"]) ?? 20_000
            )
        case "2":
            return .ping
        case "3":
            return .pong
        case "4":
            return decodeMessage(rest, raw: raw)
        default:
            return .unknown(raw: raw)
        }
    }

    private static func decodeMessage(_ body: String, raw: String) -> Inbound {
        guard let type = body.first else { return .unknown(raw: raw) }
        let tail = String(body.dropFirst())
        let (namespace, payload) = splitNamespace(tail)

        switch type {
        case "0":
            return .connected(namespace: namespace)
        case "1":
            return .disconnected(namespace: namespace)
        case "2":
            guard let (name, argument) = splitEvent(payload) else { return .unknown(raw: raw) }
            return .event(namespace: namespace, name: name, payload: argument)
        case "4":
            // 문자열 하나로 올 때도, `{ "message": ... }` 로 올 때도 있다.
            let object = jsonDictionary(payload)
            let message = object["message"] as? String
                ?? (jsonAny(payload) as? String)
                ?? payload
            return .connectError(namespace: namespace, message: message)
        default:
            return .unknown(raw: raw)
        }
    }

    /// `"/chat,[...]"` → (`"/chat"`, `"[...]"`). 네임스페이스가 없으면 `"/"`.
    ///
    /// 네임스페이스는 `/` 로 시작하고 `,` 로 끝난다. 페이로드가 `[`·`{` 로 시작하면
    /// 네임스페이스가 생략된 것이다.
    static func splitNamespace(_ text: String) -> (namespace: String, payload: String) {
        guard text.hasPrefix("/") else { return ("/", text) }
        guard let comma = text.firstIndex(of: ",") else { return (text, "") }
        return (String(text[text.startIndex..<comma]), String(text[text.index(after: comma)...]))
    }

    /// `["message",{...}]` → (`"message"`, `"{...}"`).
    ///
    /// 인자가 없으면 `"null"`, 여러 개면 **첫 번째만** 쓴다 (이 앱이 쓰는 이벤트는 모두 인자 1개).
    static func splitEvent(_ payload: String) -> (name: String, argument: String)? {
        guard let array = jsonAny(payload) as? [Any], let name = array.first as? String else {
            return nil
        }
        guard array.count > 1 else { return (name, "null") }
        let argument = array[1]
        guard JSONSerialization.isValidJSONObject([argument]),
              let data = try? JSONSerialization.data(withJSONObject: [argument]),
              let wrapped = String(data: data, encoding: .utf8),
              wrapped.count >= 2
        else {
            // 숫자·문자열 같은 단일 값
            return (name, jsonScalar(argument))
        }
        // `[ ... ]` 의 바깥 대괄호를 벗긴다.
        let inner = wrapped.dropFirst().dropLast()
        return (name, String(inner))
    }

    // MARK: - 작은 JSON 도구

    private static func normalized(_ namespace: String) -> String {
        // 기본 네임스페이스(`/`)는 프레임에 적지 않는다.
        guard namespace != "/", !namespace.isEmpty else { return "" }
        return namespace.hasPrefix("/") ? namespace : "/" + namespace
    }

    /// 문자열을 JSON 리터럴로. 사용자가 보낸 따옴표·줄바꿈이 프레임을 깨뜨리지 않게 한다.
    public static func jsonString(_ value: String) -> String {
        var escaped = ""
        for character in value.unicodeScalars {
            switch character {
            case "\"": escaped += "\\\""
            case "\\": escaped += "\\\\"
            case "\n": escaped += "\\n"
            case "\r": escaped += "\\r"
            case "\t": escaped += "\\t"
            default:
                if character.value < 0x20 {
                    escaped += String(format: "\\u%04x", character.value)
                } else {
                    escaped.unicodeScalars.append(character)
                }
            }
        }
        return "\"" + escaped + "\""
    }

    static func jsonObject(_ values: [String: String]) -> String {
        let body = values
            .sorted { $0.key < $1.key }
            .map { jsonString($0.key) + ":" + jsonString($0.value) }
            .joined(separator: ",")
        return "{" + body + "}"
    }

    private static func jsonScalar(_ value: Any) -> String {
        switch value {
        case let text as String: return jsonString(text)
        case let number as Int: return "\(number)"
        case let number as Double: return "\(number)"
        case let flag as Bool: return flag ? "true" : "false"
        default: return "null"
        }
    }

    private static func jsonAny(_ text: String) -> Any? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    private static func jsonDictionary(_ text: String) -> [String: Any] {
        jsonAny(text) as? [String: Any] ?? [:]
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let number as Int: return number
        case let number as Double: return Int(number)
        case let text as String: return Int(text)
        default: return nil
        }
    }
}
