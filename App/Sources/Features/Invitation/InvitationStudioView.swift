import SwiftUI
import WPDomain
import WPModels
import WPNetworking
import CoreImage.CIFilterBuiltins

@MainActor final class InvitationStore: ObservableObject {
    @Published var result: MyInvitation?
    @Published var error: String?
    @Published var busy = false
    @Published var wishes: [InvitationWish] = []
    @Published var total: Int?
    var state: InvitationRules.StudioState {
        InvitationRules.studioState(loaded: result != nil, failed: error != nil && result == nil, hasInvitation: result?.invitation != nil, canEdit: result?.canEdit == true)
    }
    func load(_ env: AppEnvironment) async {
        error = nil
        do {
            result = try await env.api.send(Endpoint.myInvitation())
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
        busy = true; error = nil; defer { busy = false }
        content.published = published
        do { result = try await env.api.send(Endpoint.saveInvitation(.init(content: InvitationRules.sanitize(content), createOnly: false))) }
        catch { self.error = error.localizedDescription }
    }
}

struct InvitationStudioView: View {
    var titleSlot: AnyView? = nil
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var model = InvitationStore()
    @State private var edit = false
    @State private var preview = false
    @State private var pass = false
    @State private var confirmPublish = false
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    BrandHead(corner: 24, horizontal: 20, top: 14, bottom: 20) {
                        if let titleSlot { titleSlot } else { Text("모바일 청첩장").font(WPFont.hak(18, .bold)).foregroundStyle(.white) }
                        Text("모바일 청첩장").font(WPFont.hak(22, .bold)).foregroundStyle(.white).padding(.top, 16)
                        if let saved = model.result?.invitation {
                            Text("\(saved.published ? "공개 중" : "공개 전")  ·  사진 \(saved.photos.count)장\(model.total.map { "  ·  축하 \($0)" } ?? "")")
                                .font(WPFont.hak(13)).foregroundStyle(.white).padding(.top, 12)
                        }
                    }
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
                            groom: model.result?.invitation?.groom ?? "정우진", bride: model.result?.invitation?.bride ?? "한채원")
                            .frame(height: min(geometry.size.width * 440 / 320, max(360, geometry.size.height - wpStatusBarHeight - 142)))
                            .id(model.state == .landing ? "landing" : model.state == .empty ? "empty" : "mine")
                        details.padding(24)
                    }
                }
            }.background(.white)
                .refreshable { await model.load(env) }
        }.ignoresSafeArea(edges: .top).font(.custom("KakaoSmallSans-Regular", size: 14))
            .task { await model.load(env) }
            .fullScreenCover(isPresented: $edit, onDismiss: { Task { await model.load(env) } }) {
                InvitationEditorView(saved: model.result?.invitation, roomId: model.result?.roomId)
            }
            .fullScreenCover(isPresented: $preview) {
                InvitationPreviewView(content: model.result?.invitation ?? Self.example)
            }
            .fullScreenCover(isPresented: $pass, onDismiss: { Task { await model.load(env) } }) { PassView(roomId: model.result?.roomId) }
            .confirmationDialog(model.result?.invitation?.published == true ? "청첩장을 비공개로 바꿀까요?" : "청첩장을 공개할까요?", isPresented: $confirmPublish, titleVisibility: .visible) {
                Button(model.result?.invitation?.published == true ? "비공개로 바꾸기" : "공개하기") {
                    Task { await model.publish(model.result?.invitation?.published != true, env: env) }
                }
            } message: { Text("공개하면 링크를 받은 누구나 로그인 없이 볼 수 있어요.") }
    }
    @ViewBuilder private var details: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let saved = model.result?.invitation {
                Text(saved.title).font(.custom("KakaoSmallSans-Bold", size: 28))
                Text("\(saved.groom) · \(saved.bride)")
                if let error = model.error { Text(error).foregroundStyle(.red) }
                if saved.published, let url = URL(string: AppConfig.webBaseURL + "/invitation/" + saved.slug) {
                    ShareLink(item: url) { Label("청첩장 링크 보내기", systemImage: "square.and.arrow.up") }.buttonStyle(InvitationActionStyle())
                    HStack {
                        Text(url.absoluteString.replacingOccurrences(of: "https://", with: "")).font(.system(size: 12)).lineLimit(2)
                        Spacer()
                        Button("복사") { UIPasteboard.general.url = url }
                    }
                    if let image = qr(url.absoluteString) { Image(uiImage: image).interpolation(.none).resizable().frame(width: 140, height: 140).frame(maxWidth: .infinity).accessibilityLabel("청첩장 QR 코드") }
                }
                Button("청첩장 고치기") { edit = true }.buttonStyle(InvitationActionStyle()).disabled(model.result?.canEdit != true)
                Button("하객이 보는 청첩장") { preview = true }.buttonStyle(InvitationActionStyle(primary: false))
                Button(saved.published ? "비공개로 돌리기" : "공개하기") { confirmPublish = true }.disabled(model.busy || model.result?.canEdit != true)
                Divider()
                Text("담긴 것").font(.custom("KakaoSmallSans-Bold", size: 18))
                ForEach(InvitationRules.normalize(saved.design).sections, id: \.type) { section in
                    Button { edit = true } label: {
                        HStack {
                            Text(label(section.type)); Spacer(); Text(section.visible ? "켜짐" : "꺼짐").foregroundStyle(.secondary); Image(systemName: "chevron.right")
                        }.padding(.vertical, 8)
                    }.disabled(model.result?.canEdit != true)
                }
                if !model.wishes.isEmpty {
                    Text("축하 글 \(model.total ?? model.wishes.count)").font(.custom("KakaoSmallSans-Bold", size: 18))
                    ForEach(model.wishes, id: \.id) { wish in
                        VStack(alignment: .leading, spacing: 6) { Text(wish.name).bold(); Text(wish.message) }.padding(.vertical, 8)
                    }
                }
            } else {
                let empty = model.state == .empty
                Text(empty ? "준비 패스 이용 중" : "준비 패스에 포함된 모바일 청첩장").font(.custom("KakaoSmallSans-Regular", size: 12))
                Text(empty ? "OUR GARDEN IS READY" : "OUR OWN LITTLE GARDEN").font(.system(size: 10)).tracking(2).foregroundStyle(.secondary)
                Text(empty ? "정원은 준비됐어요.\n하객 자리가 비어 있어요." : "링크 하나로,\n하객이 정원에 걸어와요.")
                    .font(.custom("KakaoSmallSans-Bold", size: 28)).lineSpacing(8)
                Text("사진과 예식 정보를 담은 모바일 청첩장. 받은 사람이 축하를 남기면 그 사람이 픽셀 하객이 되어 두 사람 곁에 서요.").lineSpacing(7)
                Text("청첩장에 담기는 것").font(.custom("KakaoSmallSans-Bold", size: 16))
                ForEach(["분위기 · 가든 / 아이보리 / 로즈", "사진 최대 20장", "예식 날짜 · 장소", "초대의 말 · 가족 소개", "계좌 · 안내 말씀", "하객의 축하 글"], id: \.self) { Text($0).padding(.vertical, 3) }
                Button(empty ? "청첩장 만들기" : "준비 패스로 시작하기") { if empty { edit = true } else { pass = true } }
                    .buttonStyle(InvitationActionStyle()).accessibilityIdentifier("invitation.primary")
                Button("예시 청첩장 구경하기") { preview = true }.buttonStyle(InvitationActionStyle(primary: false))
                Text("준비 패스로 우리 청첩장 한 장 · 패스가 끝나도 그대로").font(.custom("KakaoSmallSans-Regular", size: 11)).foregroundStyle(.secondary)
            }
        }.foregroundStyle(Color(hex: 0x173C2F))
    }
    static var example: InvitationContent {
        var result = InvitationRules.draft(); result.groom = "정우진"; result.bride = "한채원"
        result.weddingDate = "2027-05-22"; result.venue = "바닷가 정원"; return result
    }
    private func label(_ type: String) -> String { InvitationRules.sectionTypes.firstIndex(of: type).map { InvitationRules.sectionLabels[$0] } ?? type }
    private func qr(_ value: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(value.utf8)
        guard let output = filter.outputImage, let image = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: image)
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
