import SwiftUI

/// 웹과 **같은 TTF 파일**을 그대로 쓴다 (`public/font/` → `App/Resources/Fonts/`).
///
/// 폰트가 다르면 나머지를 아무리 맞춰도 다른 앱처럼 보이므로, 이식에서 가장 큰 항목이다.
///
/// | 웹 CSS | 여기 |
/// | --- | --- |
/// | `body { font-family: var(--font-dunggeunmiso) }` | ``hak(_:_:)`` — 앱 전체 기본 |
/// | `.font-user-content` | ``tmoney(_:_:)`` — 사용자가 입력한 값(이름·플랜 제목) |
///
/// - Important: `Font.custom` 은 파일명이 아니라 **PostScript 이름**을 요구한다.
///   아래 상수는 TTF 의 name 테이블(nameID 6)에서 직접 읽은 값이다. 추측해서 고치지 말 것.
///   이름이 틀리면 크래시 없이 조용히 시스템 폰트로 대체되어, 화면이 웹과 달라진 이유를 찾기 어렵다.
enum WPFont {

    // 덩근미소는 400/700 두 가지만 존재한다.
    // 웹의 `font-semibold`(600) / `font-black`(900) 은 브라우저가 가장 가까운 굵기로 대체하므로
    // 여기서도 semibold 이상은 Bold 파일로 보낸다.
    private static let hakRegular = "HakgyoansimDunggeunmisoTTF-R"
    private static let hakBold = "HakgyoansimDunggeunmisoTTF-B"

    private static let tmoneyRegular = "TmoneyRoundWind-Regular"
    private static let tmoneyExtraBold = "TmoneyRoundWind-ExtraBold"

    /// 앱 전체 기본 글꼴 (덩근미소).
    static func hak(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.custom(isHeavy(weight) ? hakBold : hakRegular, fixedSize: size)
    }

    /// 사용자 입력 값에 쓰는 글꼴 (Tmoney RoundWind).
    static func tmoney(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.custom(isHeavy(weight) ? tmoneyExtraBold : tmoneyRegular, fixedSize: size)
    }

    private static func isHeavy(_ weight: Font.Weight) -> Bool {
        switch weight {
        case .semibold, .bold, .heavy, .black: return true
        default: return false
        }
    }

    /// 웹의 `tracking-tight` (= -0.025em). 크기에 비례하므로 폰트 크기를 받는다.
    static func trackingTight(_ size: CGFloat) -> CGFloat { -0.025 * size }
}

extension View {
    /// `.font(WPFont.hak(...))` + 자간을 한 번에.
    func wpTracking(_ size: CGFloat) -> some View {
        tracking(WPFont.trackingTight(size))
    }
}
