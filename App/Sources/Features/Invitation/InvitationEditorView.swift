import SwiftUI
import PhotosUI
import WPDomain
import WPModels
import WPNetworking
import WPUtils

struct InvitationEditorView: View {
    let saved: InvitationContent?
    let roomId: Int?
    var initialFocus: String = "layout"
    var planDate: String?
    var planVenue: String?
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var target: String? = "layout"
    @State private var draft = InvitationRules.draft()
    @State private var baseline = InvitationRules.draft()
    @State private var photos: [PhotosPickerItem] = []
    @State private var busy = false
    @State private var preview = false
    @State private var layoutOpen = false
    @State private var placeSearchOpen = false
    @State private var pickingCover = false
    @State private var selectedPhoto: String?
    @State private var panelContentHeight: CGFloat = 320
    @State private var bottomHeight: CGFloat = 80
    @State private var photoPickerOpen = false
    @State private var savedNotice = false
    @State private var discard = false
    @State private var restore = false
    @State private var conflict = false
    @State private var error: String?
    @State private var pendingDraft: InvitationContent?
    @State private var storageKey: String?
    private var design: Binding<InvitationDesignBody> {
        Binding(get: { draft.design ?? InvitationRules.design(new: true) }, set: { draft.design = $0 })
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { if draft != baseline { discard = true } else { dismiss() } } label: {
                    InvIconView(InvIcon.arrowLeft, size: 18, color: WPColor.invInk).frame(width: 44, height: 44).contentShape(Rectangle())
                }.accessibilityLabel("모바일 청첩장으로 나가기").disabled(busy).padding(.leading, 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text("청첩장 만들기").font(.custom("KakaoSmallSans-Bold", size: 15)).tracking(-0.3).frame(minHeight: 20).foregroundStyle(WPColor.invForest)
                    statusLine
                }
                Spacer()
                Button { Task { await save() } } label: {
                    HStack(spacing: 6) { Text(busy ? "저장하는 중…" : "저장"); if !busy { InvIconView(InvIcon.check, size: 16, color: .white) } }
                        .font(.custom("KakaoSmallSans-Bold", size: 13)).padding(.horizontal, 16).frame(minWidth: 76, minHeight: 40)
                        .foregroundStyle(.white).background(WPColor.invAccent, in: RoundedRectangle(cornerRadius: 10))
                }.disabled(busy).accessibilityIdentifier("invitation.save").padding(.trailing, 12)
            }.frame(minHeight: 60).background(WPColor.invPaper)
            WPColor.invLine.frame(height: 1)
            if let error {
                // 안드로이드 `Banner(error = true)` — 머리 줄 바로 아래 고정, 연분홍 바탕 · 닫기
                HStack(alignment: .top, spacing: 0) {
                    Text(error.wpKeepAll).wpTypography(13, face: .kakao, lineHeight: 21).frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("invitation.error")
                    Button { self.error = nil } label: { InvIconView(InvIcon.x, size: 14, color: WPColor.invErrorInk).frame(width: 28, height: 28).contentShape(Circle()) }.accessibilityLabel("알림 닫기")
                }.foregroundStyle(WPColor.invErrorInk).padding(.leading, 14).padding(.trailing, 12).padding(.vertical, 12)
                    .background(Color(hex: 0xFFF0F3), in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 12).padding(.top, 10)
            }
            if savedNotice {
                // 안드로이드 `Banner` — 글 13/21 · 닫기 x 14 · 테두리 단추 r9
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 0) {
                        Text((draft.published ? "저장했어요. 공개된 청첩장에 바로 반영됐어요." : "저장했어요. 청첩장 화면에서 공개하면 링크와 QR로 보낼 수 있어요.").wpKeepAll).wpTypography(13, face: .kakao, lineHeight: 21)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button { savedNotice = false } label: { InvIconView(InvIcon.x, size: 14, color: WPColor.invForest).frame(width: 28, height: 28).contentShape(Circle()) }.accessibilityLabel("알림 닫기")
                    }
                    if !draft.published {
                        Button { dismiss() } label: {
                            Text("공개하러 가기").font(invitationFont(12, bold: true)).padding(.horizontal, 12).frame(minHeight: 36)
                                .overlay(RoundedRectangle(cornerRadius: 9).stroke(WPColor.invForest, lineWidth: 1)).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("invitation.goPublish")
                    }
                }.padding(.leading, 14).padding(.trailing, 12).padding(.vertical, 12).foregroundStyle(WPColor.invForest)
                    .background(WPColor.invSoft, in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 12).padding(.top, 10)
            }
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    InvitationPreviewView(content: draft, embedded: true, onSelect: { target = $0 }, selectedSection: target, onCoverPhoto: { pickingCover = true; photoPickerOpen = true }, onAddPhotos: { pickingCover = false; photoPickerOpen = true },
                                          onTurnOn: { type in
                                              if let index = design.wrappedValue.sections.firstIndex(where: { $0.type == type }) { design.wrappedValue.sections[index].visible = true }
                                              target = type
                                          }, bottomSpace: bottomHeight)
                        .accessibilityIdentifier("invitation.editPreview")
                    Group {
                    if let target {
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(target == "cover" ? "표지" : ["mood", "intro"].contains(target) ? "분위기와 첫 화면" : label(target))
                                        .font(invitationFont(16, bold: true)).tracking(-0.3).foregroundStyle(WPColor.invForest)
                                    if design.wrappedValue.sections.first(where: { $0.type == target })?.visible == false {
                                        Text("꺼 둠 · 청첩장에 보이지 않아요").font(invitationFont(12)).foregroundStyle(WPColor.invMuted)
                                    }
                                }
                                Spacer()
                                if let index = design.wrappedValue.sections.firstIndex(where: { $0.type == target }) {
                                    Text("보이기").font(invitationFont(12)).foregroundStyle(WPColor.invMuted)
                                    InvitationSwitch(isOn: design.sections[index].visible, label: label(target) + " 보이기")
                                }
                                Button { self.target = nil; UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } label: { InvIconView(InvIcon.chevronDown, size: 20, color: WPColor.invMuted).frame(width: 44, height: 44).contentShape(Circle()) }.accessibilityLabel("입력 닫기")
                            }.padding(.leading, 18).padding(.trailing, 6).frame(minHeight: 56)
                            WPColor.invLine.frame(height: 1)
                            ScrollView {
                                VStack(alignment: .leading, spacing: 0) { panel(target) }
                                    .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 18)
                                    .background(GeometryReader { content in Color.clear.onAppear { panelContentHeight = content.size.height }.onChange(of: content.size.height) { _, value in panelContentHeight = value } })
                            }.frame(height: min(panelContentHeight, max(220, geometry.size.height * 0.56) - 57)).font(invitationFont(14))
                        }
                            // 흰 면은 홈 표시줄 밑까지 — 안드로이드 패널(navigationBarsPadding 안쪽)처럼 아래로 표지가 비치지 않게
                            .background(alignment: .top) {
                                UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20).fill(WPColor.invWhite)
                                    .shadow(color: WPColor.invForest.opacity(0.12), radius: 16, y: -4)
                                    .ignoresSafeArea(edges: .bottom)
                            }
                    } else {
                        HStack(spacing: 8) {
                            editorPill("구성", icon: InvIcon.layers) { layoutOpen = true }
                            editorPill("분위기", icon: InvIcon.palette) { target = "mood" }
                            editorPill("하객 화면", icon: InvIcon.eye, dark: true) { preview = true }
                        }.padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 14).frame(maxWidth: .infinity)
                            .background(LinearGradient(stops: [.init(color: WPColor.invPaper.opacity(0), location: 0), .init(color: WPColor.invPaper.opacity(0.92), location: 0.5), .init(color: WPColor.invPaper, location: 1)], startPoint: .top, endPoint: .bottom))
                    }
                    }.background(GeometryReader { bottom in
                        Color.clear.onAppear { bottomHeight = bottom.size.height }.onChange(of: bottom.size.height) { _, value in bottomHeight = value }
                    })
                }
            }
        }.background(WPColor.invPaper.ignoresSafeArea()).overlay {
            if layoutOpen {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.32).ignoresSafeArea().onTapGesture { layoutOpen = false }
                    InvitationLayoutPanel(draft: $draft) { target = $0; layoutOpen = false }
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                        .padding(.top, 8).accessibilityIdentifier("invitation.layout")
                        // 안드로이드 바닥 시트처럼 닫기 단추 없이 — 바깥을 누르거나 아래로 끌어 닫습니다
                        .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { value in
                            if value.translation.height > 120 && abs(value.translation.width) < value.translation.height { layoutOpen = false }
                        })
                        .accessibilityAction(.escape) { layoutOpen = false }
                }
            }
        }.tint(WPColor.invAccent).interactiveDismissDisabled(draft != baseline || busy)
            .task {
                layoutOpen = initialFocus == "layout"
                target = initialFocus == "layout" || initialFocus.isEmpty ? nil : initialFocus
                draft = saved ?? InvitationRules.draft()
                if saved == nil { draft.weddingDate = planDate; draft.venue = planVenue ?? "" }
                draft.design = InvitationRules.normalize(draft.design); baseline = draft
                selectedPhoto = draft.photos.first?.key
                let token = await env.tokenStore.currentToken() ?? ""
                // Use account identity, never the token itself, for local draft isolation.
                storageKey = "invitation.draft.\(env.baseURL.absoluteString).\(roomId ?? 0).\(JWTDecoder.planUserId(from: token) ?? "unknown")"
                if !env.isDemo, let key = storageKey, let data = UserDefaults.standard.data(forKey: key), let local = try? JSONDecoder().decode(InvitationContent.self, from: data), local != baseline { pendingDraft = local; restore = true }
            }
            .onChange(of: draft) { _, value in
                if !env.isDemo, let key = storageKey, let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: key) }
            }
            .photosPicker(isPresented: $photoPickerOpen, selection: $photos, maxSelectionCount: pickingCover ? 1 : max(1, 20 - draft.photos.count), matching: .images)
            .onChange(of: photos) { _, _ in Task { await uploadPhotos() } }
            .fullScreenCover(isPresented: $preview) { InvitationPreviewView(content: draft) }
            .confirmationDialog("저장하지 않은 수정이 있어요", isPresented: $discard, titleVisibility: .visible) {
                Button("나중에 이어서 고치기") { dismiss() }
                Button("수정 버리기", role: .destructive) { if let key = storageKey { UserDefaults.standard.removeObject(forKey: key) }; dismiss() }
            }
            .confirmationDialog("이전에 고치던 내용을 이어서 쓸까요?", isPresented: $restore, titleVisibility: .visible) {
                Button("이어서 고치기") { if let pendingDraft { draft = pendingDraft } }
                Button("서버에 저장한 내용 사용", role: .destructive) { if let key = storageKey { UserDefaults.standard.removeObject(forKey: key) } }
            }
            .confirmationDialog("함께 고치는 사람이 먼저 저장했어요", isPresented: $conflict, titleVisibility: .visible) {
                Button("내 수정 이어서 검토하기") { draft.updatedAt = baseline.updatedAt }
                Button("최신 저장 내용 사용", role: .destructive) { draft = baseline }
            } message: { Text("내 수정은 이 기기에 남아 있어요. 내 수정을 이어서 저장하면 다른 사람이 바꾼 내용을 덮어쓸 수 있어요.") }
    }
    @ViewBuilder private func panel(_ target: String) -> some View {
        switch target {
        case "mood", "intro": editorSection0
        case "cover": editorSection1
        case "gallery": editorSection2
        case "message": editorSection3
        case "calendar": editorSection4
        case "location": locationPanel
        case "couple": editorSection5
        case "notice": editorSection6
        case "accounts": editorSection7
        case "guestbook": Text("하객이 이름과 축하 한마디를 남기면 픽셀 캐릭터가 되어 정원에 모여요. 남긴 글은 이 청첩장을 보는 누구나 볼 수 있어요. 보이기를 끄면 하객이 댓글을 남길 수 없어요.".wpKeepAll).wpTypography(12, face: .kakao, lineHeight: 20.4).foregroundStyle(WPColor.invMuted).padding(.top, 14)
        default: editorSection1
        }
    }
    private var editorSection0: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) { Text("분위기").font(invitationFont(13, bold: true)); Text("종이·글자 색이 바뀌어요").font(invitationFont(12)).foregroundStyle(WPColor.invMuted) }.padding(.top, 14)
            HStack(alignment: .top, spacing: 8) {
                ForEach(["garden", "ivory", "rose"], id: \.self) { template in
                    choice(selected: draft.template == template, action: { draft.template = template }) {
                        let palette = InvitationPalette(template)
                        HStack(spacing: 0) { palette.forest; palette.paper }.frame(height: 34).clipShape(RoundedRectangle(cornerRadius: 7))
                        Text(template == "garden" ? "가든" : template == "ivory" ? "아이보리" : "로즈").font(invitationFont(13, bold: true))
                        Text(template == "garden" ? "초록빛 정원, 자연스러운 초대" : template == "ivory" ? "정갈한 여백, 오래가는 아름다움" : "은은한 장밋빛, 다정한 마음").font(invitationFont(11)).foregroundStyle(WPColor.invMuted)
                    }
                }
            }.fixedSize(horizontal: false, vertical: true)
            Text("첫 화면").font(invitationFont(13, bold: true)).padding(.top, 10)
            HStack(alignment: .top, spacing: 8) {
                ForEach(["door", "photo"], id: \.self) { intro in
                    choice(selected: design.wrappedValue.intro == intro, action: { design.wrappedValue.intro = intro }) {
                        Text(intro == "door" ? "정원 문이 열려요" : "표지로 바로").font(invitationFont(13, bold: true))
                        Text(intro == "door" ? "스크롤하면 문이 열리고 표지가 나와요" : "문 없이 대표 사진부터 보여요").wpTypography(11, face: .kakao, lineHeight: 16).foregroundStyle(WPColor.invMuted)
                    }
                }
            }.fixedSize(horizontal: false, vertical: true)
        }.foregroundStyle(WPColor.invInk)
    }
    private func choice<C: View>(selected: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> C) -> some View {
        Button(action: action) {
            // 옆 카드와 높이를 맞춥니다 — 좁은 폰에서 한쪽 설명만 꺾이면 카드가 들쭉날쭉했습니다
            VStack(alignment: .leading, spacing: 6, content: content).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 12)
                .background(WPColor.invWhite, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? WPColor.invAccent : WPColor.invLine, lineWidth: selected ? 2 : 1))
        }.buttonStyle(.plain)
    }

    private var editorSection1: some View {
        VStack(spacing: 0) {
            InvitationField(label: "청첩장 제목", text: $draft.title, identifier: "invitation.title", placeholder: "우리, 결혼합니다", max: 60)
            HStack(alignment: .top, spacing: 10) {
                InvitationField(label: "신랑 이름", text: $draft.groom, identifier: "invitation.groom", max: 20)
                InvitationField(label: "신부 이름", text: $draft.bride, identifier: "invitation.bride", max: 20)
            }
            HStack(spacing: 12) {
                Group {
                    if let url = draft.photos.first?.url.flatMap(URL.init(string:)) { InvitationPhotoImage(url: url) }
                    else { InvIconView(InvIcon.imagePlus, size: 20, color: WPColor.invMuted) }
                }.frame(width: 56, height: 70).background(WPColor.invSoft).clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 4) {
                    Text("표지 사진").font(invitationFont(13, bold: true))
                    Text((draft.photos.isEmpty ? "사진을 올리면 첫 사진이 표지가 돼요. 없으면 정원 그림이 보여요." : "사진첩의 첫 사진이 표지예요. 새로 고른 사진이 표지가 돼요.").wpKeepAll)
                        .wpTypography(11, face: .kakao, lineHeight: 16.5).foregroundStyle(WPColor.invMuted)
                }.frame(maxWidth: .infinity, alignment: .leading)
                PhotosPicker(selection: $photos, maxSelectionCount: 1, matching: .images) {
                    InvitationOutlineLabel(title: busy ? "읽는 중…" : draft.photos.isEmpty ? "사진 올리기" : "다른 사진으로", enabled: !busy)
                }.buttonStyle(.plain).simultaneousGesture(TapGesture().onEnded { pickingCover = true }).disabled(busy).padding(.leading, -2)
            }.foregroundStyle(WPColor.invInk).padding(10).background(WPColor.invGarden, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(WPColor.invLine)).padding(.top, 16)
        }
    }

    private var editorSection2: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("놓는 모양").font(invitationFont(12, bold: true)).padding(.top, 14).padding(.bottom, 8)
            HStack(alignment: .top, spacing: 8) {
                ForEach(["mosaic", "grid"], id: \.self) { layout in
                    choice(selected: design.wrappedValue.galleryLayout == layout, action: { design.wrappedValue.galleryLayout = layout }) {
                        Canvas { context, size in
                            let gap: CGFloat = 3
                            func tile(_ rect: CGRect, _ color: Color) { context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(color)) }
                            if layout == "mosaic" {
                                let w = size.width * 0.62, h = (size.height - gap) / 2
                                tile(CGRect(x: 0, y: 0, width: w, height: size.height), WPColor.invLine)
                                for row in 0..<2 { tile(CGRect(x: w + gap, y: CGFloat(row) * (h + gap), width: size.width - w - gap, height: h), WPColor.invSoft) }
                            } else {
                                let w = (size.width - gap * 2) / 3, h = (size.height - gap) / 2
                                for row in 0..<2 { for col in 0..<3 { tile(CGRect(x: CGFloat(col) * (w + gap), y: CGFloat(row) * (h + gap), width: w, height: h), WPColor.invSoft) } }
                            }
                        }.frame(height: 52).padding(.bottom, 2)
                        Text(layout == "mosaic" ? "크고 작게" : "고르게").font(invitationFont(13, bold: true)).padding(.bottom, -6)
                        Text((layout == "mosaic" ? "첫 사진을 크게, 나머지는 어우러지게" : "모든 사진을 같은 크기로 세 장씩").wpKeepAll).wpTypography(11, face: .kakao, lineHeight: 16).foregroundStyle(WPColor.invMuted)
                    }
                }
            }.fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 0) {
                (Text("사진 ").foregroundColor(WPColor.invMuted) + Text("\(draft.photos.count)").font(invitationFont(12, bold: true)).foregroundColor(WPColor.invInk) + Text(" / 20장").foregroundColor(WPColor.invMuted)).font(invitationFont(12))
                Spacer()
                PhotosPicker(selection: $photos, maxSelectionCount: max(1, 20 - draft.photos.count), matching: .images) {
                    InvitationOutlineLabel(title: busy ? "사진 읽는 중…" : "사진 추가", icon: InvIcon.imagePlus, enabled: !busy && draft.photos.count < 20)
                }.buttonStyle(.plain).disabled(busy || draft.photos.count >= 20)
            }.padding(.top, 18)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Array(draft.photos.enumerated()), id: \.element.key) { index, photo in
                        Button { selectedPhoto = selectedPhoto == photo.key ? nil : photo.key } label: {
                            ZStack(alignment: .topLeading) {
                                WPColor.invSoft
                                if let url = photo.url.flatMap(URL.init(string:)) { InvitationPhotoImage(url: url).frame(width: 64, height: 64).clipped() }
                                if index == 0 { Text("표지").font(invitationFont(10, bold: true)).padding(.horizontal, 6).padding(.vertical, 1).foregroundStyle(WPColor.invWhite).background(WPColor.invForest, in: Capsule()).padding(4) }
                            }.frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedPhoto == photo.key ? WPColor.invAccent : .clear, lineWidth: 3))
                        }.buttonStyle(.plain)
                    }
                }
            }.scrollIndicators(.hidden).opacity(draft.photos.isEmpty ? 0 : 1).frame(height: draft.photos.isEmpty ? 0 : 64).padding(.top, draft.photos.isEmpty ? 0 : 12)
            if draft.photos.isEmpty {
                Text("아직 사진이 없어요. 위 청첩장의 빈 자리를 누르거나 ‘사진 추가’로 두 사람의 사진을 올려 주세요.".wpKeepAll).wpTypography(12, face: .kakao, lineHeight: 19).foregroundStyle(WPColor.invMuted)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 18)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(WPColor.invLine)).padding(.top, 12)
            } else if let index = draft.photos.firstIndex(where: { $0.key == selectedPhoto }) {
                HStack(spacing: 6) {
                    photoAction("표지로", icon: InvIcon.star, enabled: index > 0) { let photo = draft.photos.remove(at: index); draft.photos.insert(photo, at: 0) }
                    photoAction("앞으로", icon: InvIcon.chevronLeft, enabled: index > 0) { draft.photos.swapAt(index, index - 1) }
                    photoAction("뒤로", icon: InvIcon.chevronRight, enabled: index < draft.photos.count - 1) { draft.photos.swapAt(index, index + 1) }
                    photoAction("빼기", icon: InvIcon.x, enabled: true, danger: true) { draft.photos.remove(at: index); selectedPhoto = nil }
                }.padding(.top, 10)
                note("\(index + 1)번 사진을 골랐어요. 순서를 바꾸거나 표지로 올릴 수 있어요.", top: 8)
            } else {
                note("사진을 누르면 표지로 올리거나 순서를 바꾸고 뺄 수 있어요.", top: 8)
            }
            note("첫 사진이 표지가 되고, 나머지는 이 순서대로 사진첩에 놓여요. 사진은 긴 변 1600px로 줄여 올라가요.")
        }.foregroundStyle(WPColor.invInk)
    }

    private var editorSection3: some View {
        InvitationField(label: "초대의 말", text: $draft.message, multiline: true, max: 500)
    }
    private var editorSection4: some View {
        VStack(alignment: .leading, spacing: 0) {
            InvitationDateFields(date: $draft.weddingDate, time: $draft.weddingTime).padding(.top, 14)
            note((InvitationRules.invitationDateLabel(draft).map { $0 + " — 달력과 남은 날은 이 날짜로 그려져요." }) ?? "날짜를 정하면 달력과 남은 날이 그려져요.")
        }
    }
    private var locationPanel: some View {
        VStack(spacing: 0) {
            InvitationField(label: "예식장", text: $draft.venue, placeholder: "예식장 이름과 홀", max: 100)
            HStack {
                Text("주소").font(invitationFont(12, bold: true))
                Spacer()
                if !placeSearchOpen { Button { placeSearchOpen = true } label: {
                    HStack(spacing: 4) { InvIconView(InvIcon.search, size: 14, color: WPColor.invAccent); Text("카카오맵에서 찾기").font(invitationFont(12, bold: true)) }
                        .foregroundStyle(WPColor.invAccent).padding(.horizontal, 10).frame(minHeight: 36)
                } .buttonStyle(.plain).padding(.trailing, -10) }
            }.padding(.top, 14)
            if placeSearchOpen {
                InvitationPlaceSearch(initialQuery: draft.venue, onClose: { placeSearchOpen = false }) { place in
                    draft.venue = place.placeName
                    design.wrappedValue.location.address = place.roadAddressName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? place.roadAddressName! : place.addressName
                    placeSearchOpen = false
                }
            }
            InvitationField(label: "", text: design.location.address, placeholder: "도로명 주소", max: 120, top: 6)
            InvitationField(label: "교통·주차 안내", text: design.location.guide, multiline: true, placeholder: "지하철 ○호선 ○○역 3번 출구에서 걸어서 5분\n건물 지하 주차장 2시간 무료", max: 500)
            note("지도 버튼은 주소로(없으면 예식장 이름으로) 카카오맵·네이버 지도를 열어요.")
        }
    }

    private var editorSection5: some View {
        VStack(alignment: .leading, spacing: 0) {
            groupTitle("신랑 측", name: draft.groom.isEmpty ? "신랑" : draft.groom).padding(.top, 18)
            HStack(spacing: 10) { InvitationField(label: "아버지 성함", text: design.couple.groomFather, max: 20); InvitationField(label: "어머니 성함", text: design.couple.groomMother, max: 20) }
            InvitationField(label: "부를 말", text: design.couple.groomRelation, placeholder: "아들", max: 6)
            WPColor.invLine.frame(height: 1).padding(.top, 22).padding(.bottom, 18)
            groupTitle("신부 측", name: draft.bride.isEmpty ? "신부" : draft.bride)
            HStack(spacing: 10) { InvitationField(label: "아버지 성함", text: design.couple.brideFather, max: 20); InvitationField(label: "어머니 성함", text: design.couple.brideMother, max: 20) }
            InvitationField(label: "부를 말", text: design.couple.brideRelation, placeholder: "딸", max: 6)
            note("부모님 성함은 비워 두어도 돼요. 비우면 두 사람 이름만 보여요. 적은 성함은 공개한 청첩장을 보는 누구나 볼 수 있어요. ‘부를 말’은 ‘장남’·‘차녀’처럼 바꿔 적을 수 있어요.")
        }.foregroundStyle(WPColor.invForest)
    }
    private var editorSection6: some View {
        VStack(spacing: 0) {
            InvitationField(label: "제목", text: design.notice.title, placeholder: "안내 말씀", max: 30)
            InvitationField(label: "내용", text: design.notice.body, multiline: true, placeholder: "식사는 예식 후 2층 연회장에서 준비했어요.\n화환은 정중히 사양합니다.", max: 500)
        }
    }
    private var editorSection7: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<design.wrappedValue.accounts.count, id: \.self) { index in
                let account = design.wrappedValue.accounts[index]
                if index % 3 == 0 {
                    if index > 0 { WPColor.invLine.frame(height: 1).padding(.top, 22).padding(.bottom, 18) }
                    groupTitle(index == 0 ? "신랑 측" : "신부 측", name: nil).padding(.top, index == 0 ? 18 : 0)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(account.role).font(invitationFont(11, bold: true)).foregroundStyle(WPColor.invAccent).padding(.horizontal, 9).padding(.vertical, 2).background(WPColor.invWhite, in: Capsule())
                    HStack(alignment: .top, spacing: 10) {
                        InvitationField(label: "예금주", text: design.accounts[index].name, placeholder: account.role == "신랑" ? (draft.groom.isEmpty ? "성함" : draft.groom) : account.role == "신부" ? (draft.bride.isEmpty ? "성함" : draft.bride) : "성함", max: 20, top: 10)
                        InvitationField(label: "은행", text: design.accounts[index].bank, max: 20, top: 10)
                    }
                    InvitationField(label: "계좌번호", text: design.accounts[index].number, placeholder: "숫자와 - 만", max: 30, top: 10, filter: { $0.filter { $0.isNumber || $0 == "-" } }).keyboardType(.phonePad)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(WPColor.invGarden, in: RoundedRectangle(cornerRadius: 12)).padding(.top, 12)
            }
            note("은행과 계좌번호까지 적은 줄만 하객에게 보여요 — 공개한 청첩장의 주소를 아는 누구나 볼 수 있어요. 이 칸을 꺼 두면 적어 둔 계좌도 공개 청첩장에 실리지 않아요.")
        }.foregroundStyle(WPColor.invForest)
    }

    private func editorPill(_ title: String, icon: [String], dark: Bool = false, action: @escaping () -> Void) -> some View {
        let fg = dark ? WPColor.invWhite : WPColor.invForest
        return Button(action: action) {
            HStack(spacing: 8) {
                InvIconView(icon, size: 17, color: fg)
                Text(title).font(invitationFont(14, bold: true)).lineLimit(1).fixedSize()
            }.padding(.horizontal, 18).frame(minHeight: 48)
                .foregroundStyle(fg)
                .background(dark ? WPColor.invForest : WPColor.invWhite, in: Capsule())
                .overlay { if !dark { Capsule().stroke(WPColor.invLine) } }
                .shadow(color: WPColor.invForest.opacity(dark ? 0.22 : 0.12), radius: dark ? 10 : 4, y: dark ? 4 : 2)
        }.buttonStyle(.plain)
    }
    /// 안드로이드 `StatusLine` — 6pt 점 + 11pt 상태 글. 점은 저장 중에만 깜빡입니다
    private var statusLine: some View {
        let dirty = draft != baseline
        let (text, dot): (String, Color) = busy ? ("저장하는 중…", WPColor.invAccent)
            : dirty ? ("저장하지 않은 변경이 있어요", WPColor.invGold)
            : baseline.updatedAt.isEmpty ? ("아직 저장하지 않은 새 청첩장", WPColor.invLine)
            : ("\(draft.published ? "공개 중" : "공개 전") · 모두 저장됨", WPColor.invAccent)
        return HStack(spacing: 6) {
            Circle().fill(dot).frame(width: 6, height: 6)
            Text(text).font(.custom("KakaoSmallSans-Regular", size: 11)).lineLimit(1).foregroundStyle(WPColor.invMuted)
        }.frame(minHeight: 14)
    }

    /// 안드로이드 `Note` — 12/20 흐린 글, 어절 단위
    private func note(_ text: String, top: CGFloat = 12) -> some View {
        Text(text.wpKeepAll).wpTypography(12, face: .kakao, lineHeight: 20).foregroundStyle(WPColor.invMuted).padding(.top, top)
            .frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
    }
    /// 안드로이드 `GroupTitle` — 13 bold forest + (있으면) ` · 이름` 12 흐린 글
    private func groupTitle(_ title: String, name: String?) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(title).font(invitationFont(13, bold: true)).foregroundStyle(WPColor.invForest)
            if let name { Text(" · \(name)").font(invitationFont(12)).foregroundStyle(WPColor.invMuted) }
        }
    }
    /// 안드로이드 `PhotoAction` — 아이콘 16 위 · 글 11 bold, 테두리 r10, 최소 높이 52
    private func photoAction(_ title: String, icon: [String], enabled: Bool, danger: Bool = false, action: @escaping () -> Void) -> some View {
        let fg = danger ? WPColor.invErrorInk : WPColor.invAccent
        return Button(action: action) {
            VStack(spacing: 3) {
                InvIconView(icon, size: 16, color: fg)
                Text(title).font(invitationFont(11, bold: true)).foregroundStyle(fg).lineLimit(1).fixedSize()
            }.frame(maxWidth: .infinity, minHeight: 52).padding(.vertical, 6)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(WPColor.invLine)).contentShape(Rectangle())
        }.buttonStyle(.plain).opacity(enabled ? 1 : 0.45).disabled(!enabled).accessibilityLabel(title)
    }
    private func nullable(_ binding: Binding<String?>) -> Binding<String> { Binding(get: { binding.wrappedValue ?? "" }, set: { binding.wrappedValue = $0.isEmpty ? nil : $0 }) }
    private func label(_ type: String) -> String { InvitationRules.sectionTypes.firstIndex(of: type).map { InvitationRules.sectionLabels[$0] } ?? type }
    private func save() async {
        guard !busy else { return }; busy = true; error = nil; defer { busy = false }
        do {
            let result: MyInvitation = try await env.api.send(Endpoint.saveInvitation(.init(content: InvitationRules.sanitize(draft), createOnly: saved == nil && draft.updatedAt.isEmpty)))
            guard let content = result.invitation else { throw APIError.emptyData }
            baseline = content; draft = content; savedNotice = true
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            if let key = storageKey { UserDefaults.standard.removeObject(forKey: key) }
        } catch APIError.http(let status, _) where status == 409 {
            if let fresh: MyInvitation = try? await env.api.send(Endpoint.myInvitation()), let content = fresh.invitation {
                // Keep the unsaved values; retry only after explicitly reviewing the fresh version.
                pendingDraft = draft; baseline = content; conflict = true
            } else { self.error = "다른 사람이 저장한 내용을 불러오지 못했어요. 다시 시도해 주세요." }
        } catch { self.error = error.localizedDescription }
    }
    private func uploadPhotos() async {
        guard !busy else { return }; busy = true; error = nil; defer { busy = false; photos = []; pickingCover = false }
        do {
            for item in photos.prefix(max(0, 20 - draft.photos.count)) {
                guard let raw = try await item.loadTransferable(type: Data.self), let image = UIImage(data: raw) else { throw APIError.backend(message: "사진을 읽지 못했어요.") }
                let ratio = min(1, 1600 / max(image.size.width, image.size.height))
                let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let prepared = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
                guard let bytes = prepared.jpegData(compressionQuality: 0.85), bytes.count <= 8 * 1024 * 1024 else { throw APIError.backend(message: "사진 한 장은 8MB까지 올릴 수 있어요.") }
                let slot: InvitationPhotoSlot = try await env.api.send(Endpoint.invitationPhoto(contentType: "image/jpeg", sizeBytes: bytes.count))
                try await SignedStorage.upload(url: slot.uploadUrl, contentType: "image/jpeg", bytes: bytes)
                let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("InvitationPhotos", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let local = directory.appendingPathComponent(UUID().uuidString + ".jpg")
                try bytes.write(to: local, options: .atomic)
                if pickingCover { draft.photos.insert(.init(key: slot.key, url: local.absoluteString), at: 0) }
                else { draft.photos.append(.init(key: slot.key, url: local.absoluteString)) }
            }
        } catch { self.error = error.localizedDescription }
    }
}
