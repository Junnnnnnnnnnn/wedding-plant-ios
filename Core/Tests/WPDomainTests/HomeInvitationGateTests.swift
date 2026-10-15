import Testing
@testable import WPDomain

/// Android `HomeInvitationRulesTest` 와 같은 판정 — 홈은 청첩장 칸과 같은 답을 냅니다.
struct HomeInvitationGateTests {
    @Test func existingInvitationShowsGardenEvenAfterPassEnds() {
        // 패스가 끝나도 청첩장은 남으므로 홈도 정원 카드(mine)
        #expect(InvitationRules.homeState(loaded: true, failed: false, hasInvitation: true, canEdit: false) == .mine)
        #expect(InvitationRules.homeState(loaded: true, failed: false, hasInvitation: true, canEdit: true) == .mine)
    }
    @Test func withoutInvitationPassDecides() {
        #expect(InvitationRules.homeState(loaded: true, failed: false, hasInvitation: false, canEdit: false) == .landing)
        #expect(InvitationRules.homeState(loaded: true, failed: false, hasInvitation: false, canEdit: true) == .empty)
    }
    @Test func unknownShowsNothing() {
        #expect(InvitationRules.homeState(loaded: false, failed: false, hasInvitation: true, canEdit: true) == .loading)
        #expect(InvitationRules.homeState(loaded: false, failed: true, hasInvitation: true, canEdit: true) == .error)
    }
    @Test func homeMatchesStudio() {
        for inv in [false, true] { for edit in [false, true] {
            #expect(InvitationRules.homeState(loaded: true, failed: false, hasInvitation: inv, canEdit: edit)
                == InvitationRules.studioState(loaded: true, failed: false, hasInvitation: inv, canEdit: edit))
        } }
    }
}
