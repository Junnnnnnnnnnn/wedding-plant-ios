import SwiftUI
import WPModels
import WPNetworking
@MainActor final class InboxModel: ObservableObject {
    @Published var page: InboxPage?
    @Published var busy = false
    @Published var error: String?
    func load(_ env: AppEnvironment, more: Bool = false) async {
        guard !busy else { return }
        let before = more ? page?.nextCursor : nil
        if more && before == nil { return }
        busy = true; error = nil; defer { busy = false }
        do {
            var result: InboxPage = try await env.api.send(Endpoint.inbox(before: before))
            if more { result.items = (page?.items ?? []) + result.items }
            page = result
        } catch { if !error.isCancellation { self.error = "알림을 불러오지 못했어요. 다시 시도해 주세요." } }
    }
    func clear(_ env: AppEnvironment) async {
        guard !busy else { return }; busy = true; error = nil; defer { busy = false }
        do { page = try await env.api.send(Endpoint.clearUnreadInbox()) }
        catch { if !error.isCancellation { self.error = "알림을 지우지 못했어요. 다시 시도해 주세요." } }
    }
    func read(_ item: InboxItem, env: AppEnvironment) async -> Bool {
        guard !busy else { return false }; busy = true; error = nil; defer { busy = false }
        do { page = try await env.api.send(Endpoint.readInbox(item.id)); return true }
        catch { if !error.isCancellation { self.error = "알림을 읽지 못했어요. 다시 시도해 주세요." }; return false }
    }
}
struct InboxBell: View {
    let unread: Int
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "bell").font(.system(size: 22)).foregroundStyle(.white).frame(width: 44, height: 44)
                .overlay(alignment: .topTrailing) {
                    if unread > 0 { Circle().fill(WPColor.inboxDot).frame(width: 7, height: 7).padding(7) }
                }
        }.accessibilityLabel(unread > 0 ? "알림, 읽지 않은 알림 \(unread) 개" : "알림").accessibilityIdentifier("main.inbox")
    }
}
struct InboxView: View {
    @ObservedObject var model: InboxModel
    let onOpen: (InboxItem) -> Void
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if model.busy { ProgressView().frame(maxWidth: .infinity).padding() }
                    if let error = model.error {
                        Text(error).padding()
                        Button("다시 시도") { Task { await model.load(env) } }.padding()
                    }
                    if let page = model.page {
                        if page.items.isEmpty { Text("아직 알림이 없어요").padding(32).accessibilityIdentifier("inbox.empty") }
                        ForEach(page.items) { item in
                            Button {
                                Task { if await model.read(item, env: env) { dismiss(); onOpen(item) } }
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Circle().fill(item.readAt == nil ? WPColor.inboxDot : .clear).frame(width: 7, height: 7).padding(.top, 7)
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(item.body).font(WPFont.hak(16)).foregroundStyle(WPColor.fgNeutral)
                                        Text(item.readAt == nil ? "읽지 않음" : "읽음").font(WPFont.hak(12)).foregroundStyle(WPColor.fgMuted)
                                    }
                                    Spacer(minLength: 0)
                                }.padding(20).contentShape(Rectangle())
                            }.buttonStyle(.plain).disabled(model.busy).accessibilityIdentifier("inbox.item.\(item.id)")
                            Divider()
                        }
                        if page.nextCursor != nil { Button("더 보기") { Task { await model.load(env, more: true) } }.padding().disabled(model.busy) }
                    }
                }
            }.navigationTitle("알림").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("닫기") { dismiss() } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("읽지 않은 알림 지우기") { Task { await model.clear(env) } }
                            .font(WPFont.hak(12)).disabled(model.busy || (model.page?.unreadCount ?? 0) == 0).accessibilityIdentifier("inbox.clearUnread")
                    }
                }
        }.task { await model.load(env) }
    }
}
