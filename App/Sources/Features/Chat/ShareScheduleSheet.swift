import SwiftUI
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 이 일정을 **신랑·신부와의 대화에** 보내는 시트 — 안드로이드 `ui/detail/ShareScheduleSheet.kt`
/// (웹 `ShareToChatSheet`).
///
/// 고를 방이 없다(대화는 둘만의 것 하나). 그래도 누르자마자 보내지 않고 `현우에게 보내기` 를 한 번
/// 누르게 한다 — 누가 받는지가 버튼에 적혀 있어야 잘못 누른 것을 알아챈다. 보낸 뒤에는 체크를
/// 1.1초 보이고 스스로 닫는다. 아직 혼자면 보낼 곳이 없다고 말한다.
struct ShareScheduleSheet: View {
    let scheduleId: Int
    let title: String
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var state: CoupleChatState = .loading
    @State private var height: CGFloat = 200

    var body: some View {
        VStack(spacing: 0) {
            WPSheetHandle()
            if case let .ready(chat, room, _, _) = state {
                ShareScheduleSender(scheduleId: scheduleId, title: title, couple: state, chatRoomId: chat, roomId: room) { dismiss() }
            } else {
                ShareScheduleBody(title: title, couple: state, sending: false, done: false, error: nil, onClose: { dismiss() }, onSend: {})
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = ceil($0) }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .wpBottomSheet(height: height, corner: 22)
        .task { await load() }
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

/// 둘이 있을 때 — 이 대화방의 소켓을 붙여 보낸다. 붙기 전에 누르면 붙는 대로 보낸다.
private struct ShareScheduleSender: View {
    let scheduleId: Int
    let title: String
    let couple: CoupleChatState
    let onClose: () -> Void
    @StateObject private var model: ChatViewModel
    @EnvironmentObject private var env: AppEnvironment
    @State private var waiting = false

    init(scheduleId: Int, title: String, couple: CoupleChatState, chatRoomId: Int, roomId: Int, onClose: @escaping () -> Void) {
        self.scheduleId = scheduleId; self.title = title; self.couple = couple; self.onClose = onClose
        _model = StateObject(wrappedValue: ChatViewModel(chatRoomId: chatRoomId, planRoomId: roomId))
    }

    var body: some View {
        ShareScheduleBody(
            title: title, couple: couple,
            sending: waiting || model.sharingSchedule != nil,
            done: model.sharedSchedule != nil,
            error: model.shareError,
            onClose: onClose,
            onSend: send
        )
        .interactiveDismissDisabled(waiting || model.sharingSchedule != nil)
        .task { await model.start(env: env) }
        .onDisappear { model.leave() }
        .onChange(of: model.connected) { _, connected in
            if connected && waiting { waiting = false; model.shareSchedule(scheduleId) }
        }
        .onChange(of: model.sharedSchedule) { _, id in
            // 보냈다 — 체크를 1.1초 보이고 닫는다(안드로이드와 같음)
            if id != nil { Task { try? await Task.sleep(for: .milliseconds(1100)); onClose() } }
        }
        .sensoryFeedback(.success, trigger: model.sharedSchedule) { _, new in new != nil }
    }

    private func send() {
        model.shareError = nil
        if model.connected { model.shareSchedule(scheduleId); return }
        // 아직 붙는 중 — 붙는 대로 보낸다. 10초 안에 못 붙으면 실패로 알린다.
        waiting = true
        Task {
            try? await Task.sleep(for: .seconds(10))
            if waiting { waiting = false; model.shareError = ChatViewModel.shareFailedMessage }
        }
    }
}

/// 시트 속 — 머리(제목·일정 제목·닫기) · 버튼 하나 또는 빈 상태 · 오류 줄. **상태 없이** 찍는다.
struct ShareScheduleBody: View {
    var title: String?
    var couple: CoupleChatState
    var sending: Bool
    var done: Bool
    var error: String?
    var onClose: () -> Void = {}
    var onSend: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("채팅으로 보내기").tracking(-0.34).wpTypography(17, .bold).foregroundStyle(WPColor.textPrimary)
                    if let title, !title.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(title).wpTypography(13).foregroundStyle(WPColor.chatShareSub).lineLimit(1).padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                WPSheetCloseButton(action: onClose)
            }
            Color.clear.frame(height: 16)
            content
            if let error {
                Text(error.wpKeepAll).wpTypography(12.5).foregroundStyle(WPColor.danger)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 12)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }

    @ViewBuilder private var content: some View {
        switch couple {
        case .loading:
            // 받기 전에는 "없다" 고 말하지 않는다 — 버튼 모양 뼈대
            SkeletonBox(height: 52, corner: 16)
        case let .ready(_, _, _, partnerName):
            let partner = partnerName ?? "신랑·신부"
            let enabled = !sending && !done
            Button(action: onSend) {
                HStack(spacing: 8) {
                    WPLucideIcon(paths: done ? WPIconPaths.lucideCheck : WPIconPaths.lucideSend, size: 16, color: .white,
                                 strokeWidth: done ? 3 : 2)
                    Text(done ? "\(partner)에게 보냈어요" : "\(partner)에게 보내기").wpTypography(15.5, .bold)
                        .foregroundStyle(.white).lineLimit(1)
                }
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 16))
                .contentShape(RoundedRectangle(cornerRadius: 16))
                // 면·아이콘·글자를 함께 흐리게(보내는 중·보낸 뒤)
                .opacity(enabled ? 1 : 0.6)
            }
            .buttonStyle(.plain).allowsHitTesting(enabled).accessibilityIdentifier("share.send")
        default:
            // 혼자·대화방 없음·못 받음 — 보낼 곳이 없다고 말한다(대화방 없음도 혼자와 같은 문장)
            VStack(spacing: 0) {
                WPEmptyIconCircle(paths: WPIconPaths.messageCircle)
                Text(couple == .error ? "대화를 불러오지 못했어요." : "아직 함께 준비하는 사람이 없어요.")
                    .wpTypography(13.5).foregroundStyle(WPColor.stone600).padding(.top, 12)
                if couple != .error {
                    Text("신랑 · 신부를 초대하면 둘이 이야기할 수 있어요.".wpKeepAll).wpTypography(12.5, lineHeight: 20)
                        .foregroundStyle(WPColor.gray500).multilineTextAlignment(.center).padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }
}
