import SwiftUI

/// "아직 혼자 준비 중이에요" 띠. 웹 `app/components/SoloPlanBanner.tsx` 이식.
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

    var body: some View {
        Button(action: onInvite) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(WPColor.primary.opacity(0.33), lineWidth: 2)
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(WPColor.primary)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("아직 혼자 준비 중이에요")
                        .font(WPFont.hak(14, .bold))
                        .foregroundStyle(WPColor.textPrimary)
                    Text("신랑·신부를 부르면 일정과 예산을 같이 고칠 수 있어요")
                        .font(WPFont.hak(12))
                        .foregroundStyle(WPColor.fgSubtle)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WPColor.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                Color(hex: 0xFFF7FA),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(WPColor.primary.opacity(0.13), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("main.soloBanner")
    }
}
