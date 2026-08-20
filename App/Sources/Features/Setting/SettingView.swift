import SwiftUI
import WPUtils

/// 웹 `app/setting/page.tsx` 이식.
///
/// 축하 → 날짜 → 예산 → 이름 → 환영 → 약관, 6단계 플로우.
/// 웹의 3D 출입증(Lanyard) 단계는 아직 없다 — @react-three 기반이라 별도 포팅 작업이다.
/// 문구("출입증을 발급해 드렸어요!")는 웹 그대로 유지했다.
struct SettingView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore
    @StateObject private var model = SettingViewModel()

    var onComplete: () -> Void

    var body: some View {
        ZStack {
            WPScreenBackground(showsDecor: true)

            ZStack(alignment: .topLeading) {
                Color.clear

                Group {
                    switch model.step {
                    case .celebration: CelebrationStep()
                    case .date: DateStep(model: model)
                    case .budget: BudgetStep(model: model)
                    case .name: NameStep(model: model)
                    case .welcome: WelcomeStep(model: model)
                    case .terms: TermsStep(model: model, onSubmit: submit)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.5), value: model.step)

                // 웹: 예산·이름·환영·약관 단계에만 뒤로가기. 축하·날짜에는 없음.
                if model.step != .celebration && model.step != .date {
                    Button {
                        model.back()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(WPColor.stone600)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                    .accessibilityLabel("뒤로 가기")
                }

                if let message = model.errorMessage {
                    VStack {
                        Spacer()
                        InfoBanner(message: message, actionLabel: "닫기") {
                            model.errorMessage = nil
                        }
                        .padding(16)
                    }
                }
            }
        }
        .task {
            await model.prefill(env: env, guest: guest)
            if model.skipToMain {
                onComplete()
            }
        }
        // 웹과 동일하게 축하 문구를 3초 노출한 뒤 자동 전환
        .task(id: model.ready) {
            guard model.ready, model.step == .celebration else { return }
            try? await Task.sleep(for: .seconds(3))
            model.advanceFromCelebration()
        }
    }

    private func submit() {
        Task {
            await model.submit(env: env, guest: guest, onDone: onComplete)
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
                titleSize: 24,
                subtitleSize: 14,
                useUserFont: false
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
            // 온보딩에서는 결혼식이 과거일 수 없다 (프로필 수정에는 하한이 없다).
            DateWheelPicker(value: $model.date, minDate: KstDate.today())
                .accessibilityIdentifier("setting.date")
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
                WPTextField(
                    text: Binding(
                        get: { model.budget },
                        set: { model.setBudget($0) }
                    ),
                    placeholder: "0",
                    width: 128, // w-32
                    numeric: true
                )
                .accessibilityIdentifier("setting.budget")

                Text("만원")
                    .font(WPFont.hak(18, .semibold))
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
            buttonEnabled: !model.name.isEmpty,
            onNext: { model.goTo(.welcome) }
        ) {
            VStack(spacing: 8) {
                Text("최대 6 글자")
                    .font(WPFont.hak(14))
                    .foregroundStyle(WPColor.stone500)

                WPTextField(
                    text: Binding(
                        get: { model.name },
                        set: { model.setName($0) }
                    ),
                    placeholder: "이름 또는 닉네임",
                    width: 240
                )
                .accessibilityIdentifier("setting.name")
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
            titleSize: 24,
            subtitleSize: 14
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            try? await Task.sleep(for: .seconds(2.5))
            model.goTo(.terms)
        }
    }
}

private struct TermsStep: View {
    @ObservedObject var model: SettingViewModel
    var onSubmit: () -> Void

    @State private var openTerms: TermsDoc?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                LandingHero(
                    title: "자 이제 시작해볼까요?",
                    subtitle: "결혼식까지 든든한 플랜을 같이 짜보아요",
                    titleSize: 24,
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
                                .font(WPFont.hak(14, .semibold))
                                .foregroundStyle(WPColor.stone900)
                            Spacer()
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
                    text: model.submitting ? "저장 중..." : "계획 짜러 가기",
                    enabled: model.allRequiredAgreed && !model.submitting,
                    identifier: "setting.submit",
                    action: onSubmit
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 80)
            .padding(.bottom, 48)
        }
        .sheet(item: $openTerms) { doc in
            TermsSheet(doc: doc)
        }
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
                        .font(WPFont.hak(12))
                        .foregroundStyle(WPColor.stone600)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onView) {
                Text("보기")
                    .font(WPFont.hak(10))
                    .foregroundStyle(WPColor.stone400)
                    .underline()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        // 터치 타겟 48pt 확보
        .frame(height: 48)
    }
}

private struct TermsSheet: View {
    var doc: TermsDoc
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(doc.body)
                    .font(WPFont.hak(13))
                    .foregroundStyle(WPColor.stone600)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .background(Color.white)
            .navigationTitle(doc.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(WPColor.primary)
                }
            }
        }
    }
}

// MARK: - 입력창

/// 웹 입력창:
/// `px-4 py-3 text-lg font-semibold text-stone-900 bg-white rounded-lg border-2 border-stone-200
///  focus:border-[#FFAAB8] text-center` + `.font-user-content`(Tmoney)
private struct WPTextField: View {
    @Binding var text: String
    var placeholder: String
    var width: CGFloat
    var numeric: Bool = false

    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text, prompt: promptText)
            .font(WPFont.tmoney(18, .semibold))
            .foregroundStyle(WPColor.stone900)
            .multilineTextAlignment(.center)
            .keyboardType(numeric ? .numberPad : .default)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focused)
            .tint(WPColor.accent)
            .padding(.horizontal, 16)
            .frame(width: width, height: 52)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(focused ? WPColor.accent : WPColor.stone200, lineWidth: 2)
            )
    }

    private var promptText: Text {
        Text(placeholder)
            .font(WPFont.tmoney(18))
            .foregroundColor(WPColor.stone400)
    }
}
