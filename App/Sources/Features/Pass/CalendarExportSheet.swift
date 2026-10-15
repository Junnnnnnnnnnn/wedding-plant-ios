import SwiftUI
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 내보내기 시트 — 안드로이드 `ui/pass/CalendarExportSheet.kt`(웹 `CalendarExportDialog` 의 폰 모양).
///
/// 01 파일 형식 → 02 양식(썸네일 카드) → 03 기간 → 양식 미리보기(내 일정/예시 데이터) →
/// 아래 고정 줄(요약 + 다운로드). 미리보기는 파일과 **같은 재료**(`ExportDoc`)로 첫 화면을 줄여 보인다.
struct CalendarExportSheet: View {
    var roomId: Int?
    /// 「이 달」 칩의 달(`YYYY-MM`). 기본은 KST 이번 달.
    var month: String = String(KstDate.today().dateString.prefix(7))
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var items: [ScheduleItem] = []
    @State private var plan: ExportPlanInfo?
    @State private var resolvedRoom: Int?
    @State private var loading = true
    @State private var loadError: String?
    @State private var busy = false
    @State private var actionError: String?
    @State private var passRequired = false
    @State private var shareURLs: [URL] = []
    @State private var sharing = false

    var body: some View {
        CalendarExportBody(
            items: items, plan: plan, month: month, loading: loading, loadError: loadError,
            busy: busy, actionError: actionError,
            onRetry: { Task { await load() } },
            onClose: { if !busy { dismiss() } },
            onExport: { template, pdf, currentMonth, sample in
                Task { await export(template: template, pdf: pdf, month: currentMonth ? month : nil, sample: sample) }
            }
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(24)
        .presentationBackground(WPColor.exportPaper)
        .interactiveDismissDisabled(busy)
        .task { await load() }
        .fullScreenCover(isPresented: $passRequired) { PassView(roomId: resolvedRoom) }
        .sheet(isPresented: $sharing) { ActivityShareSheet(items: shareURLs) }
    }

    private func load() async {
        loading = true; loadError = nil
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
            // 플랜 정보는 실패해도 막지 않는다(그 줄만 빠짐)
            if let value: PlanUser = try? await env.api.send(Endpoint.room(shareCode: String(resolved))) {
                let names = ["OWNER", "SPOUSE"].compactMap { role in (value.members ?? []).first { $0.permission.rawValue.uppercased() == role }?.name }
                plan = ExportPlanInfo(couple: names.count == 2 ? names.joined(separator: " · ") : value.name, weddingDate: value.weddingDate.flatMap { KstDate(dateString: $0) }, budget: value.budget, venue: value.weddingVenue)
            }
            loading = false
        } catch { if !Task.isCancelled { loadError = error.localizedDescription; loading = false } }
    }

    private func export(template: ExportTemplate, pdf: Bool, month: String?, sample: Bool) async {
        guard !busy, sample || (!loading && loadError == nil) else { return }
        busy = true; actionError = nil; defer { busy = false }
        do {
            // PDF 도 서버의 동일한 패스 검증·내보내기 기록을 거친다(안드로이드와 같음).
            if !sample {
                guard let resolvedRoom else { passRequired = true; return }
                _ = try await env.api.sendRaw(Endpoint.exportExcel(roomId: resolvedRoom))
            }
            let doc = ExportDoc(items: CalendarExport.scope(sample ? CalendarExport.examples : items, month: month), template: template,
                                scope: (sample ? "예시 데이터 · " : "") + CalendarExport.scopeLabel(month), plan: sample ? CalendarExport.samplePlan : plan)
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let format = pdf ? "pdf" : "xlsx"
            let url = dir.appendingPathComponent(CalendarExport.fileName(template, format: format, month: month, sample: sample))
            if pdf { try CalendarPDF().write(doc, to: url) } else { try CalendarWorkbook.data(doc).write(to: url) }
            shareURLs = [url]; sharing = true
        } catch APIError.http(let status, _) where status == 403 { passRequired = true }
        catch { actionError = "파일을 만들지 못했어요. 다시 시도해 주세요." }
    }
}

