import SwiftUI
import UIKit
import WPDomain
import WPUtils

/// 웹 `app/setting/page.tsx` 이식 — 안드로이드 `ui/setting/SettingScreen.kt` 와 같은 화면.
///
/// 축하 → 날짜 → 예산 → 이름 → 환영 → 약관 → 권한 → 함께할 사람.
/// 웹의 3D 출입증(Lanyard) 단계는 아직 없다 — @react-three 기반이라 별도 포팅 작업이다.
/// 문구("출입증을 발급해 드렸어요!")는 웹 그대로 유지했다.
///
/// 문구·치수·색은 **안드로이드와 한 글자도 다르지 않게** 둔다(사용자 요구 — 두 앱 동시 출시).
struct SettingView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore
    @StateObject private var model = SettingViewModel()
    @State private var openTerms: TermsDoc?
    /// 종이 가루가 터질 때 한 번 — 축하의 손맛(햅틱)
    @State private var celebrated = false

    var onComplete: () -> Void

    var body: some View {
        ZStack {
            // SEED 기준으로 표면은 민 바탕이다 — 점 패턴과 뿌연 원을 걷었다(안드로이드와 같음).
            // 배경 장식이 있으면 "한 번에 하나씩 묻는" 연출에서 질문이 화면의 주인이 아니게 된다.
            Color.white
                .ignoresSafeArea()
                .contentShape(Rectangle())
                // 빈 곳을 누르면 키보드가 내려간다(안드로이드 `clearFocusOnTap`)
                .onTapGesture { dismissKeyboard() }

            // 초대·인증 확인 중에는 온보딩이 목적지인지 아직 모른다 — 축하 화면을 먼저 그리지 않는다.
            if model.ready && !model.skipToMain {
                ZStack(alignment: .topLeading) {
                    Color.clear

                    stepView(model.step)
                        .id(model.step)
                        .transition(.opacity)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // 웹: 예산·이름·환영·약관 단계에만 뒤로가기. 축하·날짜에는 없음.
                    // **권한·초대 단계에도 달지 않는다** — 약관에서 저장이 이미 끝난 뒤라 되돌아갈 곳이 없다.
                    if !SettingViewModel.Step.noBack.contains(model.step) {
                        Button {
                            model.back()
                        } label: {
                            WPMaterialPathIcon(paths: WPIconPaths.arrowBack, size: 24, color: WPColor.stone600)
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        // 식별자는 Button 바로 위에 — 감싼(padding) 뷰에 걸면 app.buttons 로 안 잡힌다
                        .accessibilityLabel("뒤로 가기")
                        .accessibilityIdentifier("setting.back")
                        // 웹 `top-6 left-6` — 위의 단계 막대(top 16) 아래에 앉는다.
                        .padding(.leading, 16)
                        .padding(.top, 28)
                    }

                    StepProgress(step: model.step)

                    // 초대 단계는 버튼 위에 한 줄로 낸다 — 바닥 띠가 '나중에 할게요' 를 덮었다
                    if model.step != .invite, let message = model.errorMessage {
                        VStack {
                            Spacer()
                            InfoBanner(message: message, actionLabel: "닫기") {
                                model.errorMessage = nil
                            }
                            .padding(16)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.5), value: model.step)

                /*
                  웹 `{showFirst && !isFadingOut && <CelebrationEffects />}` — 축하 문구 3초 동안만, 글자 **위로**
                  떨어진다. 단계가 바뀌는 순간 걷는다. 상태바까지 덮도록 화면 전체에 둔다.
                */
                if model.step == .celebration {
                    CelebrationConfetti()
                        .ignoresSafeArea()
                }
            }

            if let doc = openTerms {
                TermsDocDialog(doc: doc) { openTerms = nil }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: openTerms)
        .sensoryFeedback(.success, trigger: celebrated) { _, now in now }
        .task {
            await model.prefill(env: env, guest: guest)
            if model.skipToMain {
                onComplete()
            }
        }
        // 웹과 동일하게 축하 문구를 3초 노출한 뒤 자동 전환
        .task(id: model.ready) {
            guard model.ready, !model.skipToMain, model.step == .celebration else { return }
            if !celebrated { celebrated = true }
            try? await Task.sleep(for: .seconds(3))
            model.advanceFromCelebration()
        }
        // 단계가 바뀌면 키보드를 내린다 — 예산을 적고 `다음` 을 누르면 이름 단계에서도 키보드가 남아 있었다
        .onChange(of: model.step) { _, _ in dismissKeyboard() }
    }

    @ViewBuilder
    private func stepView(_ step: SettingViewModel.Step) -> some View {
        switch step {
        case .celebration: CelebrationStep()
        case .date: DateStep(model: model)
        case .budget: BudgetStep(model: model)
        case .name: NameStep(model: model)
        case .welcome: WelcomeStep(model: model)
        case .terms: TermsStep(model: model, openTerms: $openTerms, onSubmit: submit)
        case .permissions: PermissionsStep { model.goTo(.invite) }
        case .invite: InviteStep(model: model, onDone: onComplete)
        }
    }

    private func submit() {
        Task {
            await model.submit(env: env, guest: guest, onDone: onComplete)
        }
    }
}

private func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

// MARK: - 단계 막대

/// 폰에는 남은 단계 표시가 없었다(웹은 넓은 화면에서 좌측 패널이 알려 준다).
/// 4pt 막대 하나면 몇 개나 더 묻는지 보인다 — **질문 단계에만** 낸다
/// (축하·환영은 연출이라 단계로 세지 않는다). 권한 단계도 묻는 단계라 센다.
private struct StepProgress: View {
    var step: SettingViewModel.Step
    private let total = 6

    private var index: Int {
        switch step {
        case .date: return 1
        case .budget: return 2
        case .name: return 3
        case .terms: return 4
        case .permissions: return 5
        case .invite: return 6
        case .celebration, .welcome: return 0
        }
    }

    var body: some View {
        if index > 0 {
            HStack(spacing: 12) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(WPColor.basement)
                        Capsule()
                            .fill(WPColor.primary)
                            .frame(width: geometry.size.width * CGFloat(index) / CGFloat(total))
                    }
                }
                .frame(height: 4)
                Text(verbatim: "\(index) / \(total)")
                    .wpTypography(11, .bold)
                    .foregroundStyle(WPColor.fgSubtle)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(total)단계 중 \(index)단계")
            .accessibilityIdentifier("setting.progress")
        }
    }
}

