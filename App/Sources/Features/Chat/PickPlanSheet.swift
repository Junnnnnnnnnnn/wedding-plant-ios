import SwiftUI
import WPModels
import WPNetworking

struct PickPlanSheet: View {
    let roomId: Int?
    @ObservedObject var model: ChatViewModel
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var items: [ScheduleItem]?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 6) {
                    if let items {
                        if items.isEmpty { Text("아직 만든 플랜이 없어요.").padding(32) }
                        ForEach(items) { item in
                            Button { model.shareSchedule(item.id) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) { Text(item.title).font(WPFont.hak(14.5, .bold)); Text(item.categoryName).font(WPFont.hak(12)).foregroundStyle(.secondary) }
                                    Spacer()
                                    if model.sharingSchedule == item.id { ProgressView() }
                                    else { Image(systemName: model.sharedSchedule == item.id ? "checkmark.circle.fill" : "arrow.up") }
                                }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(WPColor.gray200))
                            }.disabled(model.sharingSchedule != nil || model.sharedSchedule != nil)
                        }
                    } else { ProgressView().padding(32) }
                    if let message = error ?? model.shareError { Text(message).font(.footnote).foregroundStyle(.red).padding() }
                }.padding(18)
            }.navigationTitle("어떤 플랜을 올릴까요?").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
        }.presentationDetents([.medium, .large]).interactiveDismissDisabled(model.sharingSchedule != nil)
            .task {
                model.sharedSchedule = nil; model.shareError = nil
                do {
                    let path = roomId.map { "/plan/schedule/room/\($0)/list" } ?? "/plan/schedule/list"
                    let page: SchedulePage = try await env.api.send(HTTPRequest(path: path, query: ["count":"50"]))
                    items = page.list
                } catch { self.error = error.localizedDescription; items = [] }
            }
            .onChange(of: model.sharedSchedule) { _, id in
                if id != nil { Task { try? await Task.sleep(for: .milliseconds(600)); dismiss() } }
            }
    }
}