/// 내보내기 본문 — **상태는 고르는 값뿐**이라 스크린샷 테스트가 그대로 그린다.
struct CalendarExportBody: View {
    var items: [ScheduleItem]
    var plan: ExportPlanInfo?
    var month: String
    var loading: Bool
    var loadError: String?
    var busy: Bool
    var actionError: String?
    var onRetry: () -> Void = {}
    var onClose: () -> Void = {}
    var onExport: (ExportTemplate, Bool, Bool, Bool) -> Void = { _, _, _, _ in }

    @State var template: ExportTemplate = .checklist
    @State var pdf = false
    @State var currentMonth = false
    @State var sample = false

    private var scopedItems: [ScheduleItem] { CalendarExport.scope(sample ? CalendarExport.examples : items, month: currentMonth ? month : nil) }
    private var doc: ExportDoc {
        ExportDoc(items: scopedItems, template: template,
                  scope: (sample ? "예시 데이터 · " : "") + CalendarExport.scopeLabel(currentMonth ? month : nil),
                  plan: sample ? CalendarExport.samplePlan : plan)
    }
    private var canDownload: Bool { !busy && (sample || (!loading && loadError == nil && !scopedItems.isEmpty)) }

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(WPColor.sheetHandle).frame(width: 38, height: 4).padding(.top, 10).padding(.bottom, 6)
            // 머리
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("KEEP OUR PLANS").tracking(1.8).wpTypography(10, .bold).foregroundStyle(WPColor.exportEyebrow)
                    Text("우리의 준비, 한 장에 담기").tracking(-0.5).wpTypography(23, .bold).foregroundStyle(WPColor.exportInk)
                    Text("마음에 드는 양식을 고르고 엑셀 또는 PDF로 간직하세요.".wpKeepAll).wpTypography(14, lineHeight: 20)
                        .foregroundStyle(WPColor.exportMuted).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onClose) {
                    WPMaterialPathIcon(paths: WPIconPaths.closeFilled, size: 20, color: WPColor.exportMuted)
                        .frame(width: 40, height: 40).contentShape(Circle())
                }
                .buttonStyle(.plain).disabled(busy).accessibilityLabel("다운로드 창 닫기").accessibilityIdentifier("export.close")
            }
            .padding(.leading, 24).padding(.trailing, 12).padding(.top, 8).padding(.bottom, 20)
            Rectangle().fill(WPColor.exportLine).frame(height: 1)

            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 24) {
                        formatSection
                        templateSection
                        scopeSection
                    }
                    .padding(24)
                    previewSection
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .accessibilityIdentifier("export.scroll")

            // 아래 고정 줄 — 무엇을 받는지 요약하고 받기
            Rectangle().fill(WPColor.exportLine).frame(height: 1)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text((sample ? "예시 데이터로 양식을 확인해 보세요" : "\(scopedItems.count)개 일정 · \(template.label)").wpKeepAll)
                        .wpTypography(12, .bold).foregroundStyle(WPColor.exportSummary)
                    Text((sample ? "실제 내 일정은 포함되지 않아요." : "내 일정 다운로드는 준비 패스에 포함돼요.").wpKeepAll)
                        .wpTypography(11).foregroundStyle(WPColor.exportNote)
                    if let actionError { Text(actionError.wpKeepAll).wpTypography(12).foregroundStyle(WPColor.exportError) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button { onExport(template, pdf, currentMonth, sample) } label: {
                    HStack(spacing: 8) {
                        if busy { ProgressView().tint(.white).controlSize(.small).frame(width: 17, height: 17) }
                        else { WPMaterialPathIcon(paths: WPIconPaths.fileDownloadOutlined, size: 17, color: .white) }
                        Text(busy ? "파일 만드는 중…" : "\(sample ? "예시 " : "")\(pdf ? "PDF" : "엑셀") 다운로드")
                            .wpTypography(14, .bold).foregroundStyle(.white).fixedSize()
                    }
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    .background(WPColor.exportButton.opacity(canDownload ? 1 : 0.45), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain).allowsHitTesting(canDownload).accessibilityIdentifier("export.save")
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
            .background(Color.white)
        }
        .background(WPColor.exportPaper)
    }

    // MARK: 01 · 02 · 03

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            legend("01", "파일 형식")
            HStack(spacing: 8) {
                ForEach([false, true], id: \.self) { isPdf in
                    let on = pdf == isPdf
                    let tint = on ? WPColor.exportAccent : WPColor.exportChipText
                    Button { pdf = isPdf } label: {
                        HStack(spacing: 0) {
                            WPLucideIcon(paths: WPIconPaths.fileText, size: 17, color: tint)
                            Text(isPdf ? "PDF" : "엑셀").wpTypography(14, on ? .bold : .regular).foregroundStyle(tint).padding(.leading, 8)
                            Text(isPdf ? ".pdf" : ".xlsx").wpTypography(10).foregroundStyle(tint.opacity(0.65)).padding(.leading, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(on ? WPColor.exportAccentBg : .white, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? WPColor.exportAccentLine : WPColor.exportChipLine, lineWidth: 1))
                    }
                    .buttonStyle(.plain).disabled(busy).accessibilityLabel(isPdf ? "PDF" : "엑셀")
                }
            }
            Text(pdf ? "공유하고 인쇄하기 좋은 A4 가로 타임라인" : "첫 장은 요약, 둘째 장부터 고쳐 쓰는 표")
                .wpTypography(11).foregroundStyle(WPColor.exportNote).padding(.top, 8)
        }
    }

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            legend("02", "양식 선택")
            VStack(spacing: 10) {
                ForEach(Array(ExportTemplate.allCases.enumerated()), id: \.element) { index, t in
                    let on = template == t
                    let color = t.exportColor
                    Button { template = t } label: {
                        HStack(spacing: 12) {
                            ExportTemplateThumb(color: color, gapAt: index == 2 ? 2 : -1)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(t.tag).wpTypography(10).foregroundStyle(color)
                                Text(t.label).wpTypography(14, .bold).foregroundStyle(WPColor.exportInk).padding(.vertical, 4)
                                Text(t.description).wpTypography(11).foregroundStyle(WPColor.exportDesc)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12)
                        .overlay(alignment: .topTrailing) {
                            if on { WPMaterialPathIcon(paths: WPIconPaths.check, size: 14, color: WPColor.exportCheck).padding(12) }
                        }
                        .background(on ? WPColor.exportPickedBg : .white, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? WPColor.exportAccentLine : WPColor.exportCardLine, lineWidth: 1))
                    }
                    .buttonStyle(.plain).disabled(busy).accessibilityIdentifier("export.template.\(t.rawValue)")
                }
            }
        }
    }

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            legend("03", "내보낼 기간")
            HStack(spacing: 8) {
                ForEach([false, true], id: \.self) { isMonth in
                    let on = currentMonth == isMonth
                    Button { currentMonth = isMonth } label: {
                        Text(CalendarExport.scopeLabel(isMonth ? month : nil)).wpTypography(13, on ? .bold : .regular)
                            .foregroundStyle(on ? WPColor.exportAccent : WPColor.exportChipText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8).padding(.vertical, 12)
                            .background(on ? WPColor.exportAccentBg : .white, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? WPColor.exportAccentLine : WPColor.exportChipLine, lineWidth: 1))
                    }
                    .buttonStyle(.plain).disabled(busy)
                }
            }
        }
    }

    private func legend(_ no: String, _ label: String) -> some View {
        Text("\(no)   \(label)").wpTypography(12, .bold).foregroundStyle(WPColor.exportMuted).padding(.bottom, 12)
    }

    // MARK: 양식 미리보기

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("양식 미리보기").wpTypography(12, .bold).foregroundStyle(WPColor.exportPreviewLabel)
                Text(pdf ? "A4 · 가로" : "EXCEL").wpTypography(12).foregroundStyle(WPColor.exportPreviewSub)
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    ForEach([false, true], id: \.self) { v in
                        let on = sample == v
                        Button { sample = v } label: {
                            Text(v ? "예시 데이터" : "내 일정").wpTypography(11).foregroundStyle(on ? WPColor.exportToggleOn : WPColor.exportToggleOff)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(on ? Color.white : .clear, in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain).disabled(busy).accessibilityLabel(v ? "예시 데이터" : "내 일정")
                    }
                }
                .padding(2)
                .background(WPColor.exportToggleBg, in: RoundedRectangle(cornerRadius: 8))
            }
            Group {
                if !sample && loading {
                    Text("일정을 불러오는 중이에요…").wpTypography(14).foregroundStyle(WPColor.exportMuted)
                        .frame(maxWidth: .infinity, minHeight: 280).background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(WPColor.exportSheetLine, lineWidth: 1))
                } else if !sample, let loadError {
                    VStack(spacing: 12) {
                        Text(loadError.wpKeepAll).wpTypography(14).foregroundStyle(WPColor.exportError).multilineTextAlignment(.center)
                        Button(action: onRetry) { Text("다시 불러오기").wpTypography(14).underline().foregroundStyle(WPColor.exportError) }.buttonStyle(.plain)
                    }
                    .padding(24).frame(maxWidth: .infinity, minHeight: 280).background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(WPColor.exportSheetLine, lineWidth: 1))
                } else if pdf {
                    ExportPdfPreview(doc: doc)
                } else {
                    ExportXlsxPreview(doc: doc)
                }
            }
            .padding(.top, 16)
            Text(template.detail).wpTypography(12, .bold).foregroundStyle(WPColor.exportPreviewLabel).padding(.top, 16)
            Text(previewNote.wpKeepAll).wpTypography(11, lineHeight: 18).foregroundStyle(WPColor.exportNote)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 6)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(WPColor.exportPreviewBg)
    }

    private var previewNote: String {
        (pdf ? "A4 가로 · 왼쪽 기둥에 두 사람과 D-day, 오른쪽은 달마다 이어지는 타임라인이에요."
            : "첫 시트 \"한눈에\"에 요약과 막대, 둘째 시트부터 표가 있어요" + (template == .monthly ? "(달마다 한 시트)" : "") + ". 합계는 수식이라 고치면 따라 바뀌어요.")
            + " " + (template == .budget ? "일정 완료와 결제 여부를 따로 구분하고, 금액 미정은 합계에서 빼요." : "날짜순이고, 날짜 미정 일정은 맨 끝에 담아요.")
            + " 미리보기는 일부만 보여 줘요."
    }
}

