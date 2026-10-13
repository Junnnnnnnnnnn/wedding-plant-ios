import UIKit
import CoreText

/// Android PixelText: 12px 글꼴, 18px 줄 높이. 세로 여백은 줄의 양끝에도 남긴다.
func gardenPixelText(_ text: String, color: UIColor) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.minimumLineHeight = 18; paragraph.maximumLineHeight = 18
    paragraph.lineBreakStrategy = []; paragraph.lineBreakMode = .byWordWrapping
    return NSAttributedString(string: text, attributes: [.font: WPTypeface.pixel.uiFont(12, .regular), .foregroundColor: color, .paragraphStyle: paragraph])
}

/// CoreText의 기준선을 14, 32, 50…으로 고정해 PixelText의 18px 행간을 유지한다.
private final class GardenPixelLabel: UILabel {
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard let text = attributedText, text.length > 0 else { return .zero }
        let typesetter = CTTypesetterCreateWithAttributedString(text)
        var index = 0, rows = 0; var width: CGFloat = 0
        while index < text.length {
            let count = CTTypesetterSuggestLineBreak(typesetter, index, max(1, Double(size.width)))
            guard count > 0 else { break }
            let line = CTTypesetterCreateLine(typesetter, CFRange(location: index, length: count))
            width = max(width, CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)))
            index += count; rows += 1
        }
        return CGSize(width: min(size.width, ceil(width)), height: CGFloat(rows) * 18)
    }
    override func drawText(in rect: CGRect) {
        guard let text = attributedText, let context = UIGraphicsGetCurrentContext() else { return }
        let typesetter = CTTypesetterCreateWithAttributedString(text)
        var index = 0, row = 0
        context.saveGState(); context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.height); context.scaleBy(x: 1, y: -1)
        while index < text.length {
            let count = CTTypesetterSuggestLineBreak(typesetter, index, max(1, Double(bounds.width)))
            guard count > 0 else { break }
            let line = CTTypesetterCreateLine(typesetter, CFRange(location: index, length: count))
            context.textPosition = CGPoint(x: 0, y: bounds.height - 14 - CGFloat(row) * 18)
            CTLineDraw(line, context); index += count; row += 1
        }
        context.restoreGState()
    }
}

final class GardenNameplate: UIView {
    private let title = GardenPixelLabel(), note = GardenPixelLabel(), border = CAShapeLayer()
    private let forest = UIColor(red: 24/255, green: 62/255, blue: 50/255, alpha: 1)
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(border)
        backgroundColor = UIColor(red: 247/255, green: 244/255, blue: 236/255, alpha: 1)
        title.numberOfLines = 0; addSubview(title); addSubview(note)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func update(title text: String, note hint: String?) {
        title.attributedText = gardenPixelText(text, color: forest)
        note.attributedText = hint.map { gardenPixelText($0, color: UIColor(red: 181/255, green: 151/255, blue: 95/255, alpha: 1)) }
        setNeedsLayout()
    }
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let noteWidth = note.attributedText?.size().width ?? 0, gap: CGFloat = noteWidth > 0 ? 8 : 0
        let available = max(0, size.width - 16 - noteWidth - gap)
        let text = title.sizeThatFits(CGSize(width: available, height: .greatestFiniteMagnitude))
        return CGSize(width: min(size.width, text.width + 16 + noteWidth + gap), height: max(18, ceil(text.height / 18) * 18) + 9)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let noteWidth = note.attributedText?.size().width ?? 0, gap: CGFloat = noteWidth > 0 ? 8 : 0
        title.frame = CGRect(x: 8, y: 5, width: bounds.width - 16 - noteWidth - gap, height: bounds.height - 9)
        note.frame = CGRect(x: bounds.width - 8 - noteWidth, y: 5, width: noteWidth, height: 18)
        let p = UIBezierPath()
        for r in [CGRect(x: 0, y: -2, width: bounds.width, height: 2), CGRect(x: 0, y: bounds.height, width: bounds.width, height: 2), CGRect(x: -2, y: 0, width: 2, height: bounds.height), CGRect(x: bounds.width, y: 0, width: 2, height: bounds.height)] { p.append(UIBezierPath(rect: r)) }
        border.path = p.cgPath; border.fillColor = forest.cgColor
    }
}

