import SwiftUI
import WPDomain
import WPModels
import WPNetworking

@MainActor final class InvitationStore: ObservableObject {
    @Published var result: MyInvitation?
    @Published var error: String?
    @Published var busy = false
    @Published var wishes: [InvitationWish] = []
    @Published var total: Int?
    @Published var planDate: String?
    @Published var planVenue: String?
    /// 공개·비공개 뒤의 한 줄 — 안드로이드 `InvitationRules.PUBLISHED_NOTE` · `UNPUBLISHED_NOTE`
    @Published var shareNote: String?
    var state: InvitationRules.StudioState {
        InvitationRules.studioState(loaded: result != nil, failed: error != nil && result == nil, hasInvitation: result?.invitation != nil, canEdit: result?.canEdit == true)
    }
    var homeState: InvitationRules.StudioState {
        InvitationRules.homeState(loaded: result != nil, failed: error != nil && result == nil,
                                 hasInvitation: result?.invitation != nil, canEdit: result?.canEdit == true)
    }
    func load(_ env: AppEnvironment) async {
        error = nil; shareNote = nil
        do {
            result = try await env.api.send(Endpoint.myInvitation())
            planDate = nil; planVenue = nil
            if state == .empty {
                let endpoint = result?.roomId.map { Endpoint.room(shareCode: String($0)) } ?? Endpoint.user()
                if let plan = try? await env.api.send(endpoint, decoding: PlanUser.self) {
                    planDate = plan.weddingDate.map { String($0.prefix(10)) }
                    planVenue = plan.weddingVenue?.trimmingCharacters(in: .whitespacesAndNewlines)
                    if planVenue?.isEmpty == true { planVenue = nil }
                }
            }
            if let invitation = result?.invitation, invitation.published,
               InvitationRules.normalize(invitation.design).sections.contains(where: { $0.type == "guestbook" && $0.visible }) {
                do {
                    let page: InvitationGuestbook = try await env.api.send(Endpoint.invitationGuestbook(slug: invitation.slug))
                    wishes = page.wishes; total = page.total ?? page.wishes.count
                } catch { total = nil }
            } else { wishes = []; total = nil }
        } catch { self.error = error.localizedDescription }
    }
    func publish(_ published: Bool, env: AppEnvironment) async {
        guard !busy, var content = result?.invitation else { return }
        busy = true; error = nil; shareNote = nil; defer { busy = false }
        content.published = published
        do {
            result = try await env.api.send(Endpoint.saveInvitation(.init(content: InvitationRules.sanitize(content), createOnly: false)))
            shareNote = published ? "공개했어요. 이제 링크를 받은 사람은 누구나 볼 수 있어요." : "비공개로 돌렸어요. 링크로 열면 없는 청첩장으로 보여요."
        } catch { shareNote = error.localizedDescription }
    }
}

