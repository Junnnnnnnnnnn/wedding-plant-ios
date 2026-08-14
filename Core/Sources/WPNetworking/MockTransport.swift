import Foundation

/// 테스트·SwiftUI 프리뷰용 전송 계층.
///
/// Windows에서 Core 전체를 검증할 수 있게 해주는 핵심 장치.
/// 등록된 핸들러로 요청을 가로채 원하는 응답을 돌려주고, 실제로 나간 요청을 기록한다.
public actor MockTransport: HTTPTransport {
    public typealias Handler = @Sendable (PreparedRequest) throws -> HTTPResponse

    private var handlers: [Handler] = []
    private var fallback: HTTPResponse?
    public private(set) var recordedRequests: [PreparedRequest] = []

    public init() {}

    /// 모든 요청에 같은 응답을 돌려준다.
    public init(always response: HTTPResponse) {
        self.fallback = response
    }

    /// 경로 접미사가 일치하면 지정한 JSON 문자열을 `status` 와 함께 응답한다.
    @discardableResult
    public func stub(path: String, status: Int = 200, json: String) -> Self {
        let body = Data(json.utf8)
        handlers.append { request in
            guard request.url.path.hasSuffix(path) else { throw MockMiss() }
            return HTTPResponse(
                status: status,
                headers: ["Content-Type": "application/json"],
                body: body
            )
        }
        return self
    }

    /// 임의 조건으로 응답을 만든다.
    @discardableResult
    public func stub(_ handler: @escaping Handler) -> Self {
        handlers.append(handler)
        return self
    }

    /// 아무 스텁도 매치되지 않을 때 쓸 기본 응답.
    @discardableResult
    public func setFallback(_ response: HTTPResponse) -> Self {
        fallback = response
        return self
    }

    public func send(_ request: PreparedRequest) async throws -> HTTPResponse {
        recordedRequests.append(request)
        for handler in handlers {
            if let response = try? handler(request) {
                return response
            }
        }
        if let fallback {
            return fallback
        }
        throw APIError.transport("MockTransport: \(request.method.rawValue) \(request.url.path) 에 대한 스텁이 없습니다.")
    }

    public func lastRequest() -> PreparedRequest? {
        recordedRequests.last
    }

    public func reset() {
        recordedRequests.removeAll()
    }
}

/// 스텁 미스를 나타내는 내부 마커 오류.
struct MockMiss: Error, Sendable {}
