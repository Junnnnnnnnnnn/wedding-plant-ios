import XCTest
import KakaoSDKCommon
@testable import WeddingPlant

final class SocialLoginTests: XCTestCase {
    @MainActor func testKakaoDiagnosticKeepsOnlyReasonAndOfficialCode() throws {
        let data = Data(#"{"error":"invalid_client","error_description":"Bad credentials KOE010 client_id=private-key code=private-code"}"#.utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let info = try decoder.decode(AuthErrorInfo.self, from: data)
        let error = SdkError.AuthFailed(reason: .InvalidClient, errorInfo: info)
        XCTAssertEqual(SocialLoginService.kakaoDiagnostic(error), "auth reason=invalid_client code=KOE010")
        XCTAssertFalse(SocialLoginService.mapKakao(error).isSilent)
    }

    @MainActor func testKakaoCancellationStaysSilentAndMessagesStayPrivate() {
        let cancelled = SdkError.ClientFailed(reason: .Cancelled, errorMessage: "private-user-data")
        XCTAssertTrue(SocialLoginService.mapKakao(cancelled).isSilent)
        XCTAssertFalse(SocialLoginService.kakaoDiagnostic(cancelled).contains("private-user-data"))
        let unknown = NSError(domain: "private-domain", code: 42, userInfo: [NSLocalizedDescriptionKey: "private-token"])
        XCTAssertEqual(SocialLoginService.kakaoDiagnostic(unknown), "non_sdk code=42")
        XCTAssertEqual(SocialLoginService.kakaoDiagnostic(SdkError.AuthFailed(reason: .InvalidGrant, errorInfo: nil)), "auth reason=invalid_grant code=unavailable")
    }
}
