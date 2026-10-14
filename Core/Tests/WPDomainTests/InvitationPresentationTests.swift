import Testing
import WPModels
@testable import WPDomain

struct InvitationPresentationTests {
    @Test func allEditorDestinationsRemainAvailableIncludingHiddenSections() {
        var content = InvitationRules.draft()
        content.design?.sections.reverse()
        let items = InvitationRules.studioItems(content)
        #expect(items.map(\.key) == ["mood", "intro", "cover"] + InvitationRules.sectionTypes.reversed())
        #expect(items.first { $0.key == "notice" }?.visible == false)
        #expect(items.first { $0.key == "notice" }?.note == "꺼 둠")
    }
    @Test func namesAloneDoNotClaimCoverPhotoIsFilled() {
        var content = InvitationRules.draft(); content.groom = "신랑"; content.bride = "신부"
        #expect(InvitationRules.studioItems(content).first { $0.key == "cover" }?.filled == false)
        content.photos = [.init(key: "photo")]
        #expect(InvitationRules.studioItems(content).first { $0.key == "cover" }?.filled == true)
    }
    @Test func dateAndReadyAccountSummariesMatchAndroid() {
        var content = InvitationRules.draft(); content.weddingDate = "2026-11-14"; content.weddingTime = "13:00"
        #expect(InvitationRules.invitationDateLabel(content) == "2026년 11월 14일 토요일 오후 1시")
        content.design?.accounts[0].bank = "국민"
        #expect(InvitationRules.sectionSummary("accounts", content: content) == "계좌를 적어 주세요")
        content.design?.accounts[0].number = "123-456"
        #expect(InvitationRules.sectionSummary("accounts", content: content) == "계좌 1곳")
    }
}
