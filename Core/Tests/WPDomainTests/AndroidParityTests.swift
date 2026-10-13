import XCTest
import WPModels
import WPNetworking
@testable import WPDomain

final class AndroidParityTests: XCTestCase {
    func testGalleryMosaicKeepsEverySlotInAndroidOrder() {
        XCTAssertEqual(InvitationRules.galleryRows(count: 1, layout: "mosaic"), [.mosaic(big: 0, top: nil, bottom: nil)])
        XCTAssertEqual(InvitationRules.galleryRows(count: 8, layout: "mosaic"), [
            .mosaic(big: 0, top: 1, bottom: 2), .even(indices: [3,4], perRow: 2, aspect: 0.8), .even(indices: [5,6,7], perRow: 3, aspect: 0.8)
        ])
        for count in 0...20 {
            let indices = InvitationRules.galleryRows(count: count, layout: "mosaic").flatMap { row -> [Int] in
                switch row { case .mosaic(let big, let top, let bottom): return [big, top, bottom].compactMap { $0 }
                case .even(let indices, _, _): return indices }
            }
            XCTAssertEqual(indices, Array(0..<count))
        }
    }
    func testGalleryGridKeepsPartialLastRowAndSquares() {
        XCTAssertEqual(InvitationRules.galleryRows(count: 4, layout: "grid"), [.even(indices: [0,1,2], perRow: 3, aspect: 1), .even(indices: [3], perRow: 3, aspect: 1)])
        XCTAssertTrue(InvitationRules.galleryRows(count: 0, layout: "grid").isEmpty)
    }
    func testEmailNormalizationAndASCIICode() {
        XCTAssertEqual(EmailAuthRules.normalize(" Me@Example.com \n"), "me@example.com")
        for value in ["a@b.c", "a+b@sub.example.com"] { XCTAssertTrue(EmailAuthRules.validEmail(value)) }
        for value in ["a@b", "a b@c.d", "a@@b.c", String(repeating: "x", count: 250) + "@a.co"] { XCTAssertFalse(EmailAuthRules.validEmail(value)) }
        XCTAssertEqual(EmailAuthRules.sanitizeCode("１２12x3-4567"), "123456")
        XCTAssertFalse(EmailAuthRules.validCode("１２３４５６"))
        XCTAssertTrue(EmailAuthRules.validPassword(String(repeating: "a", count: 72)))
        XCTAssertFalse(EmailAuthRules.validPassword(String(repeating: "a", count: 73)))
    }
    func testEmailEndpointsNeverAttachAuthAndResetUsesNewPassword() throws {
        let requests = try [Endpoint.emailCheck("a@b.co"), Endpoint.emailCode("a@b.co"), Endpoint.emailVerify("a@b.co", code: "123456"), Endpoint.emailLogin("a@b.co", password: "secret"), Endpoint.emailReset("a@b.co", code: "123456", password: "newsecret")]
        XCTAssertTrue(requests.allSatisfy { !$0.requiresAuth && $0.method == .post })
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: requests.last!.body!) as? [String: String])
        XCTAssertEqual(json["newPassword"], "newsecret"); XCTAssertNil(json["password"])
    }
    func testInvitationReplacementClearsDatesAndUsesOptimisticVersion() throws {
        var draft = InvitationRules.draft(); draft.weddingDate = nil; draft.weddingTime = nil; draft.updatedAt = "version-7"
        let data = try JSONEncoder().encode(InvitationWriteRequest(content: draft, createOnly: false))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertTrue(json["weddingDate"] is NSNull); XCTAssertTrue(json["weddingTime"] is NSNull)
        XCTAssertEqual(json["baseUpdatedAt"] as? String, "version-7"); XCTAssertNil(json["createOnly"])
    }
    func testInvitationNormalizationPreservesOrderAndAddsHiddenMissingSections() {
        var design = InvitationRules.design()
        design.sections = [.init(type: "gallery", visible: true),.init(type: "gallery", visible: false),.init(type: "unknown", visible: true)]
        design.accounts = [.init(side: "groom", role: "신랑", number: "123가４56-7")]
        let normalized = InvitationRules.normalize(design)
        XCTAssertEqual(normalized.sections.count, 8); XCTAssertEqual(normalized.sections.first?.type, "gallery")
        XCTAssertEqual(normalized.sections.filter(\.visible).count, 1)
        XCTAssertEqual(normalized.accounts.count, 6); XCTAssertEqual(normalized.accounts.first?.number, "12356-7")
    }
    func testUnknownInvitationStateNeverShowsPurchase() {
        XCTAssertEqual(InvitationRules.studioState(loaded: false, failed: false, hasInvitation: false, canEdit: false), .loading)
        XCTAssertEqual(InvitationRules.studioState(loaded: true, failed: true, hasInvitation: false, canEdit: false), .error)
        XCTAssertEqual(InvitationRules.studioState(loaded: true, failed: false, hasInvitation: true, canEdit: true), .mine)
    }
    func testGuestWalksDownAisleToAssignedSeat() {
        let e = SeasideEngine(wishes: [.init(id: "a", name: "지은", avatar: 2)])
        XCTAssertFalse(e.actors[0].visible)
        advance(e, 1); XCTAssertEqual(e.actors[0].phase, .enter)
        XCTAssertEqual(e.actors[0].x, 155, accuracy: 0.001)
        advance(e, 9); XCTAssertEqual(e.actors[0].phase, .stand)
        XCTAssertEqual(e.actors[0].x, 58, accuracy: 0.01)
        XCTAssertEqual(e.actors[0].y, 324, accuracy: 0.01)
    }
    func testFallStartsAboveScreenThenDustCompressionBounceAndWave() {
        let e = SeasideEngine(); e.skyAbove = 160
        e.enter(.init(id: "drop", name: "하객", avatar: 7), drop: true, quiet: true)
        let a = e.actors[0]
        XCTAssertLessThan(a.top, -160); XCTAssertTrue(a.flying)
        advance(e, 0.85); let mid = a.top
        XCTAssertGreaterThan(mid, -200); XCTAssertLessThan(mid, a.homeY - 72 * a.scale)
        advance(e, 0.74)
        XCTAssertFalse(a.flying); XCTAssertEqual(e.particles.count, 6)
        XCTAssertGreaterThan(a.width, 48 * a.scale); XCTAssertLessThan(a.height, 72 * a.scale)
        advance(e, 0.14); XCTAssertGreaterThan(a.lift, 0)
        advance(e, 0.2); XCTAssertNil(a.arrival); XCTAssertEqual(a.mode, .wave)
    }
    func testManualSpeechStaysUntilClosedAndEmptyCoupleIsSilent() {
        let e = SeasideEngine(quietCouple: true)
        advance(e, 10); XCTAssertNil(e.speech)
        e.showSpeech(e.actors[8], manual: true); advance(e, 12); XCTAssertNotNil(e.speech)
        e.closeSpeech(); XCTAssertNil(e.speech)
    }
    func testClockClampsResumeGap() {
        let e = SeasideEngine(); e.update(100)
        XCTAssertEqual(e.time, 0.05, accuracy: 0.0001)
    }
    func testInvitationToleratesInvalidLegacyDesignFieldsWithoutLosingValidSections() throws {
        let raw = #"{"design":{"sections":[null,3,{"type":"message","visible":true},{"type":"couple","visible":"bad"}],"couple":{"groomFather":42},"accounts":[false,{"side":"groom","role":"신랑","number":"12-34","bank":"은행"}]}}"#
        let content = try JSONDecoder().decode(InvitationContent.self, from: Data(raw.utf8))
        let design = InvitationRules.normalize(content.design)
        XCTAssertTrue(design.sections[0].visible); XCTAssertFalse(design.sections[1].visible)
        XCTAssertEqual(design.couple.groomFather, ""); XCTAssertEqual(design.couple.groomRelation, "아들")
        XCTAssertEqual(design.accounts[0].number, "12-34")
        let invalid = try JSONDecoder().decode(InvitationContent.self, from: Data(#"{"design":false}"#.utf8))
        XCTAssertEqual(InvitationRules.normalize(invalid.design), InvitationRules.design())
        var draft = InvitationRules.draft(); draft.weddingDate = "2026-02-30"
        XCTAssertNil(InvitationRules.sanitize(draft).weddingDate)
    }
    private func advance(_ engine: SeasideEngine, _ seconds: Double) {
        var remaining = seconds
        while remaining > 0.000001 { let dt = min(0.01, remaining); engine.update(dt); remaining -= dt }
    }
}
