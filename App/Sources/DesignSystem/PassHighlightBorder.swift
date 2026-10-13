import SwiftUI

/// Android PassHighlightBorder: a counterclockwise sweep, one turn every six seconds.
struct PassHighlightBorder: View {
    var radius: CGFloat
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    @State private var start = Date()
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !visible || scenePhase != .active)) { context in
            let phase = context.date.timeIntervalSince(start).truncatingRemainder(dividingBy: 6) / 6
            let color = AngularGradient(stops: Self.stops, center: .center, angle: .degrees(-phase * 360))
            RoundedRectangle(cornerRadius: radius).inset(by: 1).stroke(color.opacity(50 / 255), lineWidth: 5)
                .overlay(RoundedRectangle(cornerRadius: radius).inset(by: 1).stroke(color, lineWidth: 2))
        }.allowsHitTesting(false).accessibilityHidden(true)
            .onAppear { start = Date(); visible = true }.onDisappear { visible = false }
    }
    private static let stops: [Gradient.Stop] = [
        .init(color: WPColor.primary.opacity(0), location: 0),
        .init(color: WPColor.primary.opacity(0), location: 165 / 360),
        .init(color: WPColor.primary.opacity(0.2), location: 195 / 360),
        .init(color: Color(hex: 0xF16FB5), location: 225 / 360),
        .init(color: Color(hex: 0xAD70F2), location: 255 / 360),
        .init(color: Color(hex: 0x55A7FF), location: 285 / 360),
        .init(color: Color(hex: 0x49D5C4), location: 310 / 360),
        .init(color: Color(hex: 0xF6D776), location: 335 / 360),
        .init(color: Color(hex: 0xFF91C2), location: 350 / 360),
        .init(color: Color(hex: 0xFFF4FB), location: 357 / 360),
        .init(color: WPColor.primary.opacity(0), location: 1)
    ]
}
