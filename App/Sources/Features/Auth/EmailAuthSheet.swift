import SwiftUI
import WPDomain
import WPModels
import WPNetworking

struct EmailAuthSheet: View {
    enum Step { case email, password, social, code, signup, reset, resetDone }
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    /// 같은 이메일의 소셜 계정 버튼 — 시트를 닫은 뒤 로그인 화면이 그 로그인을 시작합니다(Android `onSocial`).
    var onSocial: ((String) -> Void)? = nil
    @State private var step: Step = .email
    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var social: String?
    @State private var busy = false
    @State private var error: String?
    @State private var resendAt = Date.distantPast
    @State private var showPassword = false
    @State private var contentHeight: CGFloat = 240
    @FocusState private var focus: Field?
    enum Field { case email, password, code }

    // Android `EmailAuthSheet.kt` 의 TITLE · SUBMIT 와 한 글자도 다르지 않게
    private var title: String {
        switch step {
        case .email: "이메일로 시작하기"
        case .password: "비밀번호를 입력해 주세요"
        case .social: "이미 쓰던 계정이 있어요"
        case .code: "메일로 받은 6자리를 입력해 주세요"
        case .signup: "비밀번호를 정해 주세요"
        case .reset: "새 비밀번호를 정해 주세요"
        case .resetDone: "비밀번호를 바꿨어요"
        }
    }
    var body: some View {
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            HStack {
                if step != .email && step != .resetDone {
                    headerIcon(.back, label: "뒤로") { back() }
                } else {
                    Color.clear.frame(width: 40, height: 40)
                }
                Spacer()
                headerIcon(.close, label: "닫기", id: "email.close") { dismiss() }
            }.padding(.top, 4)
            Text(title).font(WPFont.hak(22, .black)).tracking(-0.66).lineSpacing(6)
                .foregroundStyle(WPColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier("email.title")
            if step != .email && step != .resetDone {
                Text(email).font(WPFont.hak(14)).foregroundStyle(WPColor.gray500).lineLimit(1).padding(.top, 6)
            }
            Color.clear.frame(height: 16)
            stepContent
            Color.clear.frame(height: 20)
            if let error {
                Text(error).wpTypography(13, lineHeight: 19).foregroundStyle(WPColor.danger)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("email.error")
                    .padding(.bottom, 10)
            }
            actions
          }
          .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 24)
          .frame(maxWidth: .infinity, alignment: .leading)
          // 빈 곳을 누르면 키보드가 내려갑니다(Android `clearFocusOnTap`). 칸·버튼은 자기 누름을 먼저 받습니다.
          .contentShape(Rectangle()).onTapGesture { focus = nil }
          .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = ceil($0) }
        }
        .scrollBounceBehavior(.basedOnSize).scrollDismissesKeyboard(.interactively)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(.white)
        .presentationBackground(.white).presentationCornerRadius(28)
        .presentationDetents([.height(contentHeight)])
        .presentationContentInteraction(.scrolls)
        .preferredColorScheme(.light).interactiveDismissDisabled(busy)
        // 인증 코드(숫자 키패드)에는 리턴 키가 없다 — 그 칸에 있을 때만 키보드 위 `완료`
        .wpKeyboardDone(focus == .code)
        // 키보드는 칸을 직접 눌렀을 때만 — 단계가 바뀌면 내립니다(Android `DismissKeyboardOn(step)`)
        .onChange(of: step) { _, _ in focus = nil; showPassword = false }
        .sensoryFeedback(.error, trigger: error) { _, new in new != nil }
    }

    @ViewBuilder private var stepContent: some View {
        switch step {
        case .email:
            lead("가입했던 이메일이면 비밀번호를, 처음이면 인증 코드를 보내 드려요.")
            TextField("", text: $email, prompt: placeholder("이메일 주소"))
                .keyboardType(.emailAddress).textContentType(.emailAddress)
                .textInputAutocapitalization(.never).autocorrectionDisabled().focused($focus, equals: .email)
                .modifier(AuthField()).accessibilityIdentifier("email.address")
                .submitLabel(.done).onSubmit { submit() }.disabled(busy)
        case .password:
            passwordField("비밀번호")
        case .code, .reset:
            lead("메일이 안 보이면 스팸함도 확인해 주세요. 5분 안에 입력해야 해요.")
            TextField("", text: $code, prompt: placeholder("6자리 숫자"))
                .keyboardType(.numberPad).textContentType(.oneTimeCode)
                .font(WPFont.hak(20, .bold)).tracking(code.isEmpty ? 0 : 6).multilineTextAlignment(.center)
                .focused($focus, equals: .code).modifier(AuthField(font: nil)).accessibilityIdentifier("email.code")
                .disabled(busy)
                .onChange(of: code) { _, value in
                    let sanitized = EmailAuthRules.sanitizeCode(value)
                    if sanitized != code { code = sanitized; return }
                    // 가입 코드는 6자리가 차면 누르지 않아도 확인합니다. 재설정은 새 비밀번호도 받아야 해서 기다립니다.
                    if step == .code && EmailAuthRules.validCode(code) && !busy { run(fallback: "인증 코드가 일치하지 않아요.") { try await verify() } }
                }
            resendLine
            if step == .reset {
                Color.clear.frame(height: 12)
                passwordField("새 비밀번호 (\(EmailAuthRules.passwordMin)자 이상)")
                hint("바꾸면 다른 기기의 로그인이 모두 해제돼요.")
            }
        case .signup:
            passwordField("\(EmailAuthRules.passwordMin)자 이상")
            hint("다음 로그인부터 이 이메일과 비밀번호로 들어와요.")
        case .social:
            socialLead
        case .resetDone:
            lead("새 비밀번호로 로그인해 주세요. 다른 기기에 남아 있던 로그인은 모두 해제됐어요.")
        }
    }

    @ViewBuilder private var actions: some View {
        switch step {
        case .social:
            switch social {
            case "kakao":
                filledButton("카카오로 로그인", background: WPColor.kakao, text: WPColor.kakaoText) { openSocial("kakao") }
            case "google":
                filledButton("Google로 로그인", background: .white, text: Color(hex: 0x1F1F1F), bordered: true) { openSocial("google") }
            default: EmptyView()
            }
            textLink(busy ? "메일 보내는 중..." : "그래도 이메일로 따로 가입할게요") {
                run(fallback: "인증 메일을 보내지 못했어요.") { try await sendCode(next: .code) }
            }
        case .resetDone:
            filledButton("로그인하기", background: WPColor.primary, text: .white) { step = .password; error = nil }
                .accessibilityIdentifier("email.submit")
        default:
            filledButton(busy ? "확인하는 중..." : submitTitle, background: WPColor.primary, text: .white, loading: busy) { submit() }
                .accessibilityIdentifier("email.submit")
            if step == .password {
                textLink("비밀번호를 잊으셨나요?") { run(fallback: "인증 메일을 보내지 못했어요.") { try await sendCode(next: .reset) } }
            }
            if step == .email { textLink("다른 방법으로 시작할게요") { dismiss() } }
        }
    }

    private var submitTitle: String {
        switch step {
        case .email: "계속하기"
        case .password: "로그인"
        case .code: "확인"
        case .signup: "가입하고 시작하기"
        case .reset: "비밀번호 바꾸기"
        case .social, .resetDone: ""
        }
    }

    /// 같은 이메일을 소셜 계정이 쓰고 있다 — **"새 계정이 생긴다" 를 가입 전에** 말합니다.
    private var socialLead: some View {
        let label = EmailAuthRules.socialLabel(social) ?? "소셜"
        var text = AttributedString("이 이메일은 ")
        var strong = AttributedString(label); strong.font = WPFont.hak(14.5, .bold); strong.foregroundColor = WPColor.textPrimary
        text += strong
        text += AttributedString("로 가입돼 있어요. 이메일로 새로 가입하면 ")
        var strong2 = AttributedString("\(label) 계정의 플랜이 보이지 않는 새 계정"); strong2.font = WPFont.hak(14.5, .bold); strong2.foregroundColor = WPColor.textPrimary
        text += strong2
        text += AttributedString("이 생겨요.")
        return Text(text).font(WPFont.hak(14.5)).lineSpacing(7.5).foregroundStyle(WPColor.gray600)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var resendLine: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = max(0, Int(ceil(resendAt.timeIntervalSince(context.date))))
            HStack {
                Spacer()
                Button { run(fallback: "인증 메일을 보내지 못했어요.") { try await sendCode(next: nil) } } label: {
                    Text(left > 0 ? "다시 보내기 (\(left)초)" : "코드 다시 보내기").font(WPFont.hak(13.5))
                        .foregroundStyle(left > 0 || busy ? WPColor.gray400 : WPColor.gray500)
                        .padding(.horizontal, 4).padding(.vertical, 6)
                }.buttonStyle(.plain).disabled(busy || left > 0)
            }.padding(.top, 6)
        }
    }

    private func passwordField(_ prompt: String) -> some View {
        HStack(spacing: 0) {
            Group {
                if showPassword {
                    TextField("", text: $password, prompt: placeholder(prompt)).font(WPFont.hak(16))
                } else {
                    SecureField("", text: $password, prompt: placeholder(prompt)).font(WPFont.hak(16))
                }
            }
            // 새 비밀번호에 iOS 강력한 암호 덮개를 띄우지 않습니다 — Android 와 같은 칸
            .textContentType(step == .password ? .password : nil)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .foregroundStyle(WPColor.textPrimary)
            .focused($focus, equals: .password).accessibilityIdentifier("email.password")
            .submitLabel(.done).onSubmit { submit() }
            .onChange(of: password) { _, value in
                if value.utf16.count > EmailAuthRules.passwordMax { password = String(value.prefix(EmailAuthRules.passwordMax)) }
            }
            Button { showPassword.toggle() } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye").font(.system(size: 17))
                    .foregroundStyle(WPColor.gray400).frame(width: 40, height: 40)
            }.buttonStyle(.plain).accessibilityLabel(showPassword ? "비밀번호 가리기" : "비밀번호 보기")
        }
        .padding(.leading, 16).padding(.trailing, 4).frame(height: 52)
        .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle()).onTapGesture { focus = .password }
        .disabled(busy)
    }

    private func placeholder(_ text: String) -> Text {
        Text(text).font(WPFont.hak(16)).foregroundColor(WPColor.gray400)
    }
    private func lead(_ text: String) -> some View {
        Text(text.wpKeepAll).font(WPFont.hak(14.5)).lineSpacing(7.5).foregroundStyle(WPColor.gray600)
            .fixedSize(horizontal: false, vertical: true).padding(.bottom, 14)
            .accessibilityLabel(text)
    }
    private func hint(_ text: String) -> some View {
        Text(text.wpKeepAll).font(WPFont.hak(12.5)).foregroundStyle(WPColor.gray400)
            .fixedSize(horizontal: false, vertical: true).padding(.top, 8)
            .accessibilityLabel(text)
    }
    private func headerIcon(_ kind: WPMaterialIcon.Kind, label: String, id: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            WPMaterialIcon(kind: kind).fill(WPColor.gray500).frame(width: 24, height: 24).frame(width: 40, height: 40)
                .contentShape(Circle())
        }.buttonStyle(.plain).disabled(busy).accessibilityLabel(label).accessibilityIdentifier(id ?? label)
    }
    private func filledButton(_ label: String, background: Color, text: Color, bordered: Bool = false, loading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if loading { ProgressView().controlSize(.small).tint(text) }
                Text(label).font(WPFont.hak(16, .bold)).foregroundStyle(text)
            }
            .frame(maxWidth: .infinity).frame(height: 48)
            .background(background.opacity(busy && !loading ? 0.6 : 1), in: RoundedRectangle(cornerRadius: 12))
            .overlay { if bordered { RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xDADCE0), lineWidth: 1) } }
        }.buttonStyle(.plain).disabled(busy)
    }
    private func textLink(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(WPFont.hak(13.5)).foregroundStyle(WPColor.gray500)
                .padding(.horizontal, 8).padding(.vertical, 6)
        }.buttonStyle(.plain).disabled(busy).frame(maxWidth: .infinity).padding(.top, 10)
    }
    private func openSocial(_ platform: String) {
        dismiss()
        onSocial?(platform)
    }
    private func back() {
        guard !busy else { return }
        step = step == .reset ? .password : .email
        password = ""; code = ""; error = nil
    }
    private func run(fallback: String, _ action: @escaping () async throws -> Void) {
        guard !busy else { return }
        busy = true; error = nil
        Task { @MainActor in
            defer { busy = false }
            do { try await action() }
            catch let failure as LocalFailure { self.error = failure.message }
            catch { self.error = EmailAuthRules.errorText(error, fallback: fallback) }
        }
    }
    /// 화면에서 먼저 막는 오류 — 서버 문장·대체 문장으로 바꾸지 않습니다
    private struct LocalFailure: Error { let message: String }
    private func sendCode(next: Step?) async throws {
        try await env.api.sendIgnoringData(Endpoint.emailCode(email))
        resendAt = Date().addingTimeInterval(EmailAuthRules.resendCooldown)
        code = ""; password = ""
        if let next { step = next }
    }
    private func verify() async throws {
        guard EmailAuthRules.validCode(code) else { throw LocalFailure(message: "6자리 인증 코드를 입력해 주세요.") }
        try await env.api.sendIgnoringData(Endpoint.emailVerify(email, code: code))
        step = .signup; code = ""
    }
    private func submit() {
        switch step {
        case .email:
            let normalized = EmailAuthRules.normalize(email)
            guard EmailAuthRules.validEmail(normalized) else { error = "이메일 주소를 다시 확인해 주세요."; return }
            email = normalized
            run(fallback: "이메일 주소를 다시 확인해 주세요.") {
                let result: EmailCheckResult = try await env.api.send(Endpoint.emailCheck(email))
                if result.exists { step = .password }
                else if EmailAuthRules.socialLabel(result.socialPlatform) != nil { social = result.socialPlatform; step = .social }
                else {
                    do { try await sendCode(next: .code) }
                    catch { throw LocalFailure(message: EmailAuthRules.errorText(error, fallback: "인증 메일을 보내지 못했어요.")) }
                }
            }
        case .code:
            run(fallback: "인증 코드가 일치하지 않아요.") { try await verify() }
        case .password:
            run(fallback: "이메일 또는 비밀번호가 맞지 않아요.") { try await login(signup: false) }
        case .signup:
            guard EmailAuthRules.validPassword(password) else { error = passwordError; return }
            run(fallback: "가입하지 못했어요. 처음부터 다시 시도해 주세요.") { try await login(signup: true) }
        case .reset:
            guard EmailAuthRules.validCode(code) else { error = "6자리 인증 코드를 입력해 주세요."; return }
            guard EmailAuthRules.validPassword(password) else { error = passwordError; return }
            run(fallback: "인증 코드를 다시 확인해 주세요.") {
                try await env.api.sendIgnoringData(Endpoint.emailReset(email, code: code, password: password))
                step = .resetDone; password = ""; code = ""
            }
        case .social, .resetDone: break
        }
    }
    private func login(signup: Bool) async throws {
        let result: AuthTokenResult = try await env.api.send(Endpoint.emailLogin(email, password: password, signup: signup))
        guard let token = result.value, !token.isEmpty else { throw LocalFailure(message: "로그인하지 못했어요. 잠시 후 다시 시도해 주세요.") }
        await env.tokenStore.save(token)
        await env.refreshAuthState()
        dismiss()
    }
    /// 웹과 같은 문장("8자 이상으로"). 서버 상한(72자)을 넘긴 경우만 따로 말합니다
    private var passwordError: String {
        password.utf16.count < EmailAuthRules.passwordMin
            ? "비밀번호는 \(EmailAuthRules.passwordMin)자 이상으로 정해 주세요."
            : "비밀번호는 \(EmailAuthRules.passwordMax)자 이하로 정해 주세요."
    }
}
/// 회색 채움 칸 — 앱 입력 칸 언어(`WPColor.fill`, 테두리 없음)
private struct AuthField: ViewModifier {
    var font: Font? = WPFont.hak(16)
    func body(content: Content) -> some View {
        content.font(font).foregroundStyle(WPColor.textPrimary).padding(.horizontal, 16).frame(height: 52)
            .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 12))
    }
}
