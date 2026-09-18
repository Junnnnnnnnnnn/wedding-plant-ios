import SwiftUI
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 웹 `/plan-list` 대응 — 내가 참여 중인 플랜 목록.
///
/// 안드로이드 `ui/planlist/PlanListScreen.kt` 를 1:1 로 옮긴 것.
struct PlanListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var push: PushService
    @StateObject private var model = PlanListViewModel()
    /// 웹은 `/chat/{id}` 로 페이지를 통째로 바꾼다. 여기서는 전체 화면으로 덮는다.
    @State private var openChatRoom: ChatRoomRef?

    var body: some View {
        ZStack {
            WPScreenBackground()

            VStack(alignment: .leading, spacing: 0) {
                Text("참여 플랜")
                    .font(WPFont.hak(24, .bold))
                    .foregroundStyle(WPColor.textPrimary)
                    .padding(.leading, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                if let message = model.errorMessage {
                    InfoBanner(message: message, actionLabel: "닫기") {
                        model.errorMessage = nil
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }

                content
            }
        }
        .task { await model.load(env: env) }
        .fullScreenCover(item: $openChatRoom) { room in
            ChatView(chatRoomId: room.id)
                .environmentObject(env)
                .environmentObject(push)
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.loading {
            ProgressView()
                .tint(WPColor.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.isGuest {
            Text("로그인하면 함께 준비하는 플랜을 볼 수 있어요.")
                .font(WPFont.hak(14))
                .foregroundStyle(WPColor.gray400)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.rooms.isEmpty {
            Text("참여 중인 플랜이 없어요")
                .font(WPFont.hak(15))
                .foregroundStyle(WPColor.gray400)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(model.rooms.enumerated()), id: \.element.id) { index, room in
                        RoomCard(room: room, index: index) { chatRoomId in
                            openChatRoom = ChatRoomRef(id: chatRoomId)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
    }
}

/// `fullScreenCover(item:)` 은 Identifiable 을 요구한다.
private struct ChatRoomRef: Identifiable, Hashable {
    var id: Int
}

// MARK: - 카드

/// 참여 플랜 카드.
///
/// **읽는 순서가 곧 중요도다** — 이름·D-day → 남은 예산 → 대화.
///
/// 예전에는 `MEMBERS`/`CHANNELS` 같은 `10px` 회색 대문자 라벨과 검정 `Room #N`
/// 알약이 먼저 눈에 들어와 정작 남은 예산이 카드 맨 아래에서 묻혔다. 라벨은
/// `12.5pt` 회색 **문장**(`대화 3`)으로 바꾸고 알약은 없앴다. 참여 멤버 얼굴은
/// 제목 오른쪽으로 올라가 한 줄을 벌었다.
///
/// **카드에 `transform`(누를 때 줄어드는 효과)을 붙이지 말 것.** 안쪽 채팅방
/// 줄을 누를 때 카드까지 같이 줄어든다 — 누른 느낌은 배경색으로 낸다.
private struct RoomCard: View {
    var room: Plan
    var index: Int
    var onOpenChat: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if let dateLine {
                Spacer().frame(height: 4)
                Text(dateLine)
                    .font(WPFont.hak(13))
                    .foregroundStyle(WPColor.fgSubtle)
            }

            Spacer().frame(height: 18)

            budgetBlock

            if !room.chatRooms.isEmpty {
                Spacer().frame(height: 18)
                Text("대화 \(room.chatRooms.count)")
                    .font(WPFont.hak(12.5))
                    .foregroundStyle(WPColor.gray400)
                Spacer().frame(height: 8)
                ForEach(room.chatRooms) { chatRoom in
                    Button { onOpenChat(chatRoom.id) } label: {
                        ChatRoomRow(name: chatRoom.name)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("planlist.chat.\(chatRoom.id)")
                    Spacer().frame(height: 6)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(WPColor.cardBorder, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            // 백엔드 필드 오타 `onwerName` 을 그대로 매핑한 값이다.
            Text(room.ownerName.isEmpty ? "이름 없음" : room.ownerName)
                .font(WPFont.tmoney(18, .bold))
                .tracking(-0.02 * 18)
                .foregroundStyle(WPColor.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            // 얼굴은 제목 오른쪽으로 올라가 한 줄을 번다.
            if !room.members.isEmpty {
                HStack(spacing: -8) {
                    ForEach(Array(room.members.prefix(3).enumerated()), id: \.element.id) { i, member in
                        MemberAvatar(name: member.name, index: i, size: 26)
                    }
                }
            }
        }
    }

    /// 홈 상단과 **같은 문장** — `2026년 12월 31일 · D-131`.
    private var dateLine: String? {
        guard let date = KstDate(dateString: room.weddingDate) else { return nil }
        return "\(date.weddingDateText) · \(PlanRules.dDayLabel(weddingDate: date))"
    }

    /// 홈 예산 패널과 같은 짜임 — 큰 숫자 + "N만원 중 남음" + `h-3` 트랙.
    ///
    /// **막대는 분홍=실제 지출, 회색=아직 안 쓴 예정, 남은 트랙=여유**로 홈과 뜻이
    /// 같다. 예전에는 분홍이 "남은 비율" 이라 아무것도 안 썼을 때 막대가 꽉 차
    /// 보였다.
    private var budgetBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 시안은 숫자 26pt · 단위 14pt 로 **크기 대비**를 준다. 같은 크기면
            // "만 원" 이 숫자만큼 무거워져 금액이 덜 읽힌다.
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(wpThousands(room.remainingBudget))
                    .font(WPFont.tmoney(26, .bold))
                    .tracking(-0.04 * 26)
                Text("만 원")
                    .font(WPFont.tmoney(14, .bold))
            }
            .foregroundStyle(WPColor.fgNeutral)

            Spacer().frame(height: 14)

            Text("\(wpThousands(room.budget))만 원 중 남음")
                .font(WPFont.hak(13))
                .foregroundStyle(WPColor.fgMuted)

            Spacer().frame(height: 10)

            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle().fill(WPColor.primary)
                        .frame(width: geo.size.width * usedRatio)
                    if plannedAmount > 0 {
                        Rectangle().fill(WPColor.fgDisabled)
                            // 예산을 넘기면 작은 몫이 사실상 사라진다. 최소 4pt 를 남긴다.
                            .frame(width: max(4, geo.size.width * plannedRatio))
                    }
                    Rectangle().fill(Color(hex: 0xF4EFF2))
                }
                .clipShape(Capsule())
            }
            .frame(height: 12)
        }
    }

    /// 예정 몫. `remainingBudget = budget - (예정 + 사용)` 이므로
    /// **지출 = (budget - remaining) - 예정** 이다.
    private var plannedAmount: Int { max(0, room.plannedUseAmount) }
    private var usedAmount: Int { max(0, room.budget - room.remainingBudget - plannedAmount) }

    private var usedRatio: CGFloat {
        guard room.budget > 0 else { return 0 }
        return min(1, CGFloat(usedAmount) / CGFloat(room.budget))
    }

    private var plannedRatio: CGFloat {
        guard room.budget > 0 else { return 0 }
        return min(1 - usedRatio, CGFloat(plannedAmount) / CGFloat(room.budget))
    }
}

private struct ChatRoomRow: View {
    var name: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left")
                .font(.system(size: 17))
                .foregroundStyle(WPColor.primary)
                .frame(width: 40, height: 40)
                .background(
                    WPColor.primary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

            Text(name.isEmpty ? "채팅방" : name)
                .font(WPFont.hak(14, .bold))
                .foregroundStyle(WPColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.system(size: 13))
                .foregroundStyle(WPColor.gray300)
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(WPColor.stone100, lineWidth: 1)
        )
    }
}