/// 양식 카드의 작은 종이 그림(웹 w-12 썸네일)
private struct ExportTemplateThumb: View {
    var color: Color
    var gapAt: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 20, height: 4)
            Rectangle().fill(color.opacity(0.3)).frame(height: 6).padding(.top, 6)
            ForEach(0..<4, id: \.self) { i in
                Rectangle().fill(WPColor.exportCardLine).frame(height: 1).padding(.top, i == gapAt ? 8 : 4)
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 8)
        .frame(width: 48)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(WPColor.exportLine, lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 1, y: 0.5)
    }
}

// MARK: - 미리보기 (안드로이드 `ExportPreview.kt`, 웹 `ExportPreview.tsx`)

private struct ExportPreviewHead: View {
    var doc: ExportDoc
    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(doc.plan?.couple.map { "\($0)의 결혼 준비" } ?? "우리의 결혼 준비").wpTypography(14, .bold).foregroundStyle(.white).lineLimit(1)
                Text(headSub).wpTypography(10).foregroundStyle(WPColor.brand200).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let dday = CalendarExport.dday(doc) { Text("D-\(dday)").wpTypography(16, .bold).foregroundStyle(.white) }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(WPColor.primary)
    }
    private var headSub: String {
        guard let date = doc.plan?.weddingDate else { return doc.scope }
        return date.dateString.replacingOccurrences(of: "-", with: ".") + (doc.plan?.venue.map { " · \($0)" } ?? "")
    }
}

