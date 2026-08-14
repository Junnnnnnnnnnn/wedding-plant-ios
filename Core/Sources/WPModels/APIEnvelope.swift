import Foundation

/// 백엔드 공통 응답 래퍼.
///
/// 모든 `/plan/...` 엔드포인트는 `{ "result": Bool, "data": ... }` 형태로 응답한다.
/// `result` 가 누락된 에러 응답도 있으므로 관대하게 디코딩한다(누락 시 `false`).
public struct APIEnvelope<T: Decodable & Sendable>: Decodable, Sendable {
    public let result: Bool
    public let data: T?
    public let error: String?
    public let message: String?

    private enum CodingKeys: String, CodingKey {
        case result, data, error, message
    }

    public init(result: Bool, data: T?, error: String? = nil, message: String? = nil) {
        self.result = result
        self.data = data
        self.error = error
        self.message = message
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.result = try container.decodeIfPresent(Bool.self, forKey: .result) ?? false
        self.data = try container.decodeIfPresent(T.self, forKey: .data)
        self.error = try container.decodeIfPresent(String.self, forKey: .error)
        self.message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}

/// `data` 가 없는 응답(POST/PATCH 성공 확인용)을 위한 빈 페이로드.
public struct EmptyPayload: Codable, Sendable, Equatable {
    public init() {}
}
