import SwiftUI

/// 색상·간격 토큰.
///
/// 에셋 카탈로그 없이 코드로만 정의한다 — CI 빌드에서 에셋 관련 실패 여지를 줄이기 위함.
enum WP {

    // MARK: - 색상

    static let background = Color(red: 0.98, green: 0.97, blue: 0.96)
    static let surface = Color.white
    static let accent = Color(red: 0.91, green: 0.45, blue: 0.52)
    static let accentSoft = Color(red: 0.99, green: 0.92, blue: 0.93)
    static let textPrimary = Color(red: 0.13, green: 0.12, blue: 0.12)
    static let textSecondary = Color(red: 0.48, green: 0.46, blue: 0.45)
    static let separator = Color(red: 0.91, green: 0.90, blue: 0.89)
    static let success = Color(red: 0.30, green: 0.66, blue: 0.48)
    static let warning = Color(red: 0.90, green: 0.55, blue: 0.20)

    /// 카테고리별 파스텔 배경색. 같은 이름이면 항상 같은 색이 나온다.
    /// (웹 `app/main/page.tsx:getCategoryColor` 와 같은 발상)
    static func categoryColor(_ name: String) -> Color {
        let palette: [Color] = [
            Color(red: 1.00, green: 0.89, blue: 0.91),
            Color(red: 0.91, green: 0.87, blue: 0.96),
            Color(red: 0.87, green: 0.93, blue: 0.98),
            Color(red: 0.88, green: 0.95, blue: 0.90),
            Color(red: 1.00, green: 0.95, blue: 0.85),
            Color(red: 0.95, green: 0.92, blue: 0.87),
        ]
        var hash = 5381
        for scalar in name.unicodeScalars {
            hash = (hash &* 33) &+ Int(scalar.value)
        }
        return palette[abs(hash) % palette.count]
    }

    // MARK: - 간격

    static let cardRadius: CGFloat = 16
    static let padding: CGFloat = 20
}

/// 카드 배경 스타일.
struct WPCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(WP.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WP.surface)
            .clipShape(RoundedRectangle(cornerRadius: WP.cardRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func wpCard() -> some View {
        modifier(WPCard())
    }
}

/// 금액(만원 단위)을 "1,200만원" 형태로 표시한다.
func wpManwon(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    let number = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    return "\(number)만원"
}
