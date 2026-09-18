import SwiftUI
import WPDomain
import WPModels
import WPUtils

/// 자랑하기 상세. **페이지가 아니라 모달이다**(시안 M5-C).
///
/// 웹은 `최대 1520x680, 남는 자리를 여백으로 쓰되 한 변 200px` 규칙이지만
/// **폰에는 그럴 여백이 없다** — iOS 에서는 시트가 화면을 거의 다 쓴다.
///
/// ## 앱의 것을 그대로 쓴다
///
/// 이 화면의 값어치가 "남의 대시보드를 그대로 들여다본다" 는 데 있다. 예산 블록은
/// 홈의 것과 같은 값이고, 색은 `BragPalette` 한 곳에서 온다 — 따로 적어 두면
/// 언젠가 갈린다.
///
/// **왼쪽 범례 색과 오른쪽 묶음 머리 색이 같아야 한다.** "이 1,240만원이 이 두
/// 장이다" 가 눈으로 붙는 것이 이 화면의 전부다.
struct BragDetailSheet: View {
    var bragId: Int

    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = BragDetailViewModel()
    @State private var openedItem: BragPlanItem?

    var body: some View {
        NavigationStack {
            Group {
                if model.loading {
                    loadingState
                } else if let detail = model.detail {
                    content(detail)
                } else {
                    Text(model.errorMessage ?? "플랜을 불러오지 못했어요.")
                        .font(WPFont.hak(14))
                        .foregroundStyle(WPColor.fgSubtle)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(WPColor.background)
            .navigationTitle(model.detail?.nickname ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .task { await model.load(id: bragId, env: env) }
        // **카드를 누르면 열린다.** 처음에는 안 눌리게 뒀는데, "앱과 같아 보일수록
        // 눌러 보게 된다" 는 시안의 예측이 배포 첫날 그대로 맞았다 — 눌러도 아무
        // 일이 없는 것보다 열어 주는 편이 낫다.
        //
        // **여는 것과 바꾸는 것은 다르다**: 시트에는 닫기 말고 아무 조작도 없다.
        .sheet(item: $openedItem) { item in
            BragPlanSheet(item: item, group: group(of: item))
        }
    }

    private func group(of item: BragPlanItem) -> BragRules.Group? {
        model.groups.first { $0.items.contains(item) }
    }

    private func content(_ detail: BragDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                summary(detail)

                ForEach(model.groups) { group in
                    groupBlock(group)
                }
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - 예산 요약 + 범례

    private func summary(_ detail: BragDetail) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let date = detail.weddingDate.flatMap({ KstDate(dateString: $0) }) {
                Text(date.weddingDateText)
                    .font(WPFont.hak(13))
                    .foregroundStyle(WPColor.fgSubtle)
                Spacer().frame(height: 10)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(withThousands(detail.totalBudget))
                    .font(WPFont.tmoney(36, .bold))
                    .tracking(-0.03 * 36)
                    .foregroundStyle(WPColor.textPrimary)
                Text("만원")
                    .font(WPFont.hak(14))
                    .foregroundStyle(WPColor.fgSubtle)
            }

            Spacer().frame(height: 12)
            stackBar(detail)
            Spacer().frame(height: 14)
            legend

            Spacer().frame(height: 12)
            Text("플랜 \(detail.planCount) · 완료 \(detail.doneCount)")
                .font(WPFont.hak(12.5))
                .foregroundStyle(WPColor.fgSubtle)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(WPColor.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    /// 홈 예산 패널과 같은 `h-3` 스택 막대.
    private func stackBar(_ detail: BragDetail) -> some View {
        let total = max(detail.totalBudget, detail.usedAmount + detail.plannedAmount, 1)
        return GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(model.groups) { group in
                    Rectangle()
                        .fill(BragPalette.color(group.colorIndex))
                        .frame(width: geo.size.width * Double(group.subtotal) / Double(total))
                }
                Rectangle().fill(Color(hex: 0xF4EFF2))
            }
            .clipShape(Capsule())
        }
        .frame(height: 12)
    }

    private var legend: some View {
        FlowRow(spacing: 14, lineSpacing: 8) {
            ForEach(model.groups) { group in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(BragPalette.color(group.colorIndex))
                        .frame(width: 9, height: 9)
                    Text("\(group.categoryName) \(withThousands(group.subtotal))")
                        .font(WPFont.hak(12.5))
                        .foregroundStyle(WPColor.fgMuted)
                }
            }
        }
    }

    // MARK: - 카테고리 묶음

    private func groupBlock(_ group: BragRules.Group) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 머리 색이 **왼쪽 범례와 같아야** 좌우가 이어진다.
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(BragPalette.color(group.colorIndex))
                    .frame(width: 9, height: 9)
                Text(group.categoryName)
                    .font(WPFont.hak(15, .bold))
                    .foregroundStyle(WPColor.textPrimary)
                Spacer(minLength: 8)
                // 소계는 **지출과 예정을 함께** 센다.
                Text("\(withThousands(group.subtotal))만원")
                    .font(WPFont.tmoney(14, .bold))
                    .foregroundStyle(WPColor.textPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 8)

            ForEach(group.items) { item in
                BragPlanRow(item: item) { openedItem = item }
            }
        }
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonBox(width: 160, height: 18)
            SkeletonBox(width: 180, height: 36)
            SkeletonBox(height: 12, corner: 6)
            SkeletonBox(height: 60)
            SkeletonBox(height: 60)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - 플랜 한 줄

/// 앱의 카드와 **같은 모양**이다. 체크는 못 바꾸고, 카드는 **보기 전용으로 열린다.**
private struct BragPlanRow: View {
    var item: BragPlanItem
    var onOpen: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // **`disabled` 를 쓰지 않는다** — 흐려져서 앱의 카드와 모양이 달라진다.
            // 모양은 똑같이 두되 아예 버튼이 아니게 만든다.
            ZStack {
                Circle().fill(item.isScheduleCompleted ? WPColor.positive : Color.white)
                Circle().strokeBorder(
                    item.isScheduleCompleted ? WPColor.positive : WPColor.brand300,
                    lineWidth: 1.5
                )
                if item.isScheduleCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 22, height: 22)
            .padding(.top, 2)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(WPFont.tmoney(16, .bold))
                    .foregroundStyle(
                        item.isScheduleCompleted ? WPColor.fgSubtle : WPColor.fgNeutral
                    )
                    .strikethrough(item.isScheduleCompleted)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(
                        KstDate(dateString: item.startDate ?? "")?.monthDayWeekText ?? "날짜 미정"
                    )
                    .font(WPFont.hak(13))
                    .foregroundStyle(WPColor.fgMuted)
                    Spacer(minLength: 8)
                    AmountText(amount: Double(item.amount ?? 0))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(item.isScheduleCompleted ? 0.7 : 1)
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }
}

// MARK: - 플랜 상세 시트

/// 카드 한 장을 자세히 보는 자리. **닫기 말고 아무 조작도 없다.**
///
/// 카드가 이미 다섯 값을 다 보여 주므로 여기서는 한 겹씩 더한다 — 날짜를 요일까지
/// 펴고, 그 카테고리 소계에서 차지하는 몫을 내고, 장소를 적는다.
///
/// **장소 줄과 지도 자리를 비워 두지 않는다.** 피드의 목록 카드는 장소가 없으면
/// 줄을 지우지만(금액을 세로로 훑는 설계라), 이 시트는 한 장을 자세히 보는
/// 자리라 **"없다" 는 것도 정보다.** 줄이나 상자가 사라지면 "안 적었나" 와
/// "화면이 안 그렸나" 를 구별할 수 없다.
private struct BragPlanSheet: View {
    var item: BragPlanItem
    var group: BragRules.Group?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.title)
                        .font(WPFont.tmoney(22, .bold))
                        .foregroundStyle(WPColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 14)
                    row("카테고리", item.categoryName.isEmpty ? "없음" : item.categoryName)
                    row("날짜", dateText)
                    row("금액", item.amount.map { "\(withThousands($0))만원" } ?? "미정")
                    if let share = shareText { row("이 카테고리에서", share) }
                    row("장소", placeText)

                    Spacer().frame(height: 18)
                    mapBlock
                }
                .padding(20)
            }
            .background(WPColor.background)
            .navigationTitle("플랜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var dateText: String {
        guard let date = KstDate(dateString: item.startDate ?? "") else { return "날짜 미정" }
        return date.listDateText
    }

    /// **플랜이 하나뿐이면 몫을 말하지 않는다** — 늘 100% 라 같은 말을 두 번 한다.
    private var shareText: String? {
        guard let group else { return nil }
        guard let percent = BragRules.sharePercent(item: item, in: group) else {
            return group.items.count <= 1 ? "이 플랜 하나뿐이에요" : nil
        }
        return "\(withThousands(group.subtotal))만원 가운데 \(percent)%"
    }

    private var placeText: String {
        let place = item.location?.trimmingCharacters(in: .whitespaces) ?? ""
        return place.isEmpty ? "없음" : place
    }

    /// 지도를 못 내는 이유를 **갈라** 적는다.
    ///
    /// iOS 는 카카오 지도 SDK 를 아직 안 붙였다. 좌표가 있을 때는 카카오맵으로
    /// 넘어가는 줄을 내고, 없을 때는 왜 없는지를 적는다.
    @ViewBuilder
    private var mapBlock: some View {
        if let absence = BragRules.mapAbsence(for: item) {
            Text(absence.message)
                .font(WPFont.hak(13))
                .foregroundStyle(WPColor.fgSubtle)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 28)
                .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else if let lat = item.lat, let lng = item.lng,
                  let name = item.location?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://map.kakao.com/link/map/\(name),\(lat),\(lng)") {
            Link(destination: url) {
                HStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.system(size: 14, weight: .semibold))
                    Text("카카오맵에서 보기")
                        .font(WPFont.hak(14, .bold))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(WPColor.primary)
                .padding(16)
                .background(Color(hex: 0xFFF2F6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label)
                    .font(WPFont.hak(13, .bold))
                    .foregroundStyle(WPColor.fgMuted)
                    .frame(width: 96, alignment: .leading)
                Text(value)
                    .font(WPFont.hak(14))
                    .foregroundStyle(WPColor.fgNeutral)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
        }
    }
}
