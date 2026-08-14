import SwiftUI

/// 웹 `AuthButtons` 의 카카오 버튼.
/// `rounded-full h-11 text-sm font-semibold bg-[#FEE500] text-[#191919] shadow-sm`
struct KakaoStartButton: View {
    var label: String = "카카오로 시작하기"
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(WPFont.hak(14, .semibold))
                .foregroundStyle(WPColor.kakaoText)
                .frame(maxWidth: 320)
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(WPColor.kakao.opacity(enabled ? 1 : 0.7), in: Capsule())
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .frame(maxWidth: 320)
    }
}

/// 웹 setting 플로우의 "다음" 버튼.
/// `w-full max-w-[320px] px-8 py-3 bg-[#FFAAB8] text-white text-lg font-semibold rounded-lg shadow-md`
/// disabled 는 `bg-stone-300`.
struct WPNextButton: View {
    var text: String
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(WPFont.hak(18, .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    enabled ? WPColor.accent : WPColor.stone300,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .frame(maxWidth: 320)
    }
}

/// 웹 `LandingHero`.
///
/// 제목·부제 **둘 다** `font-bold tracking-tight text-stone-900` 이다.
/// 부제를 흐린 회색으로 두면 웹과 달라진다.
struct LandingHero: View {
    var title: String
    var subtitle: String?
    var titleSize: CGFloat = 36
    var subtitleSize: CGFloat = 18
    /// 웹의 동명 prop. true 면 Tmoney, false 면 덩근미소.
    var useUserFont: Bool = true

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(font(titleSize, .bold))
                .tracking(WPFont.trackingTight(titleSize))
                .foregroundStyle(WPColor.stone900)
                .multilineTextAlignment(.center)

            if let subtitle, !subtitle.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(subtitle)
                    .font(font(subtitleSize, .bold))
                    .tracking(WPFont.trackingTight(subtitleSize))
                    .foregroundStyle(WPColor.stone900)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func font(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        useUserFont ? WPFont.tmoney(size, weight) : WPFont.hak(size, weight)
    }
}

/// 웹: 솔리드 핑크 알약 + `0 2px 8px rgba(238,43,140,0.35)` 그림자
struct DDayBadge: View {
    var label: String

    var body: some View {
        Text(label)
            .font(WPFont.hak(14, .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(WPColor.primary, in: Capsule())
            .shadow(color: WPColor.primary.opacity(0.35), radius: 4, y: 2)
    }
}

/// 이름 첫 글자 아바타. 웹 `AVATAR_GRADIENTS`
struct MemberAvatar: View {
    var name: String
    var index: Int
    var size: CGFloat = 40

    var body: some View {
        let pair = WPColor.avatarGradients[index % WPColor.avatarGradients.count]
        let initial = name.trimmingCharacters(in: .whitespaces).prefix(1).uppercased()

        return Circle()
            .fill(
                LinearGradient(
                    colors: [pair.0, pair.1],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(initial.isEmpty ? "?" : initial)
                    .font(WPFont.hak(size * 0.35, .black))
                    .foregroundStyle(.white)
            )
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .frame(width: size, height: size)
    }
}

/// 웹 약관 동의의 원형 체크
struct CircleCheck: View {
    var checked: Bool
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            Circle().fill(checked ? WPColor.accent : Color.white)
            Circle().stroke(checked ? WPColor.accent : WPColor.stone300, lineWidth: 1)
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(checked ? .white : WPColor.stone300)
        }
        .frame(width: size, height: size)
    }
}

/// 에러/안내 배너 (웹에는 모달로 있던 것을 인라인으로 축약)
struct InfoBanner: View {
    var message: String
    var isError: Bool = true
    var actionLabel: String?
    var onAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Text(message)
                .font(WPFont.hak(13))
                .foregroundStyle(isError ? WPColor.danger : WPColor.stone500)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let actionLabel, let onAction {
                Button(action: onAction) {
                    Text(actionLabel)
                        .font(WPFont.hak(13, .semibold))
                        .foregroundStyle(WPColor.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            isError ? WPColor.dangerBg : WPColor.stone100,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}

/// 웹 `ApiLoadingOverlay`
struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            ProgressView()
                .controlSize(.large)
                .tint(WPColor.primary)
        }
        // 아래로 터치가 새지 않도록 흡수
        .contentShape(Rectangle())
        .onTapGesture {}
    }
}

/// 웹 로고 이미지. 에셋 카탈로그 없이 번들의 loose PNG 를 읽는다.
struct AppLogo: View {
    var size: CGFloat = 64

    var body: some View {
        Group {
            if let image = UIImage(named: "app_logo") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                // 리소스 누락 시에도 레이아웃이 무너지지 않게 자리만 지킨다.
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(WPColor.accent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
