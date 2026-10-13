import SwiftUI
import WPDomain
import WPModels
import WPNetworking
import WPUtils

struct ShareScheduleSheet: View {
    let scheduleId: Int
    let title: String
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var state: CoupleChatState = .loading
    @State private var invite = false
    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .loading: ProgressView()
                case .ready(let chat, let room, _, let name): ShareScheduleConfirmation(scheduleId: scheduleId, title: title, chatRoomId: chat, roomId: room, partner: name ?? "신랑·신부")
                case .solo:
                    VStack(spacing: 18) {
                        Text("아직 함께 준비하는 사람이 없어요").font(WPFont.hak(20, .bold))
                        Text("신랑 · 신부를 초대하면 플랜을 보낼 수 있어요").font(WPFont.hak(14)).foregroundStyle(.secondary)
                        Button("신랑 · 신부 초대하기") { invite = true }.buttonStyle(InvitationActionStyle())
                    }.padding(24)
                case .error, .unavailable:
                    VStack(spacing: 18) { Text("신랑 · 신부 대화를 불러오지 못했어요"); Button("다시 시도") { Task { await load() } } }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity).navigationTitle("채팅으로 보내기").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
        }.presentationDetents([.medium, .large]).task { await load() }
            .sheet(isPresented: $invite) { SpouseInviteSheet() }
    }
    private func load() async {
        state = .loading
        do {
            let token = await env.tokenStore.currentToken() ?? ""
            let page: RoomList = try await env.api.send(Endpoint.roomList())
            guard JWTDecoder.planUserId(from: await env.tokenStore.currentToken() ?? "") == JWTDecoder.planUserId(from: token) else { return }
            state = CoupleChatRules.pick(page.list, myId: JWTDecoder.planUserId(from: token))
        } catch { state = .error }
    }
}
private struct ShareScheduleConfirmation: View {
    let scheduleId: Int
    let title: String
    let partner: String
    @StateObject private var model: ChatViewModel
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    init(scheduleId: Int, title: String, chatRoomId: Int, roomId: Int, partner: String) {
        self.scheduleId = scheduleId; self.title = title; self.partner = partner
        _model = StateObject(wrappedValue: ChatViewModel(chatRoomId: chatRoomId, planRoomId: roomId))
    }
    var body: some View {
        VStack(spacing: 18) {
            Text("\(partner)에게 이 플랜을 보내요").font(WPFont.hak(18, .bold))
            Text(title).font(WPFont.hak(16)).padding(20).frame(maxWidth: .infinity).background(WPColor.fill, in: RoundedRectangle(cornerRadius: 16))
            if let error = model.shareError ?? model.errorMessage { Text(error).font(.footnote).foregroundStyle(.red) }
            Button { model.shareSchedule(scheduleId) } label: {
                Text(model.sharedSchedule != nil ? "보냈어요" : model.sharingSchedule != nil ? "보내는 중…" : model.connected ? "보내기" : "연결 중…")
            }.buttonStyle(InvitationActionStyle()).disabled(!model.connected || model.sharingSchedule != nil || model.sharedSchedule != nil)
        }.padding(24).task { await model.start(env: env) }.onDisappear { model.leave() }
            .onChange(of: model.sharedSchedule) { _, id in if id != nil { Task { try? await Task.sleep(for: .milliseconds(600)); dismiss() } } }
    }
}
