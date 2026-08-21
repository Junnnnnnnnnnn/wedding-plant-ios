#if DEBUG
import SwiftUI

/// **개발 빌드 전용** — 앱 JWT 를 직접 붙여 넣어 로그인 상태로 만든다.
///
/// 카카오 SDK 연동 전에 실기기에서 백엔드 붙은 화면(특히 채팅 실시간 수신)을 확인하려면
/// 유효한 토큰이 필요하다. 웹에 로그인한 뒤 브라우저에서 꺼내 온다:
///
/// ```js
/// localStorage.getItem("plan_auth_token")
/// ```
///
/// - Important: `#if DEBUG` 로 감싸 **릴리스 빌드에는 포함되지 않는다.**
///   토큰은 계정 전체 권한이므로 남에게 보이는 화면에서 쓰지 말 것.
struct DevTokenLoginSheet: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var token = ""
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("개발용 토큰 로그인")
                .font(WPFont.hak(18, .bold))
                .foregroundStyle(WPColor.textPrimary)

            Spacer().frame(height: 8)

            Text("웹에 로그인한 뒤 콘솔에서\nlocalStorage.getItem(\"plan_auth_token\")\n값을 붙여 넣으세요.")
                .font(WPFont.hak(12))
                .lineSpacing(4)
                .foregroundStyle(WPColor.gray500)

            Spacer().frame(height: 16)

            TextEditor(text: $token)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(WPColor.textPrimary)
                .scrollContentBackground(.hidden)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .frame(height: 120)
                .padding(8)
                .background(WPColor.stone50, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier("dev.token.input")

            if let message {
                Spacer().frame(height: 8)
                Text(message)
                    .font(WPFont.hak(12, .bold))
                    .foregroundStyle(WPColor.primary)
            }

            Spacer().frame(height: 16)

            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Text("취소")
                        .font(WPFont.hak(15, .bold))
                        .foregroundStyle(WPColor.stone600)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(WPColor.stone100, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await apply() }
                } label: {
                    Text("로그인")
                        .font(WPFont.hak(15, .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("dev.token.apply")
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .presentationDetents([.height(400)])
        .presentationCornerRadius(32)
    }

    private func apply() async {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            message = "토큰을 붙여 넣어 주세요."
            return
        }
        // 점 두 개짜리 JWT 형태인지만 가볍게 본다. 서명 검증은 백엔드 몫이다.
        guard trimmed.split(separator: ".").count == 3 else {
            message = "JWT 형태가 아닙니다. 값 전체를 복사했는지 확인해 주세요."
            return
        }
        await env.tokenStore.save(trimmed)
        await env.refreshAuthState()
        dismiss()
    }
}
#endif
