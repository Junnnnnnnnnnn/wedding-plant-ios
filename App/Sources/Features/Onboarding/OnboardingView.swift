import SwiftUI

/// 웹의 `/` 진입 화면.
struct OnboardingView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var showSetting = false

    var body: some View {
        ZStack {
            WP.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "heart.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(WP.accent)
                    .padding(.bottom, 28)

                Text("웨딩플랜")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(WP.textPrimary)

                Text("결혼 준비, 하나씩 함께 채워가요")
                    .font(.system(size: 16))
                    .foregroundStyle(WP.textSecondary)
                    .padding(.top, 10)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        Task { await signIn() }
                    } label: {
                        Text("카카오로 시작하기")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(WP.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color(red: 0.99, green: 0.87, blue: 0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .accessibilityIdentifier("onboarding.kakao")

                    Button {
                        showSetting = true
                    } label: {
                        Text("로그인 없이 둘러보기")
                            .font(.system(size: 16))
                            .foregroundStyle(WP.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .accessibilityIdentifier("onboarding.guest")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showSetting) {
            SettingView(onComplete: {
                showSetting = false
                env.isAuthenticated = true
            })
            // 시트는 환경을 자동 상속하지만, 명시해 두면 SwiftUI 버전 차이에 영향받지 않는다.
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
        await env.refreshAuthState()
    }
}
