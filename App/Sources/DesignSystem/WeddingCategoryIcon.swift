import SwiftUI
import WPDomain

struct WeddingCategoryIcon: View {
    let name: String
    var size: CGFloat = 34
    private static let images: [UIImage] = {
        guard let atlas = UIImage(named: "wedding_category_atlas")?.cgImage else { return [] }
        let frames: [[Int]] = [[0, 95, 202, 126],[203, 34, 190, 196],[408, 40, 190, 182],[599, 28, 198, 203],[806, 32, 156, 193],[994, 80, 202, 138],[1210, 57, 184, 156],[1390, 80, 194, 147],[13, 225, 182, 203],[216, 226, 167, 207],[403, 248, 194, 181],[620, 244, 174, 184],[824, 242, 132, 185],[1024, 231, 161, 200],[1215, 222, 178, 213],[1403, 277, 180, 157],[37, 437, 150, 182],[207, 466, 197, 134],[434, 443, 153, 161],[615, 450, 182, 151],[826, 437, 153, 169],[1003, 470, 188, 131],[1204, 453, 188, 150],[1404, 472, 180, 142],[20, 646, 180, 128],[211, 619, 187, 183],[408, 599, 192, 203],[618, 618, 176, 174],[805, 623, 186, 174],[1004, 622, 178, 180],[1192, 626, 207, 184],[1402, 630, 181, 166],[12, 823, 190, 159],[205, 814, 191, 178],[416, 820, 181, 172],[603, 803, 185, 184],[814, 808, 180, 180],[1004, 811, 181, 178],[1197, 814, 196, 178],[1400, 798, 180, 190]]
        let scale = CGFloat(atlas.width) / 1586
        return frames.compactMap { f in
            atlas.cropping(to: CGRect(x: CGFloat(f[0]) * scale, y: CGFloat(f[1]) * scale, width: CGFloat(f[2]) * scale, height: CGFloat(f[3]) * scale)).map { UIImage(cgImage: $0) }
        }
    }()
    var body: some View {
        let index = WeddingCategories.icon(name)
        if Self.images.indices.contains(index) {
            Image(uiImage: Self.images[index]).resizable().scaledToFit().frame(width: size * 0.92, height: size * 0.92).frame(width: size, height: size).accessibilityHidden(true)
        }
    }
}
