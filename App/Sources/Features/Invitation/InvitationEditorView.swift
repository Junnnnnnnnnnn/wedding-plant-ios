import SwiftUI
import PhotosUI
import WPDomain
import WPModels
import WPNetworking
import WPUtils

struct InvitationEditorView: View {
    let saved: InvitationContent?
    let roomId: Int?
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var target: String? = "layout"
    @State private var draft = InvitationRules.draft()
    @State private var baseline = InvitationRules.draft()
    @State private var photos: [PhotosPickerItem] = []
    @State private var busy = false
    @State private var preview = false
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
                    Text("청첩장 만들기").font(.custom("KakaoSmallSans-Bold", size: 15))
                    Text(busy ? "저장하는 중…" : draft != baseline ? "저장하지 않은 변경이 있어요" : saved == nil ? "아직 저장하지 않은 새 청첩장" : "모두 저장됨")
                        .font(.custom("KakaoSmallSans-Regular", size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { Task { await save() } } label: {
                    Label(busy ? "저장하는 중…" : "저장", systemImage: "checkmark")
                        .font(.custom("KakaoSmallSans-Bold", size: 13)).padding(.horizontal, 16).frame(height: 40)
                        .foregroundStyle(.white).background(Color(hex: 0x287A57), in: RoundedRectangle(cornerRadius: 10))
                }.disabled(busy).accessibilityIdentifier("invitation.save").padding(.trailing, 12)
            }.frame(minHeight: 60).background(.white)
            Divider()
            if let error { Text(error).foregroundStyle(.red).font(.footnote).padding(10).accessibilityIdentifier("invitation.error") }
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    InvitationPreviewView(content: draft, embedded: true, onSelect: { target = $0 })
                        .accessibilityIdentifier("invitation.editPreview")
                    if let target {
                        VStack(spacing: 0) {
                            HStack {
                                Text(target == "cover" ? "표지" : target == "mood" ? "분위기 · 첫 화면" : target == "layout" ? "구성" : label(target))
                                    .font(.custom("KakaoSmallSans-Bold", size: 15))
                                Spacer()
                                Button { self.target = nil; UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("입력 닫기")
                            }.padding(.horizontal, 16)
                            Form { panel(target) }.scrollContentBackground(.hidden).background(Color.white)
                                .font(.custom("KakaoSmallSans-Regular", size: 14))
                        }.frame(height: min(max(220, geometry.size.height * 0.56), 440)).background(.white)
                    }
                    HStack(spacing: 10) {
                            Button { target = "layout" } label: { Label("구성", systemImage: "square.grid.2x2") }
                            Button { target = "mood" } label: { Label("분위기", systemImage: "paintpalette") }
                            Button { target = "cover" } label: { Label("표지", systemImage: "photo") }.accessibilityIdentifier("invitation.editCover")
                            Button { preview = true } label: { Label("하객 화면", systemImage: "eye") }
                        }.font(.custom("KakaoSmallSans-Bold", size: 12)).buttonStyle(.bordered)
                            .padding(12).frame(maxWidth: .infinity).background(.white)
                }
            }
        }.interactiveDismissDisabled(draft != baseline || busy)
            .task {
                draft = saved ?? InvitationRules.draft(); draft.design = InvitationRules.normalize(draft.design); baseline = draft
                let token = await env.tokenStore.currentToken() ?? ""
                // Use account identity, never the token itself, for local draft isolation.
                storageKey = "invitation.draft.\(roomId ?? 0).\(JWTDecoder.planUserId(from: token) ?? "unknown")"
                if !env.isDemo, let key = storageKey, let data = UserDefaults.standard.data(forKey: key), let local = try? JSONDecoder().decode(InvitationContent.self, from: data), local != baseline { pendingDraft = local; restore = true }
            }
            .onChange(of: draft) { _, value in
                if let key = storageKey, let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: key) }
            }
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
        case "calendar", "location": editorSection4
        case "couple": editorSection5
        case "notice": editorSection6
        case "accounts": editorSection7
        case "layout", "guestbook": editorSection8
        default: editorSection1
        }
    }
    private var editorSection0: some View {
        Section("분위기") {
                    Picker("분위기", selection: $draft.template) {
                        Text("가든").tag("garden"); Text("아이보리").tag("ivory"); Text("로즈").tag("rose")
                    }.pickerStyle(.segmented)
                    Picker("첫 화면", selection: design.intro) { Text("정원 문이 열려요").tag("door"); Text("표지로 바로").tag("photo") }
                }
    }

    private var editorSection1: some View {
        Section("표지") {
                    TextField("제목", text: $draft.title).accessibilityIdentifier("invitation.title")
                    TextField("신랑 이름", text: $draft.groom).accessibilityIdentifier("invitation.groom")
                    TextField("신부 이름", text: $draft.bride).accessibilityIdentifier("invitation.bride")
                }
    }

    private var editorSection2: some View {
        Section("사진첩 · \(draft.photos.count) / 20장") {
                    PhotosPicker(selection: $photos, maxSelectionCount: max(1, 20 - draft.photos.count), matching: .images) {
                        Label(busy ? "사진 올리는 중…" : "사진 올리기", systemImage: "photo.badge.plus")
                    }.disabled(busy || draft.photos.count >= 20)
                    ForEach(Array(draft.photos.enumerated()), id: \.element.key) { index, photo in
                        HStack {
                            if let raw = photo.url, let url = URL(string: raw) { InvitationPhotoImage(url: url, mode: .fill).frame(width: 60, height: 70).clipped() }
                            Text(index == 0 ? "표지 사진" : "사진 \(index + 1)"); Spacer()
                            if index > 0 { Button { draft.photos.swapAt(index, index - 1) } label: { Image(systemName: "arrow.up") }.buttonStyle(.borderless).accessibilityLabel("사진 앞으로") }
                            Button(role: .destructive) { draft.photos.remove(at: index) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                        }
                    }
                    Picker("놓는 모양", selection: design.galleryLayout) { Text("크고 작게").tag("mosaic"); Text("고르게").tag("grid") }
                }
    }

    private var editorSection3: some View {
        Section("초대의 말") { TextEditor(text: $draft.message).frame(minHeight: 120) }
    }

    private var editorSection4: some View {
        Section("예식 일시 · 오시는 길") {
                    TextField("날짜 (YYYY-MM-DD)", text: nullable($draft.weddingDate)).keyboardType(.numbersAndPunctuation)
                    TextField("시간 (HH:mm)", text: nullable($draft.weddingTime)).keyboardType(.numbersAndPunctuation)
                    TextField("예식장", text: $draft.venue)
                    TextField("주소", text: design.location.address)
                    TextField("교통 안내", text: design.location.guide, axis: .vertical)
                }
    }

    private var editorSection5: some View {
        Section("신랑 · 신부") {
                    TextField("신랑 아버지", text: design.couple.groomFather)
                    TextField("신랑 어머니", text: design.couple.groomMother)
                    TextField("신랑 관계", text: design.couple.groomRelation)
                    TextField("신부 아버지", text: design.couple.brideFather)
                    TextField("신부 어머니", text: design.couple.brideMother)
                    TextField("신부 관계", text: design.couple.brideRelation)
                }
    }

    private var editorSection6: some View {
        Section("안내 말씀") { TextField("제목", text: design.notice.title); TextEditor(text: design.notice.body).frame(minHeight: 80) }
    }

    private var editorSection7: some View {
        Section("계좌 입력") {
                    ForEach(0..<design.wrappedValue.accounts.count, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(design.wrappedValue.accounts[index].side == "groom" ? "신랑 측" : "신부 측") · \(design.wrappedValue.accounts[index].role)").font(.headline)
                            TextField("예금주", text: design.accounts[index].name)
                            TextField("은행", text: design.accounts[index].bank)
                            TextField("계좌 번호", text: design.accounts[index].number).keyboardType(.numbersAndPunctuation)
                        }.padding(.vertical, 6)
                    }
                }
    }

    private var editorSection8: some View {
        Section("구성 · 표시와 순서") {
                    ForEach(0..<design.wrappedValue.sections.count, id: \.self) { index in
                        HStack {
                            Toggle(label(design.wrappedValue.sections[index].type), isOn: design.sections[index].visible)
                            if index > 0 {
                                Button { var d = design.wrappedValue; d.sections.swapAt(index, index - 1); design.wrappedValue = d } label: { Image(systemName: "arrow.up") }.buttonStyle(.borderless)
                            }
                        }
                    }
                }
    }

    private func nullable(_ binding: Binding<String?>) -> Binding<String> { Binding(get: { binding.wrappedValue ?? "" }, set: { binding.wrappedValue = $0.isEmpty ? nil : $0 }) }
    private func label(_ type: String) -> String { InvitationRules.sectionTypes.firstIndex(of: type).map { InvitationRules.sectionLabels[$0] } ?? type }
    private func save() async {
        guard !busy else { return }; busy = true; error = nil; defer { busy = false }
        do {
            let result: MyInvitation = try await env.api.send(Endpoint.saveInvitation(.init(content: InvitationRules.sanitize(draft), createOnly: saved == nil && draft.updatedAt.isEmpty)))
            guard let content = result.invitation else { throw APIError.emptyData }
            baseline = content
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            if let key = storageKey { UserDefaults.standard.removeObject(forKey: key) }
            dismiss()
        } catch APIError.http(let status, _) where status == 409 {
            if let fresh: MyInvitation = try? await env.api.send(Endpoint.myInvitation()), let content = fresh.invitation {
                // Keep the unsaved values; retry only after explicitly reviewing the fresh version.
                pendingDraft = draft; baseline = content; conflict = true
            } else { self.error = "다른 사람이 저장한 내용을 불러오지 못했어요. 다시 시도해 주세요." }
        } catch { self.error = error.localizedDescription }
    }
    private func uploadPhotos() async {
        guard !busy else { return }; busy = true; error = nil; defer { busy = false; photos = [] }
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
                draft.photos.append(.init(key: slot.key, url: local.absoluteString))
            }
        } catch { self.error = error.localizedDescription }
    }
}
