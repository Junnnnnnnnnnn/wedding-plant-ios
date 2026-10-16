import SwiftUI
import WPDomain

struct WeddingCategoryIcon: View {
    let name: String
    var size: CGFloat = 34
    private static let images: [UIImage] = {
        guard let atlas = UIImage(named: "wedding_category_atlas")?.cgImage else { return [] }
        let frames: [[Int]] = [[0, 95, 202, 126],[203, 34, 190, 196],[408, 40, 190, 182],[599, 28, 198, 203],[806, 32, 156, 193],[994, 80, 202, 138],[1210, 57, 184, 156],[1390, 80, 194, 147],[13, 225, 182, 203],[216, 226, 167, 207],[403, 248, 194, 181],[620, 244, 174, 184],[824, 242, 132, 185],[1024, 231, 161, 200],[1215, 222, 178, 213],[1403, 277, 180, 157],[37, 437, 150, 182],[207, 466, 197, 134],[434, 443, 153, 161],[615, 450, 182, 151],[826, 437, 153, 169],[1003, 470, 188, 131],[1204, 453, 188, 150],[1404, 472, 180, 142],[20, 646, 180, 128],[211, 619, 187, 183],[408, 599, 192, 203],[618, 618, 176, 174],[805, 623, 186, 174],[1004, 622, 178, 180],[1192, 626, 207, 184],[1402, 630, 181, 166],[12, 823, 190, 159],[205, 814, 191, 178],[416, 820, 181, 172],[603, 803, 185, 184],[814, 808, 180, 180],[1004, 811, 181, 178],[1197, 814, 196, 178],[1400, 798, 180, 190]]
        let scale = CGFloat(atlas.width) / 1586
        // 잘라 낸 조각은 큰 아틀라스(6MB)를 그대로 물고 있어, 스크롤마다 큰 원본을 줄여 그리느라 목록이 끊겼습니다.
        // 처음 한 번 타일 크기(최대 64pt @3x)의 작은 비트맵으로 구워 둡니다(Android 도 프로세스에 한 번 디코드).
        let side: CGFloat = 64
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 3
        return frames.compactMap { f in
            guard let crop = atlas.cropping(to: CGRect(x: CGFloat(f[0]) * scale, y: CGFloat(f[1]) * scale,
                                                       width: CGFloat(f[2]) * scale, height: CGFloat(f[3]) * scale)) else { return nil }
            let w = CGFloat(crop.width), h = CGFloat(crop.height)
            let fit = min(side / w, side / h)
            let size = CGSize(width: (w * fit).rounded(), height: (h * fit).rounded())
            return UIGraphicsImageRenderer(size: size, format: format).image { _ in
                UIImage(cgImage: crop).draw(in: CGRect(origin: .zero, size: size))
            }
        }
    }()
    var body: some View {
        let index = WeddingCategories.icon(name)
        if Self.images.indices.contains(index) {
            Image(uiImage: Self.images[index]).resizable().scaledToFit().frame(width: size * 0.92, height: size * 0.92).frame(width: size, height: size).accessibilityHidden(true)
        }
    }
}
