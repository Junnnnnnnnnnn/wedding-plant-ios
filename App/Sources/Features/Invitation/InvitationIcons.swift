import SwiftUI

/// 안드로이드 `ui/invitation/InvitationIcons.kt` 의 lucide 경로를 그대로 옮긴 것.
/// SF Symbols 로 갈음하면 모양(공유 = 점 셋, 지도 핀 = 물방울)과 획 두께가 안드로이드와 달라져서
/// 청첩장 화면은 이 경로만 씁니다. 굵기는 안드로이드처럼 아이콘마다 넘깁니다(꽃 0.8 · 지도 핀 1 · 꺾쇠 1.4).
enum InvIcon {
    private static func circle(_ cx: Double, _ cy: Double, _ r: Double) -> String {
        "M\(cx - r) \(cy)a\(r) \(r) 0 1 0 \(2 * r) 0a\(r) \(r) 0 1 0 \(-2 * r) 0"
    }
    static let arrowDown = ["M12 5v14", "m19 12-7 7-7-7"]
    static let arrowRight = ["M5 12h14", "m12 5 7 7-7 7"]
    static let arrowUp = ["m5 12 7-7 7 7", "M12 19V5"]
    static let arrowLeft = ["m12 19-7-7 7-7", "M19 12H5"]
    static let chevronLeft = ["m15 18-6-6 6-6"]
    static let chevronRight = ["m9 18 6-6-6-6"]
    static let chevronDown = ["m6 9 6 6 6-6"]
    static let copy = [
        "M10 8h10a2 2 0 0 1 2 2v10a2 2 0 0 1 -2 2h-10a2 2 0 0 1 -2 -2v-10a2 2 0 0 1 2 -2z",
        "M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2",
    ]
    static let leaf = [
        "M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.48 19 2c1 2 2 4.18 2 8 0 5.5-4.78 10-10 10Z",
        "M2 21c0-3 1.85-5.36 5.08-6C9.5 14.52 12 13 13 12",
    ]
    static let mapPin = [
        "M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0",
        circle(12, 10, 3),
    ]
    static let maximize = ["M15 3h6v6", "m21 3-7 7", "m3 21 7-7", "M9 21H3v-6"]
    static let rotateCcw = ["M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8", "M3 3v5h5"]
    static let imagePlus = [
        "M16 5h6", "M19 2v6",
        "M21 11.5V19a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h7.5",
        "m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21",
        circle(9, 9, 2),
    ]
    static let gripVertical = [circle(9, 12, 1), circle(9, 5, 1), circle(9, 19, 1), circle(15, 12, 1), circle(15, 5, 1), circle(15, 19, 1)]
    static let pin = [
        "M12 17v5",
        "M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z",
    ]
    static let eye = [
        "M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0",
        circle(12, 12, 3),
    ]
    static let pencil = [
        "M13 21h8", "m15 5 4 4",
        "M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z",
    ]
    static let camera = [
        "M13.997 4a2 2 0 0 1 1.76 1.05l.486.9A2 2 0 0 0 18.003 7H20a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2h1.997a2 2 0 0 0 1.759-1.048l.489-.904A2 2 0 0 1 10.004 4z",
        circle(12, 13, 3),
    ]
    static let heart = ["M2 9.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5"]
    static let share = [circle(18, 5, 3), circle(6, 12, 3), circle(18, 19, 3), "M8.59 13.51 15.42 17.49", "M15.41 6.51 8.59 10.49"]
    static let send = [
        "M14.536 21.686a.5.5 0 0 0 .937-.024l6.5-19a.496.496 0 0 0-.635-.635l-19 6.5a.5.5 0 0 0-.024.937l7.93 3.18a2 2 0 0 1 1.112 1.11z",
        "m21.854 2.147-10.94 10.939",
    ]
    static let users = ["M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2", circle(9, 7, 4), "M22 21v-2a4 4 0 0 0-3-3.87", "M16 3.128a4 4 0 0 1 0 7.744"]
    static let check = ["M20 6 9 17l-5-5"]
    static let lock = [
        "M5 11h14a2 2 0 0 1 2 2v7a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-7a2 2 0 0 1 2 -2z",
        "M7 11V7a5 5 0 0 1 10 0v4",
    ]
    static let x = ["M18 6 6 18", "m6 6 12 12"]
    static let search = ["m21 21-4.34-4.34", circle(11, 11, 8)]
    static let star = ["M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z"]
    static let layers = [
        "M12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83z",
        "M2 12a1 1 0 0 0 .58.91l8.6 3.91a2 2 0 0 0 1.65 0l8.58-3.9A1 1 0 0 0 22 12",
        "M2 17a1 1 0 0 0 .58.91l8.6 3.91a2 2 0 0 0 1.65 0l8.58-3.9A1 1 0 0 0 22 17",
    ]
    static let palette = [
        "M12 22a1 1 0 0 1 0-20 10 9 0 0 1 10 9 5 5 0 0 1-5 5h-2.25a1.75 1.75 0 0 0-1.4 2.8l.3.4a1.75 1.75 0 0 1-1.4 2.8z",
        circle(13.5, 6.5, 0.5), circle(17.5, 10.5, 0.5), circle(6.5, 12.5, 0.5), circle(8.5, 7.5, 0.5),
    ]
}

/// lucide 선 아이콘 한 개 — 안드로이드 `Icon(InvitationIcons.xxx(width), tint, Modifier.size(size))` 와 같은 자리.
struct InvIconView: View {
    let paths: [String]
    var size: CGFloat
    var color: Color
    var weight: CGFloat = 2

    init(_ paths: [String], size: CGFloat, color: Color, weight: CGFloat = 2) {
        self.paths = paths; self.size = size; self.color = color; self.weight = weight
    }

    var body: some View {
        WPLucideIcon(paths: paths, size: size, color: color, strokeWidth: weight)
    }
}

/// 채운 하트(안드로이드 `heartFilled` — 칠하고 같은 굵기로 테두리도 그립니다).
struct InvHeartFilled: View {
    var size: CGFloat
    var color: Color
    var body: some View {
        ZStack {
            WPSVGPath(paths: InvIcon.heart).fill(color)
            WPSVGPath(paths: InvIcon.heart).stroke(color, style: StrokeStyle(lineWidth: 2 * size / 24, lineCap: .round, lineJoin: .round))
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

/// 청첩장 첫 화면 배지의 새싹 — 안드로이드 `InvitationIcons.sprout`(16 격자, 선 1.3, SVG 기본 끝 모양).
struct InvSprout: View {
    var size: CGFloat = 15
    var color: Color
    var body: some View {
        WPSVGPath(paths: ["M8 14V7M8 9C5 9 3.5 7 3.5 4.5 6 4.5 8 6 8 9zm0-1c0-3 2-4.5 4.5-4.5C12.5 6 11 8 8 8z"])
            // WPSVGPath 는 24 격자라 16 격자 경로를 1.5배로 늘려 맞춥니다
            .scale(1.5, anchor: .topLeading)
            .stroke(color, lineWidth: 1.3 * size / 16)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
