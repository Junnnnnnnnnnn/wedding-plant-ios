import SwiftUI
import UIKit
import WPDomain
import WPModels

struct SeasideGardenView: UIViewRepresentable {
    var wishes: [InvitationWish] = []
    var demo = false
    var empty = false
    var peek = false
    var groom = "정우진"
    var bride = "이채원"
    func makeUIView(context: Context) -> GardenCanvas {
        GardenCanvas(wishes: wishes, demo: demo, empty: empty, peek: peek, groom: groom, bride: bride)
    }
    func updateUIView(_ view: GardenCanvas, context: Context) {
        view.updateWishes(wishes)
        view.updateCouple(groom: groom, bride: bride)
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
    private let dialog = UILabel()
    private let speaker = UILabel()
    private let nameplate = UILabel()
    private let bubble = UIButton(type: .custom)
    private var line = 0, typed = 0
    private var typedAt = 0.0, completedAt: Double?, lastBeat = -100.0
    private var lastSpeechSerial = -1
    private let lines: [String]
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
    init(wishes: [InvitationWish], demo: Bool, empty: Bool, peek: Bool, groom: String, bride: String) {
        self.demo = demo; self.empty = empty; self.peek = peek; lastWishes = wishes
        present = demo ? Array(Self.demoWishes.prefix(7)) : wishes
        engine = SeasideEngine(groom: groom, bride: bride, wishes: present, quietCouple: empty,
                              seed: ProcessInfo.processInfo.arguments.contains("-WPDemoMode") ? 42 : UInt64.random(in: 1...UInt64.max))
        lines = demo ? ["청첩장 링크를 받은 하객이 이 정원으로 들어와요.", "축하 글을 남기면, 고른 얼굴의 하객이 하늘에서 내려와요.", "사진 최대 20장과 예식 날짜·장소가 한 장에 담겨요.", "준비 패스를 사면 이 청첩장을 1회 만들 수 있어요."] : ["아직 아무도 오지 않았어요. 청첩장을 보내기 전이거든요.", "사진과 장소, 초대의 말을 넣으면 한 장이 완성돼요.", "링크를 받은 사람이 축하를 남기면, 이 자리에 와서 서요."]
        super.init(frame: .zero)
        isOpaque = false; clipsToBounds = false; contentMode = .redraw
        accessibilityIdentifier = "invitation.garden"
        dialog.font = UIFont(name: "WP-Pixel-11-Regular", size: 12) ?? .monospacedSystemFont(ofSize: 12, weight: .regular)
        dialog.textColor = UIColor(red: 0.96, green: 0.95, blue: 0.9, alpha: 1)
        dialog.numberOfLines = 0; dialog.backgroundColor = UIColor(red: 0.09, green: 0.235, blue: 0.184, alpha: 1)
        dialog.layer.borderColor = UIColor(red: 0.937, green: 0.855, blue: 0.647, alpha: 1).cgColor
        dialog.layer.borderWidth = 3; dialog.isUserInteractionEnabled = true
        dialog.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(skipLine)))
        dialog.isAccessibilityElement = true; dialog.accessibilityTraits = .button
        speaker.font = dialog.font; speaker.textColor = dialog.textColor; speaker.backgroundColor = dialog.backgroundColor
        speaker.textColor = dialog.backgroundColor
        speaker.backgroundColor = UIColor(red: 0.937, green: 0.855, blue: 0.647, alpha: 1)
        nameplate.font = dialog.font; nameplate.textColor = dialog.backgroundColor
        nameplate.backgroundColor = UIColor(red: 0.969, green: 0.961, blue: 0.929, alpha: 1)
        nameplate.layer.borderWidth = 2; nameplate.layer.borderColor = dialog.backgroundColor?.cgColor
        nameplate.text = demo ? "  우진 & 채원 · 축하의 정원  예시  " : "  축하의 정원  "; addSubview(nameplate)
        speaker.text = demo ? " 웨딩플랜트 " : " 정원지기 "
        if !peek && (demo || empty) { addSubview(dialog); addSubview(speaker) }
        bubble.titleLabel?.font = dialog.font; bubble.titleLabel?.numberOfLines = 0
        bubble.setTitleColor(UIColor(red: 0.09, green: 0.235, blue: 0.184, alpha: 1), for: .normal)
        bubble.backgroundColor = UIColor(red: 0.98, green: 0.96, blue: 0.88, alpha: 1)
        bubble.layer.borderColor = dialog.backgroundColor?.cgColor; bubble.layer.borderWidth = 2
        bubble.addTarget(self, action: #selector(closeSpeech), for: .touchUpInside); bubble.isHidden = true
        addSubview(bubble)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
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
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stop() } else if link == nil {
            let display = CADisplayLink(target: self, selector: #selector(tick(_:)))
            display.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            display.add(to: .main, forMode: .common); link = display
        }
    }
    func stop() { link?.invalidate(); link = nil; lastTick = nil }
    override func layoutSubviews() {
        super.layoutSubviews()
        dialog.frame = CGRect(x: 9, y: bounds.height - 80, width: bounds.width - 18, height: 70)
        nameplate.frame = CGRect(x: 12, y: 12, width: min(bounds.width - 24, nameplate.intrinsicContentSize.width + 12), height: 28)
        speaker.frame = CGRect(x: 24, y: bounds.height - 88, width: 98, height: 18)
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
        if !peek && (demo || empty) { advanceDialog() }
        updateFlight(); if !peek { updateBubble() }; setNeedsDisplay()
    }
    private func advanceDialog() {
        if typed < lines[line].count && engine.time - typedAt >= 0.056 { typed += 1; typedAt = engine.time }
        if typed == lines[line].count {
            if completedAt == nil { completedAt = engine.time }
            if engine.time - (completedAt ?? engine.time) >= 2.6 { nextLine() }
        }
        let full = "   " + lines[line] + "   ▾"
        let attributed = NSMutableAttributedString(string: full)
        let shown = String(full.prefix(typed + 3)).utf16.count
        if shown < full.utf16.count { attributed.addAttribute(.foregroundColor, value: UIColor.clear, range: NSRange(location: shown, length: full.utf16.count - shown)) }
        dialog.attributedText = attributed
        dialog.accessibilityLabel = "\(speaker.text ?? ""): \(lines[line]) (다음 이야기)"
    }
    @objc private func skipLine() { if typed < lines[line].count { typed = lines[line].count } else { nextLine() } }
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
        guard let a = engine.speech, let wish = a.wish, !a.flying else { bubble.isHidden = true; return }
        bubble.isHidden = false
        if lastSpeechSerial != engine.speechSerial {
            lastSpeechSerial = engine.speechSerial
            bubble.setTitle("\(wish.name)의 \(a.isCouple ? "마음" : "축하")  ×\n\(wish.message)", for: .normal)
        }
        let width = min(bounds.width - 24, 230.0)
        let height = bubble.sizeThatFits(CGSize(width: width - 20, height: 200)).height + 20
        bubble.frame = CGRect(x: max(12, min(bounds.width - width - 12, CGFloat(a.headX) * unit - width / 2)), y: max(12, sceneY + CGFloat(a.headY) * unit - height - 12), width: width, height: height)
        bubble.accessibilityLabel = "\(wish.name)의 축하 글: \(wish.message), 닫기"
    }
    @objc private func closeSpeech() { engine.closeSpeech(); bubble.isHidden = true }
    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        let p = gesture.location(in: self)
        if (demo || empty) && dialog.frame.contains(p) { return }
        if !bubble.isHidden && bubble.frame.contains(p) { closeSpeech(); return }
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
            if empty {
                c.setStrokeColor(UIColor.white.withAlphaComponent(0.3 + 0.3 * sin(engine.time * .pi / 1.4)).cgColor)
                c.setLineDash(phase: 0, lengths: [2,2]); c.setLineWidth(1)
                for p in SeasideEngine.positions.prefix(8) { c.stroke(CGRect(x: p[0] - 10, y: p[1] - 40, width: 20, height: 20)) }
            }
        }
        screen.interpolationQuality = .none
        frame.draw(in: CGRect(x: 0, y: sceneY, width: bounds.width, height: 440 * unit))
    }
}