/// 말풍선 본문을 읽거나 굴리면 유지하고, × 버튼으로 닫는다.
final class GardenSpeechBubble: UIView {
    private let heading = GardenPixelLabel(), message = GardenPixelLabel(), scroll = UIScrollView(), close = UIButton(type: .custom)
    private let frameLayer = CAShapeLayer(), shadowLayer = CAShapeLayer()
    private let forest = UIColor(red: 24/255, green: 62/255, blue: 50/255, alpha: 1)
    private let paper = UIColor(red: 247/255, green: 244/255, blue: 236/255, alpha: 1)
    private let muted = UIColor(red: 118/255, green: 124/255, blue: 110/255, alpha: 1)
    var tailX: CGFloat = 8 { didSet { setNeedsLayout() } }
    var onClose: () -> Void = {}, onHold: () -> Void = {}
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = paper
        layer.addSublayer(shadowLayer); layer.addSublayer(frameLayer)
        heading.numberOfLines = 0; message.numberOfLines = 0
        addSubview(heading); addSubview(scroll); scroll.addSubview(message)
        scroll.showsVerticalScrollIndicator = false
        close.setAttributedTitle(gardenPixelText("×", color: muted), for: .normal)
        close.accessibilityLabel = "축하 글 닫기"
        close.addTarget(self, action: #selector(closePressed), for: .touchUpInside); addSubview(close)
        let tap = UITapGestureRecognizer(target: self, action: #selector(holdPressed)); tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
        scroll.panGestureRecognizer.addTarget(self, action: #selector(holdPressed))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func closePressed() { onClose() }
    @objc private func holdPressed() { onHold() }
    func update(speaker: String, text: String) {
        heading.attributedText = gardenPixelText(speaker, color: muted)
        message.attributedText = gardenPixelText(text, color: forest)
        scroll.contentOffset = .zero
        accessibilityLabel = speaker + ": " + text
    }
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let head = heading.sizeThatFits(CGSize(width: size.width - 48, height: .greatestFiniteMagnitude))
        let body = message.sizeThatFits(CGSize(width: size.width - 24, height: .greatestFiniteMagnitude))
        return CGSize(width: size.width, height: 9 + ceil(head.height / 18) * 18 + 6 + min(72, ceil(body.height / 18) * 18) + 10)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let headH = ceil(heading.sizeThatFits(CGSize(width: bounds.width - 48, height: .greatestFiniteMagnitude)).height / 18) * 18
        heading.frame = CGRect(x: 12, y: 9, width: bounds.width - 48, height: headH)
        scroll.frame = CGRect(x: 12, y: 15 + headH, width: bounds.width - 24, height: bounds.height - headH - 25)
        let bodyH = ceil(message.sizeThatFits(CGSize(width: scroll.bounds.width, height: .greatestFiniteMagnitude)).height / 18) * 18
        message.frame = CGRect(x: 0, y: 0, width: scroll.bounds.width, height: bodyH)
        scroll.contentSize = message.bounds.size
        close.frame = CGRect(x: bounds.width - 32, y: 0, width: 30, height: 30)
        let w = bounds.width, h = bounds.height, x = tailX
        let shadow = UIBezierPath()
        for r in [CGRect(x: w + 2, y: 4, width: 2, height: h - 4), CGRect(x: w, y: h, width: 4, height: 4), CGRect(x: 4, y: h + 2, width: w - 4, height: 2)] { shadow.append(UIBezierPath(rect: r)) }
        shadowLayer.path = shadow.cgPath; shadowLayer.fillColor = UIColor(red: 17/255, green: 43/255, blue: 37/255, alpha: 0.3).cgColor
        let frame = UIBezierPath()
        for r in [CGRect(x: 0, y: -2, width: w, height: 2), CGRect(x: 0, y: h, width: w, height: 2), CGRect(x: -2, y: 0, width: 2, height: h), CGRect(x: w, y: 0, width: 2, height: h), CGRect(x: x - 2, y: h, width: 10, height: 4), CGRect(x: x, y: h + 4, width: 6, height: 4), CGRect(x: x + 2, y: h + 8, width: 2, height: 2)] { frame.append(UIBezierPath(rect: r)) }
        frameLayer.path = frame.cgPath; frameLayer.fillColor = forest.cgColor
        if layer.sublayers?.contains(where: { $0.name == "tailPaper" }) != true {
            let tail = CAShapeLayer(); tail.name = "tailPaper"; layer.insertSublayer(tail, above: frameLayer)
        }
        if let tail = layer.sublayers?.first(where: { $0.name == "tailPaper" }) as? CAShapeLayer {
            let p = UIBezierPath(rect: CGRect(x: x, y: h, width: 6, height: 4)); p.append(UIBezierPath(rect: CGRect(x: x + 2, y: h + 4, width: 2, height: 4)))
            tail.path = p.cgPath; tail.fillColor = paper.cgColor
        }
    }
}
