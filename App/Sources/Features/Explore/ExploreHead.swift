import SwiftUI

struct ExploreHead<Extra: View>: View {
    let switcher: AnyView
    let headline: String
    let stats: [(String, String)]
    let loading: Bool
    var action: (() -> Void)? = nil
    @ViewBuilder var extra: Extra

    var body: some View {
        BrandHead(corner: 24, horizontal: 20, top: 14, bottom: 20) {
            HStack {
                switcher
                Spacer(minLength: 8)
                if let action {
                    Button(action: action) { WPMaterialIcon(kind: .plus).frame(width: 22, height: 22).foregroundStyle(.white).frame(width: 36, height: 38) }.accessibilityLabel("내 후기 올리기")
                }
            }
            Text(headline.wpKeepAll).wpTypography(22, .bold, lineHeight: 29).tracking(-0.44).foregroundStyle(.white).padding(.top, 16)
            if !stats.isEmpty {
            HStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                    if index > 0 { Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 38) }
                    VStack(spacing: 3) {
                        Text(stat.1).wpTypography(17, .bold).redacted(reason: loading ? .placeholder : [])
                        Text(stat.0).wpTypography(11.5).opacity(0.8)
                    }.lineLimit(1).frame(maxWidth: .infinity).padding(.horizontal, 6)
                }
            }.foregroundStyle(.white).padding(.vertical, 12).background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 14)).padding(.top, 16)
            }
            extra
        }
    }
}
