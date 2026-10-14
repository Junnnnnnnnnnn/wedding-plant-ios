import Testing
@testable import WPDomain

struct HomeInvitationGateTests {
    @Test func unpaidNeverShowsGardenEvenWithExistingInvitation() {
        for hasInvitation in [false, true] {
            #expect(InvitationRules.homeState(loaded: true, failed: false, hasPass: false, hasInvitation: hasInvitation) == .landing)
        }
        // Existing invitations remain accessible in the studio after the pass expires.
        #expect(InvitationRules.studioState(loaded: true, failed: false, hasInvitation: true, canEdit: true) == .mine)
    }
    @Test func activePassAndKnownStateAreBothRequired() {
        #expect(InvitationRules.homeState(loaded: true, failed: false, hasPass: true, hasInvitation: false) == .empty)
        #expect(InvitationRules.homeState(loaded: true, failed: false, hasPass: true, hasInvitation: true) == .mine)
        #expect(InvitationRules.homeState(loaded: false, failed: false, hasPass: true, hasInvitation: true) == .loading)
        #expect(InvitationRules.homeState(loaded: true, failed: true, hasPass: true, hasInvitation: true) == .error)
    }
}
