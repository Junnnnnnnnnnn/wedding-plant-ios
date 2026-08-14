import SwiftUI

/// 웹 `BottomTabBar` 의 TabType. 라벨 문구도 웹 그대로다.
///
/// - Note: `settings` 라벨이 "Settings" 로 영문인 것은 웹이 그렇기 때문이다. 임의로 한글화하지 말 것.
enum WPTab: String, CaseIterable, Identifiable {
    case home
    case feed
    case rooms
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: return "홈"
        case .feed: return "피드"
        case .rooms: return "참여 플랜"
        case .settings: return "Settings"
        }
    }

    /// 안드로이드가 쓰는 Material 아이콘에 대응하는 SF Symbol.
    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .feed: return "magnifyingglass"
        case .rooms: return "square.grid.2x2.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

/// 웹 `BottomTabBar` 포팅.
///
/// iOS 기본 `TabView` 를 쓰지 않는 이유: 웹·안드로이드가 흰 배경에 4칸 균등 배치인
/// 커스텀 바를 쓰고 있어서, `TabView` 로는 같은 모양이 나오지 않는다.
/// "피드" 탭은 웹과 동일하게 **준비중 알림만** 띄운다 (라우팅 없음).
struct BottomTabBar: View {
    @Binding var active: WPTab
    var unreadCount: Int = 0

    @State private var showFeedPrepAlert = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(WPTab.allCases) { tab in
                TabItem(
                    tab: tab,
                    active: active == tab,
                    badgeCount: tab == .rooms ? unreadCount : 0
                ) {
                    if tab == .feed {
                        showFeedPrepAlert = true
                    } else {
                        active = tab
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white)
        .alert("서비스 준비중입니다.", isPresented: $showFeedPrepAlert) {
            Button("닫기", role: .cancel) {}
        } message: {
            Text("조금만 기다려 주세요")
        }
    }
}

private struct TabItem: View {
    var tab: WPTab
    var active: Bool
    var badgeCount: Int
    var action: () -> Void

    var body: some View {
        // 웹 BottomTabBar: 활성 #ffaab8, 비활성 #99a1af
        let tint = active ? WPColor.accent : WPColor.tabInactive

        Button(action: action) {
            VStack(spacing: 2) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 20))
                        .frame(width: 24, height: 24)
                        .foregroundStyle(tint)

                    if badgeCount > 0 {
                        Text(verbatim: badgeCount > 9 ? "9+" : "\(badgeCount)")
                            .font(WPFont.hak(9, .black))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(WPColor.primary, in: Circle())
                            .offset(x: 12, y: -6)
                    }
                }
                Text(tab.label)
                    .font(WPFont.hak(10))
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab.\(tab.rawValue)")
    }
}
