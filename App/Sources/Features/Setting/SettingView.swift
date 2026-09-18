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
                    case .invite: InviteStep(model: model, onDone: onComplete)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.5), value: model.step)

                // 웹: 예산·이름·환영·약관 단계에만 뒤로가기. 축하·날짜에는 없음.
                // **초대 단계에도 달지 않는다** — 저장이 이미 끝난 뒤라 되돌아갈
                // 곳이 없다.
                if model.step != .celebration && model.step != .date && model.step != .invite {
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
                    // **`다음` 이다** — 뒤에 `함께할 사람` 단계가 남아 있다.
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

// MARK: - 함께할 사람 (마지막 단계)

/// 웹 온보딩의 다섯 번째 단계 — `결혼 날짜 · 예산 · 이름 · 약관 동의 · 함께할 사람`.
///
/// 이 앱의 메리트가 "신랑·신부가 같이" 인데, 예전에는 초대 진입점이 홈의 작은
/// 점선 `＋` 원 하나였고 그마저 **멤버가 나 혼자일 때만** 떠서 조언자 한 명만
/// 들어와도 사라졌다. 온보딩은 이미 한 번에 하나씩 묻는 연출이라, 여기에 한 칸을
/// 더하면 초대가 부탁이 아니라 **절차**로 읽힌다.
///
/// **한 번 나가면 다시 볼 수 없다.** 약관에서 저장이 끝나 이름·날짜·예산이 모두
/// 찼으므로 `/setting` 으로 다시 들어와도 홈으로 보내진다(질문을 되풀이하지 않는
/// 게 맞다). 그래서 홈의 초대 띠가 유일한 재진입점이다 — 그 띠를 없애면 여기서
/// 건너뛴 사람은 초대할 방법이 사라진다.
private struct InviteStep: View {
    @ObservedObject var model: SettingViewModel
    var onDone: () -> Void

    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 80)

            LandingHero(
                title: "누구와 함께 준비하세요?",
                subtitle: "신랑·신부는 일정과 예산을 같이 고칠 수 있어요",
                titleSize: 28,
                subtitleSize: 14,
                useUserFont: false
            )

            Spacer(minLength: 24)

            choiceCard(
                choice: .invite,
                title: "신랑 · 신부를 부를게요",
                body: "지금 초대장을 보냅니다",
                filled: true
            )
            Spacer().frame(height: 10)
            choiceCard(
                choice: .solo,
                title: "혼자 먼저 둘러볼게요",
                body: "나중에 홈에서 언제든 부를 수 있어요",
                filled: false
            )

            Spacer().frame(height: 24)

            WPNextButton(
                text: buttonText,
                // 고르기 전에는 잠긴다. 무엇을 고르는 화면인지 분명해진다.
                enabled: model.inviteChoice != .none && !model.inviteLoading,
                identifier: "setting.inviteNext",
                action: primaryAction
            )

            Spacer().frame(height: 12)

            // **반드시 빠져나갈 길을 함께 둔다.** 막으면 온보딩에서 이탈한다.
            Button(action: onDone) {
                Text("나중에 할게요")
                    .font(WPFont.hak(13))
                    .foregroundStyle(WPColor.gray400)
                    .underline()
                    .padding(8)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("setting.inviteLater")

            Spacer().frame(height: 28)
        }
        .padding(.horizontal, 24)
        .sheet(isPresented: $showShareSheet, onDismiss: onDone) {
            if let url = model.inviteURL {
                // 공유 시트를 취소해도 갇히지 않는다 — `onDismiss` 가 그대로 앱으로 보낸다.
                ActivityShareSheet(items: [url])
            }
        }
    }

    private var buttonText: String {
        if model.inviteLoading { return "준비 중..." }
        return model.inviteChoice == .invite ? "초대장 보내기" : "계획 짜러 가기"
    }

    private func primaryAction() {
        if model.inviteChoice == .invite, model.inviteURL != nil {
            showShareSheet = true
        } else {
            onDone()
        }
    }

    private func choiceCard(
        choice: SettingViewModel.InviteChoice,
        title: String,
        body: String,
        filled: Bool
    ) -> some View {
        let selected = model.inviteChoice == choice
        return Button { model.inviteChoice = choice } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(WPFont.hak(16, .bold))
                    .foregroundStyle(selected ? WPColor.primary : WPColor.textPrimary)
                Text(body)
                    .font(WPFont.hak(13))
                    .foregroundStyle(WPColor.fgSubtle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                selected ? WPColor.primary.opacity(0.06) : (filled ? WPColor.fill : Color.white),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        selected ? WPColor.primary.opacity(0.4) : WPColor.strokeWeak,
                        lineWidth: selected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// 공유 시트는 `SpouseInviteSheet.swift` 의 `ActivityShareSheet` 를 함께 쓴다.
// 여기 private 사본을 두면 **모듈 범위에서 재선언으로 잡혀 빌드가 깨진다** —
// 파일 private 이어도 내부의 internal 선언과 이름이 겹치면 안 된다.
