import SwiftUI
import WPModels
import WPNetworking
import WPUtils
import WPDomain

/// 웹의 `/plan-list` — 참여 중인 플랜(방) 목록.
///
/// - Note: 팔레트·글꼴·카드 스타일은 웹에 맞췄지만, 세부 배치는 아직 안드로이드
///   `ui/planlist/PlanListScreen.kt` 와 1:1 대조를 마치지 않았다. 후속 패스 필요.
struct PlanListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var plans: [Plan] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            WPScreenBackground()

            ScrollView {
                VStack(spacing: 12) {
                    HStack {
                        Text("참여 플랜")
                            .font(WPFont.hak(20, .bold))
                            .foregroundStyle(WPColor.textPrimary)
                        Spacer()
                    }
                    .padding(.bottom, 4)

                    if isLoading {
                        ProgressView()
                            .tint(WPColor.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                    } else if plans.isEmpty {
                        VStack(spacing: 8) {
                            Text("참여 중인 플랜이 없어요")
                                .font(WPFont.hak(16, .semibold))
                                .foregroundStyle(WPColor.stone400)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                    } else {
                        ForEach(plans) { plan in
                            PlanRoomCard(plan: plan)
                        }
                    }
                }
                .padding(16)
            }
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

private struct PlanRoomCard: View {
    var plan: Plan

    var body: some View {
        let date = KstDate(dateString: plan.weddingDate)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("\(plan.ownerName)님의 플랜")
                    .font(WPFont.tmoney(18, .bold))
                    .foregroundStyle(WPColor.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                DDayBadge(label: PlanRules.dDayLabel(weddingDate: date))
            }

            HStack(spacing: 20) {
                stat("일정", "\(plan.planCount)개")
                stat("예산", "\(wpThousands(plan.budget))만 원")
                stat("남음", "\(wpThousands(plan.remainingBudget))만 원")
                Spacer(minLength: 0)
            }

            if !plan.members.isEmpty {
                HStack(spacing: -8) {
                    ForEach(Array(plan.members.prefix(4).enumerated()), id: \.element.id) { index, member in
                        MemberAvatar(name: member.name, index: index, size: 32)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(WPColor.cardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(WPFont.hak(12))
                .foregroundStyle(WPColor.gray400)
            Text(value)
                .font(WPFont.hak(14, .bold))
                .foregroundStyle(WPColor.textPrimary)
        }
    }
}