// MARK: - 단계

private struct CelebrationStep: View {
    var body: some View {
        // 웹: 기본 크기(text-4xl / text-lg), useUserFont false
        // 이모지는 웹 원문 그대로다. 임의로 빼면 문구가 달라진다.
        LandingHero(title: "결혼", subtitle: "🎉 축하드려요 🎉", useUserFont: false)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("setting.celebration")
    }
}

/// 웹 `flex flex-1 flex-col items-center pt-20 pb-12` + 하단 "다음"
private struct StepScaffold<Content: View>: View {
    var title: String
    var subtitle: String
    var buttonText: String = "다음"
    var buttonEnabled: Bool = true
    var onNext: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            LandingHero(
                title: title,
                subtitle: subtitle,
                titleSize: 28,
                subtitleSize: 14,
                useUserFont: false,
                alignStart: true
            )

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            WPNextButton(
                text: buttonText,
                enabled: buttonEnabled,
                identifier: "setting.next",
                action: onNext
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 80)
        .padding(.bottom, 48)
    }
}

private struct DateStep: View {
    @ObservedObject var model: SettingViewModel

    var body: some View {
        StepScaffold(
            title: "결혼 날짜가 언제인가요",
            subtitle: "예신, 예랑님. 가장 빛날 그날까지 함께해요.",
            onNext: { model.goTo(.budget) }
        ) {
            VStack(spacing: 12) {
                // 웹 d513e95 — 연도는 올해부터지만 올해의 **지난 날짜도 고를 수 있다**(오늘로 되돌리지 않음).
                // 이미 지난 결혼식을 적는 사람(이미 결혼한 부부의 정리용)을 막지 않는다.
                DateWheelPicker(
                    value: $model.date,
                    minDate: KstDate(year: KstDate.today().year, month: 1, day: 1)
                )
                .accessibilityIdentifier("setting.date")
                // 고른 값을 문장으로 한 번 더 낸다 — 숫자 세 칸만 보고 요일과 남은 날을 계산하게 두지 않는다.
                Text(verbatim: "\(model.date.year)년 \(model.date.month)월 \(model.date.day)일 "
                    + "\(model.date.weekdayShort)요일 · \(PlanRules.dDayLabel(weddingDate: model.date))")
                    .wpTypography(13)
                    .foregroundStyle(WPColor.fgSubtle)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

private struct BudgetStep: View {
    @ObservedObject var model: SettingViewModel

    var body: some View {
        StepScaffold(
            title: "예산도 살짝 알려주세요!",
            subtitle: "마음 편하시게 제가 꼼꼼히 챙겨드릴게요.",
            buttonEnabled: !model.budget.isEmpty,
            onNext: { model.goTo(.name) }
        ) {
            HStack(spacing: 8) {
                OnboardingField(
                    text: Binding(get: { model.budget }, set: { model.setBudget($0) }),
                    placeholder: "0",
                    width: 128, // w-32
                    numeric: true,
                    // 미리 채운 1000 은 **보기용 예시**라 칸을 누르면 통째로 고른다(웹 f6f0405). 안 그러면
                    // 가운데를 누르고 3500 을 쳤을 때 "10" + "3500" + "00" 이 저장됐다.
                    selectAllOnFocus: true,
                    identifier: "setting.budget"
                )

                Text("만원")
                    .wpTypography(18, .semibold)
                    .foregroundStyle(WPColor.stone600)
            }
        }
    }
}

private struct NameStep: View {
    @ObservedObject var model: SettingViewModel

    var body: some View {
        StepScaffold(
            title: "이름도 괜찮을까요?",
            subtitle: "닉네임도 괜찮아요!",
            buttonEnabled: !model.name.trimmingCharacters(in: .whitespaces).isEmpty,
            onNext: { model.goTo(.welcome) }
        ) {
            VStack(spacing: 8) {
                Text("최대 6 글자")
                    .wpTypography(14)
                    .foregroundStyle(WPColor.stone500)

                OnboardingField(
                    text: Binding(get: { model.name }, set: { model.setName($0) }),
                    placeholder: "이름 또는 닉네임",
                    width: 240,
                    identifier: "setting.name"
                )
            }
        }
    }
}

private struct WelcomeStep: View {
    @ObservedObject var model: SettingViewModel

    var body: some View {
        // 웹: useUserFont 기본값 true → Tmoney
        LandingHero(
            title: "\(model.name) 님 환영합니다",
            subtitle: "출입증을 발급해 드렸어요!",
            titleSize: 28,
            subtitleSize: 14
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("setting.welcome")
        .task {
            try? await Task.sleep(for: .seconds(2.5))
            if model.step == .welcome { model.goTo(.terms) }
        }
    }
}

private struct TermsStep: View {
    @ObservedObject var model: SettingViewModel
    @Binding var openTerms: TermsDoc?
    var onSubmit: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                LandingHero(
                    title: "자 이제 시작해볼까요?",
                    subtitle: "결혼식까지 든든한 플랜을 같이 짜보아요",
                    titleSize: 28,
                    subtitleSize: 14,
                    useUserFont: false
                )

                Spacer().frame(height: 40)

                VStack(spacing: 0) {
                    Button {
                        model.toggleAgreeAll()
                    } label: {
                        HStack(spacing: 8) {
                            CircleCheck(checked: model.allAgreed, size: 20)
                            Text("전체 동의합니다.")
                                .wpTypography(14, .semibold)
                                .foregroundStyle(WPColor.stone900)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("setting.agreeAll")

                    Spacer().frame(height: 12)
                    Rectangle()
                        .fill(WPColor.stone200)
                        .frame(height: 1)
                    Spacer().frame(height: 8)

                    ForEach(TermsDoc.allCases) { doc in
                        AgreementRow(
                            doc: doc,
                            checked: model.isAgreed(doc),
                            onToggle: { model.setAgreed(doc, !model.isAgreed(doc)) },
                            onView: { openTerms = doc }
                        )
                    }
                }
                .frame(maxWidth: 320)

                Spacer().frame(height: 32)

                WPNextButton(
                    // **`다음` 이다** — 저장이 끝나면 권한·초대 단계가 이어서 열린다.
                    // 마지막 `계획 짜러 가기` 는 초대 단계에 있다.
                    text: model.submitting ? "저장 중..." : "다음",
                    enabled: model.allRequiredAgreed && !model.submitting,
                    identifier: "setting.submit",
                    action: onSubmit
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 80)
            .padding(.bottom, 48)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct AgreementRow: View {
    var doc: TermsDoc
    var checked: Bool
    var onToggle: () -> Void
    var onView: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    CircleCheck(checked: checked, size: 16)
                    Text(doc.label)
                        .wpTypography(12)
                        .foregroundStyle(WPColor.stone600)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onView) {
                Text("보기")
                    .wpTypography(10)
                    .foregroundStyle(WPColor.stone400)
                    .underline()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        // 터치 타겟 48pt 확보
        .frame(height: 48)
    }
}

/// 동의서 원문 보기 — 안드로이드 `TermsDocDialog`(M3 `AlertDialog`: 흰 면 · 모서리 28 · 안쪽 24,
/// 제목 17 · 본문 13 스크롤 · 오른쪽 아래 `닫기`). 예전에는 바닥 시트였다.
private struct TermsDocDialog: View {
    var doc: TermsDoc
    var onDismiss: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onDismiss)

                VStack(alignment: .leading, spacing: 0) {
                    Text(doc.title)
                        .wpTypography(17, .semibold)
                        .foregroundStyle(WPColor.stone900)
                    Spacer().frame(height: 16)
                    ScrollView {
                        Text(doc.body)
                            .wpTypography(13)
                            .foregroundStyle(WPColor.stone600)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    Spacer().frame(height: 24)
                    HStack {
                        Spacer()
                        Button(action: onDismiss) {
                            Text("닫기")
                                .wpTypography(14)
                                .foregroundStyle(WPColor.primary)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 40)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("setting.terms.close")
                    }
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxHeight: geometry.size.height * 0.8)
                .fixedSize(horizontal: false, vertical: true)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.horizontal, 24)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

// MARK: - 입력창

/// 웹 입력창 — 안드로이드 `WpTextField`:
/// `px-4 py-3 text-lg font-semibold text-stone-900 bg-white rounded-lg border-2 border-stone-200
///  focus:border-[#FFAAB8] text-center` + `.font-user-content`(Tmoney)
private struct OnboardingField: View {
    @Binding var text: String
    var placeholder: String
    var width: CGFloat
    var numeric: Bool = false
    var selectAllOnFocus: Bool = false
    var identifier: String

    @State private var focused = false

    var body: some View {
        OnboardingTextInput(
            text: $text,
            focused: $focused,
            placeholder: placeholder,
            numeric: numeric,
            selectAllOnFocus: selectAllOnFocus,
            identifier: identifier
        )
        .padding(.horizontal, 16)
        .frame(width: width, height: 52)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(focused ? WPColor.accent : WPColor.stone200, lineWidth: 2)
        )
    }
}

/// Tmoney Regular 에 굵기를 합성(안드로이드 `FontWeight.SemiBold` + Regular 파일 하나)하고,
/// 자리 표시 글자는 합성하지 않는다(안드로이드 placeholder 는 보통 굵기).
/// 상자 둘레를 눌러도 칸에 초점이 가게 칸이 상자를 다 채운다(안드로이드 `focusFieldOnTap`).
private struct OnboardingTextInput: UIViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    var placeholder: String
    var numeric: Bool
    var selectAllOnFocus: Bool
    var identifier: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed), for: .editingChanged)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.textAlignment = .center
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.returnKeyType = .done
        field.tintColor = UIColor(WPColor.accent)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        let ink = UIColor(WPColor.stone900)
        let font = WPTypeface.tmoney.uiFont(18, .regular)
        // 조합 중인 한글은 UIKit 의 marked text 를 그대로 둔다.
        if field.markedTextRange == nil {
            field.defaultTextAttributes = [.font: font, .foregroundColor: ink, .strokeColor: ink, .strokeWidth: -2.5]
            if field.text != text { field.text = text }
            field.textAlignment = .center
        }
        field.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [
            .font: font, .foregroundColor: UIColor(WPColor.stone400),
        ])
        field.keyboardType = numeric ? .numberPad : .default
        field.accessibilityIdentifier = identifier
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 200, height: proposal.height ?? 52)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: OnboardingTextInput
        init(_ parent: OnboardingTextInput) { self.parent = parent }

        @objc func changed(_ field: UITextField) {
            guard field.markedTextRange == nil else { return }
            let raw = field.text ?? ""
            parent.text = raw
            // 바깥에서 정규화했으면(최대 6글자·숫자만) 그 값을 따른다
            DispatchQueue.main.async { [weak field, parent] in
                guard let field, field.markedTextRange == nil, field.text != parent.text else { return }
                field.text = parent.text
            }
        }

        func textFieldDidBeginEditing(_ field: UITextField) {
            parent.focused = true
            guard parent.selectAllOnFocus else { return }
            // 누른 손가락이 초점 **뒤에** 커서를 놓아 고른 범위를 풀기 때문에 한 바퀴 뒤에 고른다
            DispatchQueue.main.async {
                field.selectedTextRange = field.textRange(from: field.beginningOfDocument, to: field.endOfDocument)
            }
        }

        func textFieldDidEndEditing(_ field: UITextField) { parent.focused = false }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            field.resignFirstResponder()
            return true
        }
    }
}

