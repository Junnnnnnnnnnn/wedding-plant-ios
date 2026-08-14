import Foundation

public enum APIError: Error, Sendable, Equatable {
    /// baseURL + path 조합으로 URL을 만들지 못함 (프로그래머 실수)
    case invalidURL(String)
    /// 401. 토큰이 없거나 만료됨 → 토큰 삭제 후 재로그인 유도.
    ///
    /// 별도 케이스로 분리해 호출부가 "그냥 실패"와 "재로그인 필요"를 구분해 처리하도록 강제한다.
    case unauthorized
    /// 2xx가 아닌 응답
    case http(status: Int, body: String?)
    /// HTTP는 성공했으나 `{ result: false }`
    case backend(message: String?)
    /// `{ result: true }` 인데 `data` 가 비어 있음
    case emptyData
    case decoding(String)
    case encoding(String)
    case transport(String)
    case timedOut
}

extension APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let path):
            return "잘못된 요청 경로입니다: \(path)"
        case .unauthorized:
            return "세션이 만료되었습니다. 다시 로그인해 주세요."
        case .http(let status, _):
            return "서버 오류가 발생했습니다. (\(status))"
        case .backend(let message):
            return message ?? "요청을 처리하지 못했습니다."
        case .emptyData:
            return "응답 데이터가 비어 있습니다."
        case .decoding:
            return "응답을 해석하지 못했습니다."
        case .encoding:
            return "요청을 만들지 못했습니다."
        case .transport:
            return "네트워크에 연결할 수 없습니다."
        case .timedOut:
            return "요청 시간이 초과되었습니다."
        }
    }

    /// 사용자를 로그인 화면으로 보내야 하는 오류인지.
    public var requiresReauthentication: Bool {
        self == .unauthorized
    }
}
