import SwiftUI

/// SVG `d` 문자열을 그대로 그리는 모양 — 안드로이드가 쓰는 lucide·Material 원본 경로를 손으로
/// 다시 옮기지 않으려고 둔다. SF Symbols 로 갈음하면 획 두께·크기가 안드로이드와 달라진다
/// (일정 상세의 채팅·별·자물쇠 아이콘이 그래서 어긋났다).
///
/// 좌표계는 24×24(lucide·Material 공통)이고 rect 에 맞춰 늘린다.
struct WPSVGPath: Shape {
    var d: [String]

    init(_ d: String...) { self.d = d }
    init(paths: [String]) { self.d = paths }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        for one in d { var parser = SVGPathParser(one); parser.append(to: &p) }
        return p.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY)))
    }
}

/// lucide 아이콘 — 안드로이드 `LucideIcons.lucide(…)` 와 같은 둥근 끝·둥근 이음, 획 2(24 기준).
struct WPLucideIcon: View {
    var paths: [String]
    var size: CGFloat
    var color: Color
    var strokeWidth: CGFloat = 2

    var body: some View {
        WPSVGPath(paths: paths)
            .stroke(color, style: StrokeStyle(lineWidth: strokeWidth * size / 24, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Material 채움 아이콘(안드로이드 `Icons.Filled.*` · `Icons.Outlined.*`) — 경로를 칠한다.
struct WPMaterialPathIcon: View {
    var paths: [String]
    var size: CGFloat
    var color: Color

    var body: some View {
        WPSVGPath(paths: paths)
            .fill(color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// 안드로이드 `LucideIcons` · Material 아이콘 원본 경로(같은 문자열을 그대로 옮겼다).
enum WPIconPaths {
    static let messageCircle = ["M2.992 16.342a2 2 0 0 1 .094 1.167l-1.065 3.29a1 1 0 0 0 1.236 1.168l3.413-.998a2 2 0 0 1 1.099.092 10 10 0 1 0-4.777-4.719"]
    static let star = ["M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z"]
    static let lock = [
        "M5 11h14a2 2 0 0 1 2 2v7a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-7a2 2 0 0 1 2 -2z",
        "M7 11V7a5 5 0 0 1 10 0v4",
    ]
    static let chevronRight = ["m9 18 6-6-6-6"]
    /// Material `Icons.Outlined.LocationOn`
    static let locationOnOutlined = [
        "M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zM7 9c0-2.76 2.24-5 5-5s5 2.24 5 5c0 2.88-2.88 7.19-5 9.88C9.92 16.21 7 11.85 7 9z",
        "M12 11.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 1 0 0 5z",
    ]
    /// Material `Icons.Outlined.Description`
    static let descriptionOutlined = [
        "M8 16h8v2H8zm0-4h8v2H8zm6-10H6c-1.1 0-2 .9-2 2v16c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm4 18H6V4h7v5h5v11z",
    ]
    /// Material `Icons.Filled.Check`
    static let check = ["M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"]
    /// Material `Icons.AutoMirrored.Filled.ArrowBack`
    static let arrowBack = ["M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z"]
}

/// SVG 경로 문법(M L H V C S Q T A Z, 상대 좌표·생략된 명령 반복 포함) 해석기.
private struct SVGPathParser {
    private let chars: [Character]
    private var i = 0

    init(_ d: String) { chars = Array(d) }

    mutating func append(to path: inout Path) {
        var cmd: Character = "M"
        var current = CGPoint.zero
        var start = CGPoint.zero
        var lastControl: CGPoint?
        var lastCmd: Character = "M"

        while true {
            skipSeparators()
            guard i < chars.count else { break }
            if chars[i].isLetter {
                cmd = chars[i]; i += 1
            } else if lastCmd == "M" {
                cmd = "L"   // M 뒤의 좌표는 L 로 이어진다
            } else if lastCmd == "m" {
                cmd = "l"
            }
            let rel = cmd.isLowercase
            let base = rel ? current : .zero
            switch cmd {
            case "M", "m":
                guard let x = number(), let y = number() else { return }
                current = CGPoint(x: base.x + x, y: base.y + y)
                start = current
                path.move(to: current)
                lastControl = nil
            case "L", "l":
                guard let x = number(), let y = number() else { return }
                current = CGPoint(x: base.x + x, y: base.y + y)
                path.addLine(to: current); lastControl = nil
            case "H", "h":
                guard let x = number() else { return }
                current = CGPoint(x: (rel ? current.x : 0) + x, y: current.y)
                path.addLine(to: current); lastControl = nil
            case "V", "v":
                guard let y = number() else { return }
                current = CGPoint(x: current.x, y: (rel ? current.y : 0) + y)
                path.addLine(to: current); lastControl = nil
            case "C", "c":
                guard let x1 = number(), let y1 = number(), let x2 = number(), let y2 = number(),
                      let x = number(), let y = number() else { return }
                let c1 = CGPoint(x: base.x + x1, y: base.y + y1)
                let c2 = CGPoint(x: base.x + x2, y: base.y + y2)
                current = CGPoint(x: base.x + x, y: base.y + y)
                path.addCurve(to: current, control1: c1, control2: c2)
                lastControl = c2
            case "S", "s":
                guard let x2 = number(), let y2 = number(), let x = number(), let y = number() else { return }
                let c1 = lastControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                let c2 = CGPoint(x: base.x + x2, y: base.y + y2)
                current = CGPoint(x: base.x + x, y: base.y + y)
                path.addCurve(to: current, control1: c1, control2: c2)
                lastControl = c2
            case "Q", "q":
                guard let x1 = number(), let y1 = number(), let x = number(), let y = number() else { return }
                let c = CGPoint(x: base.x + x1, y: base.y + y1)
                current = CGPoint(x: base.x + x, y: base.y + y)
                path.addQuadCurve(to: current, control: c)
                lastControl = c
            case "T", "t":
                guard let x = number(), let y = number() else { return }
                let c = lastControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                current = CGPoint(x: base.x + x, y: base.y + y)
                path.addQuadCurve(to: current, control: c)
                lastControl = c
            case "A", "a":
                guard let rx = number(), let ry = number(), let rot = number(),
                      let large = flag(), let sweep = flag(),
                      let x = number(), let y = number() else { return }
                let end = CGPoint(x: base.x + x, y: base.y + y)
                Self.arc(&path, from: current, to: end, rx: rx, ry: ry, rotation: rot, large: large, sweep: sweep)
                current = end; lastControl = nil
            case "Z", "z":
                path.closeSubpath()
                current = start; lastControl = nil
            default:
                return
            }
            lastCmd = cmd
        }
    }

    private mutating func skipSeparators() {
        while i < chars.count, chars[i] == " " || chars[i] == "," || chars[i] == "\n" || chars[i] == "\t" { i += 1 }
    }

    private mutating func flag() -> Bool? {
        skipSeparators()
        guard i < chars.count, chars[i] == "0" || chars[i] == "1" else { return nil }
        defer { i += 1 }
        return chars[i] == "1"
    }

    private mutating func number() -> CGFloat? {
        skipSeparators()
        let begin = i
        if i < chars.count, chars[i] == "-" || chars[i] == "+" { i += 1 }
        var dot = false
        while i < chars.count {
            let c = chars[i]
            if c.isNumber { i += 1 }
            else if c == ".", !dot { dot = true; i += 1 }
            else if c == "e" || c == "E" {
                i += 1
                if i < chars.count, chars[i] == "-" || chars[i] == "+" { i += 1 }
            } else { break }
        }
        guard i > begin, let v = Double(String(chars[begin..<i])) else { return nil }
        return CGFloat(v)
    }

    /// SVG 1.1 부록 F.6.5 — 끝점 표기 호를 중심 표기로 바꿔 90° 이하 조각의 3차 곡선으로 그린다.
    private static func arc(_ path: inout Path, from p0: CGPoint, to p1: CGPoint,
                            rx rxIn: CGFloat, ry ryIn: CGFloat, rotation: CGFloat, large: Bool, sweep: Bool) {
        if p0 == p1 { return }
        var rx = abs(rxIn), ry = abs(ryIn)
        if rx == 0 || ry == 0 { path.addLine(to: p1); return }
        let phi = rotation * .pi / 180
        let cosP = cos(phi), sinP = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1p = cosP * dx + sinP * dy
        let y1p = -sinP * dx + cosP * dy
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 { let s = sqrt(lambda); rx *= s; ry *= s }
        let num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        var coef = den == 0 ? 0 : sqrt(max(0, num / den))
        if large == sweep { coef = -coef }
        let cxp = coef * rx * y1p / ry
        let cyp = -coef * ry * x1p / rx
        let cx = cosP * cxp - sinP * cyp + (p0.x + p1.x) / 2
        let cy = sinP * cxp + cosP * cyp + (p0.y + p1.y) / 2
        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let a = atan2(ux * vy - uy * vx, ux * vx + uy * vy)
            return a
        }
        let theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var delta = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
        if !sweep && delta > 0 { delta -= 2 * .pi }
        if sweep && delta < 0 { delta += 2 * .pi }
        let segments = max(1, Int(ceil(abs(delta) / (.pi / 2))))
        let step = delta / CGFloat(segments)
        let k = 4.0 / 3.0 * tan(step / 4)
        func point(_ t: CGFloat) -> CGPoint {
            CGPoint(x: cx + rx * cos(t) * cosP - ry * sin(t) * sinP,
                    y: cy + rx * cos(t) * sinP + ry * sin(t) * cosP)
        }
        func derivative(_ t: CGFloat) -> CGPoint {
            CGPoint(x: -rx * sin(t) * cosP - ry * cos(t) * sinP,
                    y: -rx * sin(t) * sinP + ry * cos(t) * cosP)
        }
        var t = theta1
        for n in 0..<segments {
            let t2 = t + step
            let a = point(t), b = n == segments - 1 ? p1 : point(t2)
            let da = derivative(t), db = derivative(t2)
            path.addCurve(to: b,
                          control1: CGPoint(x: a.x + k * da.x, y: a.y + k * da.y),
                          control2: CGPoint(x: b.x - k * db.x, y: b.y - k * db.y))
            t = t2
        }
    }
}
