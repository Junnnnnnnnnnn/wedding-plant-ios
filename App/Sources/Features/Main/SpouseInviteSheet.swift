import SwiftUI
import WPDomain
import WPModels
import WPNetworking

struct SpouseInviteSheet: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var invite: ShareCode?
    @State private var user: PlanUser?
    @State private var bound: Plan?
    @State private var loading = true
    @State private var busy = false
    @State private var share = false
    @State private var confirming = false
    @State private var error: String?
    private var couple: [Member] { (user?.members ?? []).filter { ["OWNER", "SPOUSE"].contains($0.permission.rawValue.uppercased()) } }
    private var canRemove: Bool { couple.contains { $0.planUserId == user?.id && $0.permission == .owner } && couple.contains { $0.permission == .spouse } }
    private var url: String? { invite.flatMap { ShareLink.inviteURL(webBaseURL: AppConfig.webBaseURL, code: $0.shareCode, asSpouse: true) } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("신랑 · 신부를 초대해 함께 준비해요").font(WPFont.hak(13)).foregroundStyle(WPColor.gray400)
                    Text("신랑 · 신부 두 사람이 함께 써요").font(WPFont.hak(11, .bold)).foregroundStyle(WPColor.primary).padding(12).frame(maxWidth: .infinity).background(WPColor.primary.opacity(0.04), in: Capsule())
                    if loading { ProgressView().frame(maxWidth: .infinity) }
                    if let bound {
                        Text(bound.ownerName.isEmpty ? "신랑 · 신부로 함께 쓰는 플랜이 있어요." : "\(bound.ownerName)님 플랜을 신랑 · 신부로 함께 쓰고 있어요.")
                        Button("함께하기 그만두기", role: .destructive) { confirming = true }.disabled(busy)
                    } else {
                        ForEach(couple) { member in
                            HStack {
                                Text(String(member.name.prefix(1))).frame(width: 40, height: 40).background(WPColor.primary.opacity(0.1), in: Circle())
                                Text(member.name); Spacer(); Text(member.permission == .owner ? "방장" : "신랑 · 신부").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        if canRemove { Button("신랑 · 신부 해제", role: .destructive) { confirming = true }.disabled(busy) }
                        if invite?.canInvite == true, let url {
                            Text("우리 결혼 준비, 같이 하자!").font(WPFont.hak(18, .bold))
                            Text("일정과 예산, 준비 패스를 함께 쓸 수 있어요.").font(WPFont.hak(13)).foregroundStyle(WPColor.gray500)
                            Button { share = true } label: { Label("초대 링크 보내기", systemImage: "link").frame(maxWidth: .infinity).frame(height: 48) }.buttonStyle(.borderedProminent).accessibilityIdentifier("invite.spouse")
                            Button("링크 복사") { UIPasteboard.general.string = url }.frame(maxWidth: .infinity)
                        } else if !loading && invite != nil { Text("이미 신랑 · 신부와 함께 쓰는 플랜이 있어요.").font(.footnote).foregroundStyle(.secondary) }
                    }
                    if let error { Text(error).foregroundStyle(.red); Button("다시 시도") { Task { await load() } } }
                }.padding(20)
            }.navigationTitle("플랜 공유하기").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() }.disabled(busy) } }
        }.presentationDetents([.medium, .large]).interactiveDismissDisabled(busy).task { await load() }
            .sheet(isPresented: $share) { if let url { ActivityShareSheet(items: ["우리 결혼 준비, 같이 하자!\n" + url]) } }
            .confirmationDialog(bound == nil ? "신랑 · 신부를 해제할까요?" : "함께하기를 그만둘까요?", isPresented: $confirming, titleVisibility: .visible) {
                Button(bound == nil ? "해제하기" : "그만두기", role: .destructive) { Task { await unlink() } }
            } message: {
                Text(bound == nil ? "해제하면 신랑 · 신부가 이 플랜과 대화방에서 빠져요. 주고받은 대화와 일정은 남고, 초대 링크는 새로 바뀌어요." : "그만두면 이 플랜과 대화방에서 빠지고, 홈이 내 플랜으로 돌아가요. 주고받은 대화와 일정은 남아요.")
            }
    }
    private func load() async {
        loading = true; error = nil; defer { loading = false }
        do {
            user = try await env.api.send(Endpoint.user())
            let rooms: RoomList = try await env.api.send(Endpoint.roomList())
            bound = BoundRoom.find(in: rooms.list, planUserId: user?.id)
            invite = try await env.api.send(Endpoint.shareCode())
        } catch { self.error = error.localizedDescription }
    }
    private func unlink() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        let leaving = bound != nil
        do {
            try await env.api.sendIgnoringData(HTTPRequest(method: leaving ? .post : .delete, path: leaving ? "/plan/room/leave" : "/plan/room/spouse"))
            env.boundRoom = .unknown; env.boundRoomPlan = nil
            await env.refreshBoundRoom(); env.roomsRevision += 1
            if leaving { dismiss() } else { await load() }
        } catch { self.error = error.localizedDescription }
    }
}

/// 시스템 공유 시트.
struct ActivityShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    var onComplete: ((Bool) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in onComplete?(completed) }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
