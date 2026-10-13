import SwiftUI

enum WPTab: String, CaseIterable, Identifiable {
    case home, schedule, add, explore, rooms
    var id: String { rawValue }
    var label: String {
        switch self { case .home: "홈"; case .schedule: "일정"; case .add: "플랜 추가"; case .explore: "둘러보기"; case .rooms: "채팅" }
    }
    var symbol: String {
        switch self { case .home: "house"; case .schedule: "calendar"; case .add: "plus"; case .explore: "magnifyingglass"; case .rooms: "bubble" }
    }
}

struct BottomTabBar: View {
    @Binding var active: WPTab
    var unreadCount: Int = 0
    var onAdd: () -> Void = {}
    var onSelect: () -> Void = {}
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.black.opacity(0.06)).frame(height: 0.5)
            HStack(spacing: 0) {
                ForEach(WPTab.allCases) { tab in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if tab == .add { onAdd() } else { active = tab; onSelect() }
                    } label: {
                        VStack(spacing: 3) {
                            ZStack(alignment: .topTrailing) {
                                if tab == .add {
                                    Image("tab_add").resizable().scaledToFit().frame(width: 22, height: 22).foregroundStyle(.white)
                                        .frame(width: 42, height: 42).background(WPColor.primary, in: Circle())
                                        .shadow(color: WPColor.primary.opacity(0.4), radius: 6, y: 4)
                                        .offset(y: -7).frame(width: 22, height: 28)
                                } else {
                                    Image("tab_" + tab.rawValue).resizable().scaledToFit().frame(width: 22, height: 22)
                                    if tab == .rooms && unreadCount > 0 {
                                        Text(verbatim: unreadCount > 9 ? "9+" : "\(unreadCount)")
                                            .font(WPFont.hak(9, .bold)).foregroundStyle(.white).padding(3)
                                            .background(WPColor.primary, in: Circle()).offset(x: 8, y: -5)
                                    }
                                }
                            }
                            Text(tab.label).font(WPFont.hak(10, .bold))
                        }.foregroundStyle(active == tab ? WPColor.primary : Color(hex: 0x868B94))
                            .frame(maxWidth: .infinity).frame(height: 42).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("tab.\(tab.rawValue)")
                        .accessibilityAddTraits(active == tab ? .isSelected : [])
                }
            }.padding(.top, 8).padding(.bottom, 16)
        }.background(.white)
    }
}
