import XCTest
@testable import WPUtils

final class JWTDecoderTests: XCTestCase {

    /// 서명 없이 payload만 유효한 테스트용 JWT를 만든다.
    ///
    /// base64url 인코딩 시 패딩(`=`)을 떼기 때문에, 디코더가 패딩을 복원하지 못하면
    /// 여기서 만든 토큰은 해석되지 않는다 — 즉 이 헬퍼 자체가 회귀 감지 장치다.
    private func makeToken(_ claims: [String: Any]) throws -> String {
        let payload = try JSONSerialization.data(withJSONObject: claims)
        let encoded = payload.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "eyJhbGciOiJIUzI1NiJ9.\(encoded).fake-signature"
    }

    func test_planUserId와_sub를_읽는다() throws {
        let token = try makeToken(["planUserId": "pu-123", "sub": "kakao-999"])
        XCTAssertEqual(JWTDecoder.planUserId(from: token), "pu-123")
        XCTAssertEqual(JWTDecoder.sub(from: token), "kakao-999")
    }

    func test_클레임이_없으면_nil이다() throws {
        let token = try makeToken(["foo": "bar"])
        XCTAssertNil(JWTDecoder.planUserId(from: token))
        XCTAssertNil(JWTDecoder.sub(from: token))
    }

    /// payload 길이를 1바이트씩 늘려가며 base64 패딩이 0/1/2개인 경우를 모두 훑는다.
    func test_패딩_길이가_달라도_모두_디코딩된다() throws {
        for length in 1...12 {
            let value = String(repeating: "a", count: length)
            let token = try makeToken(["planUserId": value])
            XCTAssertEqual(
                JWTDecoder.planUserId(from: token),
                value,
                "payload 길이 \(length) 에서 base64url 패딩 복원 실패"
            )
        }
    }

    func test_형식이_잘못된_토큰은_nil이다() {
        XCTAssertNil(JWTDecoder.payload(from: ""))
        XCTAssertNil(JWTDecoder.payload(from: "not-a-jwt"))
        XCTAssertNil(JWTDecoder.payload(from: "header.@@@invalid@@@.sig"))
    }

    // MARK: - 만료

    func test_exp가_지났으면_만료다() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let token = try makeToken(["exp": now.timeIntervalSince1970 - 60])
        XCTAssertTrue(JWTDecoder.isExpired(token, now: now))
    }

    func test_exp가_남았으면_유효하다() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let token = try makeToken(["exp": now.timeIntervalSince1970 + 3600])
        XCTAssertFalse(JWTDecoder.isExpired(token, now: now))
    }

    func test_leeway_안쪽이면_미리_만료로_본다() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        // 10초 뒤 만료 → 기본 leeway 30초 안쪽이므로 미리 만료 처리
        let token = try makeToken(["exp": now.timeIntervalSince1970 + 10])
        XCTAssertTrue(JWTDecoder.isExpired(token, now: now))
        XCTAssertFalse(JWTDecoder.isExpired(token, now: now, leeway: 0))
    }

    func test_exp가_없으면_만료로_보지_않는다() throws {
        let token = try makeToken(["planUserId": "pu-1"])
        XCTAssertFalse(JWTDecoder.isExpired(token))
    }

    func test_base64URLDecode_는_치환문자를_처리한다() {
        // 표준 base64의 '+' 와 '/' 가 base64url에서 '-' 와 '_' 로 바뀐 경우
        let raw = Data([0xFB, 0xFF, 0xBE])          // base64: "+/++"
        let urlSafe = raw.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        XCTAssertEqual(JWTDecoder.base64URLDecode(urlSafe), raw)
    }
}
