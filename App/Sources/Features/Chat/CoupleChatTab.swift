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
        VStack(spacing: 0) {
            BrandHead(corner: 22, horizontal: 16, top: 6, bottom: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("채팅").font(.custom("KakaoSmallSans-Bold", size: 18))
                    Text("신랑·신부와 둘이 쓰는 자리").font(.custom("KakaoSmallSans-Regular", size: 12.5)).opacity(0.85)
                }.frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).foregroundStyle(.white)
            }
            Spacer()
            VStack(spacing: 0) {
                HStack(spacing: -8) {
                    Text(String(name.prefix(1))).font(.custom("KakaoSmallSans-Bold", size: 22)).foregroundStyle(.white).frame(width: 64, height: 64).background(WPColor.primary, in: Circle())
                    Text("?").font(.custom("KakaoSmallSans-Bold", size: 22)).foregroundStyle(WPColor.primary).frame(width: 64, height: 64).background(.white, in: Circle()).overlay(Circle().stroke(WPColor.primary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5,4])))
                }.frame(height: 84)
                Text(state == .unavailable ? "대화방을 준비하고 있어요" : "같이 준비할 사람을\n불러 주세요").font(.custom("KakaoSmallSans-Bold", size: 20)).tracking(-0.6).lineSpacing(5).padding(.top, 20)
                Text(state == .unavailable ? "신랑·신부는 있는데 두 사람의 대화방이 없어요. 고객센터로 알려 주시면 바로 열어 드릴게요." : "링크를 받은 사람이 들어오면 여기서 둘이 이야기하고, 일정과 예산도 같이 봐요.").font(.custom("KakaoSmallSans-Regular", size: 14.5)).lineSpacing(7).foregroundStyle(WPColor.gray500).frame(maxWidth: 260).padding(.top, 8)
                if state == .solo {
                    Button { share = true } label: { Label("초대 링크 보내기", systemImage: "link").font(.custom("KakaoSmallSans-Bold", size: 15.5)).foregroundStyle(.white).padding(.horizontal, 20).frame(height: 48).background(WPColor.primary, in: RoundedRectangle(cornerRadius: 14)) }.disabled(invite?.canInvite != true || invite?.shareCode.isEmpty != false).padding(.top, 20).accessibilityIdentifier("chat.invite")
                    Text(error ?? (invite?.canInvite == false ? "이미 신랑·신부와 함께하고 있어요" : sent ? "보냈어요. 들어오면 여기가 대화로 바뀌어요." : "링크는 신랑·신부 한 사람만 쓸 수 있어요")).font(.custom("KakaoSmallSans-Regular", size: 12.5)).foregroundStyle(WPColor.gray500).padding(.top, 12)
                }
            }.multilineTextAlignment(.center).padding(28)
            Spacer()
        }.ignoresSafeArea(edges: .top)
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
