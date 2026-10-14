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
            let cell = size.width / (name.hasPrefix("item") ? 16 : 12)
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
        "itemMood": [
            .init(color: Color(hex: 0x2B1D2E), rects: [1, 2, 8, 1, 1, 3, 1, 7, 8, 3, 1, 1, 4, 4, 8, 1, 4, 5, 1, 5, 11, 5, 1, 1, 7, 6, 8, 1, 7, 7, 1, 5, 14, 7, 1, 7, 1, 10, 4, 1, 4, 11, 1, 1, 4, 12, 4, 1, 7, 13, 1, 1, 7, 14, 8, 1], polygons: []),
            .init(color: Color(hex: 0xEE2B8C), rects: [8, 9, 6, 3], polygons: []),
            .init(color: Color(hex: 0xFFC8DE), rects: [10, 7, 4, 1, 8, 8, 6, 1], polygons: []),
            .init(color: Color(hex: 0x79B85F), rects: [5, 3, 3, 1, 2, 4, 2, 3], polygons: []),
            .init(color: Color(hex: 0x315B41), rects: [2, 7, 2, 1], polygons: []),
            .init(color: Color(hex: 0xF3C34F), rects: [5, 10, 2, 1], polygons: []),
            .init(color: Color(hex: 0xFFF4EA), rects: [8, 5, 3, 1, 5, 6, 2, 4, 2, 8, 2, 2, 5, 11, 2, 1, 8, 12, 6, 2], polygons: []),
            .init(color: Color(hex: 0xFFFFFF), rects: [2, 3, 3, 1, 5, 5, 3, 1, 8, 7, 2, 1], polygons: [])
        ],
        "itemIntro": [
            .init(color: Color(hex: 0x2B1D2E), rects: [5, 1, 6, 1, 3, 2, 2, 1, 11, 2, 2, 1, 2, 3, 1, 2, 5, 3, 1, 1, 10, 3, 1, 1, 13, 3, 1, 2, 4, 4, 1, 9, 11, 4, 1, 9, 1, 5, 1, 8, 14, 5, 1, 8, 1, 13, 4, 1, 11, 13, 4, 1, 1, 14, 14, 1], polygons: []),
            .init(color: Color(hex: 0xFFC8DE), rects: [11, 3, 1, 1], polygons: []),
            .init(color: Color(hex: 0x79B85F), rects: [5, 2, 6, 1, 3, 3, 2, 1, 12, 3, 1, 2, 3, 4, 1, 1, 2, 5, 2, 1, 12, 5, 2, 1, 3, 6, 1, 3, 12, 6, 1, 3, 3, 10, 1, 2, 12, 10, 1, 2], polygons: []),
            .init(color: Color(hex: 0x315B41), rects: [2, 6, 1, 6, 13, 6, 1, 6, 2, 12, 2, 1, 12, 12, 2, 1], polygons: []),
            .init(color: Color(hex: 0xF3C34F), rects: [6, 3, 4, 1, 5, 4, 2, 1, 9, 4, 2, 1, 5, 5, 1, 1, 10, 5, 1, 1, 3, 9, 1, 1, 12, 9, 1, 1, 5, 13, 6, 1], polygons: []),
            .init(color: Color(hex: 0xFFF4EA), rects: [7, 4, 2, 1, 6, 5, 4, 1, 5, 6, 6, 1, 5, 7, 2, 5, 9, 7, 2, 5, 5, 12, 6, 1], polygons: []),
            .init(color: Color(hex: 0xFFFFFF), rects: [7, 7, 2, 5], polygons: [])
        ],
        "itemCover": [
            .init(color: Color(hex: 0x2B1D2E), rects: [5, 1, 2, 1, 8, 1, 2, 1, 4, 2, 1, 1, 7, 2, 1, 1, 10, 2, 1, 1, 3, 3, 2, 1, 10, 3, 3, 1, 3, 4, 1, 10, 5, 4, 1, 1, 9, 4, 1, 1, 12, 4, 1, 10, 6, 5, 1, 1, 8, 5, 1, 1, 7, 6, 1, 1, 3, 14, 10, 1], polygons: []),
            .init(color: Color(hex: 0xEE2B8C), rects: [5, 2, 2, 1, 8, 2, 2, 1, 5, 3, 1, 1, 7, 3, 3, 1, 6, 4, 3, 1, 7, 5, 1, 1], polygons: []),
            .init(color: Color(hex: 0xFFC8DE), rects: [6, 3, 1, 1, 6, 13, 4, 1], polygons: []),
            .init(color: Color(hex: 0x79B85F), rects: [5, 11, 4, 1], polygons: []),
            .init(color: Color(hex: 0x315B41), rects: [5, 10, 2, 1], polygons: []),
            .init(color: Color(hex: 0xF3C34F), rects: [9, 7, 2, 2], polygons: []),
            .init(color: Color(hex: 0xFFF4EA), rects: [4, 4, 1, 1, 10, 4, 2, 1, 4, 5, 2, 1, 9, 5, 3, 1, 4, 6, 1, 6, 11, 6, 1, 6, 4, 12, 8, 1, 4, 13, 2, 1, 10, 13, 2, 1], polygons: []),
            .init(color: Color(hex: 0x9FD3E0), rects: [5, 6, 2, 1, 8, 6, 3, 1, 5, 7, 4, 2], polygons: []),
            .init(color: Color(hex: 0x3F8FB0), rects: [5, 9, 6, 1, 7, 10, 4, 1, 9, 11, 2, 1], polygons: [])
        ],
        "itemMessage": [
            .init(color: Color(hex: 0x2B1D2E), rects: [1, 3, 14, 1, 1, 4, 1, 9, 14, 4, 1, 9, 3, 5, 1, 1, 12, 5, 1, 1, 4, 6, 2, 1, 7, 6, 5, 1, 6, 7, 1, 1, 10, 7, 1, 1, 5, 8, 1, 3, 11, 8, 1, 3, 6, 11, 1, 1, 10, 11, 1, 1, 7, 12, 3, 1, 1, 13, 14, 1], polygons: []),
            .init(color: Color(hex: 0xEE2B8C), rects: [7, 7, 3, 1, 6, 8, 1, 2, 8, 8, 1, 1, 10, 8, 1, 2, 6, 10, 2, 1, 9, 10, 2, 1, 7, 11, 3, 1], polygons: []),
            .init(color: Color(hex: 0xFFC8DE), rects: [2, 4, 1, 1, 13, 4, 1, 1, 3, 11, 1, 1, 12, 11, 1, 1, 2, 12, 1, 1, 13, 12, 1, 1], polygons: []),
            .init(color: Color(hex: 0xFFF4EA), rects: [3, 4, 10, 1, 2, 5, 1, 1, 4, 5, 8, 1, 13, 5, 1, 1, 2, 6, 2, 1, 6, 6, 1, 1, 12, 6, 2, 1, 2, 7, 4, 1, 11, 7, 3, 1, 2, 8, 3, 3, 12, 8, 2, 3, 2, 11, 1, 1, 4, 11, 2, 1, 11, 11, 1, 1, 13, 11, 1, 1, 3, 12, 4, 1, 10, 12, 3, 1], polygons: []),
            .init(color: Color(hex: 0xFFFFFF), rects: [7, 8, 1, 1, 9, 8, 1, 1, 7, 9, 3, 1, 8, 10, 1, 1], polygons: [])
        ],
        "itemCouple": [
            .init(color: Color(hex: 0x2B1D2E), rects: [2, 1, 4, 1, 10, 1, 4, 1, 1, 2, 6, 1, 9, 2, 1, 2, 14, 2, 1, 2, 1, 3, 1, 1, 6, 3, 1, 1, 1, 4, 2, 1, 5, 4, 2, 1, 9, 4, 2, 1, 13, 4, 2, 1, 1, 5, 1, 1, 6, 5, 1, 1, 9, 5, 1, 2, 14, 5, 1, 2, 2, 6, 4, 1, 11, 6, 2, 1, 2, 7, 1, 1, 6, 7, 1, 2, 10, 7, 3, 1, 1, 8, 2, 3, 4, 8, 1, 1, 8, 8, 2, 1, 13, 8, 1, 4, 6, 9, 2, 1, 10, 9, 1, 1, 6, 10, 1, 1, 11, 10, 1, 1, 1, 11, 3, 1, 5, 11, 3, 1, 10, 11, 1, 2, 1, 12, 6, 1, 8, 12, 1, 1, 2, 13, 6, 1, 9, 13, 1, 1, 14, 13, 1, 1, 2, 14, 2, 1, 5, 14, 10, 1], polygons: []),
            .init(color: Color(hex: 0xEE2B8C), rects: [8, 9, 2, 1, 7, 10, 1, 1, 9, 10, 2, 1, 8, 11, 2, 1], polygons: []),
            .init(color: Color(hex: 0xFFC8DE), rects: [11, 2, 1, 1, 8, 10, 1, 1, 13, 12, 1, 2], polygons: []),
            .init(color: Color(hex: 0x315B41), rects: [9, 12, 1, 1], polygons: []),
            .init(color: Color(hex: 0xFFF4EA), rects: [2, 3, 4, 1, 10, 3, 4, 1, 3, 4, 2, 1, 11, 4, 2, 1, 2, 5, 4, 1, 10, 5, 4, 1, 4, 10, 1, 2], polygons: []),
            .init(color: Color(hex: 0xFFFFFF), rects: [10, 2, 1, 1, 12, 2, 2, 1, 10, 6, 1, 1, 13, 6, 1, 1, 3, 7, 3, 1, 3, 8, 1, 1, 5, 8, 1, 1, 10, 8, 3, 1, 3, 9, 3, 1, 11, 9, 2, 1, 3, 10, 1, 1, 5, 10, 1, 1, 12, 10, 1, 1, 11, 11, 2, 2, 8, 13, 1, 1, 10, 13, 3, 1], polygons: [])
        ],
        "itemGallery": [
            .init(color: Color(hex: 0x2B1D2E), rects: [1, 1, 10, 1, 1, 2, 1, 9, 10, 2, 1, 2, 4, 4, 11, 1, 4, 5, 1, 6, 14, 5, 1, 9, 1, 11, 4, 1, 4, 12, 1, 2, 4, 14, 11, 1], polygons: []),
            .init(color: Color(hex: 0xFFC8DE), rects: [6, 13, 3, 1], polygons: []),
            .init(color: Color(hex: 0x79B85F), rects: [8, 10, 2, 1, 8, 11, 5, 1], polygons: []),
            .init(color: Color(hex: 0x315B41), rects: [7, 9, 2, 1, 6, 10, 2, 2], polygons: []),
            .init(color: Color(hex: 0xF3C34F), rects: [10, 7, 2, 2], polygons: []),
            .init(color: Color(hex: 0xFFF4EA), rects: [2, 2, 8, 1, 2, 3, 1, 6, 9, 3, 1, 1, 5, 5, 9, 1, 5, 6, 1, 6, 13, 6, 1, 6, 2, 9, 2, 2, 5, 12, 9, 1, 5, 13, 1, 1, 9, 13, 5, 1], polygons: []),
            .init(color: Color(hex: 0x9FD3E0), rects: [3, 3, 6, 1, 3, 4, 1, 2, 6, 6, 7, 1, 6, 7, 4, 2, 12, 7, 1, 2, 6, 9, 1, 1, 9, 9, 4, 1, 10, 10, 3, 1], polygons: []),
            .init(color: Color(hex: 0x3F8FB0), rects: [3, 6, 1, 3], polygons: [])
        ],
        "itemCalendar": [
            .init(color: Color(hex: 0x2B1D2E), rects: [4, 1, 2, 1, 10, 1, 2, 1, 4, 2, 1, 1, 10, 2, 1, 1, 2, 3, 3, 1, 6, 3, 5, 1, 12, 3, 2, 1, 2, 4, 1, 3, 4, 4, 2, 1, 10, 4, 2, 1, 13, 4, 1, 3, 2, 7, 12, 1, 2, 8, 1, 6, 13, 8, 1, 6, 2, 14, 12, 1], polygons: []),
            .init(color: Color(hex: 0xEE2B8C), rects: [3, 5, 10, 2, 9, 9, 1, 1, 11, 9, 2, 1, 8, 10, 5, 1, 9, 11, 3, 1, 10, 12, 1, 1], polygons: []),
            .init(color: Color(hex: 0xFFC8DE), rects: [3, 4, 1, 1, 6, 4, 4, 1, 12, 4, 1, 1, 8, 9, 1, 1], polygons: []),
            .init(color: Color(hex: 0xFFF4EA), rects: [3, 8, 10, 1, 3, 9, 1, 2, 6, 9, 2, 2, 10, 9, 1, 1, 3, 11, 6, 1, 12, 11, 1, 1, 3, 12, 1, 1, 6, 12, 4, 1, 11, 12, 2, 1, 3, 13, 10, 1], polygons: []),
            .init(color: Color(hex: 0xFFFFFF), rects: [5, 2, 1, 2, 11, 2, 1, 2], polygons: []),
            .init(color: Color(hex: 0x9FD3E0), rects: [4, 9, 2, 2, 4, 12, 2, 1], polygons: [])
        ],
        "itemLocation": [
            .init(color: Color(hex: 0x2B1D2E), rects: [5, 1, 6, 1, 4, 2, 1, 1, 11, 2, 1, 1, 3, 3, 1, 1, 12, 3, 1, 1, 2, 4, 1, 4, 7, 4, 2, 1, 13, 4, 1, 4, 6, 5, 1, 2, 9, 5, 1, 2, 7, 7, 2, 1, 3, 8, 1, 1, 12, 8, 1, 1, 4, 9, 1, 1, 11, 9, 1, 1, 5, 10, 1, 1, 10, 10, 1, 1, 6, 11, 1, 1, 9, 11, 1, 1, 3, 12, 10, 1, 1, 13, 1, 1, 14, 13, 1, 1, 3, 14, 10, 1], polygons: []),
            .init(color: Color(hex: 0xEE2B8C), rects: [5, 2, 6, 1, 4, 3, 2, 1, 8, 3, 4, 1, 3, 4, 1, 2, 5, 4, 2, 1, 9, 4, 4, 1, 5, 5, 1, 1, 10, 5, 3, 2, 3, 6, 3, 1, 3, 7, 4, 1, 9, 7, 4, 1, 4, 8, 8, 1, 5, 9, 6, 1, 6, 10, 4, 1, 7, 11, 2, 1], polygons: []),
            .init(color: Color(hex: 0xFFC8DE), rects: [6, 3, 2, 1, 4, 4, 1, 2], polygons: []),
            .init(color: Color(hex: 0x79B85F), rects: [2, 13, 12, 1], polygons: []),
            .init(color: Color(hex: 0xFFFFFF), rects: [7, 5, 2, 2], polygons: [])
        ],
        "itemNotice": [
            .init(color: Color(hex: 0x2B1D2E), rects: [10, 1, 4, 1, 9, 2, 1, 1, 14, 2, 1, 2, 1, 3, 9, 1, 1, 4, 1, 6, 10, 4, 5, 1, 10, 5, 1, 2, 12, 5, 1, 2, 14, 5, 1, 5, 4, 6, 5, 1, 1, 10, 14, 1, 6, 11, 1, 3, 9, 11, 1, 3, 4, 14, 8, 1], polygons: []),
            .init(color: Color(hex: 0xEE2B8C), rects: [10, 2, 4, 1, 10, 3, 1, 1, 13, 3, 1, 1, 11, 5, 1, 1, 13, 5, 1, 1], polygons: []),
            .init(color: Color(hex: 0xFFC8DE), rects: [11, 3, 2, 1], polygons: []),
            .init(color: Color(hex: 0x79B85F), rects: [11, 13, 2, 1], polygons: []),
            .init(color: Color(hex: 0x315B41), rects: [4, 8, 6, 1, 3, 13, 2, 1], polygons: []),
            .init(color: Color(hex: 0xF3C34F), rects: [3, 4, 7, 1, 2, 5, 1, 4, 13, 6, 1, 1, 12, 7, 2, 2, 2, 9, 11, 1, 7, 11, 2, 3], polygons: []),
            .init(color: Color(hex: 0xFFF4EA), rects: [3, 5, 7, 1, 3, 6, 1, 1, 9, 6, 1, 1, 11, 6, 1, 1, 3, 7, 9, 1, 3, 8, 1, 1, 10, 8, 2, 1], polygons: []),
            .init(color: Color(hex: 0xFFFFFF), rects: [2, 4, 1, 1, 13, 9, 1, 1], polygons: [])
        ],
        "itemAccounts": [
            .init(color: Color(hex: 0x2B1D2E), rects: [3, 1, 9, 1, 3, 2, 1, 12, 11, 2, 1, 6, 10, 8, 3, 1, 9, 9, 1, 1, 13, 9, 1, 1, 8, 10, 1, 3, 10, 10, 2, 1, 14, 10, 1, 3, 11, 11, 1, 1, 10, 12, 3, 1, 9, 13, 1, 1, 13, 13, 1, 1, 3, 14, 10, 1], polygons: []),
            .init(color: Color(hex: 0xEE2B8C), rects: [6, 4, 1, 1, 8, 4, 2, 1, 5, 5, 5, 1, 6, 6, 3, 1, 7, 7, 1, 1], polygons: []),
            .init(color: Color(hex: 0xFFC8DE), rects: [4, 2, 7, 1, 5, 4, 1, 1], polygons: []),
            .init(color: Color(hex: 0xF3C34F), rects: [10, 9, 3, 1, 9, 10, 1, 1, 12, 10, 2, 2, 9, 11, 2, 1, 5, 12, 3, 1, 9, 12, 1, 1, 13, 12, 1, 1, 10, 13, 3, 1], polygons: []),
            .init(color: Color(hex: 0xFFF4EA), rects: [4, 3, 7, 1, 4, 4, 1, 2, 7, 4, 1, 1, 10, 4, 1, 2, 4, 6, 2, 1, 9, 6, 2, 1, 4, 7, 3, 1, 8, 7, 3, 1, 4, 8, 6, 1, 4, 9, 5, 1, 4, 10, 4, 2, 4, 12, 1, 1, 4, 13, 5, 1], polygons: [])
        ],
        "itemGuestbook": [
            .init(color: Color(hex: 0x2B1D2E), rects: [7, 1, 7, 1, 6, 2, 1, 3, 14, 2, 1, 5, 3, 5, 4, 1, 2, 6, 5, 1, 2, 7, 1, 1, 6, 7, 2, 1, 13, 7, 2, 1, 2, 8, 2, 1, 6, 8, 8, 1, 2, 9, 1, 1, 6, 9, 3, 1, 3, 10, 7, 1, 2, 11, 6, 1, 9, 11, 1, 1, 2, 12, 1, 1, 7, 12, 3, 1, 2, 13, 6, 1, 2, 14, 2, 1, 6, 14, 2, 1], polygons: []),
            .init(color: Color(hex: 0xEE2B8C), rects: [9, 3, 1, 1, 11, 3, 2, 1, 8, 4, 5, 1, 9, 5, 3, 1, 10, 6, 1, 1], polygons: []),
            .init(color: Color(hex: 0xFFC8DE), rects: [8, 3, 1, 1], polygons: []),
            .init(color: Color(hex: 0x79B85F), rects: [3, 12, 4, 1], polygons: []),
            .init(color: Color(hex: 0xFFF4EA), rects: [3, 7, 3, 1, 4, 8, 2, 1, 3, 9, 3, 1, 8, 11, 1, 1], polygons: []),
            .init(color: Color(hex: 0xFFFFFF), rects: [7, 2, 7, 1, 7, 3, 1, 2, 10, 3, 1, 1, 13, 3, 1, 2, 7, 5, 2, 1, 12, 5, 2, 1, 7, 6, 3, 1, 11, 6, 3, 1, 8, 7, 5, 1], polygons: [])
        ],
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
