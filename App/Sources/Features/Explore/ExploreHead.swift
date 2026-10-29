import SwiftUI

struct ExploreHead<Extra: View>: View {
    let switcher: AnyView
    let headline: String
    let stats: [(String, String)]
    let loading: Bool
    var action: (() -> Void)? = nil
    /// `+` 옆 숫자 — 서버가 판정한 **아직 올릴 수 있는** 완료 일정 수(Android `FeedPostButton`). 받기 전이면 nil 이라
    /// 숫자를 내지 않고, 서버가 0 을 주면 0 을 낸다(모름과 없음을 가른다).
    var actionCount: Int? = nil
    @ViewBuilder var extra: Extra

    var body: some View {
        BrandHead(corner: 24, horizontal: 20, top: 14, bottom: 20) {
            HStack {
                switcher
                Spacer(minLength: 8)
                if let action {
                    Button(action: action) {
                        HStack(spacing: 4) {
                            WPMaterialIcon(kind: .plus).frame(width: 22, height: 22).foregroundStyle(.white)
                            if let actionCount {
                                Text(verbatim: "\(actionCount)").font(WPFont.hak(12, .bold)).foregroundStyle(WPColor.primary)
                                    .lineLimit(1).fixedSize()
                                    .padding(.horizontal, 7).padding(.vertical, 3).background(.white, in: Capsule())
                            }
                        }.padding(.horizontal, 7).frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(actionCount.map { "내 후기 올리기, 작성 가능한 후기 \($0)개" } ?? "내 후기 올리기")
                    .accessibilityIdentifier("feed.post.open")
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