// MARK: - 함께할 사람 (마지막 단계)

/// 온보딩 마지막 "함께할 사람" 단계 — 안드로이드 `InviteStep`.
///
/// 이 앱의 메리트가 "신랑·신부가 같이" 인데, 예전에는 초대 진입점이 홈의 작은
/// 점선 `＋` 원 하나였다. 온보딩은 이미 한 번에 하나씩 묻는 연출이라, 여기에 한 칸을
/// 더하면 초대가 부탁이 아니라 **절차**로 읽힌다.
///
/// **뒤로가기를 달지 않는다** — 저장이 이미 끝난 뒤라 되돌아갈 곳이 없다.
/// 대신 `나중에 할게요` 를 항상 둔다. 막으면 온보딩에서 이탈한다.
private struct InviteStep: View {
    @ObservedObject var model: SettingViewModel
    var onDone: () -> Void

    @EnvironmentObject private var env: AppEnvironment
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 80)

            LandingHero(
                title: "누구와 함께 준비하세요?",
                subtitle: "신랑·신부는 일정과 예산을 같이 고칠 수 있어요",
                titleSize: 28,
                subtitleSize: 14,
                useUserFont: false,
                alignStart: true
            )

            Spacer(minLength: 0)

            // 이미 신랑·신부와 함께 쓰는 플랜이 있으면(canInvite=false) 보낸 링크로는 아무도 못 들어온다 —
            // 고를 수 없게 하고 까닭을 적는다(웹 app/setting/page.tsx 와 같음)
            InviteChoiceCard(
                selected: model.inviteChoice == .invite,
                title: "신랑 · 신부를 부를게요",
                detail: model.canInvite ? "지금 초대장을 보냅니다" : SettingViewModel.coupleAlreadyMessage,
                filled: true,
                enabled: model.canInvite,
                identifier: "setting.invite.spouse"
            ) { model.setInviteChoice(.invite) }
            Spacer().frame(height: 10)
            InviteChoiceCard(
                selected: model.inviteChoice == .solo,
                title: "혼자 먼저 둘러볼게요",
                detail: "나중에 홈에서 언제든 부를 수 있어요",
                filled: false,
                identifier: "setting.invite.solo"
            ) { model.setInviteChoice(.solo) }

            Spacer().frame(height: 24)

            // 오류는 **버튼 바로 위 한 줄**이다(웹과 같음). 화면 바닥의 띠는 '나중에 할게요' 를 덮었다.
            if let message = model.errorMessage {
                Text(message)
                    .wpTypography(13)
                    .foregroundStyle(WPColor.danger)
                    .padding(.bottom, 10)
            }

            WPNextButton(
                text: buttonText,
                // 고르기 전에는 잠긴다. 링크를 받는 동안 잠기는 것은 '부를게요' 뿐이다 — '혼자 먼저' 는 링크가 필요 없다.
                enabled: model.inviteChoice != .none && !(model.inviteChoice == .invite && model.inviteLoading),
                identifier: "setting.inviteNext",
                action: primaryAction
            )

            Spacer().frame(height: 12)

            // **반드시 빠져나갈 길을 함께 둔다.** 막으면 온보딩에서 이탈한다.
            Button(action: onDone) {
                Text("나중에 할게요")
                    .wpTypography(13)
                    .foregroundStyle(WPColor.gray400)
                    .underline()
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("setting.inviteLater")

            Spacer().frame(height: 28)
        }
        .padding(.horizontal, 24)
        .sheet(isPresented: $showShareSheet, onDismiss: onDone) {
            if let url = model.inviteURL {
                // 공유 시트를 취소해도 갇히지 않는다 — `onDismiss` 가 그대로 앱으로 보낸다.
                ActivityShareSheet(items: ["우리 결혼 준비, 같이 하자!\n\(url)"])
            }
        }
    }

    private var buttonText: String {
        switch model.inviteChoice {
        case .invite where model.inviteLoading: return "준비 중..."
        case .invite: return "초대장 보내기"
        default: return "계획 짜러 가기"
        }
    }

    private func primaryAction() {
        guard model.inviteChoice == .invite else { onDone(); return }
        if model.inviteURL != nil {
            showShareSheet = true
        } else {
            // 링크를 못 받았으면 **조용히 끝내지 않고** 까닭을 말하고 머문다(웹 useSpouseInvite).
            Task { await model.onInviteLinkMissing(env: env) }
        }
    }
}

