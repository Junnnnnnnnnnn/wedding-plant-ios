import UIKit
import WPDomain
import WPModels
import WPUtils

/// A4 landscape timeline. Measurements and colors match Android ExportPdf.
final class CalendarPDF {
    private let side: CGFloat = 196, pad: CGFloat = 22, whenRight: CGFloat = 284, spine: CGFloat = 307, content: CGFloat = 330, right: CGFloat = 806
    private let pink = UIColor(hex: 0xEE2B8C), ink = UIColor(hex: 0x1A1C20), muted = UIColor(hex: 0x555D6D), subtle = UIColor(hex: 0x868B94), dim = UIColor(hex: 0x9A9EA6), rule = UIColor(hex: 0xFFC9E0)
    private var cg: CGContext { UIGraphicsGetCurrentContext()! }
    private func font(_ size: CGFloat, _ strong: Bool = false) -> UIFont { UIFont(name: strong ? "HakgyoansimDunggeunmisoTTF-B" : "HakgyoansimDunggeunmisoTTF-R", size: size) ?? .systemFont(ofSize: size, weight: strong ? .bold : .regular) }
    private func width(_ s: String, _ size: CGFloat, _ strong: Bool = false) -> CGFloat { (s as NSString).size(withAttributes: [.font: font(size, strong)]).width }
    @discardableResult private func text(_ s: String, _ x: CGFloat, _ baseline: CGFloat, _ size: CGFloat, _ color: UIColor, strong: Bool = false, right: Bool = false) -> CGFloat {
        let f = font(size, strong), w = width(s, size, strong)
        (s as NSString).draw(at: CGPoint(x: right ? x - w : x, y: baseline - f.ascender), withAttributes: [.font: f, .foregroundColor: color]); return w
    }
    private func wrap(_ raw: String, _ size: CGFloat, _ maxWidth: CGFloat, _ strong: Bool = false) -> [String] {
        var result: [String] = [], line = ""
        for word in raw.replacingOccurrences(of: "[\\r\\n\\t]", with: " ", options: .regularExpression).components(separatedBy: " ") {
            let next = line.isEmpty ? word : line + " " + word
            if width(next, size, strong) <= maxWidth { line = next; continue }
            if !line.isEmpty { result.append(line) }; line = ""
            for character in word {
                if !line.isEmpty && width(line + String(character), size, strong) > maxWidth { result.append(line); line = String(character) } else { line.append(character) }
            }
        }
        result.append(line); return result
    }
    private func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ color: UIColor, _ width: CGFloat, dash: [CGFloat] = []) {
        cg.saveGState(); cg.setStrokeColor(color.cgColor); cg.setLineWidth(width); cg.setLineCap(.round); cg.setLineDash(phase: 0, lengths: dash); cg.move(to: CGPoint(x: x1, y: y1)); cg.addLine(to: CGPoint(x: x2, y: y2)); cg.strokePath(); cg.restoreGState()
    }
    private func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ fill: UIColor?, _ border: UIColor?, _ width: CGFloat = 1.4, dash: [CGFloat] = []) {
        cg.saveGState(); let rect = CGRect(x: x-r, y: y-r, width: r*2, height: r*2)
        if let fill { cg.setFillColor(fill.cgColor); cg.fillEllipse(in: rect) }
        if let border { cg.setStrokeColor(border.cgColor); cg.setLineWidth(width); cg.setLineDash(phase: 0, lengths: dash); cg.strokeEllipse(in: rect) }; cg.restoreGState()
    }
    func write(_ doc: ExportDoc, to url: URL) throws {
        let bounds = CGRect(x: 0, y: 0, width: 842, height: 595)
        var total = 0
        _ = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in total = draw(doc, context, total: 0) }
        // Each pass owns its PDF consumer; reusing a finalized renderer can produce an empty file.
        try UIGraphicsPDFRenderer(bounds: bounds).writePDF(to: url) { context in _ = draw(doc, context, total: total) }
    }
    private func draw(_ doc: ExportDoc, _ context: UIGraphicsPDFRendererContext, total: Int) -> Int {
        let sorted = CalendarExport.sorted(doc.items), totals = CalendarExport.totals(sorted), dday = CalendarExport.dday(doc), money = doc.template == .budget
        let couple = doc.plan?.couple?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var page = 0
        func sidebar(_ first: Bool) {
            UIColor(hex: 0xFFF1F7).setFill(); cg.fill(CGRect(x: 0,y: 0,width: 196,height: 595))
            text("웨딩플랜트", pad, 38, 8, UIColor(hex: 0xCC1873)); var y: CGFloat = 38
            if first {
                let names = couple.contains(" · ") ? couple.components(separatedBy: " · ").enumerated().map { $0.offset == 0 ? $0.element : "그리고 " + $0.element } : [couple.isEmpty ? "우리의 결혼 준비" : couple]
                for name in names.flatMap({ wrap($0, 20, 152, true) }).prefix(3) { y += 27; text(name, pad, y, 20, ink, strong: true) }
                if let dday { y += 52; text("D-\(dday)", pad, y, 40, pink, strong: true) }
                y += doc.plan?.weddingDate != nil ? 20 : 22
                text(doc.plan?.weddingDate?.weddingDateText ?? "결혼일은 아직 정하지 않았어요", pad, y, 8.5, muted)
                if let venue = doc.plan?.venue { for row in wrap(venue, 8.5, 152).prefix(2) { y += 12.5; text(row, pad, y, 8.5, muted) } }
                y += 16; line(pad, y, side-pad, y, rule, 0.8); y += 20; text(doc.template.label, pad, y, 12, ink, strong: true)
                let scope = doc.scope + (doc.template == .checklist ? "" : " · 금액 단위 만 원")
                for row in wrap(scope, 7.5, 152) { y += 11; text(row, pad, y, 7.5, subtle) }; y += 6
                for (label, value, unit) in CalendarExport.summaryStats(doc) where y + 34 <= 519 {
                    y += 18; text(label, pad, y, 7.5, subtle); y += 17
                    let w = text(value, pad, y, 15, ink, strong: true); text(unit, pad+w+3, y, 8, muted)
                }
            } else {
                y += 25; text(wrap(couple.isEmpty ? "우리의 결혼 준비" : couple, 15, 152, true)[0], pad, y, 15, ink, strong: true)
                if let dday { y += 34; text("D-\(dday)", pad, y, 26, pink, strong: true) }
                y += 18; line(pad,y,side-pad,y,rule,0.8); y += 20; text(doc.template.label,pad,y,12,ink,strong:true); y += 12; text("이어서",pad,y,7.5,subtle)
            }
            let labels = money ? ["결제함","아직 안 냄","날짜 미정"] : ["끝낸 일","남은 일","날짜 미정"]
            for (i,label) in labels.enumerated() {
                let base = 565-CGFloat(2-i)*13
                circle(pad+4,base-2.6,3.8,i == 0 ? pink : .white,i == 2 ? UIColor(hex:0xB3B7BE) : pink,1.1,dash:i == 2 ? [1.2,1.2] : [])
                text(label,pad+13,base,7.5,muted)
            }
        }
        func finish() {
            guard page > 0 else { return }
            let foot = doc.today.dateString.replacingOccurrences(of:"-",with:".") + (doc.template == .checklist ? " 기준 · 날짜순 · 날짜 미정은 맨 끝" : " 기준 · 금액 단위 만 원 · 금액 미정 \(totals.unknown)건은 합계에서 제외")
            text(foot,226,577,7.5,dim); text("\(page) / \(max(total,page))",right,577,7.5,dim,right:true)
        }
        func newPage() -> CGFloat { finish(); context.beginPage(); page += 1; sidebar(page == 1); return 26 }
        func month(_ group: ExportMonthGroup, _ y: CGFloat, continued: Bool) -> CGFloat {
            text(continued ? "이어서" : group.year.map(String.init) ?? "언젠가",whenRight,y+9,7.5,subtle,right:true)
            text(group.short,whenRight,y+30,22,ink,strong:true,right:true)
            let t = CalendarExport.totals(group.items), sum = doc.template == .checklist ? "완료 \(t.done) / \(t.count)" : "\(t.count)건 · \(CalendarExport.won(t.total))만 원"
            text(sum,right,y+28,8,UIColor(hex:0xA5105C),right:true); line(content,y+25,right-width(sum,8)-12,y+25,rule,0.8); return y+38
        }
        func wedding(_ s: ScheduleItem) -> Bool { doc.plan?.weddingDate != nil && CalendarExport.dateOf(s) == doc.plan?.weddingDate }
        func measure(_ s: ScheduleItem) -> (CGFloat,[String],Bool,CGFloat) {
            let size: CGFloat = wedding(s) ? 12 : 10.5, strong = !(s.status?.isCompleted == true && !money)
            var rows = wrap(wedding(s) ? "결혼식 · " + s.title : s.title,size,right-content-(doc.template != .checklist ? 96 : 0),strong)
            let maxLines = Int((553-26-38-30)/(size+3.5))
            if rows.count > maxLines { rows = Array(rows.prefix(maxLines)); rows[maxLines-1] = String(rows[maxLines-1].dropLast()) + "..." }
            return (size,rows,strong,max(30,7+CGFloat(rows.count)*(size+3.5)+16))
        }
        func item(_ s: ScheduleItem, _ y: CGFloat) -> CGFloat {
            let (size,rows,strong,h) = measure(s), date = CalendarExport.dateOf(s), filled = money ? s.isPaid : s.status?.isCompleted == true, first = y+7+size
            if let date {
                text("\(date.month).\(date.day)",whenRight,first,10,ink,strong:true,right:true)
                text(date.weddingDateText.components(separatedBy:"(").last?.replacingOccurrences(of:")",with:"요일") ?? "",whenRight,first+10,7,subtle,right:true)
            } else { text("미정",whenRight,first,7.5,subtle,right:true) }
            line(spine,y,spine,y+h,date == nil ? UIColor(hex:0xCDBFC7) : rule,1.2,dash:date == nil ? [2.5,2.5] : [])
            let cy = first-size*0.36
            if wedding(s) { circle(spine,cy,10,UIColor(hex:0xFFE3EF),nil); circle(spine,cy,7.5,pink,nil) }
            else { circle(spine,cy,5.5,filled ? pink : .white,date == nil ? UIColor(hex:0xB3B7BE) : pink,dash:date == nil ? [1.5,1.5] : []) }
            for (i,row) in rows.enumerated() { text(row,content,first+CGFloat(i)*(size+3.5),size,wedding(s) ? UIColor(hex:0xCC1873) : (!money && s.status?.isCompleted == true ? dim : ink),strong:strong) }
            let meta = first+CGFloat(rows.count-1)*(size+3.5)+13, cat = s.categoryName.isEmpty ? "기타" : s.categoryName, cw = width(cat,7)+12
            let chip = UIBezierPath(roundedRect:CGRect(x:content,y:meta-8.5,width:cw,height:11.5),cornerRadius:5.75); UIColor(hex:0xFFA3CB).setStroke(); chip.lineWidth=0.7; chip.stroke(); text(cat,content+6,meta,7,UIColor(hex:0xCC1873))
            var x = content+cw+7
            func tag(_ s: String,_ c: UIColor) { x += text(s,x,meta,7.5,c)+7 }
            let time = formatKoreanTime(s.startTime); if !time.isEmpty { tag(time,subtle) }
            if money { tag(s.isPaid ? "결제함" : "미결제",s.isPaid ? UIColor(hex:0x079171) : subtle) }
            else { if s.amount != nil && s.isPaid && s.status?.isCompleted != true { tag("결제함",UIColor(hex:0x079171)) }; if s.status?.isCompleted == true { tag("완료",subtle) } }
            if doc.template != .checklist {
                if let amount = s.amount { let uw = text("만 원",right,first,7.5,subtle,right:true); text(CalendarExport.won(amount),right-uw-2,first,11,ink,strong:true,right:true) }
                else { text("금액 미정",right,first,8,UIColor(hex:0xB3B7BE),right:true) }
            }
            return y+h
        }
        var y = newPage(); let months = CalendarExport.groupByMonth(sorted)
        if months.isEmpty { text("이 기간에 등록된 일정이 없어요.",content,y+30,11,muted) }
        for group in months {
            if y+38+measure(group.items[0]).3 > 553 { y = newPage() }; y = month(group,y,continued:false)
            for s in group.items { if y+measure(s).3 > 553 { y = newPage(); y = month(group,y,continued:true) }; y = item(s,y) }; y += 4
        }
        finish(); return page
    }
}

private extension UIColor {
    convenience init(hex: UInt32) { self.init(red: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255, blue: CGFloat(hex & 255)/255, alpha: 1) }
}
