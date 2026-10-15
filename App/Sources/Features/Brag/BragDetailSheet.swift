import SwiftUI
import UIKit
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 자랑하기 상세 — 안드로이드 `ui/brag/BragDetail.kt` 의 `BragDetailDialog`(웹 `BragDetailModal` 폰 배치,
/// 시안 M5-C「카테고리로 묶는다」).
///
/// 앱의 예산 패널과 플랜 카드를 **그대로** 쓴다 — 남의 대시보드를 들여다보는 게 이 화면의 값어치다.
/// 폰은 거의 꽉 찬 면(가장자리 16pt) 안에 분홍 띠 → 예산 패널 → 카테고리 묶음이 쌓이고, 좋아요는 아래에 붙는다.
/// 예전 iOS 는 내비게이션 막대(`닫기 · 이름`)가 있는 시트라 안드로이드와 다른 화면이었다.
///
/// **왼쪽 범례 색과 묶음 머리 색이 같아야 한다** — 색은 `categoryChart` 앞 4개에만 준다.
struct BragDetailSheet: View {
    var bragId: Int
    /// 좋아요를 바꾸면 목록 카드도 맞춘다
    var onLikeChanged: (Bool, Int) -> Void = { _, _ in }
    /// 신고·차단이 끝났다 — 목록에서도 치운다
    var onHidden: () -> Void = {}

    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = BragDetailViewModel()
    @State private var openPlan: BragOpenPlan?
    @State private var likePending = false

    var body: some View {
        ZStack {
            // 안드로이드 Dialog 의 기본 막 — 바깥을 누르면 닫힌다
            Color.black.opacity(0.6).ignoresSafeArea()
                .contentShape(Rectangle()).onTapGesture { dismiss() }
            BragDetailBody(detail: model.detail, loading: model.loading, likePending: likePending,
                           onToggleLike: { Task { await toggleLike() } }, onClose: { dismiss() },
                           onHidden: { onHidden(); dismiss() }, onOpenPlan: { openPlan = $0 })
                .padding(16)
            if let open = openPlan {
                BragPlanSheet(open: open) { openPlan = nil }
            }
        }
        .task { await model.load(id: bragId, env: env) }
    }

    /// 좋아요는 **낙관적으로** 그리고 실패하면 되돌린다(목록과 같은 규칙).
    private func toggleLike() async {
        guard let before = model.detail, !likePending else { return }
        let next = BragRules.applyLike(liked: before.liked, likeCount: before.likeCount)
        model.detail?.liked = next.liked
        model.detail?.likeCount = next.likeCount
        likePending = true
        defer { likePending = false }
        do {
            let result = try await env.api.send(next.liked ? Endpoint.likeBrag(id: bragId) : Endpoint.unlikeBrag(id: bragId),
                                                decoding: BragLikeResult.self)
            if let liked = result.liked { model.detail?.liked = liked }
            if let count = result.likeCount { model.detail?.likeCount = count }
            if let now = model.detail { onLikeChanged(now.liked, now.likeCount) }
        } catch {
            model.detail = before
        }
    }
}

/// 상세에서 플랜 한 줄을 눌렀을 때 넘길 것
struct BragOpenPlan: Equatable {
    var item: BragPlanItem
    var subtotal: Double
    var count: Int
    var color: Color
}

/// 상세의 면 — **상태를 갖지 않는다**(스크린샷 테스트가 네트워크 없이 그린다).
struct BragDetailBody: View {
    var detail: BragDetail?
    var loading: Bool
    var likePending = false
    var onToggleLike: () -> Void = {}
    var onClose: () -> Void = {}
    var onHidden: () -> Void = {}
    var onOpenPlan: (BragOpenPlan) -> Void = { _ in }

    fileprivate static let cardBorder = Color(hex: 0xEE2B8C, alpha: Double(0x0F) / 255)
    fileprivate static let sub = Color(hex: 0x7A6C74)

    var body: some View {
        VStack(spacing: 0) {
            header
            if loading || detail == nil {
                Text(loading ? "불러오는 중" : "플랜을 찾지 못했어요").wpTypography(13.5).foregroundStyle(Self.sub)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let detail {
                let rows = chartRows(detail)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        budgetPanel(detail, rows: rows)
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(groups(detail), id: \.name) { group in
                                groupSection(group, color: colorOf(group.name, detail))
                            }
                        }
                    }
                    .padding(16)
                }
                .scrollIndicators(.hidden)
                if !detail.isMine { likeBar(detail) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WPColor.background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - 분홍 띠

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(detail?.nickname.isEmpty == false ? detail!.nickname : " ")
                    .wpTypography(20, .bold).tracking(-0.4).foregroundStyle(.white).lineLimit(1)
                Text(bragDateLabel(detail?.weddingDate, detail?.dday)).wpTypography(13).foregroundStyle(.white.opacity(0.75))
            }
            // 떠 있는 버튼 몫만큼 제목 묶음에만 오른쪽 여백(남의 글 76 · 내 글 44)
            .padding(.trailing, CGFloat(detail.map { $0.isMine ? 44 : 76 } ?? 44))
            if let detail {
                Color.clear.frame(height: 16)
                BragPlanDoneLine(planCount: detail.planCount, doneCount: detail.doneCount, onFill: true)
                Color.clear.frame(height: 8)
                BragTicks(done: detail.doneCount, total: detail.planCount, onFill: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 20)
        .background(brandGradient)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 4) {
                // 분홍 면 위라 `onDark` — 회색 아이콘은 여기서 안 보인다
                if let detail, !detail.isMine {
                    ModerationMenu(targetType: "BRAG", targetId: detail.bragId, onHidden: onHidden, onDark: true)
                }
                Button(action: onClose) {
                    WPMaterialPathIcon(paths: FeedIconPaths.close, size: 16, color: .white)
                        .frame(width: 36, height: 36).background(Color.white.opacity(0.2), in: Circle())
                }.buttonStyle(.plain).accessibilityLabel("닫기").accessibilityIdentifier("brag.detail.close")
            }
            .padding(16)
        }
    }

    // MARK: - 예산 패널

    private struct ChartRow { var name: String; var used: Double; var color: Color }

    /// 색 수로 잘라야 다섯 번째가 첫 번째와 같은 분홍이 되지 않는다. 나머지는 "그 외" 한 줄로.
    private func chartRows(_ detail: BragDetail) -> [ChartRow] {
        let chart = detail.categoryChart
        var rows = chart.prefix(BragPalette.stack.count).enumerated().map { ChartRow(name: $1.categoryName, used: $1.usedAmount, color: BragPalette.stack[$0]) }
        let rest = chart.dropFirst(BragPalette.stack.count).reduce(0) { $0 + $1.usedAmount }
        if rest > 0 { rows.append(ChartRow(name: "그 외", used: rest, color: BragPalette.rest)) }
        return rows
    }

    private func colorOf(_ name: String, _ detail: BragDetail) -> Color {
        let index = detail.categoryChart.prefix(BragPalette.stack.count).firstIndex { $0.categoryName == name }
        return index.map { BragPalette.stack[$0] } ?? BragPalette.rest
    }

    private func budgetPanel(_ detail: BragDetail, rows: [ChartRow]) -> some View {
        let total = detail.totalBudget
        let remaining = total - detail.usedAmount - detail.plannedAmount
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("예산").wpTypography(15, .bold).foregroundStyle(WPColor.bragInk)
                Spacer(minLength: 0)
                Text("총 \(withThousands(total))만원").wpTypography(12, .bold).foregroundStyle(WPColor.primary)
                    .padding(.horizontal, 12).padding(.vertical, 4).background(WPColor.bragPinkWeak, in: Capsule())
            }
            Color.clear.frame(height: 16)
            BragTmoneyRuns(runs: [("\(withThousands(remaining))만원", 30)], color: UIColor(WPColor.bragInk), tracking: -1.35, lineHeight: 30)
            Color.clear.frame(height: 8)
            Text("\(withThousands(total))만원 중 남음").wpTypography(13).foregroundStyle(WPColor.gray400)
            Color.clear.frame(height: 18)
            stackBar(detail, rows: rows)
            Color.clear.frame(height: 18)
            VStack(alignment: .leading, spacing: 11) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in legendRow(row.name, row.used, row.color, emphasis: true) }
                if detail.plannedAmount > 0 { legendRow("사용 예상", detail.plannedAmount, WPColor.bragPlanned, emphasis: false) }
            }
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Self.cardBorder, lineWidth: 1))
    }

    private func stackBar(_ detail: BragDetail, rows: [ChartRow]) -> some View {
        let total = detail.totalBudget
        func frac(_ v: Double) -> Double { total > 0 ? max(0, v / total) : 0 }
        var segments = rows.filter { $0.used > 0 }.map { (frac($0.used), $0.color) }
        if detail.plannedAmount > 0 { segments.append((frac(detail.plannedAmount), WPColor.bragPlanned)) }
        var left = 1.0
        var widths: [(Double, Color)] = []
        for (f, color) in segments {
            let w = min(f, left)
            if w > 0 { widths.append((w, color)); left -= w }
        }
        return GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(Array(widths.enumerated()), id: \.offset) { _, seg in
                    Rectangle().fill(seg.1).frame(width: max(4, geo.size.width * seg.0))
                }
                Spacer(minLength: 0)
            }
            .frame(width: geo.size.width, alignment: .leading)
            .background(WPColor.bragTrack)
            .clipShape(Capsule())
        }
        .frame(height: 12)
    }

    private func legendRow(_ name: String, _ amount: Double, _ color: Color, emphasis: Bool) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(color).frame(width: 9, height: 9)
            Color.clear.frame(width: 10)
            Text(name).wpTypography(13).foregroundStyle(emphasis ? Color(hex: 0x4A3F45) : Self.sub).lineLimit(1)
            Spacer(minLength: 8)
            BragTmoneyRuns(runs: [("\(withThousands(amount))만원", 13)], color: UIColor(emphasis ? WPColor.bragInk : Self.sub))
        }
    }

    // MARK: - 카테고리 묶음

    private struct BragGroup { var name: String; var items: [BragPlanItem]; var subtotal: Double; var used: Double }

    /// 안드로이드 `toGroups` — 지출(결제 기준) 큰 순, 같으면 소계 큰 순. 이름이 비면 "기타".
    private func groups(_ detail: BragDetail) -> [BragGroup] {
        var order: [String] = []
        var buckets: [String: [BragPlanItem]] = [:]
        for item in detail.items {
            let key = item.categoryName.isEmpty ? "기타" : item.categoryName
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(item)
        }
        let made = order.map { name -> BragGroup in
            let list = buckets[name] ?? []
            return BragGroup(name: name, items: list,
                         subtotal: list.reduce(0) { $0 + ($1.amount ?? 0) },
                         used: list.filter { Self.isPaid($0) }.reduce(0) { $0 + ($1.amount ?? 0) })
        }
        return made.enumerated().sorted { a, b in
            if a.element.used != b.element.used { return a.element.used > b.element.used }
            if a.element.subtotal != b.element.subtotal { return a.element.subtotal > b.element.subtotal }
            return a.offset < b.offset
        }.map(\.element)
    }

    /// 완료한 플랜은 결제한 것이다(안드로이드 `PlanRules.isPaid`)
    fileprivate static func isPaid(_ item: BragPlanItem) -> Bool { item.status == "COMPLETED" || item.isPaidRaw == true }

    private func groupSection(_ g: BragGroup, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 소계를 오른쪽 끝으로 날려 보내지 않는다 — 이름과 금액이 붙어 있어야 어느 카테고리 금액인지 읽힌다.
            FlowRow(spacing: 10, lineSpacing: 4, verticalAlignment: .center) {
                RoundedRectangle(cornerRadius: 3, style: .continuous).fill(color).frame(width: 10, height: 10)
                Text(g.name).wpTypography(14, .bold).foregroundStyle(WPColor.bragInk)
                BragTmoneyRuns(runs: [("\(withThousands(g.subtotal))만 원", 14)], color: UIColor(WPColor.bragInk))
                Text("\(g.items.count)장").wpTypography(12).foregroundStyle(WPColor.gray400)
            }
            Color.clear.frame(height: 8)
            Rectangle().fill(WPColor.stone100).frame(height: 1)
            Color.clear.frame(height: 10)
            VStack(spacing: 12) {
                ForEach(g.items) { item in
                    Button {
                        onOpenPlan(BragOpenPlan(item: item, subtotal: g.subtotal, count: g.items.count, color: color))
                    } label: {
                        BragPlanCardBody(item: item)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Self.cardBorder, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 좋아요

    private func likeBar(_ detail: BragDetail) -> some View {
        let tint = detail.liked ? WPColor.primary : Color.white
        return VStack(spacing: 0) {
            Rectangle().fill(WPColor.stone100).frame(height: 1)
            Button(action: onToggleLike) {
                HStack(spacing: 8) {
                    WPMaterialPathIcon(paths: detail.liked ? FeedIconPaths.favorite : FeedIconPaths.favoriteBorder, size: 16, color: tint)
                    Text("좋아요 \(withThousands(detail.likeCount))").wpTypography(15, .bold).foregroundStyle(tint)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(detail.liked ? WPColor.bragPinkWeak : WPColor.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain).disabled(likePending).accessibilityIdentifier("brag.detail.like")
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 16)
            .background(Color.white)
        }
    }
}

/// 웹 `PlanTaskCardBody` readOnly — 모양은 앱 카드와 같되 체크는 버튼이 아니다.
/// 결제와 일정이 **어긋날 때만** 작은 표(`결제함`)를 붙인다.
private struct BragPlanCardBody: View {
    var item: BragPlanItem
    private let faded = Color(hex: 0xA79BA3)

    var body: some View {
        let done = item.status == "COMPLETED"
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous).fill(done ? Color(hex: 0xFFAAB8) : .white)
                    RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(done ? Color(hex: 0xFFAAB8) : BragPalette.rest, lineWidth: 2)
                    if done { WPMaterialPathIcon(paths: WPIconPaths.check, size: 12, color: .white) }
                }
                .frame(width: 19, height: 19).padding(.top, 2)
                .accessibilityLabel(done ? "완료" : "")
                Text(item.title).wpTypography(14.5, .bold, lineHeight: 20)
                    .strikethrough(done, color: faded)
                    .foregroundStyle(done ? faded : WPColor.bragInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            FlowRow(spacing: 6, lineSpacing: 4, verticalAlignment: .center) {
                if !item.categoryName.isEmpty {
                    Text(item.categoryName).wpTypography(11).foregroundStyle(done ? faded : WPColor.primary)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(done ? Color(hex: 0xF2EEF0) : WPColor.bragPinkWeak, in: Capsule())
                }
                Text(item.startDate.flatMap { KstDate(dateString: $0) }?.monthDayText ?? "날짜 미정")
                    .wpTypography(12).foregroundStyle(BragDetailBody.sub)
                if let amount = item.amount, amount != 0 {
                    Text("\(withThousands(amount))만 원").wpTypography(12, .bold).foregroundStyle(done ? faded : WPColor.bragInk)
                }
                // 이제 어긋남은 미리 낸 계약금(`결제함`) 하나뿐이다
                if !done && item.isPaidRaw == true {
                    Text("결제함").wpTypography(11, .bold).foregroundStyle(WPColor.mismatchText)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(WPColor.mismatchBackground, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
            }
            .padding(.leading, 29)
        }
    }
}

/// 웹 `BragPlanSheet` — 상세에서 플랜 한 줄을 눌렀을 때의 **보기 전용** 창(가운데 뜬다).
/// 바꿀 수 있는 것이 하나도 없다. 시각·메모는 공개 범위 밖이라 없다.
private struct BragPlanSheet: View {
    var open: BragOpenPlan
    var onClose: () -> Void
    @Environment(\.openURL) private var openURL
    private let sub = BragDetailBody.sub

    var body: some View {
        let item = open.item
        let done = item.status == "COMPLETED"
        let paid = BragDetailBody.isPaid(item)
        let amount = item.amount ?? 0
        let place = item.location?.trimmingCharacters(in: .whitespaces).nilIfEmpty
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().contentShape(Rectangle()).onTapGesture(perform: onClose)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(open.color).frame(width: 10, height: 10)
                        Text(item.categoryName).wpTypography(12.5, .bold).foregroundStyle(sub)
                    }
                    Color.clear.frame(height: 8)
                    Text(item.title).wpTypography(20, .bold, lineHeight: 27).tracking(-0.4).foregroundStyle(WPColor.bragInk)
                        .fixedSize(horizontal: false, vertical: true).padding(.trailing, 32)
                    // 일정이 끝났는지와 돈이 나갔는지는 다른 축이라 따로 말한다.
                    Color.clear.frame(height: 12)
                    HStack(spacing: 6) {
                        pill(done ? "완료했어요" : "아직 예정이에요", fg: done ? sub : WPColor.primary, bg: done ? Color(hex: 0xF2EEF0) : WPColor.bragPinkWeak)
                        pill(paid ? "결제했어요" : "아직 안 냈어요", fg: paid ? WPColor.mismatchText : sub, bg: paid ? WPColor.mismatchBackground : WPColor.bragChipBg)
                    }
                    Color.clear.frame(height: 20)
                    Rectangle().fill(WPColor.stone100).frame(height: 1)
                    Color.clear.frame(height: 20)
                    VStack(alignment: .leading, spacing: 12) {
                        infoRow("날짜") { Text(longDate(item.startDate)).wpTypography(13.5, .bold).foregroundStyle(WPColor.bragInk) }
                        infoRow("금액") {
                            if item.amount == nil {
                                Text("정하지 않았어요").wpTypography(13.5).foregroundStyle(sub)
                            } else {
                                BragTmoneyRuns(runs: [("\(withThousands(amount))만 원", 19)], color: UIColor(WPColor.bragInk))
                            }
                        }
                        // 장소 줄은 항상 낸다 — 한 장을 자세히 보는 자리라 "없다" 도 정보다.
                        infoRow("장소") {
                            if let place {
                                Text(place).wpTypography(13.5, .bold).foregroundStyle(WPColor.bragInk)
                            } else {
                                Text("등록하지 않았어요").wpTypography(13.5).foregroundStyle(sub)
                            }
                        }
                    }
                    Color.clear.frame(height: 16)
                    mapArea(item, place: place)
                    Color.clear.frame(height: 16)
                    shareLine(item, amount: amount)
                    Color.clear.frame(height: 16)
                    Text("남의 플랜이라 보기만 할 수 있어요.").wpTypography(12).foregroundStyle(WPColor.gray400)
                }
                .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxWidth: 360)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxHeight: 640)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Button(action: onClose) {
                    WPMaterialPathIcon(paths: FeedIconPaths.close, size: 16, color: sub).frame(width: 32, height: 32).contentShape(Circle())
                }.buttonStyle(.plain).accessibilityLabel("닫기").padding(16)
            }
            .padding(16)
        }
    }

    @ViewBuilder private func mapArea(_ item: BragPlanItem, place: String?) -> some View {
        if item.hasCoordinates, let lat = item.lat, let lng = item.lng {
            // Android `BragDetail` — 카카오맵 줌 15, 높이 168
            KakaoMapView(latitude: lat, longitude: lng, zoomLevel: 15)
            .frame(height: 168)
            .background(WPColor.bragTrack)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Color.clear.frame(height: 8)
            Button {
                let name = (place ?? item.title).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
                if let url = URL(string: "https://map.kakao.com/link/map/\(name),\(lat),\(lng)") { openURL(url) }
            } label: {
                HStack(spacing: 4) {
                    WPMaterialPathIcon(paths: WPIconPaths.locationOnOutlined, size: 14, color: WPColor.primary)
                    Text("카카오맵에서 보기").wpTypography(12.5, .bold).foregroundStyle(WPColor.primary)
                }
            }.buttonStyle(.plain)
        } else {
            VStack(spacing: 6) {
                WPMaterialPathIcon(paths: WPIconPaths.locationOnOutlined, size: 16, color: Color(hex: 0xC9BFC5))
                Text(place != nil ? "지도에 표시할 수 없는 장소예요" : "장소를 등록하지 않은 일정이에요").wpTypography(12.5).foregroundStyle(sub)
            }
            .frame(maxWidth: .infinity).frame(height: 96)
            .padding(.horizontal, 16)
            .background(WPColor.bragSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(WPColor.stone200, lineWidth: 1))
        }
    }

    private func shareLine(_ item: BragPlanItem, amount: Double) -> some View {
        let strongFont = Font(WPTypeface.hak.uiFont(12.5, .bold)), font = Font(WPTypeface.hak.uiFont(12.5, .regular))
        let share: Int? = open.subtotal > 0 && amount > 0 ? Int((amount / open.subtotal * 100).rounded()) : nil
        let text: Text
        if open.count <= 1 {
            text = Text("\(item.categoryName) 카테고리에는 이 플랜 ").font(font)
                + Text("하나뿐").font(strongFont).foregroundColor(WPColor.bragInk) + Text("이에요.").font(font)
        } else if let share {
            text = Text("\(item.categoryName) 카테고리 총 ").font(font)
                + Text("\(withThousands(open.subtotal))만 원").font(strongFont).foregroundColor(WPColor.bragInk)
                + Text(" 중 ").font(font) + Text("\(share)%").font(strongFont).foregroundColor(WPColor.primary)
                + Text("를 차지해요.").font(font)
        } else {
            text = Text("\(item.categoryName) 카테고리에 든 플랜 ").font(font)
                + Text("\(open.count)장").font(strongFont).foregroundColor(WPColor.bragInk) + Text(" 가운데 하나예요.").font(font)
        }
        return text.foregroundColor(sub).lineSpacing(20 - 12.5 * 1.2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(WPColor.bragSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func pill(_ text: String, fg: Color, bg: Color) -> some View {
        Text(text).wpTypography(12, .bold).foregroundStyle(fg).padding(.horizontal, 10).padding(.vertical, 4).background(bg, in: Capsule())
    }

    private func infoRow<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: 16) {
            Text(label).wpTypography(13.5).foregroundStyle(sub).frame(width: 56, alignment: .leading)
            content().frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// "2027년 1월 10일 일요일"
    private func longDate(_ startDate: String?) -> String {
        guard let d = startDate.flatMap({ KstDate(dateString: $0) }) else { return "날짜 미정" }
        return "\(d.year)년 \(d.month)월 \(d.day)일 \(d.weekdayShort)요일"
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
