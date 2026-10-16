import XCTest
import WPDomain
import WPModels
import WPNetworking

/// 준비 패스 결제의 판정 — StoreKit 없이 본다(`WPDomain.PassPurchaseRules`).
final class PassPurchaseRulesTests: XCTestCase {
    /// 서버 계약: `00000000-0000-4000-8000-` + 방 id 의 12자리 소문자 16진수
    func testAppAccountTokenCarriesRoomId() {
        XCTAssertEqual(PassPurchaseRules.appAccountToken(roomId: 255)?.uuidString.lowercased(), "00000000-0000-4000-8000-0000000000ff")
        XCTAssertEqual(PassPurchaseRules.appAccountToken(roomId: 1)?.uuidString.lowercased(), "00000000-0000-4000-8000-000000000001")
        XCTAssertEqual(PassPurchaseRules.appAccountToken(roomId: 0xABCDEF012345)?.uuidString.lowercased(), "00000000-0000-4000-8000-abcdef012345")
        // 12자리를 넘거나 0 이하는 담을 수 없다
        XCTAssertNil(PassPurchaseRules.appAccountToken(roomId: 0))
        XCTAssertNil(PassPurchaseRules.appAccountToken(roomId: -3))
        XCTAssertNil(PassPurchaseRules.appAccountToken(roomId: 0x1_0000_0000_0000))
    }

    /// 복구는 결제창에 실은 방으로 — 거꾸로 읽어 같은 방이 나와야 한다
    func testRoomIdRoundTripsAndRejectsForeignTokens() {
        for room in [1, 42, 255, 70_000, 0xFFFF_FFFF_FFFF] {
            XCTAssertEqual(PassPurchaseRules.roomId(fromAppAccountToken: PassPurchaseRules.appAccountToken(roomId: room)), room)
        }
        XCTAssertNil(PassPurchaseRules.roomId(fromAppAccountToken: nil))
        XCTAssertNil(PassPurchaseRules.roomId(fromAppAccountToken: UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")))
        XCTAssertNil(PassPurchaseRules.roomId(fromAppAccountToken: UUID(uuidString: "00000000-0000-4000-8000-000000000000")))
    }

    func testProductsMapToServerPlans() {
        XCTAssertEqual(PassProduct.allCases.map(\.id), ["prep_pass_monthly", "prep_pass_yearly", "prep_pass_lifetime"])
        XCTAssertEqual(PassProduct(serverPlan: "LIFETIME"), .lifetime)
        XCTAssertEqual(PassProduct(serverPlan: "yearly"), .yearly)
        XCTAssertNil(PassProduct(serverPlan: nil))
        XCTAssertTrue(PassPurchaseRules.isLifetime(PassState(hasPass: true, plan: "LIFETIME")))
        XCTAssertFalse(PassPurchaseRules.isLifetime(PassState(hasPass: true, plan: "LIFETIME", expired: true)))
        XCTAssertFalse(PassPurchaseRules.isLifetime(PassState(hasPass: true, plan: "YEARLY")))
    }

    /// 돈이 나간 직후의 서버 실패는 빨간 오류가 아니라 "결제는 완료됐어요" — 다른 요금제로 또 사지 않게(안드로이드 messageFor)
    func testVerifyFailureWording() {
        XCTAssertEqual(PassPurchaseRules.verifyFailure(reason: "PURCHASE_NOT_VERIFIED", serverMessage: nil, charged: true),
                       .pending(PassPurchaseRules.chargedButNotApplied))
        XCTAssertEqual(PassPurchaseRules.verifyFailure(reason: nil, serverMessage: "네트워크에 연결할 수 없습니다.", charged: true),
                       .pending(PassPurchaseRules.chargedButNotApplied))
        XCTAssertEqual(PassPurchaseRules.verifyFailure(reason: "PURCHASE_PENDING", serverMessage: nil, charged: true), .pending(PassPurchaseRules.pending))
        XCTAssertEqual(PassPurchaseRules.verifyFailure(reason: "PURCHASE_OWNER_MISMATCH", serverMessage: nil, charged: true), .failed(PassPurchaseRules.ownerMismatch))
        XCTAssertEqual(PassPurchaseRules.verifyFailure(reason: "PURCHASE_NOT_VERIFIED", serverMessage: nil, charged: false), .failed(PassPurchaseRules.notVerified))
        XCTAssertEqual(PassPurchaseRules.verifyFailure(reason: nil, serverMessage: "서버 문장", charged: false), .failed("서버 문장"))
        XCTAssertFalse(PassPurchaseOutcome.pending("x").isError)
        XCTAssertTrue(PassPurchaseOutcome.failed("x").isError)
        // App Store 결제 문구에 Google Play 를 말하지 않는다
        for text in [PassPurchaseRules.lifetimeRefused, PassPurchaseRules.chargedButNotApplied, PassPurchaseRules.pending, PassPurchaseRules.notVerified] {
            XCTAssertFalse(text.contains("Google"), text)
        }
    }

    /// 실패 본문의 사유 코드는 `data.reason`(백엔드 ServiceErrorFilter), 없으면 최상위 `reason`
    func testServerReasonParsing() {
        XCTAssertEqual(APIError.http(status: 409, body: #"{"message":"평생","data":{"reason":"PASS_ALREADY_LIFETIME"}}"#).serverReason, "PASS_ALREADY_LIFETIME")
        XCTAssertEqual(APIError.http(status: 400, body: #"{"reason":"PURCHASE_NOT_VERIFIED"}"#).serverReason, "PURCHASE_NOT_VERIFIED")
        XCTAssertNil(APIError.http(status: 500, body: "oops").serverReason)
        XCTAssertNil(APIError.transport("x").serverReason)
    }

    /// 결제할 방 응답 — 권한이 빠져 오면 방장, 숫자가 문자열로 와도 받는다
    func testMyRoomDecoding() throws {
        let owner = try JSONDecoder().decode(MyRoom.self, from: Data(#"{"roomId":"12"}"#.utf8))
        XCTAssertEqual(owner, MyRoom(roomId: 12, permission: "OWNER"))
        XCTAssertFalse(owner.isSpouse)
        XCTAssertTrue(try JSONDecoder().decode(MyRoom.self, from: Data(#"{"roomId":3,"permission":"spouse"}"#.utf8)).isSpouse)
    }

    /// 애플 로그인은 탈퇴 때 토큰을 철회할 수 있게 1회용 코드를 함께 보낸다(선택 필드 — 없으면 키를 뺀다)
    func testAppleLoginCarriesAuthorizationCode() throws {
        let with = try Endpoint.appleLogin(identityToken: "id", name: nil, authorizationCode: "code-1")
        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(with.body)) as? [String: String])
        XCTAssertEqual(body, ["identityToken": "id", "authorizationCode": "code-1"])
        let without = try Endpoint.appleLogin(identityToken: "id", name: "민준")
        let plain = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(without.body)) as? [String: String])
        XCTAssertEqual(plain, ["identityToken": "id", "name": "민준"])
    }

    func testVerifyEndpointBody() throws {
        let request = try Endpoint.verifyApplePurchase(roomId: 7, signedTransaction: "a.b.c")
        XCTAssertEqual(request.path, "/plan/pass/apple/verify")
        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(request.body)) as? [String: Any])
        XCTAssertEqual(body["roomId"] as? Int, 7)
        XCTAssertEqual(body["signedTransaction"] as? String, "a.b.c")
        XCTAssertEqual(Endpoint.ensureMyRoom().path, "/plan/room/mine")
    }
}