struct InvitationStudioView: View {
    var titleSlot: AnyView? = nil
    var motionEnabled = true
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var model = InvitationStore()
    private struct EditTarget: Identifiable { let id: String }
    @State private var editTarget: EditTarget?
    @State private var preview = false
    @State private var headerHeight: CGFloat = 170
    @State private var pass = false
    private var published: Bool { model.result?.invitation?.published == true }
    private var guestbookOn: Bool { model.result?.invitation.map { InvitationRules.normalize($0.design).sections.contains { $0.type == "guestbook" && $0.visible } } ?? false }
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    ExploreHead(switcher: titleSlot ?? AnyView(Text("모바일 청첩장").font(WPFont.hak(18, .bold)).foregroundStyle(.white)), headline: "모바일 청첩장", stats: studioStats, loading: false) { EmptyView() }
                        .background(GeometryReader { head in
                            Color.clear.onAppear { headerHeight = head.size.height }.onChange(of: head.size.height) { _, value in headerHeight = value }
                        })
                    Color.clear.frame(height: 12)
                    switch model.state {
                    case .loading: ProgressView().frame(height: 400)
                    case .error:
                        VStack(spacing: 16) {
                            Text(model.error ?? "청첩장을 불러오지 못했어요.")
                            Button("다시 시도") { Task { await model.load(env) } }
                        }.padding(32)
                    case .landing, .empty, .mine:
                        SeasideGardenView(wishes: model.wishes, demo: model.state == .landing, empty: model.state == .empty,
                            groom: model.result?.invitation?.groom ?? InvitationRules.exampleGroom, bride: model.result?.invitation?.bride ?? InvitationRules.exampleBride,
                            script: model.state == .mine ? InvitationRules.mineLines(published: published, guestbookOn: guestbookOn, guests: model.total) : nil,
                            labelNote: model.state == .mine ? InvitationRules.mineLabelNote(published: published, guests: model.total) : nil,
                            emptySeats: model.state == .mine && InvitationRules.mineEmptySeats(published: published, guestbookOn: guestbookOn, guests: model.total), motionEnabled: motionEnabled)
                            .frame(height: min(geometry.size.width * 440 / 320, max(360, geometry.size.height - headerHeight - 12)))
                            .id(model.state == .landing ? "landing" : model.state == .empty ? "empty" : "mine")
                        details.padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 32)
                    }
                }
            }.background(.white)
                .refreshable { await model.load(env) }
        }.ignoresSafeArea(edges: .top).font(.custom("KakaoSmallSans-Regular", size: 14))
            .task { await model.load(env) }
            .fullScreenCover(item: $editTarget, onDismiss: { Task { await model.load(env) } }) { target in
                InvitationEditorView(saved: model.result?.invitation, roomId: model.result?.roomId, initialFocus: target.id, planDate: model.planDate, planVenue: model.planVenue)
            }
            .fullScreenCover(isPresented: $preview) {
                // 안드로이드 `StudioPreviewDialog` — 내 청첩장은 "하객이 보는 청첩장"(공개 전이면 안내 한 줄), 예시는 "예시 청첩장"
                if let saved = model.result?.invitation {
                    InvitationPreviewView(content: saved, title: "하객이 보는 청첩장", notice: saved.published ? nil : "아직 공개하지 않았어요")
                } else {
                    InvitationPreviewView(content: Self.example, title: "예시 청첩장")
                }
            }
            .fullScreenCover(isPresented: $pass, onDismiss: { Task { await model.load(env); await env.refreshAdEligibility() } }) { PassView(roomId: model.result?.roomId, staysAfterPurchase: true) }
    }
    private var studioStats: [(String, String)] {
        guard let saved = model.result?.invitation else { return [] }
        return [("청첩장", saved.published ? "공개 중" : "공개 전"), ("하객", model.total.map { "\($0)명" } ?? "—"), ("사진", "\(saved.photos.count)장")]
    }
    @ViewBuilder private var details: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let saved = model.result?.invitation {
                InvitationSavedDetails(content: saved, total: model.total, canEdit: model.result?.canEdit == true, busy: model.busy,
                    onEdit: { editTarget = .init(id: $0) },
                    // 안드로이드처럼 묻지 않고 바로 바꾸고, 결과는 칸 아래 한 줄로 알립니다
                    onPublish: { Task { await model.publish(model.result?.invitation?.published != true, env: env) } },
                    onPreview: { preview = true }, shareNote: model.shareNote)
            } else {
                InvitationLandingDetails(empty: model.state == .empty, planDate: model.planDate, planVenue: model.planVenue,
                    onEdit: { editTarget = .init(id: $0) }, onPass: { pass = true }, onExample: { preview = true })
            }
        }.foregroundStyle(Color(hex: 0x173C2F))
    }
    static var example: InvitationContent {
        var result = InvitationRules.draft(); result.groom = InvitationRules.exampleGroom; result.bride = InvitationRules.exampleBride
        result.title = "우리의 계절이 피어나는 날"
        result.message = "서로의 계절이 되어 주기로 했습니다.\n봄의 설렘과 여름의 다정함으로\n오래도록 나란히 걷겠습니다.\n그 첫걸음에 함께해 주세요."
        result.weddingDate = "2027-05-22"; result.weddingTime = "13:00"; result.venue = "웨딩플랜트 가든홀"
        result.photos = [.init(key: "showcase-portrait", url: Bundle.main.url(forResource: "invitation_showcase_portrait", withExtension: "png")?.absoluteString)]
        result.design?.sections = InvitationRules.sectionTypes.map { .init(type: $0, visible: true) }
        result.design?.couple = .init(groomFather: "정민호", groomMother: "이수정", groomRelation: "아들", brideFather: "한상우", brideMother: "오지혜", brideRelation: "딸")
        result.design?.location.guide = "지하철을 타고 오시면 역에서 걸어서 5분이에요.\n건물 지하 주차장을 2시간 무료로 쓰실 수 있어요."
        result.design?.notice.title = "안내 말씀"
        result.design?.notice.body = "예식이 끝나면 2층 연회장에서 식사를 준비했어요.\n화환은 정중히 사양합니다. 마음만 감사히 받을게요."
        for (index, name) in [InvitationRules.exampleGroom, "정민호", "이수정", InvitationRules.exampleBride, "한상우", "오지혜"].enumerated() where index < (result.design?.accounts.count ?? 0) { result.design?.accounts[index].name = name }
        return result
    }

}
struct InvitationActionStyle: ButtonStyle {
    var primary = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.custom("KakaoSmallSans-Bold", size: 15)).frame(maxWidth: .infinity).frame(minHeight: 52)
            .foregroundStyle(primary ? Color(hex: 0xFBF8ED) : Color(hex: 0x173C2F))
            .background(primary ? Color(hex: 0x173C2F) : Color(hex: 0xF4F2E9), in: RoundedRectangle(cornerRadius: 6))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
