import SwiftUI

extension Color {
    /// 0xRRGGBB 또는 0xAARRGGBB 로 색을 만든다.
    init(hex: UInt32, alpha: Double? = nil) {
        let hasAlpha = hex > 0xFFFFFF
        let a = alpha ?? (hasAlpha ? Double((hex >> 24) & 0xFF) / 255 : 1)
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// 웹 Tailwind 값을 **1:1 로 옮긴** 팔레트.
///
/// 안드로이드 `ui/theme/Theme.kt:WpColors` 와 같은 값이다.
/// 화면 코드에 hex 를 직접 쓰지 말고 여기를 참조할 것. 값이 어긋나면 세 앱의 브랜드가 깨진다.
/// Tailwind 기본 색(stone/gray)도 실제 hex 를 그대로 적어둔다 — 이름만 보고 짐작하면 틀린다.
enum WPColor {

    /// 앱 배경. 웹 `bg-[#fcfbfc]`
    static let background = Color(hex: 0xFCFBFC)
    static let white = Color.white

    /// 브랜드 핑크. 웹 `#ee2b8c`
    static let primary = Color(hex: 0xEE2B8C)

    /// setting 플로우 버튼·활성 탭. 웹 `bg-[#FFAAB8]`
    static let accent = Color(hex: 0xFFAAB8)

    /// 본문 강조 텍스트. 웹 `text-[#1b0d14]`
    static let textPrimary = Color(hex: 0x1B0D14)

    // Tailwind stone
    static let stone900 = Color(hex: 0x1C1917)
    static let stone800 = Color(hex: 0x292524)
    static let stone700 = Color(hex: 0x44403C)
    static let stone600 = Color(hex: 0x57534E)
    static let stone500 = Color(hex: 0x78716C)
    static let stone400 = Color(hex: 0xA8A29E)
    static let stone300 = Color(hex: 0xD6D3D1)
    static let stone200 = Color(hex: 0xE7E5E4)
    static let stone100 = Color(hex: 0xF5F5F4)
    static let stone50 = Color(hex: 0xFAFAF9)

    // Tailwind gray
    static let gray600 = Color(hex: 0x4B5563)
    static let gray500 = Color(hex: 0x6B7280)
    static let gray400 = Color(hex: 0x9CA3AF)
    static let gray300 = Color(hex: 0xD1D5DB)
    static let gray200 = Color(hex: 0xE5E7EB)
    static let gray100 = Color(hex: 0xF3F4F6)
    static let gray50 = Color(hex: 0xF9FAFB)

    /// 하단 탭 비활성. 웹 BottomTabBar 의 `#99a1af`
    static let tabInactive = Color(hex: 0x99A1AF)

    /// 예산 카드 그라데이션. 웹 `linear-gradient(135deg, #ee2b8c 0%, #ff5c95 100%)`
    static let budgetGradientStart = Color(hex: 0xEE2B8C)
    static let budgetGradientEnd = Color(hex: 0xFF5C95)

    /// 카카오 버튼. 웹 `bg-[#FEE500] text-[#191919]`
    static let kakao = Color(hex: 0xFEE500)
    static let kakaoText = Color(hex: 0x191919)

    /// 배경 점 그리드. 웹 `radial-gradient(#ee2b8c22 1px, transparent 1px)` — 알파 0x22
    static let gridDot = Color(hex: 0xEE2B8C, alpha: Double(0x22) / 255)

    /// 카드 테두리. 웹 `border-[#ee2b8c0a]`
    static let cardBorder = Color(hex: 0xEE2B8C, alpha: Double(0x0A) / 255)

    static let danger = Color(hex: 0xDC2626)
    static let dangerBg = Color(hex: 0xFEF2F2)

    /// 멤버 아바타 그라데이션. 웹 `AVATAR_GRADIENTS`
    static let avatarGradients: [(Color, Color)] = [
        (Color(hex: 0xEE2B8C), Color(hex: 0xFF7EB3)),
        (Color(hex: 0x6366F1), Color(hex: 0xA5B4FC)),
        (Color(hex: 0x059669), Color(hex: 0x34D399)),
        (Color(hex: 0xD97706), Color(hex: 0xFBBF24)),
        (Color(hex: 0x0EA5E9), Color(hex: 0x7DD3FC)),
    ]

    /// 일정 상태 뱃지 배경
    static func statusBackground(_ status: PlanStatusStyle) -> Color { status.background }
    static func statusForeground(_ status: PlanStatusStyle) -> Color { status.foreground }
}

/// 일정 상태 뱃지 색. 웹 값 그대로.
enum PlanStatusStyle {
    case past, today, soon, upcoming

    var background: Color {
        switch self {
        case .past: return Color(hex: 0xFEE2E2)
        case .today: return Color(hex: 0xFCE7F3)
        case .soon: return Color(hex: 0xFEF3C7)
        case .upcoming: return Color(hex: 0xF5F5F4)
        }
    }

    var foreground: Color {
        switch self {
        case .past: return Color(hex: 0xDC2626)
        case .today: return WPColor.primary
        case .soon: return Color(hex: 0xB45309)
        case .upcoming: return WPColor.gray400
        }
    }
}
