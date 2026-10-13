import SwiftUI
import WPNetworking

struct ModerationMenu: View {
    let targetType: String
    let targetId: Int
    var onHidden: () -> Void = {}
    var compact = false
    @EnvironmentObject private var env: AppEnvironment
    @State private var report = false
    @State private var block = false
    @State private var busy = false
    @State private var message: String?
    var body: some View {
        Menu {
            Button("신고하기", role: .destructive) { report = true }
            if targetType != "CHAT_MESSAGE" { Button("이 작성자 차단", role: .destructive) { block = true } }
        } label: { Image(systemName: "ellipsis").font(.system(size: compact ? 12 : 17)).frame(width: compact ? 28 : 44, height: compact ? 28 : 44) }
            .accessibilityLabel("신고·차단").disabled(busy)
            .sheet(isPresented: $report) { ReportContentSheet(targetType: targetType, targetId: targetId) { if targetType != "CHAT_MESSAGE" { onHidden() } } }
            .confirmationDialog("이 작성자를 차단할까요?", isPresented: $block, titleVisibility: .visible) {
                Button("차단", role: .destructive) { Task { await blockAuthor() } }
            } message: { Text("앞으로 이 사람이 올리는 글이 회원님 화면에 보이지 않아요. 상대에게는 알려지지 않고, 프로필 > 차단 관리에서 언제든 풀 수 있어요.") }
            .alert("안내", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("확인") {} } message: { Text(message ?? "") }
    }
    private func blockAuthor() async {
        busy = true; defer { busy = false }
        struct Body: Encodable { let targetType: String; let targetId: Int }
        do {
            try await env.api.sendIgnoringData(HTTPRequest.json(.post, "/plan/moderation/block", body: Body(targetType: targetType, targetId: targetId)))
            env.moderationRevision += 1; onHidden()
        } catch { message = error.localizedDescription }
    }
}
struct ReportContentSheet: View {
    let targetType: String
    let targetId: Int
    var onHidden: () -> Void
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var detail = ""
    @State private var busy = false
    @State private var sent = false
    @State private var error: String?
    private let reasons = [("SPAM","스팸이거나 광고예요"),("ABUSE","욕설·비방이 있어요"),("SEXUAL","선정적이거나 불쾌해요"),("FALSE_INFO","금액·업체 정보가 사실과 달라요"),("PRIVACY","남의 개인정보가 드러나 있어요"),("OTHER","그 밖의 이유")]
    var body: some View {
        NavigationStack {
            Form {
                if sent {
                    Text(targetType == "CHAT_MESSAGE" ? "신고를 접수했어요. 운영자가 확인한 뒤 필요하면 조치합니다." : "신고를 접수했어요. 이 글은 회원님 화면에서 바로 사라집니다.")
                    Button("확인") { dismiss(); onHidden() }
                } else {
                    Text(targetType == "CHAT_MESSAGE" ? "운영자가 확인한 뒤 필요하면 조치합니다. 대화 흐름이 끊기지 않게 메시지는 그대로 남아요." : "신고한 글은 회원님 화면에서 바로 사라져요. 확인 뒤 필요하면 모두에게 보이지 않도록 조치합니다.")
                    ForEach(reasons, id: \.0) { value in
                        Button { reason = value.0 } label: { HStack { Text(value.1); Spacer(); if reason == value.0 { Image(systemName: "checkmark") } } }
                    }
                    if reason == "OTHER" { TextField("조금 더 알려 주세요", text: $detail, axis: .vertical).onChange(of: detail) { _, v in detail = String(v.prefix(500)) } }
                    if let error { Text(error).foregroundStyle(.red) }
                    Button(busy ? "보내는 중…" : "신고 보내기") { Task { await submit() } }.disabled(reason.isEmpty || busy)
                }
            }.navigationTitle("신고하기").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss(); if sent { onHidden() } }.disabled(busy) } }
        }.interactiveDismissDisabled(busy || sent)
    }
    private func submit() async {
        busy = true; defer { busy = false }
        struct Body: Encodable { let targetType: String; let targetId: Int; let reason: String; let detail: String? }
        do {
            try await env.api.sendIgnoringData(HTTPRequest.json(.post, "/plan/moderation/report", body: Body(targetType: targetType, targetId: targetId, reason: reason, detail: detail.isEmpty ? nil : detail)))
            sent = true; env.moderationRevision += 1
        } catch { self.error = error.localizedDescription }
    }
}
struct BlockListView: View {
    struct Blocked: Decodable, Sendable, Identifiable { let id: Int; let displayName: String }
    @EnvironmentObject private var env: AppEnvironment
    @State private var items: [Blocked] = []
    @State private var error: String?
    @State private var pending: Blocked?
    var body: some View {
        List {
            if items.isEmpty && error == nil { Text("차단한 사용자가 없어요") }
            ForEach(items) { item in HStack { Text(item.displayName); Spacer(); Button("해제") { pending = item } } }
            if let error { Text(error).foregroundStyle(.red) }
        }.navigationTitle("차단 관리").task { await load() }
            .confirmationDialog("차단을 해제할까요?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), titleVisibility: .visible) {
                Button("차단 해제") {
                    guard let item = pending else { return }
                    Task {
                        do { try await env.api.sendIgnoringData(HTTPRequest(method: .delete, path: "/plan/moderation/block/\(item.id)")); env.moderationRevision += 1; await load() }
                        catch { self.error = error.localizedDescription }; pending = nil
                    }
                }
            }
    }
    private func load() async { do { items = try await env.api.send(HTTPRequest(path: "/plan/moderation/block/list")) } catch { self.error = error.localizedDescription } }
}
