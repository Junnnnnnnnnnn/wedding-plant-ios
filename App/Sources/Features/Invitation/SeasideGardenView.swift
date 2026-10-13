import SwiftUI
import UIKit
import CoreText
import WPDomain
import WPModels

struct SeasideGardenView: UIViewRepresentable {
    var wishes: [InvitationWish] = []
    var demo = false
    var empty = false
    var peek = false
    var groom = "정우진"
    var bride = "이채원"
    var script: [String]? = nil
    var labelNote: String? = nil
    var emptySeats = false
    func makeUIView(context: Context) -> GardenCanvas {
        GardenCanvas(wishes: wishes, demo: demo, empty: empty, peek: peek, groom: groom, bride: bride, script: script, labelNote: labelNote, emptySeats: emptySeats)
    }
    func updateUIView(_ view: GardenCanvas, context: Context) {
        view.updateWishes(wishes)
        view.updateCouple(groom: groom, bride: bride)
        view.updatePresentation(script: script, labelNote: labelNote, emptySeats: emptySeats, groom: groom, bride: bride)
    }
    static func dismantleUIView(_ uiView: GardenCanvas, coordinator: ()) { uiView.stop() }
}

/// Draw at world resolution first, then enlarge with nearest-neighbour sampling.
/// Flying sprites use unclipped subviews so they cross the header above the garden.
final class GardenCanvas: UIView {
    private let engine: SeasideEngine
    private let demo: Bool, empty: Bool, peek: Bool
    private var lastWishes: [InvitationWish]
    private var present: [InvitationWish]
    private var nextDrop = 7
    private var link: CADisplayLink?
    private var lastTick: CFTimeInterval?
    private var flightViews: [Int: UIImageView] = [:]
    private let dialog = GardenDialogLabel()
    private let speaker = UILabel()
    private let nameplate = GardenNameplate()
    private let bubble = GardenSpeechBubble()
    private var bubbleAppearedAt: Double?
    private var line = 0, typed = 0
    private var typedAt = 0.0, completedAt: Double?, lastBeat = -100.0
    private var lastSpeechSerial = -1
    private var lines: [String]
    private let showsDialog: Bool, motionEnabled: Bool
    private var extraEmptySeats: Bool
    private static let demoWishes: [InvitationWish] = {
        let names = ["지은","수아","민재","외숙모","하린","할머니","도윤","서연","큰아버지","유나","준호","이모"]
        let messages = ["결혼 축하해요!","채원아 너무 예뻐","우진아 장가 간다!","두 분 행복하세요","식장에서 봐요","평생 지금처럼 웃으며 살아라","축하 축하!","오래오래 다정하게","잘 살아라","두 사람의 모든 계절을 응원해","신혼여행 사진 꼭 보여줘","예쁜 가정 이루렴"]
        let avatars = [2,4,6,12,9,18,0,7,15,3,10,13]
        return names.indices.map { InvitationWish(id: "example-landing-\($0)", name: names[$0], message: messages[$0], avatar: avatars[$0]) }
    }()
    private static let venue = UIImage(named: "invitation_seaside_venue")
    private static let sprites: [[UIImage]] = frames("invitation_seaside_guests", rows: 20)
    private static let couple: [[UIImage]] = frames("invitation_seaside_couple", rows: 2)
    private static func frames(_ name: String, rows: Int) -> [[UIImage]] {
        guard let atlas = UIImage(named: name)?.cgImage else { return [] }
        return (0..<rows).map { row in (0..<8).compactMap { pose in
            atlas.cropping(to: CGRect(x: pose * 48, y: row * 72, width: 48, height: 72)).map { UIImage(cgImage: $0) }
        } }
    }
    init(wishes: [InvitationWish], demo: Bool, empty: Bool, peek: Bool, groom: String, bride: String, script: [String]? = nil, labelNote: String? = nil, emptySeats: Bool = false, motionEnabled: Bool = true) {
        self.showsDialog = demo || empty || script != nil; self.motionEnabled = motionEnabled; extraEmptySeats = emptySeats
        self.demo = demo; self.empty = empty; self.peek = peek; lastWishes = wishes
        present = demo ? Array(Self.demoWishes.prefix(7)) : wishes
        engine = SeasideEngine(groom: groom, bride: bride, wishes: present, quietCouple: empty,
                              seed: ProcessInfo.processInfo.arguments.contains("-WPDemoMode") ? 42 : UInt64.random(in: 1...UInt64.max))
        lines = script ?? (demo ? ["청첩장 링크를 받은 하객이 이 정원으로 들어와요.", "축하 글을 남기면, 고른 얼굴의 하객이 하늘에서 내려와요.", "사진 최대 20장과 예식 날짜·장소가 한 장에 담겨요.", "준비 패스를 사면 이 청첩장을 1회 만들 수 있어요."] : ["아직 아무도 오지 않았어요. 청첩장을 보내기 전이거든요.", "사진과 장소, 초대의 말을 넣으면 한 장이 완성돼요.", "링크를 받은 사람이 축하를 남기면, 이 자리에 와서 서요."])
        super.init(frame: .zero)
        isOpaque = false; clipsToBounds = false; contentMode = .redraw
        accessibilityIdentifier = "invitation.garden"
        dialog.font = UIFont(name: "WP-Pixel-11-Regular", size: 12) ?? .monospacedSystemFont(ofSize: 12, weight: .regular)
        dialog.textColor = UIColor(red: 0.96, green: 0.95, blue: 0.9, alpha: 1)
        dialog.numberOfLines = 0; dialog.backgroundColor = UIColor(red: 0.09, green: 0.235, blue: 0.184, alpha: 1)
        dialog.layer.borderColor = UIColor(red: 0.937, green: 0.855, blue: 0.647, alpha: 1).cgColor
        dialog.isUserInteractionEnabled = true
        dialog.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(skipLine)))
        dialog.isAccessibilityElement = true; dialog.accessibilityTraits = .button
        speaker.font = dialog.font; speaker.textColor = dialog.textColor; speaker.backgroundColor = dialog.backgroundColor
        speaker.textColor = dialog.backgroundColor
        speaker.backgroundColor = UIColor(red: 0.937, green: 0.855, blue: 0.647, alpha: 1)
        nameplate.update(title: demo ? "우진 & 채원 · 축하의 정원" : empty ? "축하의 정원" : "\(groom) & \(bride) · 축하의 정원", note: labelNote ?? (demo ? "예시" : empty ? "하객 0명" : nil))
        addSubview(nameplate)
        speaker.text = demo ? "웨딩플랜트" : "정원지기"
        speaker.textAlignment = .center
        speaker.layer.borderColor = dialog.backgroundColor?.cgColor; speaker.layer.borderWidth = 3
        if !peek && showsDialog { addSubview(dialog); addSubview(speaker) }
        bubble.onClose = { [weak self] in self?.closeSpeech() }
        bubble.onHold = { [weak self] in self?.engine.holdSpeech() }
        bubble.isHidden = true; addSubview(bubble)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
        if !motionEnabled && showsDialog { typed = lines[0].count; advanceDialog() }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func updateWishes(_ values: [InvitationWish]) {
        guard !demo, values != lastWishes else { return }
        lastWishes = values; engine.setWishes(values)
    }
    func updateCouple(groom: String, bride: String) {
        for actor in engine.actors where actor.isCouple {
            let name = actor.id == 8 ? groom : bride
            if actor.wish?.name != name {
                actor.wish?.name = name
                lastSpeechSerial = -1
            }
        }
    }
    func updatePresentation(script: [String]?, labelNote: String?, emptySeats: Bool, groom: String, bride: String) {
        if let script, !script.isEmpty, script != lines {
            lines = script; line = 0; typed = motionEnabled ? 0 : script[0].count; typedAt = engine.time; completedAt = nil
            advanceDialog()
        }
        extraEmptySeats = emptySeats
        nameplate.update(title: demo ? "우진 & 채원 · 축하의 정원" : empty ? "축하의 정원" : "\(groom) & \(bride) · 축하의 정원", note: labelNote ?? (demo ? "예시" : empty ? "하객 0명" : nil))
        setNeedsLayout(); setNeedsDisplay()
    }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stop() } else if link == nil && motionEnabled {
            let display = CADisplayLink(target: self, selector: #selector(tick(_:)))
            display.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            display.add(to: .main, forMode: .common); link = display
        }
    }
    func stop() { link?.invalidate(); link = nil; lastTick = nil }
    override func layoutSubviews() {
        super.layoutSubviews()
        dialog.frame = CGRect(x: 9, y: bounds.height - 79, width: bounds.width - 18, height: 70)
        nameplate.frame = CGRect(origin: CGPoint(x: 14, y: 14), size: nameplate.sizeThatFits(CGSize(width: bounds.width - 28, height: 100)))
        speaker.frame = CGRect(x: 18, y: dialog.frame.minY - 17, width: speaker.intrinsicContentSize.width + 26, height: 30)
        updateFlight()
    }
    private var unit: CGFloat { bounds.width / 320 }
    private var sceneY: CGFloat {
        guard peek, unit > 0 else { return bounds.height - 440 * unit }
        // Android GardenPeek: world y 172...332; preserve couple heads on shorter cards.
        let visible = min(160, max(1, bounds.height / unit))
        return -(172 + min((160 - visible) / 2, 12)) * unit
    }
    @objc private func tick(_ display: CADisplayLink) {
        defer { lastTick = display.timestamp }
        guard UIApplication.shared.applicationState == .active, let window,
              convert(bounds, to: window).intersects(window.bounds) else { lastTick = nil; return }
        guard let previous = lastTick, unit > 0 else { return }
        let origin = convert(CGPoint(x: 0, y: sceneY), to: window)
        engine.skyAbove = max(12, (origin.y + 12) / unit)
        engine.update(display.timestamp - previous)
        if !peek && showsDialog { advanceDialog() }
        updateFlight(); if !peek { updateBubble() }; setNeedsDisplay()
    }
    private func advanceDialog() {
        // Carry the remainder between display frames: resetting to `time` makes a 56 ms
        // character take 4 × 16.7 ms and delays the following drop by almost 0.3 seconds.
        if typed < lines[line].count {
            let count = min(lines[line].count - typed, Int((engine.time - typedAt) / 0.056))
            if count > 0 { typed += count; typedAt += Double(count) * 0.056 }
        }
        if typed == lines[line].count {
            if completedAt == nil { completedAt = typedAt }
            if engine.time - (completedAt ?? engine.time) >= 2.6 { nextLine() }
        }
        let full = lines[line]
        let paragraph = NSMutableParagraphStyle(); paragraph.minimumLineHeight = 18; paragraph.maximumLineHeight = 18
        let wrapped = full.wpKeepAll
        let attributed = NSMutableAttributedString(string: wrapped, attributes: [.paragraphStyle: paragraph, .font: dialog.font!, .foregroundColor: UIColor(red: 247/255, green: 245/255, blue: 237/255, alpha: 1)])
        let shown = String(full.prefix(typed)).wpKeepAll.utf16.count
        if shown < wrapped.utf16.count { attributed.addAttribute(.foregroundColor, value: UIColor.clear, range: NSRange(location: shown, length: wrapped.utf16.count - shown)) }
        dialog.attributedText = attributed
        dialog.updateIndicators(line: line, count: lines.count, more: typed == full.count && engine.time.truncatingRemainder(dividingBy: 0.8) < 0.4)
        dialog.accessibilityLabel = "\(speaker.text ?? ""): \(lines[line]) (다음 이야기)"
    }
    @objc private func skipLine() { if typed < lines[line].count { typed = lines[line].count; typedAt = engine.time; completedAt = engine.time } else { nextLine() } }
    private func nextLine() {
        line = (line + 1) % lines.count; typed = 0; completedAt = nil; typedAt = engine.time
        guard demo, engine.time - lastBeat >= 6 else { return }
        if line == 1 && engine.freeSeats > 0 {
            let wish = Self.demoWishes[nextDrop % Self.demoWishes.count]; nextDrop += 1
            engine.enter(wish, drop: true, quiet: true); present.append(wish); engine.setWishes(present); lastBeat = engine.time
        } else if line == 3 && !present.isEmpty { present.removeFirst(); engine.setWishes(present); lastBeat = engine.time }
    }
    private func sprite(_ a: SeasideEngine.Actor) -> UIImage? {
        let atlas = a.isCouple ? Self.couple : Self.sprites
        let row = a.isCouple ? a.id - 8 : (a.wish?.avatar ?? 0)
        guard atlas.indices.contains(row), atlas[row].indices.contains(a.pose) else { return nil }
        return atlas[row][a.pose]
    }
    private func updateFlight() {
        for a in engine.actors {
            guard a.visible && a.flying else { flightViews[a.id]?.isHidden = true; continue }
            let view: UIImageView
            if let existing = flightViews[a.id] { view = existing }
            else { view = UIImageView(); view.layer.magnificationFilter = .nearest; view.layer.minificationFilter = .nearest; addSubview(view); flightViews[a.id] = view }
            view.image = sprite(a); view.isHidden = false
            view.frame = CGRect(x: (a.x - a.width / 2) * unit, y: sceneY + a.top * unit, width: a.width * unit, height: a.height * unit)
            bringSubviewToFront(view)
        }
    }
    private func updateBubble() {
        guard let a = engine.speech, let wish = a.wish else { bubble.isHidden = true; bubbleAppearedAt = nil; return }
        if lastSpeechSerial != engine.speechSerial {
            lastSpeechSerial = engine.speechSerial
            bubble.update(speaker: "\(wish.name)의 \(a.isCouple ? "마음" : "축하")", text: wish.message)
        }
        let width = min(bounds.width - 20, 196.0)
        let height = bubble.sizeThatFits(CGSize(width: width, height: bounds.height)).height
        let x = CGFloat(a.headX) * unit, y = sceneY + CGFloat(a.headY) * unit
        let waiting = a.flying && y - height - 11 < 8
        bubble.isHidden = waiting
        if bubbleAppearedAt == nil { bubbleAppearedAt = engine.time }
        let q = min(1, floor((engine.time - (bubbleAppearedAt ?? engine.time)) / 0.24 * 3) / 3)
        let left = max(8, min(bounds.width - width - 8, x - width / 2)).rounded()
        let top = max(8, y - height - 11).rounded()
        bubble.frame = CGRect(x: left, y: top + (1 - q) * 4, width: width, height: height)
        bubble.tailX = max(8, min(width - 16, x - left - 4)).rounded()
        bubble.alpha = q
        bubble.accessibilityLabel = "\(wish.name)의 축하 글: \(wish.message)"
        bringSubviewToFront(bubble)
    }
    @objc private func closeSpeech() { engine.closeSpeech(); bubble.isHidden = true }
    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        let p = gesture.location(in: self)
        if showsDialog && dialog.frame.contains(p) { return }
        if !bubble.isHidden && bubble.frame.contains(p) { engine.holdSpeech(); return }
        if let actor = engine.hit(x: p.x / unit, y: (p.y - sceneY) / unit) { engine.showSpeech(actor, manual: true); updateBubble() }
    }
    override func draw(_ rect: CGRect) {
        guard unit > 0, let screen = UIGraphicsGetCurrentContext() else { return }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let frame = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 440), format: format).image { renderer in
            let c = renderer.cgContext; c.interpolationQuality = .none; c.setShouldAntialias(false)
            Self.venue?.draw(in: CGRect(x: 0, y: 0, width: 320, height: 440))
            c.setFillColor(UIColor(red: 245/255, green: 248/255, blue: 219/255, alpha: 0.55).cgColor)
            for i in 0..<9 where Int(floor(engine.time * 1.1 + Double(i))) % 3 == 0 {
                c.fill(CGRect(x: (i * 37 + 19) % 310, y: 104 + (i * 13) % 40, width: 4, height: 1))
            }
            for a in engine.actors.filter(\.visible).sorted(by: { ($0.arrival != nil ? 1 : 0, $0.y, $0.id) < ($1.arrival != nil ? 1 : 0, $1.y, $1.id) }) {
                c.setFillColor((a === engine.selected ? UIColor(red: 0.95, green: 0.91, blue: 0.75, alpha: 0.67) : UIColor(red: 0.27, green: 0.33, blue: 0.22, alpha: 0.22)).cgColor)
                c.fill(CGRect(x: (a.x - 13 * a.scale).rounded(), y: (a.y - 1).rounded(), width: (26 * a.scale).rounded(), height: 3))
                if a.flying { continue }
                c.saveGState(); c.translateBy(x: a.x.rounded(), y: a.top.rounded())
                if a.mirror { c.scaleBy(x: -1, y: 1) }
                sprite(a)?.draw(in: CGRect(x: -(a.width / 2).rounded(), y: 0, width: a.width.rounded(), height: a.height.rounded()))
                c.restoreGState()
            }
            c.setFillColor(UIColor(red: 238/255, green: 230/255, blue: 196/255, alpha: 0.72).cgColor)
            for p in engine.particles { c.fill(CGRect(x: p.x.rounded(), y: p.y.rounded(), width: 2, height: 3)) }
        }
        screen.interpolationQuality = .none
        frame.draw(in: CGRect(x: 0, y: sceneY, width: bounds.width, height: 440 * unit))
        if empty || (extraEmptySeats && lastWishes.isEmpty) {
            // Seats are a screen-resolution overlay in Android, not part of the pixel scene.
            let side = min(34, max(16, bounds.width * 0.056)), arm = side * 0.45
            for (index, p) in SeasideEngine.positions.prefix(8).enumerated() {
                let x = p[0] * unit, y = sceneY + (p[1] - 30) * unit
                guard y >= -side && y <= bounds.height + side else { continue }
                screen.saveGState(); screen.setAlpha(SeasideEngine.emptySeatOpacity(time: engine.time, index: index))
                let box = CGRect(x: x - side / 2, y: y - side / 2, width: side, height: side)
                screen.setFillColor(UIColor(red: 23/255, green: 60/255, blue: 47/255, alpha: 89/255).cgColor); screen.fill(box)
                screen.setStrokeColor(UIColor.white.cgColor); screen.setLineDash(phase: 0, lengths: [4,3]); screen.setLineWidth(2)
                screen.stroke(box.insetBy(dx: 1, dy: 1))
                screen.setFillColor(UIColor.white.cgColor)
                screen.fill(CGRect(x: x - arm / 2, y: y - 1, width: arm, height: 2))
                screen.fill(CGRect(x: x - 1, y: y - arm / 2, width: 2, height: arm))
                screen.restoreGState()
            }
        }
    }
}

