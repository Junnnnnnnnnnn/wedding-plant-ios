import SwiftUI
import WPDomain
import WPModels
import WPNetworking
import WPUtils

struct CoupleChatTab: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase
    @State private var state: CoupleChatState = .loading
    @State private var name = "나"
    @State private var invite: ShareCode?
    @State private var share = false
    @State private var sent = false
    @State private var error: String?
    var body: some View {
        Group {
            switch state {
            case .loading: ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .error:
                VStack(spacing: 16) {
                    Text("대화를 불러오지 못했어요.\n네트워크 상태를 확인한 뒤 다시 시도해 주세요.").multilineTextAlignment(.center)
                    Button("다시 시도") { Task { await load() } }.buttonStyle(.borderedProminent)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready(let chat, let room, let date, let partner):
                ChatView(chatRoomId: chat, standalone: true, planRoomId: room, weddingDate: date, partnerName: partner).id(chat)
            case .solo, .unavailable: solo
            }
        }.background(.white).task { await load() }
            .onChange(of: env.roomsRevision) { _, _ in Task { await load() } }
            .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await load() } } }
            .sheet(isPresented: $share) {
                if let invite, let url = ShareLink.inviteURL(webBaseURL: AppConfig.webBaseURL, code: invite.shareCode, asSpouse: true) {
                    ActivityShareSheet(items: ["우리 결혼 준비, 같이 하자!\n" + url], onComplete: { completed in if completed { sent = true } })
                }
            }
    }
    private var solo: some View {
        CoupleChatInviteBody(name: name, unavailable: state == .unavailable,
            enabled: invite?.canInvite == true && invite?.shareCode.isEmpty == false,
            message: error ?? (invite?.canInvite == false ? "이미 신랑·신부와 함께하고 있어요" : sent ? "보냈어요. 들어오면 여기가 대화로 바뀌어요." : "링크는 신랑·신부 한 사람만 쓸 수 있어요"),
            onInvite: { share = true })
    }
    private func load() async {
        let token = await env.tokenStore.currentToken() ?? "", me = JWTDecoder.planUserId(from: token)
        do {
            let page: RoomList = try await env.api.send(Endpoint.roomList())
            guard JWTDecoder.planUserId(from: await env.tokenStore.currentToken() ?? "") == me else { return }
            state = CoupleChatRules.pick(page.list, myId: me)
            if state == .solo {
                do { invite = try await env.api.send(Endpoint.shareCode()); error = nil } catch { self.error = "링크를 불러오지 못했습니다." }
                if let user: PlanUser = try? await env.api.send(Endpoint.user()), let value = user.name, !value.isEmpty { name = value }
            }
        } catch { if state == .loading || state == .error { state = .error } }
    }
}

/// Android SoloChatHeader + CoupleChatInvite. 테스트도 이 본문을 같은 크기로 렌더링한다.
struct CoupleChatInviteBody: View {
    var name: String
    var unavailable = false
    var enabled = true
    var message = "링크는 신랑·신부 한 사람만 쓸 수 있어요"
    var onInvite: () -> Void = {}
    var body: some View {
        VStack(spacing: 0) {
            BrandHead(corner: 22, horizontal: 16, top: 6, bottom: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("채팅").wpTypography(18, .bold, face: .kakao, lineHeight: 22.5)
                    Text("신랑·신부와 둘이 쓰는 자리").wpTypography(12.5, face: .kakao).opacity(0.85)
                }.frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).foregroundStyle(.white)
            }
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                ZStack(alignment: .topLeading) {
                    Text(String(name.trimmingCharacters(in: .whitespaces).prefix(1))).wpTypography(22, .bold, face: .kakao)
                        .foregroundStyle(.white).frame(width: 64, height: 64).background(WPColor.primary, in: Circle())
                        .shadow(color: WPColor.primary.opacity(0.18), radius: 3, y: 3).offset(x: 6, y: 10)
                    Text("?").wpTypography(22, .bold, face: .kakao).foregroundStyle(Color(hex: 0xE58AB5))
                        .frame(width: 64, height: 64).background(.white, in: Circle())
                        .overlay(Circle().inset(by: 1).stroke(Color(hex: 0xF0B8D3), style: StrokeStyle(lineWidth: 2, dash: [5,4])))
                        .offset(x: 62, y: 10)
                }.frame(width: 132, height: 84, alignment: .topLeading)
                Text(unavailable ? "대화방을 열지 못했어요" : "함께 준비할 사람을\n불러 주세요")
                    .tracking(-0.6).wpTypography(20, .bold, face: .kakao, lineHeight: 27.5).fixedSize(horizontal: false, vertical: true).foregroundStyle(WPColor.textPrimary).padding(.top, 20)
                Text((unavailable ? "신랑·신부는 있는데 두 사람의 대화방이 없어요. 고객센터로 알려 주시면 바로 열어 드릴게요." : "링크를 받은 사람이 들어오면 여기서 둘이 이야기하고, 일정과 예산도 같이 봐요.").wpKeepAll)
                    .wpTypography(14.5, face: .kakao, lineHeight: 23.5).foregroundStyle(Color(hex: 0x7A6C74)).frame(maxWidth: 260).padding(.top, 8)
                if !unavailable {
                    Button(action: onInvite) {
                        HStack(spacing: 8) {
                            WPLink2().stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)).frame(width: 16, height: 16)
                            Text("초대 링크 보내기").wpTypography(15.5, .bold, face: .kakao).fixedSize()
                        }.foregroundStyle(.white).padding(.horizontal, 20).frame(height: 48)
                            .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 14))
                            .shadow(color: WPColor.primary.opacity(0.18), radius: 3, y: 3)
                    }.buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.5).padding(.top, 20).accessibilityIdentifier("chat.invite")
                    Text(message.wpKeepAll).wpTypography(12.5, face: .kakao).foregroundStyle(Color(hex: 0x7A6C74)).padding(.top, 12)
                }
                Spacer(minLength: 0)
            }.multilineTextAlignment(.center).padding(.horizontal, 28).padding(.vertical, 24)
        }.background(.white).ignoresSafeArea(edges: .top)
    }
}
/// Lucide Link2: Android와 같은 가로 연결 고리.
struct WPLink2: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 9, y: 17)); p.addLine(to: CGPoint(x: 7, y: 17))
        p.addArc(center: CGPoint(x: 7, y: 12), radius: 5, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false); p.addLine(to: CGPoint(x: 9, y: 7))
        p.move(to: CGPoint(x: 15, y: 7)); p.addLine(to: CGPoint(x: 17, y: 7))
        p.addArc(center: CGPoint(x: 17, y: 12), radius: 5, startAngle: .degrees(270), endAngle: .degrees(450), clockwise: false); p.addLine(to: CGPoint(x: 15, y: 17))
        p.move(to: CGPoint(x: 8, y: 12)); p.addLine(to: CGPoint(x: 16, y: 12))
        return p.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}
