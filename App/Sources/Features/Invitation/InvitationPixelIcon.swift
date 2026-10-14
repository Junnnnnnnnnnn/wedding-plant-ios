import SwiftUI

/// Exact 12×12 rectangles/polygons from Android InvitationPixelIcons.kt.
struct InvitationPixelIcon: View {
    let name: String
    @Environment(\.displayScale) private var displayScale
    private struct Layer {
        let color: Color
        let rects: [Int]
        let polygons: [[Int]]
    }
    var body: some View {
        Canvas { context, size in
            let cell = size.width / 12
            func px(_ n: Int) -> CGFloat { (CGFloat(n) * cell * displayScale).rounded() / displayScale }
            for layer in Self.icons[name] ?? [] {
                for i in stride(from: 0, to: layer.rects.count, by: 4) {
                    let r = layer.rects
                    let rect = CGRect(x: px(r[i]), y: px(r[i+1]), width: px(r[i]+r[i+2])-px(r[i]), height: px(r[i+1]+r[i+3])-px(r[i+1]))
                    context.fill(Path(rect), with: .color(layer.color), style: FillStyle(antialiased: false))
                }
                for polygon in layer.polygons {
                    var path = Path(); path.move(to: CGPoint(x: px(polygon[0]), y: px(polygon[1])))
                    for i in stride(from: 2, to: polygon.count, by: 2) { path.addLine(to: CGPoint(x: px(polygon[i]), y: px(polygon[i+1]))) }
                    path.closeSubpath(); context.fill(path, with: .color(layer.color), style: FillStyle(antialiased: false))
                }
            }
        }.accessibilityHidden(true)
    }
    private static let icons: [String: [Layer]] = [
        "album": [
            .init(color: Color(hex: 0xFFC8DE), rects: [1, 2, 10, 8], polygons: []),
            .init(color: Color(hex: 0x2B1D2E), rects: [2, 3, 8, 6], polygons: []),
            .init(color: Color(hex: 0x79B85F), rects: [], polygons: [[2, 7, 4, 5, 6, 7, 7, 6, 10, 9, 2, 9]]),
            .init(color: Color(hex: 0xF3C34F), rects: [7, 4, 2, 2], polygons: [])
        ],
        "info": [
            .init(color: Color(hex: 0xFFF4EA), rects: [1, 2, 10, 9], polygons: []),
            .init(color: Color(hex: 0xEE2B8C), rects: [1, 2, 10, 2], polygons: []),
            .init(color: Color(hex: 0x2B1D2E), rects: [3, 6, 2, 1, 6, 6, 2, 1, 3, 8, 2, 1, 6, 8, 2, 1], polygons: [])
        ],
        "garden": [
            .init(color: Color(hex: 0x79B85F), rects: [0, 8, 12, 4], polygons: []),
            .init(color: Color(hex: 0xFFC8DE), rects: [4, 2, 4, 4], polygons: []),
            .init(color: Color(hex: 0x2B1D2E), rects: [5, 3, 1, 1, 7, 3, 1, 1], polygons: []),
            .init(color: Color(hex: 0xEE2B8C), rects: [4, 6, 4, 3], polygons: [])
        ],
        "qr": [
            .init(color: Color(hex: 0xFFFFFF), rects: [0, 0, 12, 12], polygons: []),
            .init(color: Color(hex: 0x2B1D2E), rects: [1, 1, 4, 4, 7, 1, 4, 4, 1, 7, 4, 4, 7, 7, 2, 2, 9, 9, 2, 2], polygons: []),
            .init(color: Color(hex: 0xFFFFFF), rects: [2, 2, 2, 2, 8, 2, 2, 2, 2, 8, 2, 2], polygons: [])
        ],
        "couple": [
            .init(color: Color(hex: 0xFFC8DE), rects: [2, 1, 3, 3, 7, 1, 3, 3], polygons: []),
            .init(color: Color(hex: 0xEE2B8C), rects: [1, 5, 5, 6, 6, 5, 5, 6], polygons: [])
        ],
        "date": [
            .init(color: Color(hex: 0xFFF4EA), rects: [1, 2, 10, 9], polygons: []),
            .init(color: Color(hex: 0xEE2B8C), rects: [1, 2, 10, 2], polygons: []),
            .init(color: Color(hex: 0x2B1D2E), rects: [3, 6, 2, 2], polygons: [])
        ],
        "letter": [
            .init(color: Color(hex: 0xFFF4EA), rects: [1, 3, 10, 7], polygons: []),
            .init(color: Color(hex: 0x2B1D2E), rects: [1, 3, 10, 1, 2, 4, 1, 1, 9, 4, 1, 1, 3, 5, 2, 1, 7, 5, 2, 1, 5, 6, 2, 1], polygons: [])
        ]
    ]
}
