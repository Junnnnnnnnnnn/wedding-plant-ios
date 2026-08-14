import SwiftUI
import WPModels
import WPUtils

/// 웹의 `/main` — D-day, 예산 요약, 다가오는 일정.
struct MainView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var model = MainViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                WP.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        dDayCard
                        budgetCard
                        scheduleSection
                    }
                    .padding(16)
                }
                .accessibilityIdentifier("main.scroll")

                if model.isLoading && model.user == nil {
                    ProgressView()
                        .controlSize(.large)
                        .tint(WP.accent)
                }
            }
            .navigationTitle("홈")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await model.load(api: env.api)
        }
    }

    // MARK: - D-day

    private var dDayCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greeting)
                .font(.system(size: 15))
                .foregroundStyle(WP.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let dDay = model.dDay {
                    Text(dDay >= 0 ? "D-\(dDay)" : "D+\(-dDay)")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(WP.accent)
                        .accessibilityIdentifier("main.dday")
                } else {
                    Text("D-??")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(WP.textSecondary)
                }
            }

            if let text = model.weddingDateText {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(WP.textSecondary)
            }
        }
        .wpCard()
    }

    private var greeting: String {
        if let name = model.user?.name, !name.isEmpty {
            return "\(name)님의 결혼식까지"
        }
        return "결혼식까지"
    }

    // MARK: - 예산

    @ViewBuilder
    private var budgetCard: some View {
        if let budget = model.budget {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("예산")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(WP.textPrimary)
                    Spacer()
                    Text(wpManwon(budget.total))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(WP.textSecondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(WP.accentSoft)
                        Capsule()
                            .fill(budget.isOverBudget ? WP.warning : WP.accent)
                            .frame(width: max(6, geo.size.width * CGFloat(budget.usedRatio)))
                    }
                }
                .frame(height: 10)

                HStack(spacing: 0) {
                    amountColumn("사용", value: budget.used, color: WP.textPrimary)
                    Divider().frame(height: 28)
                    amountColumn(
                        budget.isOverBudget ? "초과" : "남음",
                        value: abs(budget.remaining),
                        color: budget.isOverBudget ? WP.warning : WP.success
                    )
                }
            }
            .wpCard()
            .accessibilityIdentifier("main.budget")
        }
    }

    private func amountColumn(_ title: String, value: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(WP.textSecondary)
            Text(wpManwon(value))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 일정

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("다가오는 일정")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WP.textPrimary)
                Spacer()
                Text("완료 \(model.completedCount)/\(model.schedules.count)")
                    .font(.system(size: 13))
                    .foregroundStyle(WP.textSecondary)
            }

            if model.upcoming.isEmpty {
                Text("등록된 일정이 없어요")
                    .font(.system(size: 14))
                    .foregroundStyle(WP.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 10) {
                    ForEach(model.upcoming) { item in
                        ScheduleRow(item: item)
                    }
                }
            }
        }
        .wpCard()
        .accessibilityIdentifier("main.schedules")
    }
}

struct ScheduleRow: View {
    let item: ScheduleItem

    private var dateText: String {
        guard let raw = item.startDate, let date = KstDate(dateString: raw) else { return "-" }
        return String(format: "%d.%02d", date.month, date.day)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(dateText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WP.textPrimary)
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(WP.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(item.categoryName)
                        .font(.system(size: 12))
                        .foregroundStyle(WP.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(WP.categoryColor(item.categoryName))
                        .clipShape(Capsule())

                    if let location = item.location, !location.isEmpty {
                        Text(location)
                            .font(.system(size: 12))
                            .foregroundStyle(WP.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 8)

            if let amount = item.amount, amount > 0 {
                Text(wpManwon(amount))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WP.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}
