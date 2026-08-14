import Foundation
import WPModels
import WPUtils

/// 백엔드(`${API_BASE_URL}/plan/...`) 호출 진입점.
///
/// 웹의 `ApiContext.fetchWithAuth / fetchBackend` 에 대응한다.
/// 로딩 오버레이 카운팅 같은 UI 관심사는 여기에 두지 않고 App 레이어에서 처리한다.
public actor APIClient {
    private let baseURL: URL
    private let transport: any HTTPTransport
    private let tokenStore: (any TokenStoring)?
    private let decoder = JSONDecoder()

    public init(
        baseURL: URL,
        transport: any HTTPTransport,
        tokenStore: (any TokenStoring)? = nil
    ) {
        // 끝의 슬래시를 제거해 `"/plan/user"` 와 항상 안전하게 결합되게 한다.
        var normalized = baseURL.absoluteString
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        self.baseURL = URL(string: normalized) ?? baseURL
        self.transport = transport
        self.tokenStore = tokenStore
    }

    // MARK: - 공개 API

    /// 응답 봉투(`{ result, data }`)를 벗겨 `data` 를 디코딩해 돌려준다.
    public func send<T: Decodable & Sendable>(
        _ request: HTTPRequest,
        decoding type: T.Type = T.self
    ) async throws -> T {
        let response = try await perform(request)
        let envelope: APIEnvelope<T>
        do {
            envelope = try decoder.decode(APIEnvelope<T>.self, from: response.body)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
        guard envelope.result else {
            throw APIError.backend(message: envelope.error ?? envelope.message)
        }
        guard let data = envelope.data else {
            throw APIError.emptyData
        }
        return data
    }

    /// `data` 없이 성공 여부만 확인하는 요청(POST/PATCH/DELETE).
    public func sendIgnoringData(_ request: HTTPRequest) async throws {
        let response = try await perform(request)
        // 바디가 비어 있으면 2xx 자체를 성공으로 본다.
        guard !response.body.isEmpty else { return }
        let envelope = try? decoder.decode(APIEnvelope<EmptyPayload>.self, from: response.body)
        guard let envelope else { return }
        guard envelope.result else {
            throw APIError.backend(message: envelope.error ?? envelope.message)
        }
    }

    /// 봉투를 벗기지 않은 원본 응답이 필요할 때.
    @discardableResult
    public func sendRaw(_ request: HTTPRequest) async throws -> HTTPResponse {
        try await perform(request)
    }

    // MARK: - 내부

    private func perform(_ request: HTTPRequest) async throws -> HTTPResponse {
        let prepared = try await prepare(request)
        let response: HTTPResponse
        do {
            response = try await transport.send(prepared)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(String(describing: error))
        }

        if response.status == 401 {
            // 만료된 토큰을 들고 계속 재시도하는 것을 막기 위해 즉시 폐기한다.
            await tokenStore?.clear()
            throw APIError.unauthorized
        }
        guard response.isSuccess else {
            throw APIError.http(
                status: response.status,
                body: String(data: response.body, encoding: .utf8)
            )
        }
        return response
    }

    func prepare(_ request: HTTPRequest) async throws -> PreparedRequest {
        // `appendingPathComponent` 는 플랫폼마다 슬래시 이스케이프 동작이 달라
        // 문자열로 직접 결합한다. 동적 경로 세그먼트는 `Endpoint.escape(_:)` 로 미리 인코딩할 것.
        let path = request.path.hasPrefix("/") ? request.path : "/" + request.path
        guard var components = URLComponents(string: baseURL.absoluteString + path) else {
            throw APIError.invalidURL(request.path)
        }
        if !request.query.isEmpty {
            components.queryItems = request.query
                .sorted { $0.key < $1.key }
                .map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else {
            throw APIError.invalidURL(request.path)
        }

        var headers = request.headers
        headers["Accept"] = headers["Accept"] ?? "application/json"

        if request.requiresAuth {
            guard let token = await tokenStore?.currentToken(), !token.isEmpty else {
                throw APIError.unauthorized
            }
            // 만료가 확실한 토큰은 네트워크를 태우지 않고 바로 걸러낸다.
            if JWTDecoder.isExpired(token) {
                await tokenStore?.clear()
                throw APIError.unauthorized
            }
            headers["Authorization"] = "Bearer \(token)"
        }

        return PreparedRequest(
            method: request.method,
            url: url,
            headers: headers,
            body: request.body,
            timeout: request.timeout
        )
    }
}
