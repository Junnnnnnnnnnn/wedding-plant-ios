import SwiftUI

enum ExploreSection: String, CaseIterable { case feed = "피드", brag = "자랑하기", invitation = "청첩장" }
struct ExploreView: View {
    /// 처음 보일 쪽 — 홈의 자랑하기 `보러 가기` 는 `.brag`(안드로이드 `ExploreScreen(initial:)`)
    @State private var selection: ExploreSection
    init(initial: ExploreSection = .feed) { _selection = State(initialValue: initial) }
    var body: some View {
        Group {
            switch selection {
            case .feed: FeedView(titleSlot: AnyView(switcher))
            case .brag: BragView(titleSlot: AnyView(switcher))
            case .invitation: InvitationStudioView(titleSlot: AnyView(switcher))
            }
        }
    }
    private var switcher: some View {
        HStack(spacing: 0) {
            ForEach(ExploreSection.allCases, id: \.self) { section in
                Button { if selection != section { selection = section } } label: {
                    Text(section.rawValue).wpTypography(14.5, .bold)
                        .foregroundStyle(selection == section ? WPColor.primary : .white.opacity(0.9))
                        .padding(.horizontal, 16).frame(height: 38)
                        .background(selection == section ? Color.white : .clear, in: Capsule())
                }.accessibilityIdentifier("explore.\(section)")
            }
        }.padding(3).background(.white.opacity(0.2), in: Capsule())
    }
}
