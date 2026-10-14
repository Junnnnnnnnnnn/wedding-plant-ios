import SwiftUI
import WPModels
import WPDomain
import WPUtils

struct InvitationPreviewView: View {
    let content: InvitationContent
    var embedded = false
    var onSelect: ((String) -> Void)? = nil
    var selectedSection: String? = nil
    var bottomInset: CGFloat = 0
    var motionEnabled = true
    var onCoverPhoto: (() -> Void)? = nil
    var onAddPhotos: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var started: Date? = nil
    @State private var replayID = 0
    @State private var toast: String?
    @State private var photoIndex: Int?
    private var design: InvitationDesignBody { InvitationRules.normalize(content.design) }
    private var palette: InvitationPalette { .init(content.template) }
    private var forest: Color { palette.forest }
    private var paper: Color { palette.paper }
    var body: some View {
        VStack(spacing: 0) {
            if !embedded {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("미리보기 닫기")
                    Spacer()
                    Text("하객이 보는 화면").font(.custom("KakaoSmallSans-Bold", size: 14))
                    Spacer()
                    Button { replayID += 1 } label: { Label("처음부터", systemImage: "arrow.counterclockwise").font(.custom("KakaoSmallSans-Bold", size: 12)) }.frame(minHeight: 44).accessibilityIdentifier("invitation.replay")
                }.padding(.horizontal, 12).frame(height: 56).foregroundStyle(forest).background(Color(hex: 0xFFFDF9))
                Divider()
            }
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            InvitationHero(content: content, height: max(320, geometry.size.height + bottomInset), started: design.intro == "door" ? started : nil,
                                replay: { replayID += 1 }, share: shareNotice, edit: embedded ? { onCoverPhoto?() } : nil, selected: selectedSection == "cover")
                                .overlay(alignment: .bottom) { Color.clear.frame(height: 200).id("moodAnchor").allowsHitTesting(false) }.modifier(InvitationEditSelection(enabled: embedded, selected: selectedSection == "cover", showsBadge: false)).id("cover").contentShape(Rectangle()).onTapGesture { onSelect?("cover") }
                            ForEach(design.sections.filter { $0.visible && (embedded || hasContent($0.type)) }, id: \.type) { section in
                                sectionView(section.type).modifier(InvitationEditSelection(enabled: embedded, selected: selectedSection == section.type)).id(section.type).contentShape(Rectangle()).onTapGesture { onSelect?(section.type) }
                            }
                            footer
                        }.foregroundStyle(palette.ink)
                    }.background(paper)
                        .onChange(of: selectedSection) { _, value in
                            if let value { proxy.scrollTo(["mood", "intro"].contains(value) ? "moodAnchor" : value == "gallery" ? "galleryGrid" : value, anchor: .top) }
                        }
                        .task { if let selectedSection { try? await Task.sleep(for: .milliseconds(150)); proxy.scrollTo(["mood", "intro"].contains(selectedSection) ? "moodAnchor" : selectedSection == "gallery" ? "galleryGrid" : selectedSection, anchor: .top) } }
                        .onChange(of: replayID) { _, _ in proxy.scrollTo("cover", anchor: .top); started = Date() }
                }
            }
        }.background(paper).ignoresSafeArea(.container, edges: .bottom).overlay(alignment: .bottom) {
            if let toast { Text(toast).wpTypography(12, face: .kakao, lineHeight: 18).padding(14).foregroundStyle(.white).background(.black.opacity(0.8), in: Capsule()).padding(24) }
        }.onAppear { started = embedded ? nil : Date() }
            .task(id: toast) { guard toast != nil else { return }; try? await Task.sleep(for: .seconds(2.5)); if !Task.isCancelled { toast = nil } }
            .fullScreenCover(isPresented: Binding(get: { photoIndex != nil }, set: { if !$0 { photoIndex = nil } })) {
                photoViewer
            }
    }
    private func shareNotice() { toast = "저장하고 공개하면 링크로 보낼 수 있어요" }
    private func hasContent(_ type: String) -> Bool {
        switch type {
        case "message": return !content.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case "gallery": return !content.photos.isEmpty
        case "calendar": return content.weddingDate.flatMap { KstDate(dateString: $0) } != nil
        case "location": return !content.venue.isEmpty
        case "notice": return !design.notice.body.isEmpty
        case "accounts": return design.accounts.contains { !$0.bank.isEmpty && !$0.number.isEmpty }
        default: return true
        }
    }
    private var footer: some View {
        VStack(spacing: 0) {
            InvitationFlower().stroke(palette.gold, lineWidth: 1).frame(width: 30, height: 30).frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(height: 24)
            VStack(spacing: 0) {
                Text("Love grows").font(.custom("NotoSerif", size: 56)).foregroundStyle(palette.ink)
                Text("with you.").font(.custom("NotoSerif-Italic", size: 56)).foregroundStyle(palette.gold)
            }.tracking(-2).padding(.bottom, 24)
            Text("우리의 시작을 함께해 주셔서 고맙습니다.").wpTypography(11, face: .kakao, lineHeight: 19.8).foregroundStyle(palette.muted).padding(.bottom, 28)
            Button(action: shareNotice) { Label("청첩장 전하기", systemImage: "square.and.arrow.up").wpTypography(12, face: .kakao, lineHeight: 18).frame(maxWidth: .infinity).frame(height: 48).overlay(Rectangle().stroke(palette.rule)) }.padding(.bottom, 12)
            Button { replayID += 1 } label: { Label("문 열림 다시 보기", systemImage: "arrow.counterclockwise").wpTypography(10, face: .kakao, lineHeight: 15).frame(minHeight: 44) }.foregroundStyle(palette.muted)
            Rectangle().fill(palette.rule).frame(height: 1).padding(.top, 40).padding(.bottom, 24)
            VStack(spacing: 8) {
                Text("MADE WITH LOVE").wpTypography(7, face: .kakao, lineHeight: 10.5).tracking(2)
                Text("WEDDING PLANT").wpTypography(9, face: .kakao, lineHeight: 13.5).tracking(3)
            }.foregroundStyle(palette.muted)
        }.padding(.horizontal, 32).padding(.top, 64).padding(.bottom, 24)
    }
    private var photoViewer: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: Binding(get: { photoIndex ?? 0 }, set: { photoIndex = $0 })) {
                ForEach(Array(content.photos.enumerated()), id: \.offset) { index, photo in
                    if let url = photo.url.flatMap(URL.init(string:)) {
                        InvitationPhotoImage(url: url, mode: .fit).tag(index)
                    }
                }
            }.tabViewStyle(.page)
            Button { photoIndex = nil } label: { Image(systemName: "xmark").foregroundStyle(.white).padding(20) }.accessibilityLabel("사진 닫기")
        }
    }
    @ViewBuilder private func sectionView(_ type: String) -> some View {
        switch type {
        case "message":
            VStack(spacing: 18) {
                eyebrow("INVITATION")
                Text(content.message.isEmpty ? "초대의 말을 적으면 여기에 보여요" : content.message).wpTypography(15, face: .kakao, lineHeight: 30).padding(.vertical, -4).multilineTextAlignment(.center)
                Text("\(content.groom) · \(content.bride)").wpTypography(12, face: .kakao, lineHeight: 18).tracking(1).foregroundStyle(palette.muted)
            }.frame(maxWidth: .infinity).padding(.horizontal, 32).padding(.top, 56).padding(.bottom, 48)
        case "couple":
            VStack(spacing: 12) {
                eyebrow("THE COUPLE")
                Text("저희 두 사람이 결혼합니다").wpTypography(17, face: .kakao, lineHeight: 25.5)
                Color.clear.frame(height: 8)
                HStack(alignment: .top, spacing: 0) {
                    person(role: "신랑", name: content.groom, parents: [design.couple.groomFather, design.couple.groomMother], relation: design.couple.groomRelation)
                    Rectangle().fill(palette.rule).frame(width: 1, height: 88).overlay(alignment: .top) { Image(systemName: "heart.fill").font(.system(size: 12)).foregroundStyle(palette.gold).padding(.vertical, 2).background(palette.soft).offset(y: 30) }
                    person(role: "신부", name: content.bride, parents: [design.couple.brideFather, design.couple.brideMother], relation: design.couple.brideRelation)
                }
            }.padding(.horizontal, 24).padding(.top, 56).padding(.bottom, 52).background(palette.soft)
        case "gallery": InvitationGallery(content: content, editing: embedded, select: { index in
            if embedded { onSelect?("gallery") } else { photoIndex = index }
        }, add: { onAddPhotos?() })
        case "calendar": InvitationCalendar(content: content, palette: palette)
        case "location": InvitationLocation(content: content, editing: embedded, toast: { toast = $0 })
        case "notice":
            VStack(spacing: 14) {
                eyebrow("NOTICE")
                Text(design.notice.title.isEmpty ? "안내 말씀" : design.notice.title).wpTypography(18, face: .kakao, lineHeight: 27).tracking(-0.4)
                Text(design.notice.body.isEmpty ? "알릴 내용을 적으면 여기에 보여요" : design.notice.body).wpTypography(13, face: .kakao, lineHeight: 24.7).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity).padding(.horizontal, 32).padding(.top, 52).padding(.bottom, 48).background(palette.soft)
        case "accounts": InvitationAccounts(content: content, editing: embedded, toast: { toast = $0 })
        case "guestbook": InvitationGuestbookSection(content: content, editing: embedded, motionEnabled: motionEnabled, toast: { toast = $0 })
        default: EmptyView()
        }
    }
    private func eyebrow(_ text: String) -> some View { Text(text).wpTypography(9, face: .kakao, lineHeight: 13.5).tracking(3).foregroundStyle(palette.muted) }
    private func person(role: String, name: String, parents: [String], relation: String) -> some View {
        VStack(spacing: 8) {
            Text(role).wpTypography(10, face: .kakao, lineHeight: 15).tracking(2).foregroundStyle(palette.gold)
            Text(name.isEmpty ? role : name).wpTypography(22, face: .kakao, lineHeight: 33).tracking(1)
            if parents.contains(where: { !$0.isEmpty }) { Text(parents.filter { !$0.isEmpty }.joined(separator: " · ") + "의 " + relation).wpTypography(11, face: .kakao, lineHeight: 16.5).foregroundStyle(palette.muted) }
        }.frame(maxWidth: .infinity).padding(.horizontal, 12).padding(.vertical, 4)
    }
    private func block<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 24) {
            Text(title).font(.custom("KakaoSmallSans-Bold", size: 24)); content()
        }.wpTypography(15, face: .kakao, lineHeight: 22.5).frame(maxWidth: .infinity).padding(.horizontal, 24).padding(.vertical, 48)
    }
}
