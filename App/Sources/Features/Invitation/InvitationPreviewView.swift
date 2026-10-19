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
    /// 편집기 전용 — 꺼 둔 칸 칩(안드로이드 `HiddenSections`)을 누르면 켜고 그 칸을 엽니다
    var onTurnOn: ((String) -> Void)? = nil
    /// 편집기 전용 — 아래 패널·단추 높이만큼 비워 마지막 칸도 패널 위로 올라오게(안드로이드 `bottomSpace + 24`)
    var bottomSpace: CGFloat = 0
    /// 편집기 전용 — 지금 적고 있는 줄(예: 계좌 `account.3`). 키보드가 올라오면 미리보기에 남는 자리가 한 뼘이라
    /// 칸 머리만 보였습니다 — 그 줄을 미리보기 맨 위로 올려 적는 대로 바뀌는 것이 보이게 합니다.
    var focusAnchor: String? = nil
    /// 머리 제목·안내 — 안드로이드 `GuestPreview(title, notice)`
    var title = "하객이 보는 화면"
    var notice: String? = nil
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
                // 안드로이드 `GuestPreview` 머리 — x 20 ink · 제목 14 bold forest · 처음부터(초록, 돌림 14)
                HStack(spacing: 0) {
                    Button { dismiss() } label: { InvIconView(InvIcon.x, size: 20, color: WPColor.invInk).frame(width: 44, height: 44).contentShape(Circle()) }.accessibilityLabel("미리보기 닫기")
                    VStack(spacing: 0) {
                        Text(title).font(.custom("KakaoSmallSans-Bold", size: 14)).foregroundStyle(WPColor.invForest)
                        if let notice { Text(notice).font(.custom("KakaoSmallSans-Regular", size: 11)).foregroundStyle(WPColor.invMuted) }
                    }.multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    Button { replayID += 1 } label: {
                        HStack(spacing: 4) { InvIconView(InvIcon.rotateCcw, size: 14, color: WPColor.invAccent); Text("처음부터").font(.custom("KakaoSmallSans-Bold", size: 12)) }
                            .foregroundStyle(WPColor.invAccent).padding(.horizontal, 10).frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("invitation.replay")
                }.padding(.horizontal, 6).frame(minHeight: 56).background(WPColor.invWhite)
                WPColor.invLine.frame(height: 1)
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
                            if embedded { hiddenSections; Color.clear.frame(height: bottomSpace + 24) }
                        }.foregroundStyle(palette.ink)
                    }.background(paper)
                        .onChange(of: selectedSection) { _, value in
                            if let value { proxy.scrollTo(["mood", "intro"].contains(value) ? "moodAnchor" : value == "gallery" ? "galleryGrid" : value, anchor: .top) }
                        }
                        .task { if let selectedSection { try? await Task.sleep(for: .milliseconds(150)); proxy.scrollTo(["mood", "intro"].contains(selectedSection) ? "moodAnchor" : selectedSection == "gallery" ? "galleryGrid" : selectedSection, anchor: .top) } }
                        .onChange(of: replayID) { _, _ in proxy.scrollTo("cover", anchor: .top); started = Date() }
                        // 꺼 둔 칸을 고르고 나서 켜면(구성 → 계좌 입력 → 보이기) 고를 때는 자리가 없어 굴러가지 않았습니다 — 켜진 뒤에 맞춥니다
                        .onChange(of: design.sections.filter(\.visible).map(\.type)) { old, new in
                            guard embedded, let selectedSection, new.contains(selectedSection), !old.contains(selectedSection) else { return }
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(60))
                                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(selectedSection == "gallery" ? "galleryGrid" : selectedSection, anchor: .top) }
                            }
                        }
                        .onChange(of: focusAnchor) { _, value in
                            guard let value else { return }
                            withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(value, anchor: .top) }
                        }
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
    /// 안드로이드 `HiddenSections` — "꺼 둔 칸 — 누르면 켜고 바로 고쳐요" + `+ 칸 이름` 알약
    @ViewBuilder private var hiddenSections: some View {
        let hidden = design.sections.filter { !$0.visible }.map(\.type)
        if !hidden.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("꺼 둔 칸 — 누르면 켜고 바로 고쳐요").font(.custom("KakaoSmallSans-Regular", size: 12)).foregroundStyle(WPColor.invMuted)
                HiddenChipFlow(spacing: 8) {
                    ForEach(hidden, id: \.self) { type in
                        let name = InvitationRules.sectionTypes.firstIndex(of: type).map { InvitationRules.sectionLabels[$0] } ?? type
                        Button { onTurnOn?(type) } label: {
                            Text("+ \(name)").font(.custom("KakaoSmallSans-Bold", size: 12)).foregroundStyle(WPColor.invAccent).lineLimit(1).fixedSize()
                                .padding(.horizontal, 14).frame(minHeight: 36)
                                .background(WPColor.invWhite, in: Capsule()).overlay(Capsule().stroke(WPColor.invLine))
                        }.buttonStyle(.plain).accessibilityLabel("\(name) 칸 켜기").accessibilityIdentifier("invitation.turnOn.\(type)")
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.top, 20).background(WPColor.invPaper)
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
            InvitationFlower().stroke(palette.gold, lineWidth: 0.8 * 30 / 24).frame(width: 30, height: 30).frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(height: 24)
            VStack(spacing: 0) {
                Text("Love grows").font(.custom("NotoSerif", size: 56)).foregroundStyle(palette.ink)
                Text("with you.").font(.custom("NotoSerif-Italic", size: 56)).foregroundStyle(palette.gold)
            }.tracking(-2).padding(.bottom, 24)
            Text("우리의 시작을 함께해 주셔서 고맙습니다.").wpTypography(11, face: .kakao, lineHeight: 19.8).foregroundStyle(palette.muted).padding(.bottom, 28)
            Button(action: shareNotice) {
                HStack(spacing: 8) { InvIconView(InvIcon.share, size: 14, color: palette.ink); Text("청첩장 전하기").wpTypography(12, face: .kakao, lineHeight: 18) }
                    .frame(maxWidth: .infinity).frame(height: 48).overlay(Rectangle().stroke(palette.rule)).contentShape(Rectangle())
            }.buttonStyle(.plain).padding(.bottom, 12)
            Button { replayID += 1 } label: {
                HStack(spacing: 8) { InvIconView(InvIcon.rotateCcw, size: 12, color: palette.muted); Text("문 열림 다시 보기").wpTypography(10, face: .kakao, lineHeight: 15) }
                    .padding(8).frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundStyle(palette.muted)
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

/// 줄이 넘치면 다음 줄로 — 안드로이드 `FlowRow(spacedBy 8)`.
private struct HiddenChipFlow: Layout {
    var spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { y += row + spacing; x = 0; row = 0 }
            x += size.width + spacing; row = max(row, size.height); widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + row)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX { y += row + spacing; x = bounds.minX; row = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing; row = max(row, size.height)
        }
    }
}
