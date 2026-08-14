import Foundation

public enum HTTPMethod: String, Sendable, Hashable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case put = "PUT"
    case delete = "DELETE"
}

/// 백엔드 호출 1건에 대한 플랫폼 독립 기술(記述).
///
/// `path` 는 `"/plan/user"` 처럼 baseURL 기준 절대 경로다.
public struct HTTPRequest: Sendable, Hashable {
    public var method: HTTPMethod
    public var path: String
    public var query: [String: String]
    public var headers: [String: String]
    public var body: Data?
    /// `true` 면 `Authorization: Bearer <JWT>` 를 붙인다. 토큰이 없으면 `APIError.unauthorized`.
    public var requiresAuth: Bool
    public var timeout: TimeInterval

    public init(
        method: HTTPMethod = .get,
        path: String,
        query: [String: String] = [:],
        headers: [String: String] = [:],
        body: Data? = nil,
        requiresAuth: Bool = true,
        timeout: TimeInterval = 15
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.headers = headers
        self.body = body
        self.requiresAuth = requiresAuth
        self.timeout = timeout
    }

    /// JSON 바디를 실어 보내는 요청을 만든다.
    public static func json<Body: Encodable>(
        _ method: HTTPMethod,
        _ path: String,
        body: Body,
        query: [String: String] = [:],
        requiresAuth: Bool = true,
        timeout: TimeInterval = 15
    ) throws -> HTTPRequest {
        let encoder = JSONEncoder()
        let data: Data
        do {
            data = try encoder.encode(body)
        } catch {
            throw APIError.encoding(String(describing: error))
        }
        return HTTPRequest(
            method: method,
            path: path,
            query: query,
            headers: ["Content-Type": "application/json"],
            body: data,
            requiresAuth: requiresAuth,
            timeout: timeout
        )
    }
}

/// baseURL·인증 헤더까지 모두 반영된, 전송 계층이 그대로 실행하면 되는 요청.
public struct PreparedRequest: Sendable, Hashable {
    public var method: HTTPMethod
    public var url: URL
    public var headers: [String: String]
    public var body: Data?
    public var timeout: TimeInterval

    public init(
        method: HTTPMethod,
        url: URL,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 15
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

public struct HTTPResponse: Sendable, Hashable {
    public var status: Int
    public var headers: [String: String]
    public var body: Data

    public init(status: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    public var isSuccess: Bool { (200..<300).contains(status) }
}

/// 실제 네트워크 전송 계층.
///
/// Core는 이 프로토콜에만 의존한다. iOS/macOS 구현(`URLSessionTransport`)은 App 타깃에 두고,
/// Windows 유닛테스트에서는 `MockTransport` 를 주입한다.
/// 이 분리가 "Windows에서 Core를 통째로 테스트한다"는 전략의 핵심이다.
public protocol HTTPTransport: Sendable {
    func send(_ request: PreparedRequest) async throws -> HTTPResponse
}