/// 엑셀 — 첫 시트 "한눈에"(분홍 띠 · 요약 셋 · 표 넉 줄) + 시트 탭
struct ExportXlsxPreview: View {
    var doc: ExportDoc
    var body: some View {
        let stats = CalendarExport.summaryStats(doc)
        let section = ExportPreviewTable.first(doc)
        let tabs: [String] = {
            switch doc.template {
            case .budget: return ["예산 내역"]
            case .checklist: return ["체크리스트"]
            case .monthly: return CalendarExport.groupByMonth(doc.items).map(\.label)
            }
        }()
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ExportPreviewHead(doc: doc)
                HStack(spacing: 3) {
                    ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(stat.0).wpTypography(9).foregroundStyle(WPColor.exportFilePinkDeep).lineLimit(1)
                            HStack(alignment: .lastTextBaseline, spacing: 0) {
                                Text(stat.1).wpTypography(15, .bold).foregroundStyle(WPColor.fgNeutral).lineLimit(1).fixedSize()
                                Text(" \(stat.2)").wpTypography(9).foregroundStyle(WPColor.fgSubtle).lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(WPColor.brand100)
                    }
                }
                .padding(.top, 3)
                if section.rows.isEmpty {
                    Text("이 기간에 등록된 일정이 없어요.").wpTypography(12).foregroundStyle(WPColor.exportMuted)
                        .frame(maxWidth: .infinity).padding(.vertical, 40).padding(.top, 12)
                } else {
                    GeometryReader { g in
                        let total = CGFloat(section.widths.reduce(0, +))
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                ForEach(Array(section.headers.enumerated()), id: \.offset) { i, h in
                                    Text(h).wpTypography(10, .bold).foregroundStyle(WPColor.exportFilePinkDeep).lineLimit(1)
                                        .padding(6).frame(width: g.size.width * CGFloat(section.widths[i]) / total, alignment: .leading)
                                }
                            }
                            .background(WPColor.brand100)
                            ForEach(Array(section.rows.prefix(4).enumerated()), id: \.offset) { r, row in
                                HStack(spacing: 0) {
                                    ForEach(Array(row.enumerated()), id: \.offset) { i, v in
                                        Text(v).wpTypography(10).foregroundStyle(WPColor.fgMuted).lineLimit(1)
                                            .padding(.horizontal, 6).padding(.vertical, 7)
                                            .frame(width: g.size.width * CGFloat(section.widths[i]) / total, alignment: .leading)
                                    }
                                }
                                .background(r % 2 == 1 ? WPColor.exportFileZebra : .white)
                                Rectangle().fill(WPColor.exportFileRowLine).frame(height: 1)
                            }
                        }
                    }
                    .frame(height: 30 + CGFloat(min(4, section.rows.count)) * 30)
                    .padding(.top, 12)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 280, alignment: .top)
            // 시트 탭
            HStack(spacing: 0) {
                ExportTabChip(label: "한눈에", on: true)
                ForEach(Array(tabs.prefix(4).enumerated()), id: \.offset) { _, tab in ExportTabChip(label: tab, on: false) }
                if tabs.count > 4 { Text("+\(tabs.count - 4)").wpTypography(10).foregroundStyle(WPColor.exportFileDim).padding(.horizontal, 8).padding(.vertical, 7) }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .background(WPColor.fill)
        }
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(WPColor.exportSheetLine, lineWidth: 1))
    }
}

