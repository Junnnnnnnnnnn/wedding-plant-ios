import XCTest
import WPModels
@testable import WPNetworking

final class APIClientTests: XCTestCase {

    private let baseURL = URL(string: "https://api.example.com")!

    /// 만료되지 않은 테스트용 JWT.
    private func validToken(planUserId: String = "pu-1", expiresIn: TimeInterval = 3600) throws -> String {
        try makeToken(["planUserId": planUserId, "exp": Date().timeIntervalSince1970 + expiresIn])
    }

    private func makeToken(_ claims: [String: Any]) throws -> String {
        let payload = try JSONSerialization.data(withJSONObject: claims)
        let encoded = payload.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "eyJhbGciOiJIUzI1NiJ9.\(encoded).sig"
    }

    private func makeClient(
        transport: MockTransport,
        token: String?
    ) -> (APIClient, InMemoryTokenStore) {
        let store = InMemoryTokenStore(token: token)
        return (APIClient(baseURL: baseURL, transport: transport, tokenStore: store), store)
    }

    // MARK: - 요청 조립

    func test_baseURL과_path를_올바르게_결합한다() async throws {
        let transport = MockTransport()
        await transport.stub(path: "/plan/user", json: #"{"result":true,"data":{"name":"지수"}}"#)
        let (client, _) = makeClient(transport: transport, token: try validToken())

        _ = try await client.send(Endpoint.user(), decoding: PlanUser.self)

        let request = await transport.lastRequest()
        XCTAssertEqual(request?.url.absoluteString, "https://api.example.com/plan/user")
    }

    func test_baseURL_끝의_슬래시는_중복되지_않는다() async throws {
        let transport = MockTransport()
        await transport.stub(path: "/plan/user", json: #"{"result":true,"data":{}}"#)
        let store = InMemoryTokenStore(token: try validToken())
        let client = APIClient(
            baseURL: URL(string: "https://api.example.com/")!,
            transport: transport,
            tokenStore: store
        )

        _ = try await client.send(Endpoint.user(), decoding: PlanUser.self)

        let request = await transport.lastRequest()
        XCTAssertEqual(request?.url.absoluteString, "https://api.example.com/plan/user")
    }

    func test_인증이_필요한_요청에_Bearer_헤더가_붙는다() async throws {
        let token = try validToken()
        let transport = MockTransport()
        await transport.stub(path: "/plan/user", json: #"{"result":true,"data":{}}"#)
        let (client, _) = makeClient(transport: transport, token: token)

        _ = try await client.send(Endpoint.user(), decoding: PlanUser.self)

        let request = await transport.lastRequest()
        XCTAssertEqual(request?.headers["Authorization"], "Bearer \(token)")
    }

    func test_인증이_불필요한_요청에는_Bearer_헤더가_없다() async throws {
        let transport = MockTransport()
        await transport.stub(path: "/plan/auth/kakao/login", json: #"{"result":true,"data":{"token":"jwt-abc"}}"#)
        let (client, _) = makeClient(transport: transport, token: nil)

        let auth = try await client.send(
            Endpoint.kakaoLogin(kakaoToken: "kakao-access-token"),
            decoding: AuthToken.self
        )

        XCTAssertEqual(auth.token, "jwt-abc")
        let request = await transport.lastRequest()
        XCTAssertNil(request?.headers["Authorization"])
        XCTAssertEqual(request?.method, .post)
        XCTAssertEqual(request?.headers["Content-Type"], "application/json")
    }

    func test_쿼리스트링이_붙는다() async throws {
        let transport = MockTransport()
        await transport.stub(path: "/plan/schedule/list", json: #"{"result":true,"data":[]}"#)
        let (client, _) = makeClient(transport: transport, token: try validToken())

        var request = Endpoint.scheduleList()
        request.query = ["roomId": "7", "size": "100"]
        _ = try await client.send(request, decoding: [ScheduleItem].self)

        let sent = await transport.lastRequest()
        XCTAssertEqual(sent?.url.query, "roomId=7&size=100")
    }

    func test_동적_경로_세그먼트는_인코딩된다() async throws {
        let transport = MockTransport()
        await transport.setFallback(HTTPResponse(status: 200, body: Data(#"{"result":true}"#.utf8)))
        let (client, _) = makeClient(transport: transport, token: try validToken())

        try await client.sendIgnoringData(Endpoint.joinRoom(shareCode: "share code/1"))

        let sent = await transport.lastRequest()
        XCTAssertFalse(sent?.url.absoluteString.contains(" ") ?? true, "공백이 인코딩되지 않았습니다")
    }

    // MARK: - 401 처리

    func test_401이면_unauthorized를_던지고_토큰을_지운다() async throws {
        let transport = MockTransport(always: HTTPResponse(status: 401))
        let (client, store) = makeClient(transport: transport, token: try validToken())

        await assertThrows(.unauthorized) {
            _ = try await client.send(Endpoint.user(), decoding: PlanUser.self)
        }
        let remaining = await store.currentToken()
        XCTAssertNil(remaining, "401 이후에도 만료 토큰이 남아 있으면 무한 재시도가 발생한다")
    }

    func test_토큰이_없으면_네트워크를_타지_않고_unauthorized다() async throws {
        let transport = MockTransport()
        let (client, _) = makeClient(transport: transport, token: nil)

        await assertThrows(.unauthorized) {
            _ = try await client.send(Endpoint.user(), decoding: PlanUser.self)
        }
        let count = await transport.recordedRequests.count
        XCTAssertEqual(count, 0)
    }

    func test_만료된_토큰이면_네트워크를_타지_않고_unauthorized다() async throws {
        // 만료가 확실한 토큰은 왕복 비용을 쓰지 않고 클라이언트에서 바로 걸러낸다.
        let expired = try makeToken(["exp": Date().timeIntervalSince1970 - 600])
        let transport = MockTransport()
        let (client, store) = makeClient(transport: transport, token: expired)

        await assertThrows(.unauthorized) {
            _ = try await client.send(Endpoint.user(), decoding: PlanUser.self)
        }
        let count = await transport.recordedRequests.count
        XCTAssertEqual(count, 0)
        let remaining = await store.currentToken()
        XCTAssertNil(remaining)
    }

    // MARK: - 봉투/에러 처리

    func test_result가_false면_backend_에러다() async throws {
        let transport = MockTransport()
        await transport.stub(path: "/plan/user", json: #"{"result":false,"error":"NOT_FOUND"}"#)
        let (client, _) = makeClient(transport: transport, token: try validToken())

        await assertThrows(.backend(message: "NOT_FOUND")) {
            _ = try await client.send(Endpoint.user(), decoding: PlanUser.self)
        }
    }

    func test_result가_true인데_data가_없으면_emptyData다() async throws {
        let transport = MockTransport()
        await transport.stub(path: "/plan/user", json: #"{"result":true}"#)
        let (client, _) = makeClient(transport: transport, token: try validToken())

        await assertThrows(.emptyData) {
            _ = try await client.send(Endpoint.user(), decoding: PlanUser.self)
        }
    }

    func test_5xx는_http_에러다() async throws {
        let transport = MockTransport(always: HTTPResponse(status: 503, body: Data("upstream down".utf8)))
        let (client, _) = makeClient(transport: transport, token: try validToken())

        await assertThrows(.http(status: 503, body: "upstream down")) {
            _ = try await client.send(Endpoint.user(), decoding: PlanUser.self)
        }
    }

    func test_형식이_깨진_JSON은_decoding_에러다() async throws {
        let transport = MockTransport()
        await transport.stub(path: "/plan/user", json: "not json at all")
        let (client, _) = makeClient(transport: transport, token: try validToken())

        do {
            _ = try await client.send(Endpoint.user(), decoding: PlanUser.self)
            XCTFail("에러가 발생해야 합니다")
        } catch let error as APIError {
            guard case .decoding = error else {
                return XCTFail("decoding 에러를 기대했지만 \(error)")
            }
        }
    }

    func test_sendIgnoringData는_빈_바디를_성공으로_본다() async throws {
        let transport = MockTransport(always: HTTPResponse(status: 204))
        let (client, _) = makeClient(transport: transport, token: try validToken())

        try await client.sendIgnoringData(Endpoint.markMainGuideSeen())
    }

    func test_sendIgnoringData도_result_false는_실패로_본다() async throws {
        let transport = MockTransport(always: HTTPResponse(status: 200, body: Data(#"{"result":false,"error":"NOPE"}"#.utf8)))
        let (client, _) = makeClient(transport: transport, token: try validToken())

        await assertThrows(.backend(message: "NOPE")) {
            try await client.sendIgnoringData(Endpoint.markMainGuideSeen())
        }
    }

    // MARK: - 헬퍼

    private func assertThrows(
        _ expected: APIError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ block: () async throws -> Void
    ) async {
        do {
            try await block()
            XCTFail("\(expected) 가 발생해야 합니다", file: file, line: line)
        } catch let error as APIError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("APIError를 기대했지만 \(error)", file: file, line: line)
        }
    }
}
