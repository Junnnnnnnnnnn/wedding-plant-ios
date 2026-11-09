import SwiftUI
import WPDomain
import WPModels
import WPNetworking
import WPUtils

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
    /// `새 축하 N`(청첩장 칸에서 본 뒤로 늘어난 축하 수). 홈은 카드에, 칸은 정원 아래 줄에 — 칸은 시트를 열면 0
    @Published var fresh = 0
    /// 청첩장 칸이면 받은 하객 수를 "본 것" 으로 적고, 홈이면 그 수와 비교한다(Android `InvitationStudioViewModel` · `HomeInvitationViewModel`)
    let marksSeen: Bool
    init(marksSeen: Bool = false) { self.marksSeen = marksSeen }
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
            if state == .empty {
                let endpoint = result?.roomId.map { Endpoint.room(shareCode: String($0)) } ?? Endpoint.user()
                // 받은 뒤에 바꾼다 — 먼저 비우면 다시 받는 사이 빈 정원의 날짜 · 예식장 칸이 잠깐 빈칸으로 깜빡였다
                if let plan = try? await env.api.send(endpoint, decoding: PlanUser.self) {
                    planDate = plan.weddingDate.map { String($0.prefix(10)) }
                    let venue = plan.weddingVenue?.trimmingCharacters(in: .whitespacesAndNewlines)
                    planVenue = venue?.isEmpty == true ? nil : venue
                }
            } else { planDate = nil; planVenue = nil }
            if let invitation = result?.invitation, invitation.published,
               InvitationRules.normalize(invitation.design).sections.contains(where: { $0.type == "guestbook" && $0.visible }) {
                do {
                    let page: InvitationGuestbook = try await env.api.send(Endpoint.invitationGuestbook(slug: invitation.slug))
                    wishes = page.wishes; total = page.total ?? page.wishes.count
                    await countFresh(env)
                } catch { if !error.isCancellation { total = nil; fresh = 0 } }
            } else { wishes = []; total = nil; fresh = 0 }
        } catch { if !error.isCancellation { self.error = error.localizedDescription } }
    }
    /// 칸이면 지금 수를 본 것으로 적는다. 홈은 본 수와 빼고, 이 기기에서 처음이면 지금 수를 기준으로 삼아 0 —
    /// 이미 칸에서 다 읽은 사람에게 새 축하를 지어내지 않는다. 홈이 다시 앞으로 올 때(칸에서 읽고 돌아옴)도 부른다.
    func countFresh(_ env: AppEnvironment) async {
        guard let slug = result?.invitation?.slug, let total,
              let account = await env.tokenStore.currentToken().flatMap({ JWTDecoder.planUserId(from: $0) }) else { fresh = 0; return }
        if marksSeen {
            // 칸에서는 정원 아래 줄에 이번에 처음 보는 수를 한 번 보여 준 뒤 본 것으로 적는다 — 홈의 `새 축하` 는 칸에 들른 순간
            // 0 이 되어야 해서(안드로이드와 같은 기준) 적는 시점은 그대로 두고, 줄의 배지는 시트를 열 때 지운다(`clearFresh`).
            let seen = InvitationSeenStore.seen(account: account, slug: slug)
            InvitationSeenStore.markSeen(account: account, slug: slug, total: total)
            fresh = max(fresh, InvitationRules.freshWishes(total: total, seen: seen))
        } else {
            let seen = InvitationSeenStore.seen(account: account, slug: slug) ?? {
                InvitationSeenStore.markSeen(account: account, slug: slug, total: total)
                return total
            }()
            fresh = InvitationRules.freshWishes(total: total, seen: seen)
        }
    }
    func clearFresh() { fresh = 0 }
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
    @StateObject private var model = InvitationStore(marksSeen: true)
    private struct EditTarget: Identifiable { let id: String }
    @State private var editTarget: EditTarget?
    @State private var preview = false
    @State private var headerHeight: CGFloat = 170
    @State private var pass = false
    @State private var guestbook = false
    @State private var summon: GardenSummon?
    private var published: Bool { model.result?.invitation?.published == true }
    private var guestbookOn: Bool { model.result?.invitation.map { InvitationRules.normalize($0.design).sections.contains { $0.type == "guestbook" && $0.visible } } ?? false }
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { reader in
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
                            emptySeats: model.state == .mine && InvitationRules.mineEmptySeats(published: published, guestbookOn: guestbookOn, guests: model.total), motionEnabled: motionEnabled,
                            summon: summon)
                            .frame(height: min(geometry.size.width * 440 / 320, max(360, geometry.size.height - headerHeight - 12)))
                            .id(model.state == .landing ? "landing" : model.state == .empty ? "empty" : "mine")
                        Color.clear.frame(height: 0).id("gardenTop")
                        if model.state == .mine { guestbookRow.padding(.horizontal, 16).padding(.top, 14) }
                        details.padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 32)
                    }
                }
            }.background(.white)
                .refreshable { await model.load(env) }
                .onChange(of: summon) { _, value in
                    // 정원이 화면 위에 보이도록 — 줄을 누른 자리는 정원 아래라 내려와 있다
                    guard value != nil else { return }
                    withAnimation(.easeInOut(duration: 0.3)) { reader.scrollTo(model.state == .mine ? "mine" : "gardenTop", anchor: .top) }
                }
            }
        }.ignoresSafeArea(edges: .top).font(.custom("KakaoSmallSans-Regular", size: 14))
            .task { await model.load(env) }
            .fullScreenCover(item: $editTarget, onDismiss: { Task { await model.load(env) } }) { target in
                InvitationEditorView(saved: model.result?.invitation, roomId: model.result?.roomId, initialFocus: target.id, planDate: model.planDate, planVenue: model.planVenue)
            }
            .fullScreenCover(isPresented: $preview) {
                // 안드로이드 `StudioPreviewDialog` — 내 청첩장은 "하객이 보는 청첩장"(공개 전이면 안내 한 줄), 예시는 "예시 청첩장"
                if let saved = model.result?.invitation {
                    InvitationPreviewView(content: saved, title: "하객이 보는 청첩장", notice: saved.published ? nil : "아직 공개하지 않았어요",
                                          guestbookWishes: saved.published && guestbookOn && model.total != nil ? model.wishes : nil)
                } else {
                    InvitationPreviewView(content: Self.example, title: "예시 청첩장")
                }
            }
            .sheet(isPresented: $guestbook) {
                InvitationGuestbookSheet(onChanged: { Task { await model.load(env) } },
                                         onMeet: { wish in summon = GardenSummon(wish: wish, serial: (summon?.serial ?? 0) + 1) })
            }
            .passCover(isPresented: $pass, onPassChanged: { Task { await model.load(env); await env.refreshAdEligibility() } }) { PassView(roomId: model.result?.roomId, staysAfterPurchase: true) }
    }
    /// 정원 바로 아래 `축하 글 N개 [새 K] · 전체 보기 ›` + 가장 늦은 글 한 줄(시안 ①).
    /// 공개 전에는 하객 글이 있을 수 없어 열지 않는다 — 아래 `InvitationSavedDetails` 의 안내가 이유를 말한다.
    private var guestbookRow: some View {
        let openable = InvitationRules.guestbookOpenable(published: published)
        let latest = InvitationRules.homeLatestWish(model.wishes.map { ($0.name, $0.message, $0.createdAt) })
        return Button { model.clearFresh(); guestbook = true } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(InvitationRules.guestbookRowTitle(total: model.total ?? (published ? nil : 0)))
                        .font(.custom("KakaoSmallSans-Bold", size: 14)).foregroundStyle(WPColor.primary)
                    if model.fresh > 0 {
                        Text("새 \(model.fresh)").font(.custom("KakaoSmallSans-Bold", size: 11)).foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 1).background(WPColor.primary, in: Capsule())
                    }
                    Spacer()
                    if openable { Text("전체 보기 ›").font(.custom("KakaoSmallSans-Regular", size: 13)).foregroundStyle(WPColor.stone600) }
                }
                Text(latest.map { "\($0.name) · \"\($0.message)\"" } ?? InvitationRules.guestbookEmpty)
                    .font(.custom("KakaoSmallSans-Regular", size: 12)).foregroundStyle(WPColor.stone500).lineLimit(1)
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: 0xFFF4F9), in: RoundedRectangle(cornerRadius: 12)).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(!openable).accessibilityIdentifier("invitation.guestbookRow")
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
