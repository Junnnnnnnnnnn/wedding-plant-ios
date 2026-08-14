import SwiftUI
import WPModels
import WPNetworking
import WPUtils

/// 웹의 `/plan-list` — 참여 중인 플랜(방) 목록.
struct PlanListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var plans: [Plan] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                WP.background.ignoresSafeArea()

                if plans.isEmpty && !isLoading {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2")
                            .font(.system(size: 34))
                            .foregroundStyle(WP.textSecondary)
                        Text("참여 중인 플랜이 없어요")
                            .font(.system(size: 15))
                            .foregroundStyle(WP.textSecondary)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(plans) { plan in
                                PlanRow(plan: plan)
                            }
                        }
                        .padding(16)
                    }
                }

                if isLoading && plans.isEmpty {
                    ProgressView().tint(WP.accent)
                }
            }
            .navigationTitle("참여 플랜")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        if let list = try? await env.api.send(Endpoint.roomList(), decoding: RoomList.self) {
            plans = list.list
        }
    }
}

struct PlanRow: View {
    let plan: Plan

    private var dDayText: String {
        guard let date = KstDate(dateString: plan.weddingDate) else { return "-" }
        let days = date.daysFromToday()
        return days >= 0 ? "D-\(days)" : "D+\(-days)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(plan.ownerName)님의 플랜")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(WP.textPrimary)
                Spacer()
                Text(dDayText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WP.accent)
            }

            HStack(spacing: 16) {
                statItem("일정", "\(plan.planCount)개")
                statItem("예산", wpManwon(plan.budget))
                statItem("남음", wpManwon(plan.remainingBudget))
            }

            if !plan.members.isEmpty {
                HStack(spacing: 6) {
                    ForEach(plan.members) { member in
                        Text(member.name)
                            .font(.system(size: 12))
                            .foregroundStyle(WP.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(WP.background)
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
            }
        }
        .wpCard()
    }

    private func statItem(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(WP.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(WP.textPrimary)
        }
    }
}
