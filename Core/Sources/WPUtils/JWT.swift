import Foundation

/// 앱 자체 JWT 의 payload 중 앱이 사용하는 클레임.
public struct JWTPayload: Decodable, Hashable, Sendable {
    public let planUserId: String?
    public let sub: String?
    /// 만료 시각 (Unix epoch seconds)
    public let exp: Double?

    public init(planUserId: String? = nil, sub: String? = nil, exp: Double? = nil) {
        self.planUserId = planUserId
        self.sub = sub
        self.exp = exp
    }
}

/// JWT payload 디코딩 유틸.
///
/// 웹 `lib/api.ts` 의 `getJwtPayload / getPlanUserIdFromToken / getSubFromToken` 대응.
/// **서명은 검증하지 않는다** — 클라이언트에서 클레임을 읽기 위한 용도이며,
/// 실제 신뢰 경계는 백엔드다.
public enum JWTDecoder {
    public static func payload(from token: String) -> JWTPayload? {
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 2 else { return nil }
        guard let data = base64URLDecode(String(segments[1])) else { return nil }
        return try? JSONDecoder().decode(JWTPayload.self, from: data)
    }

    public static func planUserId(from token: String) -> String? {
        payload(from: token)?.planUserId
    }

    public static func sub(from token: String) -> String? {
        payload(from: token)?.sub
    }

    /// 토큰 만료 여부.
    ///
    /// `exp` 클레임이 없으면 만료를 판단할 수 없으므로 `false`(유효)로 본다.
    ///
    /// - Parameter leeway: 시계 오차 및 요청 왕복 시간을 감안한 여유(초). 기본 30초.
    public static func isExpired(_ token: String, now: Date = Date(), leeway: TimeInterval = 30) -> Bool {
        guard let exp = payload(from: token)?.exp else { return false }
        return Date(timeIntervalSince1970: exp).addingTimeInterval(-leeway) <= now
    }

    /// base64url → Data. 표준 base64 로 치환하고 패딩을 복원한다.
    ///
    /// 웹의 `atob(...replace(/-/g,"+").replace(/_/g,"/"))` 는 패딩 없이도 동작하지만
    /// Swift 의 `Data(base64Encoded:)` 는 4의 배수 길이를 요구하므로 `=` 를 채워야 한다.
    /// 이 패딩 처리를 빠뜨리는 것이 JWT 디코딩 실패의 가장 흔한 원인이다.
    static func base64URLDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }
}
