import SwiftUI

struct CelebrationConfetti: View {
    @State private var start = Date()
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { clock in
            Canvas { context, size in draw(context, size: size, elapsed: clock.date.timeIntervalSince(start)) }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
    private func draw(_ context: GraphicsContext, size: CGSize, elapsed: Double) {
        for item in ConfettiPiece.all {
            guard elapsed >= item.delay else { continue }
            let p = (elapsed-item.delay).truncatingRemainder(dividingBy: item.duration)/item.duration
            let alpha = p < 0.02 ? p/0.02 : p <= 0.5 ? 1 : 1-(p-0.5)/0.5
            let half = Double(size.height)/2
            let y = p <= 0.5 ? -100+(half+75)*p/0.5 : half-25+(half+75)*(p-0.5)/0.5
            let x = Double(size.width)*item.left/100+2*item.drift*p
            var piece = context
            piece.translateBy(x: x+item.side/2,y: y+item.side/2); piece.rotate(by: .degrees(720*p))
            let rect = CGRect(x: -item.side/2,y: -item.side/2,width: item.side,height: item.side)
            piece.fill(Path(roundedRect: rect, cornerRadius: item.corner), with: .color(Color(hex: item.color).opacity(alpha)))
        }
    }
}
private struct ConfettiPiece {
    let color: UInt32
    let left, duration, delay, side, corner, drift: Double
    static let all: [ConfettiPiece] = {
        let colors: [UInt32] = [0xFF6B6B,0x4ECDC4,0x45B7D1,0xFFA07A,0x98D8C8,0xF7DC6F,0xBB8FCE,0x85C1E2,0xF8B739,0xFF6B9D]
        var result: [ConfettiPiece] = []
        for (i, color) in colors.enumerated() {
            let f = Double(i), sign = i % 2 == 0 ? 1.0 : -1.0
            result.append(.init(color: color,left: Double((i*10)%100),duration: 3+Double(i%3),delay: f*0.05,side: i%2 == 0 ? 8 : 10,corner: i%2 == 0 ? 4 : 2,drift: sign*Double(20+i%30)))
            result.append(.init(color: color,left: Double((i*7+15)%100),duration: 4+Double(i%2),delay: f*0.08,side: i%3 == 0 ? 6 : 12,corner: i%3 == 0 ? 3 : 0,drift: sign*Double(15+i%25)))
            result.append(.init(color: color,left: Double((i*13+30)%100),duration: 3.5+f.truncatingRemainder(dividingBy: 2.5),delay: f*0.06,side: i%2 == 1 ? 9 : 11,corner: i%2 == 1 ? 4.5 : 3,drift: sign*Double(25+i%35)))
            result.append(.init(color: color,left: Double((i*11+5)%100),duration: 3.2+f.truncatingRemainder(dividingBy: 2.8),delay: 0,side: i%4 == 0 ? 7 : 9,corner: i%4 == 0 ? 3.5 : 1,drift: sign*Double(18+i%28)))
        }
        return result
    }()
}
