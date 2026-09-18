import AuthenticationServices
import SwiftUI

/// 앱의 첫 문 — 웹 `app/components/LoginView.tsx` 의 **폰 레이아웃**(`md:` 앞의 값).
///
/// ```
/// bg-gradient-to-br from-[#ee2b8c] to-[#ff5c95]  · 화면 전체
/// min-h-[100dvh] flex-col justify-between · px-8 pt-20 pb-10
/// [흰 카드 rounded-[24px] p-3 → 로고 h-14 rounded-[14px]]  mb-8
/// "결혼 준비 / 같이 시작해요"   text-[32px] font-black leading-tight tracking-[-0.045em] white
/// "카카오로 시작하면 / …"       text-base font-bold leading-snug white/80   mt-3
/// ⋯
/// [카카오로 시작하기]            h-12 w-full rounded-xl text-[16px] font-bold
/// ```
///
/// - **분홍을 머리에만 두지 않고 화면 전체로 편다.** 로그인은 들어오는 문이라
///   앱에서 이 화면과 초대 수락 둘만 그렇다.
/// - **글은 왼쪽 정렬.** 가운데로 맞추면 두 줄 제목의 둘째 줄 시작점이 흔들린다.
///
/// ## 들어오는 길은 카카오 하나다
///
/// 예전에는 아래에 "로그인 없이 둘러보기" 가 붙어 온보딩으로 보냈다. 웹이 그
/// 입구를 없앴고 안드로이드도 따라갔다 — **다시 만들지 말 것.** 로그인 전에는
/// 온보딩에서 받은 답을 **저장할 곳이 없고**, 게스트로 만든 일정은 이 기기 밖으로
/// 나가지 못해 "앱을 지우면 사라지는 플랜" 이 된다.
///
/// ## 문구
///
/// 웹은 처음 온 사람을 마케팅 랜딩(`/`)이 받고 이 화면은 `/login` 이지만,
/// **앱은 이 한 화면이 둘을 겸한다**(랜딩은 앱에 옮기지 않는다). 그래서 웹의
/// 기본 문구를 쓴다 — 웹도 "다시 오셨네요" 가 처음 보는 사람에게 어긋나서
/// 지금의 문구로 고쳤다. 만료로 돌아온 사람에게 다른 말을 하는 `?expired=1`
/// 분기는 앱에 아직 없다.
struct LandingView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var isLoading = false
    @State private var errorMessage: String?
    @StateObject private var login = LoginCoordinator()
    #if DEBUG
    @State private var showDevLogin = false
    #endif

    var body: some View {
        ZStack {
            // 웹 `bg-gradient-to-br` — 왼쪽 위에서 오른쪽 아래로.
            LinearGradient(
                colors: [WPColor.budgetGradientStart, WPColor.budgetGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: 24)
                footer
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)   // px-8
            .padding(.top, 80)          // pt-20
            .padding(.bottom, 40)       // pb-10
        }
        // 분홍 면 위라 상태바 글자가 흰색이어야 한다.
        .preferredColorScheme(.dark)
        #if DEBUG
        .sheet(isPresented: $showDevLogin) {
            DevTokenLoginSheet().environmentObject(env)
        }
        #endif
    }

    // MARK: - 위

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            // rounded-[24px] bg-white p-3 shadow-lg shadow-black/10
            AppLogo(size: 56, corner: 14)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white)
                )
                .shadow(color: .black.opacity(0.1), radius: 12, y: 6)

            Spacer().frame(height: 32) // mb-8

            Text("결혼 준비\n같이 시작해요")
                .font(WPFont.hak(32, .black))
                .tracking(-0.045 * 32)   // tracking-[-0.045em]
                .lineSpacing(40 - 32)    // leading-tight (1.25)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: 12) // mt-3

            Text("카카오로 시작하면\n일정과 예산이 한곳에 모여요.")
                .font(WPFont.hak(16, .bold))
                .lineSpacing(22 - 16)    // leading-snug (1.375)
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 아래

    private var footer: some View {
        VStack(spacing: 8) {
            if let errorMessage {
                Button {
                    self.errorMessage = nil
                } label: {
                    Text(errorMessage)
                        .font(WPFont.hak(13))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Color.black.opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }

            KakaoStartButton(
                label: isLoading ? "확인 중..." : "카카오로 시작하기",
                enabled: !isLoading
            ) {
                Task { await signIn() }
            }

            // **Sign in with Apple 은 같은 위치·크기여야 한다**(심사 지침 4.8).
            // 카카오보다 작거나 아래로 밀어 두면 "동등하게 제공" 으로 안 본다.
            SignInWithAppleButton(.signIn) { request in
                // 이름은 애플이 **첫 로그인 때 한 번만** 준다. 그때 받아야 한다.
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task { await handleApple(result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .disabled(isLoading)
            .opacity(isLoading ? 0.7 : 1)
            .accessibilityIdentifier("auth.apple")

            #if DEBUG
            // 카카오 SDK 연동 전, 실기기에서 백엔드 붙은 화면을 보기 위한 통로.
            // 릴리스 빌드에는 포함되지 않는다.
            Button { showDevLogin = true } label: {
                Text("개발용 토큰으로 로그인")
                    .font(WPFont.hak(11, .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("landing.devLogin")
            #endif
        }
        .frame(maxWidth: .infinity)
    }

    private func signIn() async {
        // 데모 모드(CI 캡처)에서는 SDK 없이 바로 통과시킨다.
        if env.isDemo {
            env.isAuthenticated = true
            env.planComplete = true
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await login.service.signInWithKakao(env: env)
        } catch {
            show(error)
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) async {
        if env.isDemo {
            env.isAuthenticated = true
            env.planComplete = true
            return
        }
        isLoading = true
        defer { isLoading = false }

        switch result {
        case .failure(let error):
            // 사용자가 시트를 닫은 것은 오류가 아니다.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = "로그인하지 못했어요. 잠시 후 다시 시도해 주세요."
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential
            else {
                errorMessage = "로그인하지 못했어요. 잠시 후 다시 시도해 주세요."
                return
            }
            do {
                try await login.service.signInWithApple(credential: credential, env: env)
            } catch {
                show(error)
            }
        }
    }

    /// 사용자가 스스로 취소한 것은 띄우지 않는다.
    private func show(_ error: Error) {
        if let social = error as? SocialLoginError, social.isSilent { return }
        errorMessage = (error as? LocalizedError)?.errorDescription
            ?? "로그인하지 못했어요. 잠시 후 다시 시도해 주세요."
    }
}