private struct InviteChoiceCard: View {
    var selected: Bool
    var title: String
    var detail: String
    var filled: Bool
    var enabled: Bool = true
    var identifier: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    if filled {
                        Circle().fill(selected ? WPColor.primary : WPColor.inviteChoiceIcon)
                    } else {
                        Circle().strokeBorder(selected ? WPColor.primary : WPColor.stone300, lineWidth: 2)
                    }
                    WPMaterialPathIcon(
                        paths: filled ? InviteIcon.favorite : InviteIcon.person,
                        size: 18,
                        color: filled ? (selected ? .white : WPColor.primary) : (selected ? WPColor.primary : WPColor.gray400)
                    )
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .wpTypography(15, .bold)
                        .foregroundStyle(WPColor.stone900)
                    Text(detail)
                        .wpTypography(12, lineHeight: 17)
                        .foregroundStyle(WPColor.gray500)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if selected {
                    WPMaterialPathIcon(paths: WPIconPaths.check, size: 20, color: WPColor.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(selected ? WPColor.inviteChoiceSelected : Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? WPColor.primary : WPColor.stone200, lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(UndimmedButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
        .frame(maxWidth: 340)
        .accessibilityIdentifier(identifier)
    }
}

/// 안드로이드 `Icons.Filled.Favorite` · `Icons.Filled.Person` 원본 경로
private enum InviteIcon {
    static let favorite = ["M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"]
    static let person = ["M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"]
}

// 공유 시트는 `SpouseInviteSheet.swift` 의 `ActivityShareSheet` 를 함께 쓴다.
// 여기 private 사본을 두면 **모듈 범위에서 재선언으로 잡혀 빌드가 깨진다** —
// 파일 private 이어도 내부의 internal 선언과 이름이 겹치면 안 된다.
