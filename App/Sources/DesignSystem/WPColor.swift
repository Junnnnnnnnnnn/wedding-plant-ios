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

    // MARK: - 모바일 C안 (웹 main `docs/concepts/c-tokens.css`)
    //
    // 당근 SEED 의 중립 램프·레이어를 그대로 가져온 값이다. 폰 화면은
    // **"분홍 머리 면 + 흰 시트 + 회색 채움 카드 + 헤어라인"** 으로만 짠다.
    //
    // C안 규칙 넷:
    //  1. 분홍 면은 **화면 맨 위 한 덩이**뿐. 본문에 분홍 면을 또 두지 않는다.
    //  2. 면에는 그 화면에서 **변하지 않는 사실**만 — 누구의 플랜인지, 언제인지, 지금 얼마인지.
    //  3. 본문의 분홍은 **누를 것**에만 — 주 버튼, 활성 탭, 선택된 칩.
    //  4. 나머지는 SEED 중립 — 회색 채움 카드와 헤어라인.
    //
    // 안드로이드 `WpColors` 와 같은 값이다. 한쪽만 고치면 두 앱이 갈린다.

    /// SEED `bg-layer-fill` — 회색 채움 카드·입력 칸. 웹 `#f7f8f9`
    static let fill = Color(hex: 0xF7F8F9)
    /// SEED `bg-neutral-weak-pressed`. 웹 `#eeeff1`
    static let fillPressed = Color(hex: 0xEEEFF1)
    /// SEED `bg-layer-basement` / `bg-neutral-weak`. 웹 `#f3f4f5`
    static let basement = Color(hex: 0xF3F4F5)
    /// SEED `fg-neutral`. 웹 `#1a1c20`
    static let fgNeutral = Color(hex: 0x1A1C20)
    /// SEED `fg-neutral-muted`. 웹 `#555d6d`
    static let fgMuted = Color(hex: 0x555D6D)
    /// SEED `fg-neutral-subtle`. 웹 `#868b94` — 탭바 비활성도 이 값
    static let fgSubtle = Color(hex: 0x868B94)
    /// SEED `fg-neutral-disabled`. 웹 `#d1d3d8`
    static let fgDisabled = Color(hex: 0xD1D3D8)
    /// SEED `stroke-neutral-weak`. 웹 `#dcdee3`
    static let strokeWeak = Color(hex: 0xDCDEE3)
    /// SEED `stroke-neutral-muted`. 웹 `#00000010` — 탭바 위 경계선
    static let strokeMuted = Color(hex: 0x10000000)
    /// SEED `stroke-neutral-subtle`. 웹 `#0000000c` — 구분선 목록
    static let strokeSubtle = Color(hex: 0x0C000000)
    /// 브랜드 램프. 웹 `#fff1f7` — 카테고리 태그 바탕
    static let brand100 = Color(hex: 0xFFF1F7)
    static let brand200 = Color(hex: 0xFFE3EF)
    /// 웹 `#ffc9e0` — 미완료 체크 테두리
    static let brand300 = Color(hex: 0xFFC9E0)
    /// 웹 `#cc1873` — 태그 글자·pressed
    static let brand700 = Color(hex: 0xCC1873)
    /// SEED `fg-positive`. 웹 `#079171` — 완료 체크
    static let positive = Color(hex: 0x079171)
    static let positiveWeak = Color(hex: 0xEDFAF6)
    /// SEED `fg-critical`. 웹 `#fa342c` — 일요일·삭제
    static let critical = Color(hex: 0xFA342C)
    static let criticalWeak = Color(hex: 0xFDF0F0)
    /// SEED `fg-informative`. 웹 `#217cf9` — 토요일
    static let informative = Color(hex: 0x217CF9)

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