/// Android DialogBox: outer forest ring, corner-cut gold border, stable text wrap,
/// one square per line and a 0.8-second blinking continuation marker.
private final class GardenDialogLabel: UILabel {
    private let frameLayer = CAShapeLayer()
    private let forestLayer = CAShapeLayer()
    private let marks = CAShapeLayer(), inactiveMarks = CAShapeLayer()
    private var indicatorState = (line: 0, count: 0, more: false)
    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        layer.insertSublayer(forestLayer, at: 0)
        layer.insertSublayer(frameLayer, at: 1)
        layer.addSublayer(inactiveMarks); layer.addSublayer(marks)
        frameLayer.fillColor = UIColor(red: 239/255, green: 218/255, blue: 165/255, alpha: 1).cgColor
        forestLayer.fillColor = UIColor(red: 23/255, green: 60/255, blue: 47/255, alpha: 1).cgColor
        forestLayer.fillRule = .evenOdd
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        frameLayer.frame = bounds.insetBy(dx: -6, dy: -6)
        let box = CGRect(x: 6, y: 6, width: bounds.width, height: bounds.height)
        forestLayer.frame = frameLayer.frame
        let ring = UIBezierPath(rect: frameLayer.bounds); ring.append(UIBezierPath(rect: box))
        forestLayer.path = ring.cgPath
        let path = UIBezierPath()
        for r in [CGRect(x: box.minX, y: 3, width: box.width, height: 3),
                  CGRect(x: box.minX, y: box.maxY, width: box.width, height: 3),
                  CGRect(x: 3, y: box.minY, width: 3, height: box.height),
                  CGRect(x: box.maxX, y: box.minY, width: 3, height: box.height)] { path.append(UIBezierPath(rect: r)) }
        frameLayer.path = path.cgPath
        updateIndicators(line: indicatorState.line, count: indicatorState.count, more: indicatorState.more)
    }
    override func drawText(in rect: CGRect) {
        guard let text = attributedText, let context = UIGraphicsGetCurrentContext() else { return }
        let typesetter = CTTypesetterCreateWithAttributedString(text)
        var index = 0, row = 0
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.height); context.scaleBy(x: 1, y: -1)
        while index < text.length {
            let count = CTTypesetterSuggestLineBreak(typesetter, index, Double(max(0, rect.width - 70)))
            guard count > 0 else { break }
            let line = CTTypesetterCreateLine(typesetter, CFRange(location: index, length: count))
            context.textPosition = CGPoint(x: 12, y: bounds.height - (17 + 14 + CGFloat(row) * 18))
            CTLineDraw(line, context)
            index += count; row += 1
        }
        context.restoreGState()
    }
    func updateIndicators(line: Int, count: Int, more: Bool) {
        indicatorState = (line, count, more)
        let path = UIBezierPath(), off = UIBezierPath()
        for index in 0..<count {
            let x = bounds.width - 30 - CGFloat(count * 10 - 4) + CGFloat(index * 10)
            (index == line ? path : off).append(UIBezierPath(rect: CGRect(x: x, y: bounds.height - 16, width: 6, height: 6)))
        }
        if more {
            path.move(to: CGPoint(x: bounds.width - 24, y: bounds.height - 15))
            path.addLine(to: CGPoint(x: bounds.width - 12, y: bounds.height - 15))
            path.addLine(to: CGPoint(x: bounds.width - 18, y: bounds.height - 9)); path.close()
        }
        marks.fillColor = frameLayer.fillColor; marks.path = path.cgPath
        inactiveMarks.fillColor = UIColor(red: 47/255, green: 86/255, blue: 70/255, alpha: 1).cgColor; inactiveMarks.path = off.cgPath
    }
}