private struct ExportTabChip: View {
    var label: String
    var on: Bool
    var body: some View {
        VStack(spacing: 0) {
            Text(label).wpTypography(10, on ? .bold : .regular).foregroundStyle(on ? WPColor.fgNeutral : WPColor.exportFileTabText).lineLimit(1)
                .padding(.horizontal, 12).padding(.vertical, 6)
            Rectangle().fill(on ? WPColor.primary : WPColor.exportFileTabLine).frame(height: 2)
        }
        .fixedSize()
        .background(on ? Color.white : .clear)
    }
}

/// PDF — A4 가로 한 쪽(왼쪽 연분홍 기둥 · 오른쪽 타임라인 열 줄)
struct ExportPdfPreview: View {
    var doc: ExportDoc
    var body: some View {
        let dday = CalendarExport.dday(doc)
        let stats = CalendarExport.summaryStats(doc)
        let money = doc.template == .budget
        let shown: [(ExportMonthGroup, [ScheduleItem])] = {
            var room = 10
            return CalendarExport.groupByMonth(doc.items).compactMap { m in
                let picked = Array(m.items.prefix(max(0, room))); room -= picked.count
                return picked.isEmpty ? nil : (m, picked)
            }
        }()
        GeometryReader { g in
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("웨딩플랜트").wpTypography(7).foregroundStyle(WPColor.brand700)
                    Text((doc.plan?.couple ?? "우리의 결혼 준비").wpKeepAll).wpTypography(11, .bold, lineHeight: 14).foregroundStyle(WPColor.fgNeutral)
                        .fixedSize(horizontal: false, vertical: true).padding(.top, 6)
                    if let dday { Text("D-\(dday)").wpTypography(15, .bold).foregroundStyle(WPColor.primary).lineLimit(1).fixedSize().padding(.top, 4) }
                    Rectangle().fill(WPColor.brand300).frame(height: 1).padding(.top, 8)
                    Text(doc.template.label.wpKeepAll).wpTypography(9, .bold).foregroundStyle(WPColor.fgNeutral).padding(.top, 6)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                            Text("\(stat.0) \(stat.1)\(stat.2.hasPrefix("/") ? " \(stat.2)" : stat.2)".wpKeepAll).wpTypography(7, lineHeight: 10)
                                .foregroundStyle(WPColor.fgSubtle).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 4)
                    Spacer(minLength: 0)
                }
                .padding(10)
                .frame(width: g.size.width * 0.28, height: g.size.height, alignment: .topLeading)
                .background(WPColor.brand100)
                VStack(alignment: .leading, spacing: 0) {
                    if shown.isEmpty {
                        Text("이 기간에 등록된 일정이 없어요.").wpTypography(10).foregroundStyle(WPColor.exportMuted)
                            .frame(maxWidth: .infinity).padding(.top, 40)
                    }
                    ForEach(Array(shown.enumerated()), id: \.offset) { _, entry in
                        HStack(alignment: .bottom, spacing: 8) {
                            Text(entry.0.short).wpTypography(12, .bold).foregroundStyle(WPColor.fgNeutral).frame(width: 34, alignment: .trailing)
                            Rectangle().fill(WPColor.brand300).frame(height: 1).padding(.bottom, 3)
                        }
                        ForEach(entry.1) { s in
                            let date = CalendarExport.dateOf(s)
                            let done = s.status?.isCompleted == true
                            let on = money ? s.isPaid : done
                            HStack(spacing: 8) {
                                Text(date.map { "\($0.month).\($0.day)" } ?? "미정").wpTypography(8).foregroundStyle(WPColor.fgMuted)
                                    .frame(width: 34, alignment: .trailing)
                                Circle().fill(on ? WPColor.primary : .white)
                                    .overlay(Circle().stroke(date == nil ? WPColor.exportFileLight : WPColor.primary, lineWidth: 1))
                                    .frame(width: 7, height: 7)
                                Text(s.title).wpTypography(9, !money && done ? .regular : .bold)
                                    .foregroundStyle(!money && done ? WPColor.exportFileDim : WPColor.fgNeutral).lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if doc.template != .checklist {
                                    Text(s.amount.map { "\(CalendarExport.won($0))만" } ?? "미정").wpTypography(8).foregroundStyle(WPColor.fgMuted)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        Color.clear.frame(height: 4)
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .frame(width: g.size.width * 0.72, height: g.size.height, alignment: .topLeading)
                .clipped()
            }
        }
        .aspectRatio(842.0 / 595.0, contentMode: .fit)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(WPColor.exportSheetLine, lineWidth: 1))
    }
}

/// 미리보기 표의 첫 칸 — 안드로이드 `CalendarExport.sections(...).firstOrNull()` 와 같은 머리·폭·값.
/// 좁은 칸에서 날짜가 잘리지 않게 날짜는 `M.D` 로 짧게 쓴다(안드로이드 미리보기와 같음).
enum ExportPreviewTable {
    struct Section { let headers: [String]; let widths: [Int]; let rows: [[String]] }
    static func first(_ doc: ExportDoc) -> Section {
        let sorted = CalendarExport.sorted(doc.items)
        func date(_ s: ScheduleItem) -> String { CalendarExport.dateOf(s).map { "\($0.month).\($0.day)" } ?? "날짜 미정" }
        func time(_ s: ScheduleItem) -> String { s.startTime.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : String($0.prefix(5)) } ?? "미정" }
        func status(_ s: ScheduleItem) -> String { s.status?.isCompleted == true ? "완료" : "예정" }
        func category(_ s: ScheduleItem) -> String { s.categoryName.trimmingCharacters(in: .whitespaces).isEmpty ? "기타" : s.categoryName }
        func amount(_ s: ScheduleItem) -> String { s.amount.map { CalendarExport.won($0) } ?? "미정" }
        switch doc.template {
        case .checklist:
            return Section(headers: ["날짜", "시간", "일정", "카테고리", "상태"], widths: [18, 12, 46, 18, 12],
                           rows: sorted.map { [date($0), time($0), $0.title, category($0), status($0)] })
        case .budget:
            return Section(headers: ["날짜", "일정", "카테고리", "금액 (만 원)", "결제"], widths: [18, 42, 18, 18, 14],
                           rows: sorted.map { [date($0), $0.title, category($0), amount($0), $0.isPaid ? "결제 완료" : "미결제"] })
        case .monthly:
            let first = CalendarExport.groupByMonth(sorted).first?.items ?? []
            return Section(headers: ["날짜", "시간", "일정", "금액 (만 원)", "상태"], widths: [18, 12, 42, 18, 14],
                           rows: first.map { [date($0), time($0), $0.title, amount($0), status($0)] })
        }
    }
}

