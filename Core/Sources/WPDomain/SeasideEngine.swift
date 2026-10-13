import Foundation
import WPModels

/// Native port of Android SeasideEngine. Coordinates are a 320 × 440 pixel world.
/// The caller owns the clock; invisible/background scenes must not advance it.
public final class SeasideEngine {
    public enum Phase { case out, enter, stand, leave }
    public enum Mode { case idle, walk, laugh, jump, wave, clap }
    public struct Point { public var x: Double; public var y: Double }
    public struct Dust { public var x, y, vx, vy, age, life: Double }
    public final class Actor {
        public let id: Int
        public let homeX, homeY, scale: Double
        let bounds: [Double]
        public var wish: InvitationWish?
        public var x, y: Double
        public var phase: Phase = .stand
        public var mode: Mode = .idle
        public var pose = 0
        public var top = 0.0, width = 0.0, height = 0.0, lift = 0.0
        public var mirror = false, flying = false
        public var headX = 0.0, headY = 0.0
        public var arrival: Double?
        var landed = false, pendingSet = false
        var pending: InvitationWish?
        var path: [Point] = []
        var stride = 0.0, enterAt = 0.0, modeStart = 0.0, nextMode = 0.0, pinned = 0.0
        var face = 0, routes = 0
        public var isCouple: Bool { id >= 8 }
        public var visible: Bool { wish != nil && phase != .out }
        init(id: Int, position p: [Double]) {
            self.id = id; homeX = p[0]; homeY = p[1]; scale = p[2]; bounds = Array(p[3...])
            x = p[0]; y = p[1]; nextMode = 2.5 + Double(id) * 0.9
        }
    }
    public private(set) var actors: [Actor]
    public private(set) var time = 0.0
    public private(set) var particles: [Dust] = []
    public private(set) var speech: Actor?
    public private(set) var selected: Actor?
    public private(set) var manualSpeech = false
    public private(set) var speechSerial = 0
    public var skyAbove = 12.0
    public let quietCouple: Bool
    private var wishes: [InvitationWish] = [], queue: [InvitationWish] = []
    private var speechUntil = 0.0, nextSpeech = 2.2, nextRotation = 25.0
    private var randomState: UInt64
    private var guests: [Actor] { Array(actors.prefix(8)) }
    public static let positions: [[Double]] = [
        [58,324,1.05,34,130,320,378], [252,322,1.05,193,283,320,378],
        [106,383,1.12,73,167,360,411], [224,386,1.12,162,248,357,411],
        [44,412,1.08,27,86,370,413], [282,412,1.08,235,290,373,413],
        [147,345,0.96,122,185,325,366], [164,411,1.05,119,199,384,414],
        [150,251,0.86,146,153,251,251], [174,251,0.86,170,177,251,251]
    ]
    /// CSS steps(4, end), applied independently to each half of the 2.8-second cycle.
    public static func emptySeatOpacity(time: Double, index: Int) -> Double {
        let progress = (time + Double(index) * 0.35).truncatingRemainder(dividingBy: 2.8) / 2.8
        let p = progress < 0 ? progress + 1 : progress
        let first = p < 0.5, u = p < 0.5 ? p * 2 : (p - 0.5) * 2
        let step = floor(u * 4) / 4
        return first ? 1 - 0.5 * step : 0.5 + 0.5 * step
    }
    public init(groom: String = "정우진", bride: String = "이채원", wishes: [InvitationWish] = [], quietCouple: Bool = false, seed: UInt64 = 42) {
        self.quietCouple = quietCouple; randomState = seed
        actors = Self.positions.enumerated().map { Actor(id: $0.offset, position: $0.element) }
        for a in actors {
            if a.isCouple {
                a.wish = InvitationWish(id: a.id == 8 ? "groom" : "bride", name: a.id == 8 ? groom : bride,
                    message: a.id == 8 ? "우리의 시작에 함께해 주셔서 고맙습니다." : "이 따뜻한 마음들을 오래오래 간직할게요. 감사합니다 ♡", avatar: a.id - 8)
            } else { a.x = 160; a.y = 478; a.phase = .out }
        }
        setWishes(wishes)
        layout()
    }
    private func random() -> Double {
        randomState = randomState &* 6364136223846793005 &+ 1442695040888963407
        return Double(randomState >> 11) / Double(UInt64(1) << 53)
    }
    private func shuffled<T>(_ values: [T]) -> [T] {
        var result = values
        if result.count > 1 { for i in stride(from: result.count - 1, through: 1, by: -1) { result.swapAt(i, Int(random() * Double(i + 1))) } }
        return result
    }
    public func settle() {
        for a in guests where a.wish != nil { a.phase = .stand; a.x = a.homeX; a.y = a.homeY; a.path = []; a.face = 0; a.mode = .idle; a.modeStart = time }
        layout()
    }
    private func transitioning(_ a: Actor) -> Bool { a.phase == .enter || a.phase == .leave || (a.phase == .out && a.wish != nil) }
    private func protected(_ a: Actor) -> Bool { a.arrival != nil || transitioning(a) || a === speech || time < a.pinned }
    public func setWishes(_ values: [InvitationWish]) {
        wishes = values; queue = []
        let ids = Set(values.map(\.id))
        var assigned = Set(guests.flatMap { [$0.wish?.id, $0.pending?.id].compactMap { $0 } }.filter { ids.contains($0) })
        var arriving = 0
        for a in guests {
            if let p = a.pending, !ids.contains(p.id) { a.pending = nil; a.pendingSet = true }
            if let value = values.first(where: { $0.id == a.wish?.id }) { a.wish = value; continue }
            if protected(a) && !transitioning(a) && a.wish?.id.hasPrefix("example-") != true { continue }
            if a.phase == .leave && a.pendingSet { continue }
            let value = values.first { !assigned.contains($0.id) }
            if let value { assigned.insert(value.id) }
            bind(a, value, delay: value == nil ? 0 : 0.6 + Double(arriving) * 1.5)
            if value != nil { arriving += 1 }
        }
    }
    public var freeSeats: Int { guests.filter { $0.wish == nil && $0.pending == nil }.count }
    public func enter(_ wish: InvitationWish, drop: Bool = false, quiet: Bool = false) {
        let target = guests.first { $0.wish?.id == wish.id } ?? guests.first { $0.pending?.id == wish.id }
            ?? guests.first { $0.wish == nil } ?? guests.first { !protected($0) }
            ?? guests.first { $0 !== speech && $0.arrival == nil } ?? guests.first { $0 !== speech }
        guard let a = target else { return }
        for other in guests where other !== a && other.pending?.id == wish.id { other.pending = nil; other.pendingSet = true }
        a.pinned = time + 30
        if drop {
            if a.wish?.id != wish.id { assign(a, wish) }
            a.phase = .stand; a.pending = nil; a.pendingSet = false; a.enterAt = time
            a.x = a.homeX; a.y = a.homeY; a.path = []; a.face = 0; a.arrival = time; a.landed = false
            setMode(a, .idle); showSpeech(a, manual: !quiet); layout(); return
        }
        if a.wish?.id == wish.id {
            if a.phase == .stand { setMode(a, .wave); showSpeech(a, manual: !quiet) }
            else if a.phase == .out { a.enterAt = time }
            else if a.phase == .leave { turnBack(a) }
            return
        }
        if a.pending?.id != wish.id { bind(a, wish) }
    }
    public func update(_ elapsed: Double) {
        let dt = max(0, min(0.05, elapsed))
        time += dt
        for a in actors where a.wish != nil {
            if let start = a.arrival {
                let age = time - start - 0.12
                if age >= 1.45 && !a.landed {
                    a.landed = true
                    for i in 0..<6 {
                        particles.append(Dust(x: a.x + (Double(i) - 2.5) * 4, y: a.y - 1,
                            vx: (Double(i) - 2.5) * 9, vy: -9 - random() * 8, age: 0, life: 0.28 + random() * 0.16))
                    }
                }
                if age >= 1.77 { a.arrival = nil; a.phase = .stand; setMode(a, .wave) } else { continue }
            }
            if a.phase == .out {
                if time >= a.enterAt { a.phase = .enter; setMode(a, .walk) }; continue
            }
            if a.phase == .enter || a.phase == .leave || a.mode == .walk { move(a, dt); continue }
            if time >= a.nextMode { nextStandMode(a) }
        }
        if time >= nextRotation { rotate() }
        if speech != nil && !manualSpeech && time >= speechUntil { closeSpeech() }
        if speech == nil && time >= nextSpeech {
            let choices = actors.filter { $0.wish != nil && !($0.isCouple && quietCouple) && $0.arrival == nil && $0.phase == .stand && $0.mode != .walk }
            if !choices.isEmpty {
                let a = choices[Int(random() * Double(choices.count))]
                showSpeech(a, manual: false); setMode(a, a.isCouple ? .wave : .laugh)
            } else { nextSpeech = time + 1 }
        }
        particles.removeAll { $0.age >= $0.life }
        for i in particles.indices { particles[i].age += dt; particles[i].x += particles[i].vx * dt; particles[i].y += particles[i].vy * dt }
        layout()
    }
    public func showSpeech(_ actor: Actor, manual: Bool) {
        guard let wish = actor.wish else { return }
        speech = actor; manualSpeech = manual; selected = actor; speechSerial += 1
        speechUntil = time + min(9, max(5.5, Double(wish.message.utf16.count) * 0.09 + 3))
    }
    public func closeSpeech() { speech = nil; manualSpeech = false; nextSpeech = time + 2.5 }
    public func hit(x: Double, y: Double) -> Actor? {
        actors.filter {
            $0.visible && !($0.isCouple && quietCouple) && x >= $0.x - $0.width / 2 && x <= $0.x + $0.width / 2 && y >= $0.y - $0.lift - $0.height && y <= $0.y - $0.lift
        }.max { ($0.arrival != nil ? 500 + Double($0.id) : $0.y) < ($1.arrival != nil ? 500 + Double($1.id) : $1.y) }
    }
    public func layout() {
        for a in actors where a.visible {
            var lift = 0.0, width = 1.0, height = 1.0, airborne = false
            if let start = a.arrival {
                let age = time - start - 0.12
                if age < 1.45 { let t = max(0, age / 1.45); lift = (a.y + skyAbove) * (1 - t * t); airborne = true }
                else {
                    let landed = age - 1.45
                    if landed < 0.09 { let compression = sin(landed / 0.09 * .pi); width = 1 + 0.08 * compression; height = 1 - 0.09 * compression }
                    else if landed < 0.27 { lift = 6 * sin((landed - 0.09) / 0.18 * .pi) }
                }
            }
            let age = time - a.modeStart, jumpPhase = age.truncatingRemainder(dividingBy: 1.35)
            let jumping = a.mode == .jump && jumpPhase > 0.16 && jumpPhase < 1
            let jump = jumping ? (sin((jumpPhase - 0.16) / 0.84 * .pi) * 17).rounded() : 0
            switch a.mode {
            case .walk: a.pose = [1,2,3,2][Int(floor(a.stride / 3.2)) % 4]
            case .laugh: a.pose = 4
            case .wave: a.pose = Int(floor(age * 3)) % 3 == 0 ? 0 : 6
            case .clap: a.pose = Int(floor(age * 5)) % 2 == 0 ? 4 : 7
            default: a.pose = jumping ? 5 : 0
            }
            if a.arrival != nil { a.pose = airborne ? 5 : 0 }
            let bob = a.arrival == nil && a.mode == .laugh ? Double(Int(floor(age * 4)) % 2) : 0
            a.width = 48 * a.scale * width; a.height = 72 * a.scale * height
            a.lift = jump * a.scale + lift; a.top = a.y - a.height - a.lift + bob * a.scale * height
            a.mirror = a.mode == .walk && a.face < 0; a.flying = a.arrival != nil && airborne
            a.headX = a.x
            let head: Int
            if a.id == 8 { head = Self.groomHeads[a.pose] }
            else if a.id == 9 { head = Self.brideHeads[a.pose] }
            else if let avatar = a.wish?.avatar, (0..<20).contains(avatar) { head = Self.guestHeads[avatar][a.pose] }
            else { head = 7 }
            a.headY = a.top + Double(head) * a.scale * height
        }
    }
    private func lane(_ a: Actor) -> Double { 160 + Double(a.id % 3 - 1) * 5 }
    private func assign(_ a: Actor, _ wish: InvitationWish?, delay: Double = 0) {
        if a === speech { closeSpeech() }
        a.arrival = nil; a.wish = wish; a.pending = nil; a.pendingSet = false; a.phase = .out
        if wish != nil {
            a.x = lane(a); a.y = 478; a.face = 0; a.enterAt = time + delay
            a.path = [Point(x: lane(a), y: a.homeY + 3), Point(x: a.homeX, y: a.homeY)]
        }
    }
    private func turnBack(_ a: Actor) {
        a.pending = nil; a.pendingSet = false; a.phase = .enter
        a.path = [Point(x: lane(a), y: a.homeY + 3), Point(x: a.homeX, y: a.homeY)]; setMode(a, .walk)
    }
    private func bind(_ a: Actor, _ wish: InvitationWish?, delay: Double = 0) {
        if let wish, a.wish?.id == wish.id { a.wish = wish; if a.phase == .leave { turnBack(a) }; return }
        if a.phase == .leave { a.pending = wish; a.pendingSet = true; return }
        if a.wish != nil && (a.phase == .enter || a.phase == .stand) {
            a.pending = wish; a.pendingSet = true
            if a === speech { closeSpeech() }; a.phase = .leave
            a.path = [Point(x: lane(a), y: a.y + 3), Point(x: lane(a), y: 486)]; setMode(a, .walk); return
        }
        assign(a, wish, delay: delay)
    }
    public func rotate() {
        for a in guests where a.wish != nil && !wishes.contains(where: { $0.id == a.wish?.id }) && !protected(a) { bind(a, nil) }
        var excluded = Set(guests.flatMap { [$0.wish?.id, $0.pending?.id].compactMap { $0 } })
        for a in shuffled(guests.filter { !protected($0) }).prefix(2) {
            if queue.isEmpty { queue = shuffled(wishes) }
            while !queue.isEmpty {
                let wish = queue.removeFirst()
                if !excluded.contains(wish.id) { excluded.insert(wish.id); bind(a, wish); break }
            }
        }
        nextRotation = time + 25
    }
    private func setMode(_ a: Actor, _ mode: Mode) {
        a.mode = mode; a.modeStart = time
        switch mode { case .idle: a.nextMode = time + 3.2 + random() * 4.3
        case .walk: a.nextMode = time + 600
        case .jump: a.nextMode = time + 1.35
        default: a.nextMode = time + 1.3 + random() * 0.6 }
    }
    private func nextStandMode(_ a: Actor) {
        if a.mode != .idle { setMode(a, .idle); return }
        a.routes += 1
        if !a.isCouple && a.routes % 4 == 0 {
            for _ in 0..<8 {
                let x = min(a.bounds[1], max(a.bounds[0], a.x + (random() * 2 - 1) * 22))
                let y = min(a.bounds[3], max(a.bounds[2], a.y + (random() * 2 - 1) * 6))
                if hypot(x - a.x, y - a.y) > 8 && actors.allSatisfy({ $0 === a || $0.wish == nil || $0.phase == .out || hypot(x - $0.x, y - $0.y) > 20 }) {
                    a.path = [Point(x: x, y: y)]; setMode(a, .walk); return
                }
            }
            setMode(a, .idle); return
        }
        let modes: [Mode] = a.isCouple ? [.wave, .clap, .laugh] : [.wave, .clap, .laugh, .wave, .jump]
        setMode(a, modes[(a.routes + a.id) % modes.count])
    }
    private func move(_ a: Actor, _ dt: Double) {
        var budget = 34 * a.scale * (a.phase == .stand ? 0.55 : 1) * dt
        while budget > 0, let target = a.path.first {
            let dx = target.x - a.x, dy = target.y - a.y, distance = hypot(dx, dy)
            if distance < 0.01 { a.path.removeFirst(); continue }
            let step = min(distance, budget)
            a.x += dx / distance * step; a.y += dy / distance * step; a.stride += step; budget -= step
            a.face = abs(dx) > abs(dy) ? (dx < 0 ? -1 : 1) : 0
            if step >= distance { a.path.removeFirst() }
        }
        guard a.path.isEmpty else { return }
        let from = a.phase; a.face = 0
        if from == .leave {
            var next = a.pending
            if let n = next, !wishes.contains(where: { $0.id == n.id }) || guests.contains(where: { $0 !== a && $0.wish?.id == n.id }) { next = nil }
            assign(a, next, delay: next == nil ? 0 : 0.35)
        } else { a.phase = .stand; setMode(a, from == .enter ? .wave : .idle) }
    }
    static let groomHeads = [8,9,9,9,9,11,9,8]
    static let brideHeads = [17,17,17,17,17,18,17,17]
    static let guestHeads = [
        [6,4,6,5,5,10,5,5],[6,5,4,5,6,8,6,6],[4,4,4,4,5,10,4,5],[5,5,4,5,6,7,5,5],
        [4,4,5,5,4,6,4,4],[6,4,5,4,6,6,6,6],[5,4,4,4,4,6,5,6],[4,4,4,5,6,8,4,6],
        [5,4,4,4,8,8,6,7],[5,5,5,5,6,7,5,6],[6,6,6,6,7,8,6,6],[9,9,9,9,9,11,9,9],
        [12,11,12,11,13,13,12,12],[8,8,8,8,8,9,8,8],[9,9,9,9,9,12,9,9],[9,9,8,9,9,11,9,9],
        [8,8,8,8,8,10,8,8],[8,8,8,8,8,9,9,9],[10,10,10,10,10,12,10,10],[15,15,15,15,15,14,15,15]
    ]
}
