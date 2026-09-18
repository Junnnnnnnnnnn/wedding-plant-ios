import SwiftUI
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 자랑하기 목록 — 웹 `app/brag/page.tsx`.
///
/// **단위는 플랜 전체다.** 홈 예산 패널의 토글을 켜면 내 웨딩 플랜 한 장이 통째로
/// 여기 올라간다.
///
/// **피드와 규칙이 정반대다** — 여기는 닉네임을 내는 것이 목적이다.
/// 피드 코드를 베껴 올 때 익명 처리를 함께 가져오지 말 것.
///
/// 웹은 핀터레스트식 벽돌(`column-count`)인데, **폰은 한 열이라 차이가 없다** —
/// 카드 높이가 달라도 톱니가 생기지 않는다. 넓은 화면 전용 배치는 앱에 옮기지
/// 않는다.
struct BragView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var model = BragViewModel()
    @State private var openedId: Int?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    head

                    if model.loading {
                        ForEach(0..<3, id: \.self) { _ in SkeletonCardBlock() }
                    } else if model.posts.isEmpty {
                        emptyState
                    } else {
                        ForEach(model.posts) { post in
                            BragCard(
                                post: post,
                                likePending: model.likePendingId == post.bragId,
                                onLike: { Task { await model.toggleLike(post, env: env) } },
                                onOpen: { openedId = post.bragId }
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
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
        // 상세는 **페이지가 아니라 모달**이다(시안 M5-C).
        .sheet(item: Binding(
            get: { openedId.map(BragSheetTarget.init) },
            set: { if $0 == nil { openedId = nil } }
        )) { target in
            BragDetailSheet(bragId: target.id)
                .environmentObject(env)
        }
    }

    private var head: some View {
        BrandHead {
            Text("자랑하기")
                .font(WPFont.hak(18, .bold))
                .tracking(-0.02 * 18)
                .foregroundStyle(.white)

            Spacer().frame(height: 10)

            Text("남의 웨딩 플랜을 그대로 들여다봅니다")
                .font(WPFont.hak(14))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("아직 올라온 플랜이 없어요")
                .font(WPFont.hak(16, .bold))
                .foregroundStyle(WPColor.fgNeutral)
            Text("홈 예산 패널에서 내 플랜을 올릴 수 있어요")
                .font(WPFont.hak(13))
                .foregroundStyle(WPColor.fgSubtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    private var moreButton: some View {
        Button {
            Task { await model.load(env: env, replace: false) }
        } label: {
            Text(model.loadingMore ? "불러오는 중..." : "더 보기")
                .font(WPFont.hak(14, .bold))
                .foregroundStyle(WPColor.fgMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(model.loadingMore)
        .padding(.horizontal, 16)
    }
}

/// `sheet(item:)` 이 `Identifiable` 을 요구해서 감싼다.
private struct BragSheetTarget: Identifiable, Hashable {
    var id: Int
}

// MARK: - 카드

/// 목록 카드. **앱의 것을 그대로 쓴다** — 예산 블록은 홈 예산 패널과 같은 값이다.
struct BragCard: View {
    var post: BragPost
    var likePending: Bool
    var onLike: () -> Void
    var onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // **닉네임을 낸다.** 이 화면의 목적이다.
                Text(post.nickname.isEmpty ? "이름 없음" : post.nickname)
                    .font(WPFont.tmoney(16, .bold))
                    .foregroundStyle(WPColor.textPrimary)
                    .lineLimit(1)
                if let dday = post.dday {
                    Text(ddayText(dday))
                        .font(WPFont.hak(12.5))
                        .foregroundStyle(WPColor.fgSubtle)
                }
                Spacer(minLength: 0)
                if post.isMine {
                    Text("내 플랜")
                        .font(WPFont.hak(11, .bold))
                        .foregroundStyle(WPColor.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(hex: 0xFFF2F6), in: Capsule())
                }
            }

            Spacer().frame(height: 14)

            budgetBlock

            if !post.categories.isEmpty {
                Spacer().frame(height: 12)
                FlowRow(spacing: 6, lineSpacing: 6) {
                    ForEach(post.categories.prefix(6), id: \.self) { name in
                        CategoryTag(name: name)
                    }
                }
            }

            Spacer().frame(height: 12)

            HStack(spacing: 8) {
                Text("플랜 \(post.planCount) · 완료 \(post.doneCount)")
                    .font(WPFont.hak(12.5))
                    .foregroundStyle(WPColor.fgSubtle)
                Spacer(minLength: 0)
                likeButton
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(WPColor.cardBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        // `children: .contain` 이 없으면 XCUITest 가 `otherElements` 로 못 찾는다 —
        // 식별자만 붙여 두면 하네스가 카드를 잡지 못해 상세가 안 찍힌다.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("brag.card")
    }

    /// 홈 예산 패널과 **같은 짜임** — 큰 숫자 + `h-3` 스택 막대.
    /// 분홍=실제 지출, 회색=아직 안 쓴 예정, 남은 트랙=여유.
    private var budgetBlock: some View {
        let total = max(post.totalBudget, 1)
        let usedRatio = min(1, Double(post.usedAmount) / Double(total))
        let plannedRatio = min(1 - usedRatio, Double(post.plannedAmount) / Double(total))

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(withThousands(post.totalBudget))
                    .font(WPFont.tmoney(26, .bold))
                    .tracking(-0.03 * 26)
                    .foregroundStyle(WPColor.textPrimary)
                Text("만원")
                    .font(WPFont.hak(13))
                    .foregroundStyle(WPColor.fgSubtle)
            }

            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle().fill(WPColor.primary)
                        .frame(width: geo.size.width * usedRatio)
                    Rectangle().fill(BudgetDonutView.plannedColor)
                        .frame(width: geo.size.width * plannedRatio)
                    Rectangle().fill(Color(hex: 0xF4EFF2))
                }
                .clipShape(Capsule())
            }
            .frame(height: 12)

            Text("지출 \(withThousands(post.usedAmount)) · 예정 \(withThousands(post.plannedAmount))만원")
                .font(WPFont.hak(12))
                .foregroundStyle(WPColor.fgSubtle)
        }
    }

    private var likeButton: some View {
        Button(action: onLike) {
            HStack(spacing: 5) {
                Image(systemName: post.liked ? "heart.fill" : "heart")
                    .font(.system(size: 13, weight: .semibold))
                if post.likeCount > 0 {
                    Text("\(post.likeCount)")
                        .font(WPFont.tmoney(12.5, .bold))
                }
            }
            .foregroundStyle(post.liked ? WPColor.primary : WPColor.fgSubtle)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(post.liked ? Color(hex: 0xFFF2F6) : WPColor.fill, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(likePending)
        .opacity(likePending ? 0.6 : 1)
        .accessibilityLabel(post.liked ? "좋아요 취소" : "좋아요")
    }

    private func ddayText(_ dday: Int) -> String {
        if dday > 0 { return "D-\(dday)" }
        if dday == 0 { return "D-Day" }
        return "D+\(abs(dday))"
    }
}

private struct SkeletonCardBlock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonBox(width: 140, height: 20)
            SkeletonBox(width: 120, height: 28)
            SkeletonBox(height: 12, corner: 6)
            SkeletonBox(width: 180, height: 14)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(WPColor.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
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
