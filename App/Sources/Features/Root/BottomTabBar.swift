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

    /// 웹 `tabs.ts` 의 `TAB_ITEMS` · 안드로이드 `BottomTabBar` 와 **같은 그림**의 SF Symbol.
    ///
    /// 웹이 아이콘을 고른 이유를 코드에 적어 두었고 안드로이드가 그대로 따랐는데,
    /// 여기만 달랐다.
    ///
    /// - **피드는 돋보기가 아니라 글 목록이다.** 이 화면은 검색하는 곳이 아니라
    ///   남이 올린 후기를 훑는 곳이라, 돋보기는 **없는 기능을 약속한다.**
    /// - **참여 플랜은 격자가 아니라 사람이다.** 격자는 무엇이 모여 있는지를
    ///   말하지 않는다.
    ///
    /// 채움(`.fill`)이 아니라 선 그림인 것도 웹(lucide)·안드로이드(Outlined)와
    /// 맞춘 것이다. iOS 관습은 채움이지만 세 앱이 같아야 한다는 쪽이 앞선다.
    var symbol: String {
        switch self {
        case .home: return "house"
        case .feed: return "note.text"
        case .rooms: return "person.2"
        case .settings: return "gearshape"
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
