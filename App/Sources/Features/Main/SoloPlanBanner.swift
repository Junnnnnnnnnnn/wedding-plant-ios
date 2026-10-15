import SwiftUI

/// "아직 혼자 준비 중이에요" 띠. 웹 `app/components/SoloPlanBanner.tsx` 이식 —
/// 안드로이드 `ui/components/SoloPlanBanner.kt` 와 같은 모양(점선 `+` 원 · 두 줄 · 분홍 `부르기`).
///
/// 온보딩의 `함께할 사람` 단계를 건너뛴 사실이 홈에 남는 자리다.
/// **온보딩은 한 번뿐이라 거기서 안 부르면 다시 물을 기회가 없었고**,
/// 예전 진입점(점선 `＋` 원)은 멤버가 나 혼자일 때만 떠서 조언자 한 명만
/// 들어와도 사라졌다.
///
/// 초대 단계는 약관에서 저장이 끝난 뒤라 `/setting` 으로 다시 들어와도 홈으로
/// 보내진다(질문을 되풀이하지 않는 게 맞다). **그래서 이 띠가 유일한
/// 재진입점이다** — 없애면 온보딩에서 건너뛴 사람은 초대할 방법이 사라진다.
///
/// **닫기 버튼을 두지 않는다.** 배우자가 들어오면 저절로 사라지는 띠라 "끄는"
/// 동작의 뜻이 애매하고, 끄고 나면 다시 부를 자리가 없어진다.
struct SoloPlanBanner: View {
    var onInvite: () -> Void

    private let note = "신랑·신부를 부르면 예산과 일정을 같이 고칠 수 있어요"

    var body: some View {
        Button(action: onInvite) {
            HStack(spacing: 12) {
                // 웹: 2px **점선** 원(border-dashed #ee2b8c55) — 빈자리에 '추가' 를 뜻한다
                ZStack {
                    Circle()
                        .inset(by: 1)
                        .stroke(WPColor.primary.opacity(0.33), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    WPLucideIcon(paths: ["M5 12h14", "M12 5v14"], size: 16, color: WPColor.primary)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text("아직 혼자 준비 중이에요")
                        .wpTypography(13.5, .bold)
                        .foregroundStyle(WPColor.textPrimary)
                    Text(note.wpKeepAll)
                        .wpTypography(11.5, lineHeight: 19)
                        .foregroundStyle(Color(hex: 0x7A6C74))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(note)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("부르기")
                    .wpTypography(13, .bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    // 웹 shadow-[0_8px_20px_-8px_rgba(238,43,140,0.75)] — 분홍으로 번지는 그림자
                    .shadow(color: WPColor.primary.opacity(0.45), radius: 6, y: 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(hex: 0xFFF6FA), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(WPColor.primary.opacity(0.13), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("main.soloBanner")
    }
}
