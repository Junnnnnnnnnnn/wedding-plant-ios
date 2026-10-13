import SwiftUI
import WPDomain
import WPModels
import WPNetworking

struct EmailAuthSheet: View {
    enum Step { case email, password, social, code, signup, reset, resetDone }
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .email
    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var social: String?
    @State private var busy = false
    @State private var error: String?
    @State private var resendAt = Date.distantPast
    @FocusState private var focus: Field?
    enum Field { case email, password, code }

    private var title: String {
        switch step {
        case .email: "이메일로 시작하기"
        case .password: "비밀번호를 입력해 주세요"
        case .social: "이 이메일로 시작한 적 있어요"
        case .code: "이메일을 확인해 주세요"
        case .signup: "비밀번호를 정해 주세요"
        case .reset: "비밀번호 다시 정하기"
        case .resetDone: "비밀번호를 바꿨어요"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if step != .email && step != .resetDone {
                    Button { back() } label: { Image(systemName: "chevron.left").frame(width: 32, height: 32) }
                        .accessibilityLabel("뒤로")
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 32, height: 32) }.accessibilityLabel("닫기")
            }
            Text(title).font(WPFont.hak(22, .bold))
            if step != .email { Text(email).font(WPFont.hak(14)).foregroundStyle(WPColor.gray500) }
            switch step {
            case .email:
                TextField("이메일 주소", text: $email).keyboardType(.emailAddress).textContentType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().focused($focus, equals: .email)
                    .modifier(AuthField()).accessibilityIdentifier("email.address")
            case .password, .signup:
                if step == .signup { Text("8자 이상으로 정해 주세요.").font(WPFont.hak(14)) }
                passwordField
            case .social:
                Text("\(EmailAuthRules.socialLabel(social) ?? "소셜 로그인")로 시작한 이메일이에요. 같은 방법으로 로그인하거나 이메일로 새로 시작할 수 있어요.")
                    .font(WPFont.hak(14))
            case .code, .reset:
                Text("메일로 보낸 6자리 인증 코드를 입력해 주세요.").font(WPFont.hak(14))
                TextField("6자리 인증 코드", text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode)
                    .focused($focus, equals: .code).modifier(AuthField()).accessibilityIdentifier("email.code")
                    .onChange(of: code) { _, value in
                        let sanitized = EmailAuthRules.sanitizeCode(value)
                        if sanitized != code { code = sanitized; return }
                        if step == .code && EmailAuthRules.validCode(code) && !busy { run { try await verify() } }
                    }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, Int(ceil(resendAt.timeIntervalSince(context.date))))
                    Button(remaining > 0 ? "다시 보내기 (\(remaining)초)" : "인증 코드 다시 보내기") { run { try await sendCode(next: nil) } }
                        .disabled(busy || remaining > 0).font(WPFont.hak(13))
                }
                if step == .reset { passwordField }
            case .resetDone:
                Text("새 비밀번호로 로그인해 주세요.").font(WPFont.hak(14))
            }
            if let error { Text(error).font(WPFont.hak(13)).foregroundStyle(.red).accessibilityIdentifier("email.error") }
            Button { submit() } label: {
                HStack {
                    if busy { ProgressView().tint(.white) }
                    Text(buttonTitle).font(WPFont.hak(16, .bold))
                }.frame(maxWidth: .infinity).frame(height: 48)
                    .foregroundStyle(.white).background(WPColor.primary, in: RoundedRectangle(cornerRadius: 14))
            }.disabled(busy).accessibilityIdentifier("email.submit")
            if step == .password {
                Button("비밀번호를 잊으셨나요?") { run { try await sendCode(next: .reset) } }
                    .font(WPFont.hak(13)).frame(maxWidth: .infinity).disabled(busy)
            }
        }
        .foregroundStyle(WPColor.textPrimary).padding(24).background(.white)
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        .preferredColorScheme(.light).interactiveDismissDisabled(busy)
        .onAppear { focus = .email }
    }
    private var passwordField: some View {
        SecureField(step == .password ? "비밀번호" : "비밀번호 (8자 이상)", text: $password)
            .textContentType(step == .password ? .password : .newPassword)
            .focused($focus, equals: .password).modifier(AuthField()).accessibilityIdentifier("email.password")
    }
    private var buttonTitle: String {
        switch step {
        case .email: "계속하기"
        case .password: "로그인"
        case .social: "이메일로 새로 시작하기"
        case .code: "확인"
        case .signup: "시작하기"
        case .reset: "비밀번호 바꾸기"
        case .resetDone: "로그인하기"
        }
    }
    private func back() {
        guard !busy else { return }
        step = step == .reset ? .password : .email
        password = ""; code = ""; error = nil
        focus = step == .email ? .email : .password
    }
    private func run(_ action: @escaping () async throws -> Void) {
        guard !busy else { return }
        busy = true; error = nil
        Task { @MainActor in
            defer { busy = false }
            do { try await action() }
            catch { self.error = error.localizedDescription }
        }
    }
    private func sendCode(next: Step?) async throws {
        try await env.api.sendIgnoringData(Endpoint.emailCode(email))
        resendAt = Date().addingTimeInterval(EmailAuthRules.resendCooldown)
        code = ""; password = ""
        if let next { step = next }
        focus = .code
    }
    private func verify() async throws {
        guard EmailAuthRules.validCode(code) else { throw APIError.backend(message: "6자리 인증 코드를 입력해 주세요.") }
        try await env.api.sendIgnoringData(Endpoint.emailVerify(email, code: code))
        step = .signup; code = ""; focus = .password
    }
    private func submit() {
        run {
            switch step {
            case .email:
                email = EmailAuthRules.normalize(email)
                guard EmailAuthRules.validEmail(email) else { throw APIError.backend(message: "이메일 주소를 다시 확인해 주세요.") }
                let result: EmailCheckResult = try await env.api.send(Endpoint.emailCheck(email))
                if result.exists { step = .password; focus = .password }
                else if EmailAuthRules.socialLabel(result.socialPlatform) != nil { social = result.socialPlatform; step = .social }
                else { try await sendCode(next: .code) }
            case .social: try await sendCode(next: .code)
            case .code: try await verify()
            case .password, .signup:
                if step == .signup && !EmailAuthRules.validPassword(password) {
                    throw APIError.backend(message: "비밀번호는 8자 이상 72자 이하로 정해 주세요.")
                }
                let result: AuthTokenResult = try await env.api.send(Endpoint.emailLogin(email, password: password, signup: step == .signup))
                guard let token = result.value else { throw APIError.emptyData }
                await env.tokenStore.save(token)
                await env.refreshAuthState()
                dismiss()
            case .reset:
                guard EmailAuthRules.validCode(code), EmailAuthRules.validPassword(password) else {
                    throw APIError.backend(message: "6자리 코드와 8자 이상 72자 이하 비밀번호를 입력해 주세요.")
                }
                try await env.api.sendIgnoringData(Endpoint.emailReset(email, code: code, password: password))
                step = .resetDone; password = ""; code = ""; focus = nil
            case .resetDone: step = .password; focus = .password
            }
        }
    }
}
private struct AuthField: ViewModifier {
    func body(content: Content) -> some View {
        content.font(WPFont.hak(16)).padding(.horizontal, 16).frame(height: 52)
            .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 12))
    }
}
