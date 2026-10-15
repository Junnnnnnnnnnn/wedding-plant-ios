import SwiftUI
import UIKit
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 자랑하기 화면들의 색 — 안드로이드 `ui/brag/BragToggle.kt` 의 `BragMuted`·`BragTrack`… 와 같은 값.
/// 공용 `WPColor.swift` 를 건드리지 않으려고 여기서 늘린다.
extension WPColor {
    /// 웹 자랑하기의 따뜻한 회색 글자 `#7a6c74`
    static let bragMuted = Color(hex: 0x7A6C74)
    static let bragTrack = Color(hex: 0xF4EFF2)
    static let bragChipBg = Color(hex: 0xF7F5F6)
    static let bragPinkWeak = Color(hex: 0xFFF2F6)
    static let bragInk = Color(hex: 0x1B0D14)
    /// 막대의 회색 = 아직 안 쓴 예정
    static let bragPlanned = Color(hex: 0xCDBFC7)
    /// 상세 바탕 묶음 (`SoftBg`)
    static let bragSoft = Color(hex: 0xFAF7F9)
}

/// 웹 BragCard `dateLabel` — "2026년 10월 3일 (토) · D-66". 둘 다 없으면 "결혼식 날짜 미정"
func bragDateLabel(_ date: String?, _ dday: Int?) -> String {
    var parts: [String] = []
    if let d = date.flatMap({ KstDate(dateString: $0) }) { parts.append(d.weddingDateText) }
    if let dday { parts.append(dday == 0 ? "D-DAY" : dday > 0 ? "D-\(dday)" : "D+\(-dday)") }
    return parts.isEmpty ? "결혼식 날짜 미정" : parts.joined(separator: " · ")
}

/// 크기가 다른 Tmoney 글자를 한 줄에 — 안드로이드 `buildAnnotatedString` + Regular 파일의 합성 굵기.
/// (SwiftUI `Text` 로는 합성 굵기를 못 내고, ExtraBold 파일로 바꾸면 폭이 달라진다.)
struct BragTmoneyRuns: UIViewRepresentable {
    var runs: [(String, CGFloat)]
    var color: UIColor
    var bold = true
    var tracking: CGFloat = 0
    var lineHeight: CGFloat? = nil

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }
    func updateUIView(_ label: UILabel, context: Context) {
        let text = NSMutableAttributedString()
        for (string, size) in runs {
            text.append(NSAttributedString(string: string, attributes: [
                .font: WPTypeface.tmoney.uiFont(size, .regular), .foregroundColor: color,
                .strokeColor: color, .strokeWidth: bold ? -2.5 : 0, .kern: tracking,
            ]))
        }
        label.attributedText = text
        label.accessibilityLabel = runs.map(\.0).joined()
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let size = uiView.intrinsicContentSize
        return CGSize(width: size.width, height: lineHeight ?? (runs.map(\.1).max() ?? 14) * 1.5)
    }
}

/// 자랑하기 목록 — 안드로이드 `ui/brag/BragScreen.kt`(웹 `app/brag/page.tsx`).
///
/// **피드와 규칙이 정반대다** — 여기는 닉네임을 내는 것이 목적이다.
/// 카드를 누르면 페이지를 옮기지 않고 **거의 꽉 찬 상세**가 뜬다.
struct BragView: View {
    var titleSlot: AnyView? = nil
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var model = BragViewModel()
    @State private var openedId: Int?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    head
                    sortRow

