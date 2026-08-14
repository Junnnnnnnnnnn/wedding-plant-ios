import SwiftUI
import WPModels
import WPNetworking
import WPUtils

/// 웹의 `/setting` — 이름 · 예산 · 결혼일 입력.
struct SettingView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    var onComplete: () -> Void

    @State private var name: String = ""
    @State private var budgetText: String = "5000"
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
        NavigationStack {
            ZStack {
                WP.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("어떻게 불러드릴까요?")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(WP.textPrimary)
                            TextField("이름", text: $name)
                                .textFieldStyle(.plain)
                                .font(.system(size: 17))
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)
                                .background(WP.background)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .accessibilityIdentifier("setting.name")
                        }
                        .wpCard()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("총 예산")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(WP.textPrimary)
                            HStack {
                                TextField("0", text: $budgetText)
                                    .keyboardType(.numberPad)
                                    .font(.system(size: 17))
                                    .accessibilityIdentifier("setting.budget")
                                Text("만원")
                                    .font(.system(size: 15))
                                    .foregroundStyle(WP.textSecondary)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .background(WP.background)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .wpCard()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("결혼 예정일")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(WP.textPrimary)
                            DatePicker(
                                "결혼 예정일",
                                selection: $weddingDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .tint(WP.accent)
                            .accessibilityIdentifier("setting.date")
                        }
                        .wpCard()

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundStyle(WP.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("플랜 시작하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task { await save() }
                    }
                    .disabled(!canSave || isSaving)
                    .accessibilityIdentifier("setting.save")
                }
            }
        }
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

        let request = PlanSettingRequest(
            weddingDate: kstDate.dateString,
            budget: budget,
            name: name.trimmingCharacters(in: .whitespaces),
            requiredAgreementDate: KstDate.todayString()
        )

        do {
            try await env.api.sendIgnoringData(Endpoint.createSetting(request))
            onComplete()
        } catch {
            // 게스트 모드에서는 서버 저장 실패해도 로컬로 계속 진행한다(웹과 동일한 성격).
            onComplete()
        }
    }
}
