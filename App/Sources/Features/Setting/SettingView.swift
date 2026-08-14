import SwiftUI
import WPModels
import WPNetworking
import WPUtils

/// 웹의 `/setting` — 이름 · 예산 · 결혼일 입력.
///
/// 웹·안드로이드는 한 항목씩 넘기는 다단계 플로우(`WpNextButton` + 약관 동의)이지만,
/// 여기서는 아직 한 화면에 모아둔 축약판이다. 색·글꼴·버튼 모양은 웹과 맞췄다.
struct SettingView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore

    var onComplete: () -> Void

    @State private var name: String = ""
    @State private var budgetText: String = ""
    @State private var weddingDate: Date = Date()
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var budget: Int? {
        Int(budgetText.trimmingCharacters(in: .whitespaces))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && budget != nil
    }

    var body: some View {
        ZStack {
            WPScreenBackground(showsDecor: true)

            ScrollView {
                VStack(spacing: 24) {
                    LandingHero(
                        title: "플랜을 시작해볼까요?",
                        subtitle: "몇 가지만 알려주세요",
                        titleSize: 28,
                        subtitleSize: 16,
                        useUserFont: false
                    )
                    .padding(.top, 24)

                    field(title: "어떻게 불러드릴까요?") {
                        TextField("이름", text: $name)
                            .font(WPFont.tmoney(17))
                            .foregroundStyle(WPColor.textPrimary)
                            .accessibilityIdentifier("setting.name")
                    }

                    field(title: "총 예산") {
                        HStack(spacing: 6) {
                            TextField("0", text: $budgetText)
                                .font(WPFont.tmoney(17))
                                .foregroundStyle(WPColor.textPrimary)
                                .keyboardType(.numberPad)
                                .accessibilityIdentifier("setting.budget")
                            Text("만원")
                                .font(WPFont.hak(15))
                                .foregroundStyle(WPColor.gray500)
                        }
                    }

                    field(title: "결혼 예정일") {
                        DatePicker(
                            "결혼 예정일",
                            selection: $weddingDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                        .tint(WPColor.primary)
                        .accessibilityIdentifier("setting.date")
                    }

                    if let errorMessage {
                        InfoBanner(message: errorMessage)
                    }

                    WPNextButton(text: "시작하기", enabled: canSave && !isSaving) {
                        Task { await save() }
                    }
                    .accessibilityIdentifier("setting.save")
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func field<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(WPFont.hak(15, .bold))
                .foregroundStyle(WPColor.textPrimary)
            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    WPColor.background,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(WPColor.cardBorder, lineWidth: 1)
        )
    }

    private func save() async {
        guard let budget else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let components = KST.calendar.dateComponents([.year, .month, .day], from: weddingDate)
        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              let kstDate = KstDate(year: year, month: month, day: day)
        else {
            errorMessage = "결혼 예정일을 다시 선택해 주세요."
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        // 게스트는 로컬에만 저장한다 (웹과 동일). 로그인 시 GuestMigration 이 백엔드로 올린다.
        guest.save(name: trimmedName, budget: budget, weddingDate: kstDate)

        let token = await env.tokenStore.currentToken()
        if let token, !token.isEmpty {
            let request = PlanSettingRequest(
                weddingDate: kstDate.dateString,
                budget: budget,
                name: trimmedName,
                requiredAgreementDate: KstDate.todayString()
            )
            // 서버 저장 실패해도 화면은 진행한다 (게스트 데이터가 로컬에 남아 있으므로).
            try? await env.api.sendIgnoringData(Endpoint.createSetting(request))
        }

        onComplete()
    }
}
