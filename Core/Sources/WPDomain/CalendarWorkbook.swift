import Foundation
import WPModels
import WPUtils

/// OOXML with explicit string cells (user titles must never become spreadsheet formulas).
public enum CalendarWorkbook {
    private enum Value { case text(String), number(Double), formula(String, Double) }
    private struct Cell { let value: Value; var style = 0 }
    private struct Sheet {
        let name: String
        var rows: [[Cell]] = []
        var merges: [String] = []
        var widths: [Int] = [2,18,20,44,20,20,2]
        var filter: String?
        var bars: [(String, String)] = []
    }
    public static func data(_ doc: ExportDoc) -> Data {
        let items = CalendarExport.sorted(doc.items), totals = CalendarExport.totals(items)
        func t(_ text: String, _ style: Int = 0) -> Cell { Cell(value: .text(text), style: style) }
        func n(_ value: Double, _ style: Int = 3) -> Cell { Cell(value: .number(value), style: style) }
        func n(_ value: Int, _ style: Int = 3) -> Cell { n(Double(value), style) }
        var overview = Sheet(name: "한눈에", widths: [2,20,24,20,20,24,2])
        overview.rows = [[t("")], [t(""), t((doc.plan?.couple ?? "우리") + "의 결혼 준비", 1), t("",1), t("",1), t("",1), t(CalendarExport.dday(doc).map { "D-\($0)" } ?? "",1)],
            [t(""), t([doc.plan?.weddingDate?.weddingDateText, doc.plan?.venue].compactMap { $0 }.joined(separator: " · "), 1), t("",1),t("",1),t("",1),t("웨딩플랜트",1)], [t("")]]
        overview.merges = ["B2:E2", "B3:E3"]
        let stats: [(String,Double,String)]
        switch doc.template {
        case .budget: stats = [(doc.plan?.budget == nil ? "합계" : "총예산", doc.plan?.budget ?? totals.total,"만 원"),("결제한 돈",totals.paid,"\(totals.paidCount)건"),("남은 결제",totals.unpaid,"\(totals.unpaidCount)건"),("남는 예산",(doc.plan?.budget ?? totals.total)-totals.total,"예정까지 다 쓰면"),("금액 미정",Double(totals.unknown),"합계에서 제외")]
        case .checklist: stats = [("전체 일정",Double(totals.count),"개"),("완료",Double(totals.done),"개"),("30일 안에 할 일",Double(items.filter { item in guard let date = CalendarExport.dateOf(item) else { return false }; let days = doc.today.days(until: date); return item.status?.isCompleted != true && days >= 0 && days <= 30 }.count),"개"),("남은 일",Double(totals.count-totals.done),"개"),("날짜 미정",Double(totals.undated),"개")]
        case .monthly: stats = [("준비 기간",Double(CalendarExport.groupByMonth(items).filter { $0.year != nil }.count),"개월"),("일정",Double(totals.count),"개"),("금액 합계",totals.total,"만 원"),("완료",Double(totals.done),"개"),("날짜 미정",Double(totals.undated),"개")]
        }
        overview.rows += [[t("")] + stats.map { t($0.0,2) }, [t("")] + stats.map { n($0.1,4) }, [t("")] + stats.map { t($0.2,2) }, [t("")]]
        func f(_ formula: String, _ cached: Double, _ style: Int = 3) -> Cell { Cell(value: .formula(formula, cached), style: style) }
        if doc.template == .budget {
            overview.rows[5][2] = f("SUMIFS('예산 내역'!$E:$E,'예산 내역'!$F:$F,\"결제함\")", totals.paid, 4)
            overview.rows[5][3] = f("SUMIFS('예산 내역'!$E:$E,'예산 내역'!$F:$F,\"미결제\")", totals.unpaid, 4)
            if let budget = doc.plan?.budget {
                overview.rows[5][4] = f("B6-C6-D6", budget - totals.total, 4)
                overview.rows[4][5] = t("예산 중 결제", 2)
                overview.rows[5][5] = f("IFERROR(C6/B6,0)", budget > 0 ? totals.paid / budget : 0, 8)
                overview.rows[6][5] = t("예정 포함 \(budget > 0 ? Int((totals.total / budget * 100).rounded()) : 0)%", 2)
            } else {
                overview.rows[5][1] = f("C6+D6", totals.total, 4)
                overview.rows[4][4] = t("금액 미정", 2); overview.rows[5][4] = t("\(totals.unknown)건", 4); overview.rows[6][4] = t("합계에서 제외", 2)
                overview.rows[4][5] = t("일정", 2); overview.rows[5][5] = t("\(totals.count)개", 4); overview.rows[6][5] = t("완료 \(totals.done)개", 2)
            }
        } else if let days = CalendarExport.dday(doc) {
            overview.rows[4][5] = t("결혼식까지", 2); overview.rows[5][5] = t("\(days)일", 4)
            overview.rows[6][5] = t(doc.plan?.weddingDate?.weddingDateText ?? "", 2)
        }
        var details: [Sheet] = []
        if doc.template == .budget {
            overview.rows.append([t(""),t("카테고리별 금액",5)])
            overview.rows.append([t(""),t("카테고리",2),t("결제함",2),t("미결제",2),t("합계",2),t("합계 중 비율",2)])
            let categories = Dictionary(grouping: items) { $0.categoryName.isEmpty ? "기타" : $0.categoryName }.sorted { CalendarExport.totals($0.value).total > CalendarExport.totals($1.value).total }
            let first = overview.rows.count + 1, last = first + categories.count - 1
            func range(_ col: String) -> String { "'예산 내역'!$\(col)$5:$\(col)$\(max(5, items.count + 4))" }
            for (name, rows) in categories {
                let values = CalendarExport.totals(rows), row = overview.rows.count+1
                func by(_ label: String) -> String { "SUMPRODUCT(--(\(range("D"))=$B\(row)),--(\(range("F"))=\"\(label)\"),\(range("E")))" }
                overview.rows.append([t(""),t(name),f(by("결제함"),values.paid),f(by("미결제"),values.unpaid),f("C\(row)+D\(row)",values.total),f("IFERROR(E\(row)/SUM($E$\(first):$E$\(last)),0)",totals.total > 0 ? values.total / totals.total : 0,7)])
            }
            if !categories.isEmpty { overview.bars.append(("F\(first):F\(last)", "FFFA6BAD")) }
            details.append(detail("예산 내역",items,doc))
        } else {
            overview.rows.append([t(""),t(doc.template == .checklist ? "달마다 얼마나 끝냈나" : "월별 한눈에",5)])
            overview.rows.append([t(""),t("달",2),t("일정",2),t("완료",2),t(doc.template == .checklist ? "남음" : "금액 (만 원)",2),t(doc.template == .checklist ? "진행" : "금액 막대",2)])
            let first = overview.rows.count + 1
            for group in CalendarExport.groupByMonth(items) {
                let values = CalendarExport.totals(group.items), row = overview.rows.count+1
                let sum = "SUM('\(group.label.replacingOccurrences(of: "'", with: "''"))'!E5:E\(group.items.count + 4))"
                overview.rows.append([t(""),t(group.label),n(values.count),n(values.done),doc.template == .checklist ? f("C\(row)-D\(row)",Double(values.count-values.done)) : f(sum,values.total),doc.template == .checklist ? f("IFERROR(D\(row)/C\(row),0)",values.count > 0 ? Double(values.done)/Double(values.count) : 0,8) : f("E\(row)",values.total)])
                if doc.template == .monthly { details.append(detail(group.label,group.items,doc)) }
            }
            if first <= overview.rows.count { overview.bars.append(("F\(first):F\(overview.rows.count)",doc.template == .checklist ? "FF8FDCC4" : "FFFA6BAD")) }
            if doc.template == .checklist { details.append(detail("체크리스트",items,doc)) }
        }
        overview.rows += [[t("")],[t(""),t("다가오는 일정",5)],[t(""),t("날짜",2),t("일정",2),t("카테고리",2),t("금액 (만 원)",2),t("상태",2)]]
        for item in items.filter({ $0.status?.isCompleted != true && (CalendarExport.dateOf($0).map { doc.today.days(until:$0) >= 0 } ?? false) }).prefix(5) {
            overview.rows.append([t(""),t(item.startDate ?? "날짜 미정"),t(item.title),t(item.categoryName),item.amount.map { n($0) } ?? t("미정"),t("예정")])
        }
        overview.rows += [[t("")],[t(""),t(doc.scope + " · " + doc.today.dateString + " 기준")]]
        overview.merges.append("B\(overview.rows.count):F\(overview.rows.count)")
        return archive([overview]+details)
    }
    private static func detail(_ name: String, _ items: [ScheduleItem], _ doc: ExportDoc) -> Sheet {
        func t(_ s: String,_ style: Int = 0) -> Cell { Cell(value:.text(s),style:style) }
        var sheet = Sheet(name:name)
        let headers = doc.template == .budget ? ["날짜","일정","카테고리","금액 (만 원)","결제"] : doc.template == .monthly ? ["날짜","시간","일정","금액 (만 원)","상태"] : ["날짜","시간","일정","카테고리","상태"]
        sheet.rows = [[t("")],[t(""),t(name,1),t("",1),t("",1),t("",1),t("",1)],[t(""),t(doc.scope)],[t("")] + headers.map { t($0,2) }]
        sheet.merges = ["B2:F2","B3:F3"]
        for item in items {
            let date = CalendarExport.dateOf(item).map { date -> Cell in
                let epoch = KstDate(dateString:"1899-12-30")!
                return Cell(value:.number(Double(epoch.days(until:date))),style:6)
            } ?? t("날짜 미정")
            let amount = item.amount.map { Cell(value:.number($0),style:3) } ?? t("미정")
            let status = t(item.status?.isCompleted == true ? "완료" : "예정")
            let category = t(item.categoryName.isEmpty ? "기타" : item.categoryName)
            if doc.template == .budget { sheet.rows.append([t(""),date,t(item.title),category,amount,t(item.isPaid ? "결제함" : "미결제")]) }
            else { sheet.rows.append([t(""),date,t(item.startTime?.isEmpty == false ? item.startTime! : "미정"),t(item.title),doc.template == .monthly ? amount : category,status]) }
        }
        let end = sheet.rows.count
        sheet.filter = "B4:F\(max(4,end))"
        if doc.template != .checklist {
            sheet.rows.append([t(""),t("합계",2),t("",2),t("",2),Cell(value:.formula(end >= 5 ? "SUM(E5:E\(end))" : "0",CalendarExport.totals(items).total),style:4),t("",2)])
        }
        return sheet
    }
    private static func xml(_ s: String) -> String {
        String(s.unicodeScalars.filter { $0.value == 9 || $0.value == 10 || $0.value == 13 || $0.value >= 32 }).replacingOccurrences(of:"&",with:"&amp;").replacingOccurrences(of:"<",with:"&lt;").replacingOccurrences(of:">",with:"&gt;").replacingOccurrences(of:"\"",with:"&quot;").replacingOccurrences(of:"'",with:"&apos;")
    }
    private static func archive(_ sheets: [Sheet]) -> Data {
        let head = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        let ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main", rel = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        var files: [(String,Data)] = []
        func add(_ path:String,_ value:String) { files.append((path,Data((head+value).utf8))) }
        add("[Content_Types].xml", "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/xl/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/>" + sheets.indices.map { "<Override PartName=\"/xl/worksheets/sheet\($0+1).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" }.joined() + "</Types>")
        add("_rels/.rels","<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"\(rel)/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>")
        add("xl/workbook.xml","<workbook xmlns=\"\(ns)\" xmlns:r=\"\(rel)\"><bookViews><workbookView activeTab=\"0\"/></bookViews><sheets>" + sheets.enumerated().map { "<sheet name=\"\(xml($0.element.name))\" sheetId=\"\($0.offset+1)\" r:id=\"rId\($0.offset+1)\"/>" }.joined() + "</sheets><calcPr calcId=\"191029\" fullCalcOnLoad=\"1\"/></workbook>")
        add("xl/_rels/workbook.xml.rels","<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" + sheets.indices.map { "<Relationship Id=\"rId\($0+1)\" Type=\"\(rel)/worksheet\" Target=\"worksheets/sheet\($0+1).xml\"/>" }.joined() + "<Relationship Id=\"styles\" Type=\"\(rel)/styles\" Target=\"styles.xml\"/></Relationships>")
        add("xl/styles.xml",styles)
        for (index,sheet) in sheets.enumerated() {
            let rows = sheet.rows.enumerated().map { row -> String in
                let height = row.offset == 1 ? 30 : 24
                let cells = row.element.enumerated().map { col -> String in
                    let ref = String(UnicodeScalar(65+col.offset)!) + String(row.offset+1), cell = col.element
                    let open = "<c r=\"\(ref)\" s=\"\(cell.style)\""
                    switch cell.value {
                    case .text(let s): return open + " t=\"inlineStr\"><is><t xml:space=\"preserve\">\(xml(s))</t></is></c>"
                    case .number(let n): return open + "><v>\(n)</v></c>"
                    case .formula(let f,let n): return open + "><f>\(xml(f))</f><v>\(n)</v></c>"
                    }
                }.joined()
                return "<row r=\"\(row.offset+1)\" ht=\"\(height)\" customHeight=\"1\">\(cells)</row>"
            }.joined()
            let columns = sheet.widths.enumerated().map { "<col min=\"\($0.offset+1)\" max=\"\($0.offset+1)\" width=\"\($0.element)\" customWidth=\"1\"/>" }.joined()
            let filter = sheet.filter.map { "<autoFilter ref=\"\($0)\"/>" } ?? ""
            let merges = sheet.merges.isEmpty ? "" : "<mergeCells count=\"\(sheet.merges.count)\">" + sheet.merges.map { "<mergeCell ref=\"\($0)\"/>" }.joined() + "</mergeCells>"
            let bars = sheet.bars.enumerated().map { i, bar in "<conditionalFormatting sqref=\"\(bar.0)\"><cfRule type=\"dataBar\" priority=\"\(i+1)\"><dataBar><cfvo type=\"min\"/><cfvo type=\"max\"/><color rgb=\"\(bar.1)\"/></dataBar></cfRule></conditionalFormatting>" }.joined()
            add("xl/worksheets/sheet\(index+1).xml","<worksheet xmlns=\"\(ns)\"><sheetPr><tabColor rgb=\"FFEE2B8C\"/><pageSetUpPr fitToPage=\"1\"/></sheetPr><dimension ref=\"A1:G\(sheet.rows.count)\"/><sheetViews><sheetView workbookViewId=\"0\" showGridLines=\"0\"><pane ySplit=\"4\" topLeftCell=\"A5\" activePane=\"bottomLeft\" state=\"frozen\"/></sheetView></sheetViews><cols>\(columns)</cols><sheetData>\(rows)</sheetData>\(filter)\(merges)\(bars)<pageMargins left=\"0.25\" right=\"0.25\" top=\"0.4\" bottom=\"0.4\" header=\"0.2\" footer=\"0.2\"/><pageSetup paperSize=\"9\" orientation=\"landscape\" fitToWidth=\"1\" fitToHeight=\"\(index == 0 ? 1 : 0)\"/></worksheet>")
        }
        return StoreZip.make(files)
    }
    private static let styles = """
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><numFmts count="1"><numFmt numFmtId="164" formatCode="[$-412]yyyy.mm.dd (ddd)"/></numFmts><fonts count="4"><font><sz val="11"/><color rgb="FF1A1C20"/><name val="맑은 고딕"/></font><font><b/><sz val="16"/><color rgb="FFFFFFFF"/><name val="맑은 고딕"/></font><font><b/><sz val="11"/><color rgb="FFA5105C"/><name val="맑은 고딕"/></font><font><b/><sz val="17"/><color rgb="FFCC1873"/><name val="맑은 고딕"/></font></fonts><fills count="4"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FFEE2B8C"/><bgColor indexed="64"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFFFF1F7"/><bgColor indexed="64"/></patternFill></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="9"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment vertical="center" wrapText="1"/></xf><xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0"/><xf numFmtId="0" fontId="2" fillId="3" borderId="0" xfId="0"/><xf numFmtId="3" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/><xf numFmtId="3" fontId="3" fillId="3" borderId="0" xfId="0" applyNumberFormat="1"/><xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0"/><xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/><xf numFmtId="10" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/><xf numFmtId="9" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>
    """
}
/// ZIP method 0 is supported by all XLSX readers; no third-party compression dependency.
private enum StoreZip {
    static func make(_ files: [(String,Data)]) -> Data {
        var output = Data(), central = Data()
        func put(_ value: UInt32,_ bytes: Int,_ data: inout Data) { for i in 0..<bytes { data.append(UInt8((value >> (i*8)) & 255)) } }
        for (name,bytes) in files {
            let filename = Data(name.utf8), start = UInt32(output.count), size = UInt32(bytes.count)
            var crc: UInt32 = 0xFFFFFFFF
            for byte in bytes { crc ^= UInt32(byte); for _ in 0..<8 { crc = crc & 1 == 1 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1 } }; crc ^= 0xFFFFFFFF
            put(0x04034B50,4,&output); for v: UInt32 in [20,0x800,0,0,33] { put(v,2,&output) }; for v in [crc,size,size] { put(v,4,&output) }; put(UInt32(filename.count),2,&output); put(0,2,&output); output.append(filename); output.append(bytes)
            put(0x02014B50,4,&central); for v: UInt32 in [20,20,0x800,0,0,33] { put(v,2,&central) }; for v in [crc,size,size] { put(v,4,&central) }; for v in [UInt32(filename.count),0,0,0,0] { put(v,2,&central) }; put(0,4,&central); put(start,4,&central); central.append(filename)
        }
        let start = UInt32(output.count); output.append(central); put(0x06054B50,4,&output); put(0,2,&output); put(0,2,&output); put(UInt32(files.count),2,&output); put(UInt32(files.count),2,&output); put(UInt32(central.count),4,&output); put(start,4,&output); put(0,2,&output)
        return output
    }
}
