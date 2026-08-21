import SwiftUI

/// 웹 `app/page.tsx` 이식.
///
/// ```
/// px-8 py-20 · grid-bg · 장식 블러 2개
/// [로고 96 흰 카드] mb-6
/// "웨딩 플랜트"                        text-5xl font-black text-[#1b0d14] tracking-tight
/// "우리만의 특별한 웨딩 플랜,"  gray-400
/// "지금 바로 시작하세요."        #ee2b8c   — 둘 다 text-lg font-bold
/// mt-24
/// [카카오로 시작하기]                   rounded-full h-11
/// "로그인 없이 둘러보기"                text-xs stone-600 underline
/// ```
struct LandingView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var showSetting = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    #if DEBUG
    @State private var showDevLogin = false
    #endif

    var body: some View {
        ZStack {
            WPScreenBackground(showsDecor: true)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // 로고 — 흰 카드 안에 앱 아이콘 (웹과 동일한 이미지 파일)
                AppLogo(size: 64)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(WPColor.cardBorder, lineWidth: 1)
                    )
                    .shadow(color: WPColor.primary.opacity(0.18), radius: 20, y: 8)

                Spacer().frame(height: 40) // mb-6(24) + space-y-4(16)

                Text("웨딩 플랜트")
                    .font(WPFont.hak(48, .black))
                    .tracking(WPFont.trackingTight(48))
                    .foregroundStyle(WPColor.textPrimary)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 16)

                (
                    Text("우리만의 특별한 웨딩 플랜,\n").foregroundStyle(WPColor.gray400)
                    + Text("지금 바로 시작하세요.").foregroundStyle(WPColor.primary)
                )
                .font(WPFont.hak(18, .bold))
                .lineSpacing(6) // leading-snug (18 → 24)
                .multilineTextAlignment(.center)

                Spacer().frame(height: 96) // mt-24

                if let errorMessage {
                    InfoBanner(
                        message: errorMessage,
                        actionLabel: "닫기",
                        onAction: { self.errorMessage = nil }
                    )
                    Spacer().frame(height: 16)
                }

                KakaoStartButton(
                    label: isLoading ? "확인 중..." : "카카오로 시작하기",
                    enabled: !isLoading
                ) {
                    Task { await signIn() }
                }

                Spacer().frame(height: 20) // gap-4 + mt-1

                Button {
                    showSetting = true
                } label: {
                    Text("로그인 없이 둘러보기")
                        .font(WPFont.hak(12, .medium))
                        .foregroundStyle(WPColor.stone600)
                        .underline()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("landing.guest")

                #if DEBUG
                // 카카오 SDK 연동 전, 실기기에서 백엔드 붙은 화면을 보기 위한 통로.
                // 릴리스 빌드에는 포함되지 않는다.
                Spacer().frame(height: 8)
                Button { showDevLogin = true } label: {
                    Text("개발용 토큰으로 로그인")
                        .font(WPFont.hak(11, .medium))
                        .foregroundStyle(WPColor.stone400)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("landing.devLogin")
                #endif

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 80)
        }
        #if DEBUG
        .sheet(isPresented: $showDevLogin) {
            DevTokenLoginSheet().environmentObject(env)
        }
        #endif
        .fullScreenCover(isPresented: $showSetting) {
            SettingView {
                showSetting = false
                env.isAuthenticated = true
            }
            .environmentObject(env)
        }
    }

    private func signIn() async {
        // 데모 모드에서는 카카오 SDK 없이 바로 통과시킨다.
        // 실제 구현은 Kakao SDK 로그인 → POST /plan/auth/kakao/login → JWT 저장 순서.
        if env.isDemo {
            env.isAuthenticated = true
            return
        }
        isLoading = true
        defer { isLoading = false }
        await env.refreshAuthState()
        if !env.isAuthenticated {
            errorMessage = "카카오 로그인이 아직 연결되지 않았어요."
        }
    }
}
