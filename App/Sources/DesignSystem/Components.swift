import SwiftUI

/// 웹 `AuthButtons` 의 카카오 버튼.
/// `rounded-full h-11 text-sm font-semibold bg-[#FEE500] text-[#191919] shadow-sm`
/// 웹 `AuthButtons` 의 **`onBrand`** 변형 —
/// `w-full h-12 rounded-xl text-[16px] font-bold bg-[#FEE500] text-[#191919]`.
///
/// 분홍 면 위에 놓이는 화면(로그인 문 · 초대 수락)이 쓰는 모양이다.
/// 웹의 `default` 변형(흰 배경 위의 `h-11 rounded-full`)은 마케팅 랜딩 자리인데
/// **그 랜딩은 앱에 옮기지 않으므로** 여기에는 없다.
struct KakaoStartButton: View {
    var label: String = "카카오로 시작하기"
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(WPFont.hak(16, .bold))
                .foregroundStyle(WPColor.kakaoText)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    WPColor.kakao,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.7)
        .accessibilityIdentifier("auth.kakao")
    }
}

/// 온보딩 "다음" 버튼 — 안드로이드 `WpPrimaryButton`(시안 C안 10).
/// `w-full max-w-[340px] rounded-xl bg-[#ee2b8c] py-4 text-[16px] font-bold`,
/// 잠김은 `bg-[#e8eaed] text-[#b0b4bb]`. 예전 `#FFAAB8` + 그림자는 안드로이드와 달랐다.
/// 높이 56 = 위아래 16 + 16pt 글자의 줄 높이 24(Compose 기본 1.5).
struct WPNextButton: View {
    var text: String
    var enabled: Bool = true
    /// UI 테스트용 식별자. 바깥에서 `.accessibilityIdentifier` 를 걸면 감싼 뷰에 붙어
    /// `app.buttons[...]` 로 잡히지 않으므로, Button 자체에 직접 붙인다.
    var identifier: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(WPFont.hak(16, .bold))
                .foregroundStyle(enabled ? Color.white : WPColor.buttonDisabledText)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    enabled ? WPColor.primary : WPColor.buttonDisabled,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .contentShape(Rectangle())
        }
        // `.plain` 은 잠긴 버튼을 반투명으로 흐려 `#e8eaed` 가 `#f3f4f6` 으로 보였다 — 잠김 색은 위에서 직접 칠한다.
        .buttonStyle(UndimmedButtonStyle())
        .disabled(!enabled)
        .accessibilityIdentifier(identifier ?? "")
        .frame(maxWidth: 340)
    }
}

/// 잠겨도 흐리지 않는 버튼 모양 — 잠긴 모습을 화면이 직접 칠할 때 쓴다.
struct UndimmedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// 웹 `LandingHero` — 안드로이드 `Common.kt` 의 `LandingHero` 와 같은 치수.
///
/// 가운데 정렬(축하·환영·약관)은 제목·부제 **둘 다** `font-bold tracking-tight text-stone-900` 이다.
/// 줄 높이는 Compose 기본(1.5)을 따른다.
struct LandingHero: View {
    var title: String
    var subtitle: String?
    var titleSize: CGFloat = 36
    var subtitleSize: CGFloat = 18
    /// 웹의 동명 prop. true 면 Tmoney, false 면 덩근미소.
    var useUserFont: Bool = true
    /// 온보딩 질문 단계는 `true`(시안 C안 10) — 왼쪽 정렬, 폭 340, 제목 줄 높이 1.3,
    /// 부제는 보통 굵기 `#555d6d` · 줄 높이 1.7. 가운데 정렬이면 두 줄 제목의 둘째 줄이
    /// 매번 다른 자리에서 시작해 읽는 눈이 흔들린다(안드로이드 주석 그대로).
    var alignStart: Bool = false

    /// 안드로이드 `TrackingTight` = -0.4sp (크기와 무관한 고정값)
    private let tracking: CGFloat = -0.4

    var body: some View {
        VStack(alignment: alignStart ? .leading : .center, spacing: 8) {
            line(title, size: titleSize, bold: true, color: WPColor.stone900,
                 lineHeight: alignStart ? titleSize * 1.3 : titleSize * 1.5)

            if let subtitle, !subtitle.trimmingCharacters(in: .whitespaces).isEmpty {
                line(subtitle, size: subtitleSize, bold: !alignStart,
                     color: alignStart ? WPColor.fgMuted : WPColor.stone900,
                     lineHeight: alignStart ? subtitleSize * 1.7 : subtitleSize * 1.5)
            }
        }
        .frame(maxWidth: alignStart ? 340 : .infinity, alignment: alignStart ? .leading : .center)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func line(_ text: String, size: CGFloat, bold: Bool, color: Color, lineHeight: CGFloat) -> some View {
        if useUserFont {
            // 안드로이드 Tmoney 는 Regular 파일 하나에 굵기를 합성한다 — ExtraBold 파일로 바꾸면 모양이 달라진다.
            WPTmoneyText(text: text, size: size, bold: bold, color: UIColor(color), lineHeight: lineHeight, tracking: tracking)
                .fixedSize()
        } else {
            Text(text)
                .wpTypography(size, bold ? .bold : .regular, lineHeight: lineHeight)
                .tracking(tracking)
                .foregroundStyle(color)
                .multilineTextAlignment(alignStart ? .leading : .center)
        }
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
            Circle().strokeBorder(checked ? WPColor.accent : WPColor.stone300, lineWidth: 1)
            // 안드로이드 `Icons.Filled.Check`(지름의 0.6) — SF `checkmark` 는 획이 달라 원본 경로로 그린다.
            WPMaterialPathIcon(paths: WPIconPaths.check, size: size * 0.6, color: checked ? .white : WPColor.stone300)
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
    /// 웹 로고 이미지의 `rounded-[…]`. 로그인 문은 14, 나머지는 16.
    var corner: CGFloat = 16

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
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}