                    if model.loading {
                        ForEach(0..<4, id: \.self) { _ in
                            SkeletonBox(height: 260, corner: 20).padding(.horizontal, 16).padding(.vertical, 10)
                        }
                    } else if model.posts.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(model.posts.enumerated()), id: \.element.bragId) { index, post in
                            BragCard(
                                post: post,
                                likePending: model.likePendingId == post.bragId,
                                onLike: { Task { await model.toggleLike(post, env: env) } },
                                onOpen: { openedId = post.bragId },
                                onUnpublish: post.isMine ? { Task { await model.unpublish(post.bragId, env: env) } } : nil,
                                onHidden: { model.hide(post.bragId) }
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            if AdRules.adAfter(index: index, count: model.posts.count, first: 2, every: 6) {
                                NativeAdSlot(placement: "brag.\(index)", style: .brag, top: 4, bottom: 16)
                            }
                        }

                        if model.hasMore {
                            moreButton
                        }
                    }
                }
                .id(model.loading)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            if let message = model.errorMessage {
                InfoBanner(message: message, actionLabel: "닫기") {
                    model.errorMessage = nil
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WPColor.background)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.load(env: env, replace: true) }
        .onChange(of: env.moderationRevision) { _, _ in Task { await model.load(env: env, replace: true) } }
        // 상세는 **페이지가 아니라 거의 꽉 찬 면**이다(시안 M5-C).
        .fullScreenCover(item: Binding(
            get: { openedId.map(BragSheetTarget.init) },
            set: { if $0 == nil { openedId = nil } }
        )) { target in
            BragDetailSheet(bragId: target.id,
                            onLikeChanged: { model.applyLike(bragId: target.id, liked: $0, count: $1) },
                            onHidden: { model.hide(target.id) })
                .environmentObject(env)
                .presentationBackground(.clear)
        }
    }

    private var head: some View {
        ExploreHead(switcher: titleSlot ?? AnyView(Text("자랑하기").wpTypography(20, .bold).foregroundStyle(.white)),
                    headline: "다른 커플은 어떻게 준비했을까", stats: headerStats,
                    loading: model.loading && model.posts.isEmpty) { EmptyView() }
    }
    private var headerStats: [(String, String)] {
        var stats = [("올라온 플랜", "\(model.total)장")]
        if let my = model.myStatus {
            stats.append(("내 플랜", my.published ? "공개 중" : "비공개"))
            if my.published { stats.append(("받은 좋아요", String(my.likeCount))) }
        }
        return stats
    }

    /// 안드로이드 — 채움 칩 `최신순 · 좋아요순`, 오른쪽에 `N장`
    private var sortRow: some View {
        HStack(spacing: 6) {
            ForEach(BragViewModel.Sort.allCases) { sort in
                let on = model.sort == sort
                Button { Task { await model.setSort(sort, env: env) } } label: {
                    Text(sort.label).wpTypography(13, on ? .bold : .regular)
                        .foregroundStyle(on ? .white : WPColor.bragMuted)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(on ? WPColor.bragInk : WPColor.bragChipBg, in: Capsule())
                }.buttonStyle(.plain).accessibilityIdentifier("brag.sort.\(sort.rawValue)")
            }
            Spacer(minLength: 0)
            Text(verbatim: "\(withThousands(model.total))장").wpTypography(12.5).foregroundStyle(WPColor.gray400)
        }
        .padding(16)
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Text("아직 올라온 플랜이 없어요").wpTypography(15, .bold).foregroundStyle(WPColor.bragInk)
            Color.clear.frame(height: 8)
            Text("홈의 예산 패널에서 자랑하기를 켜면\n우리 플랜이 여기 첫 장으로 올라갑니다.")
                .wpTypography(13, lineHeight: 21).foregroundStyle(WPColor.bragMuted)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24).padding(.vertical, 56)
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(WPColor.stone200, lineWidth: 1))
        .padding(16)
    }

    private var moreButton: some View {
        Button {
            Task { await model.load(env: env, replace: false) }
        } label: {
            Text(model.loadingMore ? "불러오는 중" : "더 보기")
                .wpTypography(13.5, .bold).foregroundStyle(WPColor.bragMuted)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .overlay(Capsule().strokeBorder(WPColor.stone200, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(model.loadingMore)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

/// `sheet(item:)` 이 `Identifiable` 을 요구해서 감싼다.
private struct BragSheetTarget: Identifiable, Hashable {
    var id: Int
}

// MARK: - 카드

/// 안드로이드 `BragCard`(웹 시안 A안) — 카드가 **커플과 날짜로 시작한다**
/// (앱의 읽는 순서 "누구의·언제 → 얼마 → 무엇을").
struct BragCard: View {
    var post: BragPost
    var likePending: Bool
    var onLike: () -> Void
    var onOpen: () -> Void
    var onUnpublish: (() -> Void)? = nil
    var onHidden: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(post.nickname).wpTypography(17, .bold).tracking(-0.34).foregroundStyle(WPColor.bragInk).lineLimit(1)
                Color.clear.frame(height: 4)
                Text(bragDateLabel(post.weddingDate, post.dday)).wpTypography(13).foregroundStyle(WPColor.bragMuted)
                Color.clear.frame(height: 16)
                BragTmoneyRuns(runs: [(withThousands(remaining), 30), ("만 원", 15)], color: UIColor(WPColor.bragInk),
                               tracking: -1.2, lineHeight: 30)
                Color.clear.frame(height: 6)
                Text("\(withThousands(post.totalBudget))만 원 중 남음").wpTypography(13).foregroundStyle(WPColor.bragMuted)
                // 분홍 = 실제 지출, 회색 = 아직 안 쓴 예정. 홈 막대와 뜻이 같다.
                Color.clear.frame(height: 12)
                budgetBar
                Color.clear.frame(height: 8)
                Text("사용 \(withThousands(post.usedAmount)) · 예정 \(withThousands(post.plannedAmount))")
                    .wpTypography(12).foregroundStyle(WPColor.gray400)
                if !post.categories.isEmpty {
                    Color.clear.frame(height: 16)
                    FlowRow(spacing: 6, lineSpacing: 6) {
                        ForEach(post.categories, id: \.self) { name in
                            Text(name).wpTypography(12).foregroundStyle(WPColor.bragMuted)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(WPColor.bragChipBg, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                }
                // 금액 다음으로 궁금한 값 — "얼마나 했나"
                Color.clear.frame(height: 16)
                BragPlanDoneLine(planCount: post.planCount, doneCount: post.doneCount)
                if (1...32).contains(post.planCount) {
                    Color.clear.frame(height: 8)
                    BragTicks(done: post.doneCount, total: post.planCount)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            Color.clear.frame(height: 16)
            Rectangle().fill(WPColor.stone100).frame(height: 1)
            Color.clear.frame(height: 12)
            footer
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(WPColor.stone200.opacity(0.8), lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 1.5, y: 1)
        // `children: .contain` 이 없으면 XCUITest 가 `otherElements` 로 못 찾는다.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("brag.card")
    }

    private var remaining: Double { post.totalBudget - post.usedAmount - post.plannedAmount }

    private var budgetBar: some View {
        let total = post.totalBudget
        let used = total > 0 ? min(1, max(0, post.usedAmount / total)) : 0
        let planned = total > 0 ? min(1 - used, max(0, post.plannedAmount / total)) : 0
        return GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle().fill(WPColor.primary).frame(width: geo.size.width * used)
                Rectangle().fill(WPColor.bragPlanned).frame(width: geo.size.width * planned)
                Spacer(minLength: 0)
            }
            .background(WPColor.bragTrack)
            .clipShape(Capsule())
        }
        .frame(height: 10)
    }

    @ViewBuilder private var footer: some View {
        HStack(spacing: 0) {
            if post.isMine {
                Text("내 플랜").wpTypography(12, .bold).foregroundStyle(WPColor.primary)
                Color.clear.frame(width: 8)
                WPMaterialPathIcon(paths: FeedIconPaths.favorite, size: 14, color: WPColor.gray400)
                Color.clear.frame(width: 4)
                Text(verbatim: withThousands(post.likeCount)).wpTypography(12).foregroundStyle(WPColor.gray400)
                Spacer(minLength: 0)
                if let onUnpublish {
                    Button(action: onUnpublish) {
                        Text("내려두기").wpTypography(12, .bold).foregroundStyle(WPColor.bragMuted)
                            .padding(.horizontal, 10).padding(.vertical, 4).contentShape(Capsule())
                    }.buttonStyle(.plain)
                }
            } else {
                // 남의 플랜에만 — 자랑하기는 **닉네임이 공개**라 신고·차단이 피드보다 더 필요하다.
                ModerationMenu(targetType: "BRAG", targetId: post.bragId, onHidden: onHidden).offset(x: -6)
                Spacer(minLength: 0)
                BragLikePill(liked: post.liked, count: post.likeCount, pending: likePending, action: onLike)
            }
        }
    }
}

/// 안드로이드 `LikePill`
struct BragLikePill: View {
    var liked: Bool
    var count: Int
    var pending: Bool
    var action: () -> Void
    var body: some View {
        let tint = liked ? WPColor.primary : WPColor.bragMuted
        Button(action: action) {
            HStack(spacing: 6) {
                WPMaterialPathIcon(paths: liked ? FeedIconPaths.favorite : FeedIconPaths.favoriteBorder, size: 14, color: tint)
                Text(verbatim: withThousands(count)).wpTypography(12.5, .bold).foregroundStyle(tint)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(liked ? WPColor.bragPinkWeak : WPColor.bragChipBg, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(pending)
        .accessibilityLabel(liked ? "좋아요 취소" : "좋아요")
    }
}

/// 안드로이드 `PlanDoneLine` — `플랜 12개 · 완료 5개`
struct BragPlanDoneLine: View {
    var planCount: Int
    var doneCount: Int
    var onFill = false
    var body: some View {
        let sub = onFill ? Color.white.opacity(0.7) : WPColor.gray400
        let strong = onFill ? Color.white : WPColor.bragInk
        let small = Font(WPTypeface.hak.uiFont(12, .regular)), big = Font(WPTypeface.hak.uiFont(13, .bold))
        (Text("플랜 ").font(small).foregroundColor(sub)
         + Text("\(planCount)개").font(big).foregroundColor(strong)
         + Text(" · 완료 ").font(small).foregroundColor(sub)
         + Text("\(doneCount)개").font(big).foregroundColor(strong))
            .lineLimit(1)
            .padding(.vertical, 3)
    }
}

/// 완료 개수 눈금. 숫자보다 먼저 읽힌다.
struct BragTicks: View {
    var done: Int
    var total: Int
    var onFill = false
    var max = 40
    var body: some View {
        if total > 0 && total <= max {
            HStack(spacing: 2) {
                ForEach(0..<total, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(i < done ? (onFill ? Color.white : WPColor.primary) : (onFill ? Color.white.opacity(0.2) : WPColor.bragTrack))
                        .frame(maxWidth: .infinity).frame(height: 7)
                }
            }
        }
    }
}

/// 홈 예산 패널의 스택 색. **왼쪽 범례 색과 오른쪽 묶음 머리 색이 같아야 한다.**
enum BragPalette {
    /// 웹 `HomeDashboard` 의 `STACK_COLORS`.
    static let stack: [Color] = [
        Color(hex: 0xEE2B8C),
        Color(hex: 0xFF7AB5),
        Color(hex: 0xFFA8CD),
        Color(hex: 0xFFD0E3),
    ]
    /// 상위 4개 밖 카테고리. 무채색.
    static let rest = Color(hex: 0xE6DBE2)

    /// 묶음 색. `nil` 이면 무채색이다 —
    /// **`i % 4` 로 돌리지 말 것.** 다섯 번째가 첫 번째와 같은 분홍이 된다.
    static func color(_ index: Int?) -> Color {
        guard let index, index < stack.count else { return rest }
        return stack[index]
    }
}
