import SwiftUI

/// 구글 "G" 마크 — Android `drawable/ic_google_g.xml` 과 같은 48×48 벡터.
/// **색을 바꾸거나 한 조각만 쓰지 마세요** — 구글 브랜드 가이드 위반입니다.
struct GoogleGMark: View {
    var body: some View {
        ZStack {
        piece(0xEA4335) { p in
            p.move(to: P(24, 9.5))
            p.addCurve(to: P(33, 13.1), control1: P(27.5, 9.5), control2: P(30.6, 10.7))
            p.addLine(to: P(39.7, 6.4))
            p.addCurve(to: P(24, 0), control1: P(35.6, 2.6), control2: P(30.2, 0))
            p.addCurve(to: P(2.6, 13.2), control1: P(14.6, 0), control2: P(6.5, 5.4))
            p.addLine(to: P(10.4, 19.3))
            p.addCurve(to: P(24, 9.5), control1: P(12.3, 13.3), control2: P(17.6, 9.5))
            p.closeSubpath()
        }
        piece(0x4285F4) { p in
            p.move(to: P(46.1, 24.6))
            p.addCurve(to: P(45.7, 20), control1: P(46.1, 23), control2: P(46, 21.5))
            p.addLine(to: P(24, 20))
            p.addLine(to: P(24, 29.1))
            p.addLine(to: P(36.4, 29.1))
            p.addCurve(to: P(31.8, 36.1), control1: P(35.9, 32), control2: P(34.2, 34.4))
            p.addLine(to: P(39, 41.7))
            p.addCurve(to: P(45.6, 25.3), control1: P(43.2, 37.8), control2: P(45.6, 32.1))
            p.closeSubpath()
        }
        piece(0xFBBC05) { p in
            p.move(to: P(10.4, 28.7))
            p.addCurve(to: P(9.6, 24), control1: P(9.9, 27.2), control2: P(9.6, 25.7))
            p.addCurve(to: P(10.4, 19.3), control1: P(9.6, 22.3), control2: P(9.9, 20.8))
            p.addLine(to: P(2.6, 13.2))
            p.addCurve(to: P(0, 24), control1: P(1, 16.3), control2: P(0, 20))
            p.addCurve(to: P(2.6, 34.8), control1: P(0, 28), control2: P(1, 31.7))
            p.addLine(to: P(10.4, 28.7))
            p.closeSubpath()
        }
        piece(0x34A853) { p in
            p.move(to: P(24, 48))
            p.addCurve(to: P(39.9, 42.2), control1: P(30.5, 48), control2: P(35.9, 45.9))
            p.addLine(to: P(32.7, 36.6))
            p.addCurve(to: P(24, 38.8), control1: P(30.7, 38), control2: P(28.1, 38.8))
            p.addCurve(to: P(10.4, 29.7), control1: P(17.6, 38.8), control2: P(12.3, 35))
            p.addLine(to: P(2.6, 35.8))
            p.addCurve(to: P(24, 48), control1: P(6.5, 42.6), control2: P(14.6, 48))
            p.closeSubpath()
        }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
    private func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
    private func piece(_ hex: UInt32, _ build: (inout Path) -> Void) -> some View {
        var p = Path(); build(&p)
        return GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / 48
            p.applying(CGAffineTransform(scaleX: s, y: s)).fill(Color(hex: hex))
        }
    }
}
