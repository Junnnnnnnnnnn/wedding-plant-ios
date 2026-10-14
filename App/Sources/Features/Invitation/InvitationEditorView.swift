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
                    Image(systemName: "arrow.left").frame(width: 44, height: 44)
                }.accessibilityLabel("모바일 청첩장으로 나가기").disabled(busy)
                VStack(alignment: .leading, spacing: 3) {
                    Text("청첩장 만들기").font(.custom("KakaoSmallSans-Bold", size: 15)).foregroundStyle(WPColor.invForest)
                    Text(busy ? "저장하는 중…" : draft != baseline ? "저장하지 않은 변경이 있어요" : baseline.updatedAt.isEmpty ? "아직 저장하지 않은 새 청첩장" : "\(draft.published ? "공개 중" : "공개 전") · 모두 저장됨")
                        .font(.custom("KakaoSmallSans-Regular", size: 11)).foregroundStyle(WPColor.invMuted)
                }
                Spacer()
                Button { Task { await save() } } label: {
                    HStack(spacing: 6) { Text(busy ? "저장하는 중…" : "저장"); Image(systemName: "checkmark") }
                        .font(.custom("KakaoSmallSans-Bold", size: 13)).padding(.horizontal, 16).frame(height: 40)
                        .foregroundStyle(.white).background(WPColor.invAccent, in: RoundedRectangle(cornerRadius: 10))
                }.disabled(busy).accessibilityIdentifier("invitation.save").padding(.trailing, 12)
            }.frame(minHeight: 60).background(.white)
            Divider()
            if let error { Text(error).foregroundStyle(.red).font(.footnote).padding(10).accessibilityIdentifier("invitation.error") }
            if savedNotice {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text(draft.published ? "저장했어요. 공개된 청첩장에 바로 반영됐어요." : "저장했어요. 청첩장 화면에서 공개하면 링크와 QR로 보낼 수 있어요.").wpTypography(13, face: .kakao, lineHeight: 21)
                        Spacer(); Button { savedNotice = false } label: { Image(systemName: "xmark").frame(width: 28, height: 28) }.accessibilityLabel("알림 닫기")
                    }
                    if !draft.published { Button("공개하러 가기") { dismiss() }.font(invitationFont(12, bold: true)).frame(minHeight: 36) }
                }.padding(14).foregroundStyle(WPColor.invForest).background(WPColor.invSoft, in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 12).padding(.top, 10)
            }
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    InvitationPreviewView(content: draft, embedded: true, onSelect: { target = $0 }, selectedSection: target, onCoverPhoto: { pickingCover = true; photoPickerOpen = true }, onAddPhotos: { pickingCover = false; photoPickerOpen = true })
                        .accessibilityIdentifier("invitation.editPreview")
                    if let target {
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                Text(target == "cover" ? "표지" : ["mood", "intro"].contains(target) ? "분위기 · 첫 화면" : label(target))
                                    .font(invitationFont(16, bold: true)).foregroundStyle(WPColor.invForest)
                                Spacer()
                                if let index = design.wrappedValue.sections.firstIndex(where: { $0.type == target }) {
                                    Text("보이기").font(invitationFont(12)).foregroundStyle(WPColor.invMuted)
                                    InvitationSwitch(isOn: design.sections[index].visible, label: label(target) + " 보이기")
                                }
                                Button { self.target = nil; UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } label: { Image(systemName: "chevron.down").frame(width: 44, height: 44) }.accessibilityLabel("입력 닫기").foregroundStyle(WPColor.invMuted)
                            }.padding(.leading, 18).padding(.trailing, 6).frame(height: 56)
                            WPColor.invLine.frame(height: 1)
                            ScrollView {
                                VStack(alignment: .leading, spacing: 0) { panel(target) }
                                    .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 18)
                                    .background(GeometryReader { content in Color.clear.onAppear { panelContentHeight = content.size.height }.onChange(of: content.size.height) { _, value in panelContentHeight = value } })
                            }.frame(height: min(panelContentHeight, max(220, geometry.size.height * 0.56) - 57)).font(invitationFont(14))
                        }
                            .background(WPColor.invWhite, in: UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
                            .compositingGroup()
                            .shadow(color: WPColor.invForest.opacity(0.12), radius: 16, y: -4)
                    } else {
                        HStack(spacing: 8) {
                            editorPill("구성", icon: "square.3.layers.3d") { layoutOpen = true }
                            editorPill("분위기", icon: "paintpalette") { target = "mood" }
                            editorPill("하객 화면", icon: "eye", dark: true) { preview = true }
                        }.padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 14).frame(maxWidth: .infinity)
                            .background(LinearGradient(colors: [WPColor.invPaper.opacity(0), WPColor.invPaper], startPoint: .top, endPoint: .bottom))
                    }
                }
            }
        }.overlay {
            if layoutOpen {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.32).ignoresSafeArea().onTapGesture { layoutOpen = false }
                    InvitationLayoutPanel(draft: $draft) { target = $0; layoutOpen = false }
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                        .padding(.top, 8).accessibilityIdentifier("invitation.layout")
                        .overlay(alignment: .topTrailing) { Button { layoutOpen = false } label: { Image(systemName: "chevron.down").frame(width: 44, height: 44) }.accessibilityLabel("구성 닫기").foregroundStyle(WPColor.invMuted).padding(8) }
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
        case "guestbook": Text("하객이 이름과 축하 한마디를 남기면 픽셀 캐릭터가 되어 정원에 모여요. 남긴 글은 이 청첩장을 보는 누구나 볼 수 있어요. 보이기를 끄면 하객이 댓글을 남길 수 있어요.").wpTypography(12, face: .kakao, lineHeight: 20.4).foregroundStyle(WPColor.invMuted).padding(.top, 14)
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
            }
            Text("첫 화면").font(invitationFont(13, bold: true)).padding(.top, 10)
            HStack(alignment: .top, spacing: 8) {
                ForEach(["door", "photo"], id: \.self) { intro in
                    choice(selected: design.wrappedValue.intro == intro, action: { design.wrappedValue.intro = intro }) {
                        Text(intro == "door" ? "정원 문이 열려요" : "표지로 바로").font(invitationFont(13, bold: true))
                        Text(intro == "door" ? "스크롤하면 문이 열리고 표지가 나와요" : "문 없이 대표 사진부터 보여요").wpTypography(11, face: .kakao, lineHeight: 16).foregroundStyle(WPColor.invMuted)
                    }
                }
            }
        }.foregroundStyle(WPColor.invInk)
    }
    private func choice<C: View>(selected: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> C) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6, content: content).frame(maxWidth: .infinity, alignment: .leading).padding(10)
                .background(WPColor.invWhite, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? WPColor.invAccent : WPColor.invLine, lineWidth: selected ? 2 : 1))
        }.buttonStyle(.plain)
    }

    private var editorSection1: some View {
        VStack(spacing: 0) {
            InvitationField(label: "청첩장 제목", text: $draft.title, identifier: "invitation.title")
            HStack(alignment: .top, spacing: 10) {
                InvitationField(label: "신랑 이름", text: $draft.groom, identifier: "invitation.groom")
                InvitationField(label: "신부 이름", text: $draft.bride, identifier: "invitation.bride")
            }
            HStack(spacing: 12) {
                Group {
                    if let url = draft.photos.first?.url.flatMap(URL.init(string:)) { InvitationPhotoImage(url: url) }
                    else { Image(systemName: "photo.badge.plus").foregroundStyle(WPColor.invMuted) }
                }.frame(width: 56, height: 70).background(WPColor.invSoft).clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 4) {
                    Text("표지 사진").font(invitationFont(13, bold: true))
                    Text(draft.photos.isEmpty ? "사진을 올리면 첫 사진이 표지가 돼요. 없으면 정원 그림이 보여요." : "사진첩의 첫 사진이 표지예요. 새로 고른 사진이 표지가 돼요.")
                        .wpTypography(11, face: .kakao, lineHeight: 16.5).foregroundStyle(WPColor.invMuted)
                }.frame(maxWidth: .infinity, alignment: .leading)
                PhotosPicker(selection: $photos, maxSelectionCount: 1, matching: .images) {
                    Text(draft.photos.isEmpty ? "사진 올리기" : "다른 사진으로").font(invitationFont(12, bold: true)).padding(10)
                        .background(WPColor.invWhite, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(WPColor.invLine))
                }.simultaneousGesture(TapGesture().onEnded { pickingCover = true }).disabled(busy)
            }.foregroundStyle(WPColor.invInk).padding(10).background(WPColor.invGarden, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(WPColor.invLine)).padding(.top, 16)
        }
    }

    private var editorSection2: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("놓는 모양").font(invitationFont(12, bold: true)).padding(.top, 14)
            HStack(spacing: 8) {
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
                        }.frame(height: 52)
                        Text(layout == "mosaic" ? "크고 작게" : "고르게").font(invitationFont(13, bold: true))
                        Text((layout == "mosaic" ? "첫 사진을 크게, 나머지는 어우러지게" : "모든 사진을 같은 크기로 세 장씩").wpKeepAll).wpTypography(11, face: .kakao, lineHeight: 16).foregroundStyle(WPColor.invMuted)
                    }
                }
            }
            HStack {
                Text("사진 \(draft.photos.count) / 20장").font(invitationFont(12)); Spacer()
                PhotosPicker(selection: $photos, maxSelectionCount: max(1, 20 - draft.photos.count), matching: .images) {
                    Label(busy ? "사진 읽는 중…" : "사진 추가", systemImage: "photo.badge.plus").font(invitationFont(12, bold: true)).padding(10).background(WPColor.invWhite, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(WPColor.invLine))
                }.disabled(busy || draft.photos.count >= 20)
            }.padding(.top, 6)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Array(draft.photos.enumerated()), id: \.element.key) { index, photo in
                        Button { selectedPhoto = selectedPhoto == photo.key ? nil : photo.key } label: {
                            ZStack(alignment: .topLeading) {
                                if let url = photo.url.flatMap(URL.init(string:)) { InvitationPhotoImage(url: url).frame(width: 64, height: 64).clipped() }
                                if index == 0 { Text("표지").font(invitationFont(10, bold: true)).padding(.horizontal, 6).padding(.vertical, 1).foregroundStyle(WPColor.invWhite).background(WPColor.invForest, in: Capsule()).padding(4) }
                            }.frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedPhoto == photo.key ? WPColor.invAccent : .clear, lineWidth: 3))
                        }.buttonStyle(.plain)
                    }
                }
            }
            if let index = draft.photos.firstIndex(where: { $0.key == selectedPhoto }) {
                HStack {
                    Button("표지로") { let photo = draft.photos.remove(at: index); draft.photos.insert(photo, at: 0) }.disabled(index == 0)
                    Button("앞으로") { draft.photos.swapAt(index, index - 1) }.disabled(index == 0)
                    Button("뒤로") { draft.photos.swapAt(index, index + 1) }.disabled(index == draft.photos.count - 1)
                    Button("빼기") { draft.photos.remove(at: index); selectedPhoto = nil }
                }.font(invitationFont(12)).buttonStyle(.bordered)
            } else {
                Text(draft.photos.isEmpty ? "아직 사진이 없어요. 위 청첩장의 빈 자리를 누르거나 ‘사진 추가’로 두 사람의 사진을 올려 주세요." : "사진을 누르면 표지로 올리거나 순서를 바꾸고 뺄 수 있어요.").wpTypography(12, face: .kakao, lineHeight: 20.4).foregroundStyle(WPColor.invMuted)
            }
            Text("첫 사진이 표지가 되고, 나머지는 이 순서대로 사진첩에 놓여요. 사진은 긴 변 1600px로 줄여 올라가요.").wpTypography(12, face: .kakao, lineHeight: 20.4).foregroundStyle(WPColor.invMuted)
        }.foregroundStyle(WPColor.invInk)
    }

    private var editorSection3: some View {
        InvitationField(label: "초대의 말", text: $draft.message, multiline: true)
    }
    private var editorSection4: some View {
        VStack(alignment: .leading, spacing: 14) {
            InvitationDateFields(date: $draft.weddingDate, time: $draft.weddingTime).padding(.top, 14)
            Text((InvitationRules.invitationDateLabel(draft).map { $0 + " — 달력과 남은 날은 이 날짜로 그려져요." }) ?? "날짜를 정하면 달력과 남은 날이 그려져요.")
                .wpTypography(12, face: .kakao, lineHeight: 20.4).foregroundStyle(WPColor.invMuted)
        }
    }
    private var locationPanel: some View {
        VStack(spacing: 0) {
            InvitationField(label: "예식장", text: $draft.venue)
            HStack {
                Text("주소").font(invitationFont(12, bold: true))
                Spacer()
                if !placeSearchOpen { Button { placeSearchOpen = true } label: { Label("카카오맵에서 찾기", systemImage: "magnifyingglass").font(invitationFont(12, bold: true)).frame(minHeight: 36) } }
            }.padding(.top, 14)
            if placeSearchOpen {
                InvitationPlaceSearch(initialQuery: draft.venue, onClose: { placeSearchOpen = false }) { place in
                    draft.venue = place.placeName
                    design.wrappedValue.location.address = place.roadAddressName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? place.roadAddressName! : place.addressName
                    placeSearchOpen = false
                }
            }
            InvitationField(label: "", text: design.location.address).padding(.top, -8)
            InvitationField(label: "교통·주차 안내", text: design.location.guide, multiline: true)
            Text("지도 버튼은 주소로(없으면 예식장 이름으로) 카카오맵·네이버 지도를 열어요.").wpTypography(12, face: .kakao, lineHeight: 20.4).foregroundStyle(WPColor.invMuted).padding(.top, 14)
        }
    }

    private var editorSection5: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("신랑 측 · \(draft.groom)").font(invitationFont(13, bold: true)).padding(.top, 18)
            HStack(spacing: 10) { InvitationField(label: "아버지 성함", text: design.couple.groomFather); InvitationField(label: "어머니 성함", text: design.couple.groomMother) }
            InvitationField(label: "부를 말", text: design.couple.groomRelation)
            WPColor.invLine.frame(height: 1).padding(.top, 22).padding(.bottom, 18)
            Text("신부 측 · \(draft.bride)").font(invitationFont(13, bold: true))
            HStack(spacing: 10) { InvitationField(label: "아버지 성함", text: design.couple.brideFather); InvitationField(label: "어머니 성함", text: design.couple.brideMother) }
            InvitationField(label: "부를 말", text: design.couple.brideRelation)
            Text("부모님 성함은 비워 두어도 돼요. 비우면 두 사람 이름만 보여요. 적은 성함은 공개한 청첩장을 보는 누구나 볼 수 있어요. ‘부를 말’은 ‘장남’·‘차녀’처럼 바꿔 적을 수 있어요.").wpTypography(12, face: .kakao, lineHeight: 20.4).foregroundStyle(WPColor.invMuted).padding(.top, 12)
        }.foregroundStyle(WPColor.invForest)
    }
    private var editorSection6: some View {
        VStack(spacing: 0) { InvitationField(label: "제목", text: design.notice.title); InvitationField(label: "안내 말씀", text: design.notice.body, multiline: true) }
    }
    private var editorSection7: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<design.wrappedValue.accounts.count, id: \.self) { index in
                if index % 3 == 0 { Text(index == 0 ? "신랑 측" : "신부 측").font(invitationFont(13, bold: true)).padding(.top, 18) }
                VStack(alignment: .leading, spacing: 0) {
                    Text(design.wrappedValue.accounts[index].role).font(invitationFont(11, bold: true)).foregroundStyle(WPColor.invAccent).padding(.horizontal, 9).padding(.vertical, 2).background(WPColor.invWhite, in: Capsule())
                    HStack(alignment: .top, spacing: 10) { InvitationField(label: "예금주", text: design.accounts[index].name); InvitationField(label: "은행", text: design.accounts[index].bank) }
                    InvitationField(label: "계좌번호", text: design.accounts[index].number).keyboardType(.numbersAndPunctuation)
                }.padding(12).background(WPColor.invGarden, in: RoundedRectangle(cornerRadius: 12))
            }
            Text("은행과 계좌번호까지 적은 줄만 하객에게 보여요 — 공개한 청첩장의 주소를 아는 누구나 볼 수 있어요. 이 칸을 꺼 두면 적어 둔 계좌도 공개 청첩장에 실리지 않아요.").wpTypography(12, face: .kakao, lineHeight: 20.4).foregroundStyle(WPColor.invMuted)
        }.foregroundStyle(WPColor.invForest)
    }

    private func editorPill(_ title: String, icon: String, dark: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(invitationFont(14, bold: true)).padding(.horizontal, 18).frame(minHeight: 48)
                .foregroundStyle(dark ? WPColor.invWhite : WPColor.invForest)
                .background(dark ? WPColor.invForest : WPColor.invWhite, in: Capsule())
                .overlay(Capsule().stroke(dark ? WPColor.invForest : WPColor.invLine))
        }.buttonStyle(.plain)
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
