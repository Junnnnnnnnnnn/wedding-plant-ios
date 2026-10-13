import SwiftUI
import WPDomain
import WPModels
import WPNetworking
import WPUtils

struct CalendarExportSheet: View {
    var roomId: Int?
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var template: ExportTemplate = .checklist
    @State private var format = "pdf"
    @State private var sample = false
    private var chosenItems: [ScheduleItem] { sample ? CalendarExport.examples : items }
    private var document: ExportDoc { ExportDoc(items: CalendarExport.scope(chosenItems, month: month), template: template, scope: (sample ? "예시 데이터 · " : "") + CalendarExport.scopeLabel(month), plan: sample ? CalendarExport.samplePlan : plan) }
    @State private var month: String?
    @State private var items: [ScheduleItem] = []
    @State private var plan: ExportPlanInfo?
    @State private var resolvedRoom: Int?
    @State private var loaded = false
    @State private var busy = false
    @State private var error: String?
    @State private var loadError: String?
    @State private var passRequired = false
    @State private var preview: DownloadedDocument?
    @State private var shareURLs: [URL] = []
    @State private var sharing = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("두 사람이 쌓아 온 준비를,\n보기 좋은 한 장으로").font(WPFont.hak(25, .bold))
                    Text("일정과 예산을 파일로 저장하고 함께 나눠요.").font(WPFont.hak(14)).foregroundStyle(.secondary)
                    ForEach(ExportTemplate.allCases, id: \.self) { choice in
                        Button { template = choice } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) { Text(choice.label).font(WPFont.hak(16, .bold)); Text(choice.description).font(WPFont.hak(12)).foregroundStyle(.secondary) }
                                Spacer(); Image(systemName: template == choice ? "checkmark.circle.fill" : "circle").foregroundStyle(WPColor.primary)
                            }.padding(16).background(template == choice ? Color(hex: 0xFFF1F7) : .white, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(WPColor.gray200))
                        }.buttonStyle(.plain).disabled(busy)
                    }
                    Picker("데이터", selection: $sample) { Text("내 일정").tag(false); Text("예시 데이터").tag(true) }.pickerStyle(.segmented).disabled(busy)
                    Picker("기간", selection: $month) {
                        Text("전체 기간 · 날짜 미정 포함").tag(String?.none)
                        ForEach(CalendarExport.groupByMonth(chosenItems).filter { $0.year != nil }, id: \.key) { group in Text(group.label).tag(Optional(group.key)) }
                    }.pickerStyle(.menu).disabled(busy)
                    Picker("파일 형식", selection: $format) { Text("PDF").tag("pdf"); Text("엑셀").tag("xlsx") }.pickerStyle(.segmented).disabled(busy)
                    if !loaded && !sample { ProgressView("전체 일정을 불러오고 있어요") }
                    else {
                        let doc = document
                        HStack(alignment: .top) {
                            ForEach(Array(CalendarExport.summaryStats(doc).enumerated()), id: \.offset) { _, stat in
                                VStack(alignment: .leading, spacing: 8) { Text(stat.0).font(WPFont.hak(11)).foregroundStyle(.secondary); Text(stat.1).font(WPFont.hak(23, .bold)); Text(stat.2).font(WPFont.hak(11)) }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }.padding(18).background(Color(hex: 0xFFF1F7), in: RoundedRectangle(cornerRadius: 16))
                    }
                    if let loadError, !sample { Text(loadError).font(WPFont.hak(13)).foregroundStyle(.red); Button("다시 불러오기") { Task { await load() } } }
                    if let error { Text(error).font(WPFont.hak(13)).foregroundStyle(.red) }
                    Text(sample ? "실제 내 일정은 포함되지 않아요." : "내 일정 다운로드는 준비 패스에 포함돼요.").font(WPFont.hak(12)).foregroundStyle(.secondary)
                    Button("PDF 미리보기") { Task { await export(showPreview: true) } }.disabled((!loaded && !sample) || busy).accessibilityIdentifier("export.preview")
                    Button(busy ? "파일 만드는 중…" : "파일로 저장하기") { Task { await export() } }.buttonStyle(InvitationActionStyle()).disabled((!loaded && !sample) || busy).accessibilityIdentifier("export.save")
                }.padding(24)
            }.navigationTitle("파일로 보관하기").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
        }.task { await load() }.interactiveDismissDisabled(busy)
            .fullScreenCover(isPresented: $passRequired) { PassView(roomId: resolvedRoom) }
            .sheet(item: $preview) { DocumentPreview(url: $0.url) }
            .sheet(isPresented: $sharing) { ActivityShareSheet(items: shareURLs) }
    }
    private func load() async {
        loaded = false; loadError = nil
        do {
            var resolved = roomId ?? env.boundRoomId
            if resolved == nil { let user: PlanUser = try await env.api.send(Endpoint.user()); resolved = user.roomId }
            guard let resolved else { throw APIError.backend(message: "플랜 정보를 불러오지 못했어요.") }; resolvedRoom = resolved
            let path = "/plan/schedule/room/\(resolved)/list"
            var pages = SchedulePages(), page = 1
            while !Task.isCancelled {
                let result: SchedulePage = try await env.api.send(HTTPRequest(path: path, query: ["page": String(page), "count": "100"]))
                if try pages.append(result) { break }; page += 1
            }
            try Task.checkCancellation()
            items = pages.result
            if let value: PlanUser = try? await env.api.send(Endpoint.room(shareCode: String(resolved))) {
                let names = ["OWNER", "SPOUSE"].compactMap { role in (value.members ?? []).first { $0.permission.rawValue.uppercased() == role }?.name }
                plan = ExportPlanInfo(couple: names.count == 2 ? names.joined(separator: " · ") : value.name, weddingDate: value.weddingDate.flatMap { KstDate(dateString: $0) }, budget: value.budget, venue: value.weddingVenue)
            }
            loaded = true
        } catch { if !Task.isCancelled { self.loadError = error.localizedDescription } }
    }
    private func export(showPreview: Bool = false) async {
        guard loaded || sample, !busy else { return }; busy = true; error = nil; defer { busy = false }
        do {
            // Both formats use the same entitlement check and export audit record as Android.
            if !sample {
                guard let resolvedRoom else { throw APIError.backend(message: "플랜 정보를 불러오지 못했어요.") }
                _ = try await env.api.sendRaw(Endpoint.exportExcel(roomId: resolvedRoom))
            }
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let outputFormat = showPreview ? "pdf" : format
            let url = dir.appendingPathComponent(CalendarExport.fileName(template, format: outputFormat, month: month, sample: sample))
            if outputFormat == "pdf" { try CalendarPDF().write(document, to: url) }
            else { try CalendarWorkbook.data(document).write(to: url) }
            if showPreview { preview = DownloadedDocument(url: url) }
            else { shareURLs = [url]; sharing = true }
        } catch APIError.http(let status, _) where status == 403 { passRequired = true }
        catch { self.error = error.localizedDescription }
    }
}