extension ExportTemplate {
    /// 안드로이드 `ExportTemplate.tag` · `detail`
    var tag: String { switch self { case .checklist: return "일정 관리"; case .budget: return "예산 확인"; case .monthly: return "함께 공유" } }
    var detail: String {
        switch self {
        case .checklist: return "날짜 · 시간 · 일정 · 카테고리 · 완료 여부"
        case .budget: return "일정 · 카테고리 · 금액 · 결제 여부 · 합계"
        case .monthly: return "월별 일정 · 금액 · 완료 여부 · 날짜 미정"
        }
    }
    var exportColor: Color {
        switch self { case .checklist: return WPColor.exportChecklist; case .budget: return WPColor.exportBudget; case .monthly: return WPColor.exportMonthly }
    }
}

/// 안드로이드 `WpColors.Export*` — 내보내기 시트·미리보기
extension WPColor {
    static let exportPaper = Color(hex: 0xFFFDFB)
    static let exportInk = Color(hex: 0x30262D)
    static let exportEyebrow = Color(hex: 0xA88797)
    static let exportMuted = Color(hex: 0x8B7D85)
    static let exportLine = Color(hex: 0xEEE7E9)
    static let exportNote = Color(hex: 0x9B8B94)
    static let exportDesc = Color(hex: 0x95848F)
    static let exportAccent = Color(hex: 0xAC496F)
    static let exportAccentLine = Color(hex: 0xD57A9F)
    static let exportAccentBg = Color(hex: 0xFFF1F6)
    static let exportPickedBg = Color(hex: 0xFFF7FA)
    static let exportChipLine = Color(hex: 0xE7E0E3)
    static let exportChipText = Color(hex: 0x81727B)
    static let exportCardLine = Color(hex: 0xE9E3E5)
    static let exportCheck = Color(hex: 0xBF5D87)
    static let exportPreviewBg = Color(hex: 0xF5F1EE)
    static let exportPreviewLabel = Color(hex: 0x877680)
    static let exportPreviewSub = Color(hex: 0xAD9BA5)
    static let exportToggleBg = Color(hex: 0xEAE3E5)
    static let exportToggleOn = Color(hex: 0x6B525F)
    static let exportToggleOff = Color(hex: 0x9B8592)
    static let exportSheetLine = Color(hex: 0xE7E0DB)
    static let exportSummary = Color(hex: 0x6F5E68)
    static let exportError = Color(hex: 0xB94162)
    static let exportButton = Color(hex: 0xC25D87)
    static let exportChecklist = Color(hex: 0x537565)
    static let exportBudget = Color(hex: 0xAA7952)
    static let exportMonthly = Color(hex: 0xB46589)
    static let exportFilePinkDeep = Color(hex: 0xA5105C)
    static let exportFileZebra = Color(hex: 0xFAFAFB)
    static let exportFileRowLine = Color(hex: 0xF0F1F3)
    static let exportFileTabLine = Color(hex: 0xCDD0D5)
    static let exportFileTabText = Color(hex: 0x6B7079)
    static let exportFileDim = Color(hex: 0x9A9EA6)
    static let exportFileLight = Color(hex: 0xB3B7BE)
}
