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

private struct RoomCard: View {
    var room: Plan
    var index: Int
    var onOpenChat: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader(index: index, ownerName: room.ownerName)

            Spacer().frame(height: 24)

            // 백엔드가 members 를 생략해도 목록이 깨지지 않도록 방어한다 (웹 main 과 동일).
            SectionLabel("참여 멤버")
            Spacer().frame(height: 12)
            if room.members.isEmpty {
                Text("아직 참여한 멤버가 없어요")
                    .font(WPFont.hak(12))
                    .foregroundStyle(WPColor.gray400)
            } else {
                HStack(spacing: -8) {
                    ForEach(Array(room.members.enumerated()), id: \.element.id) { i, member in
                        ZStack(alignment: .top) {
                            MemberAvatar(name: member.name, index: i, size: 40)
                            if member.permission == .owner {
                                // 방장 표시: 아바타 위에 얹히는 왕관 뱃지
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(Color(hex: 0x78350F))
                                    .frame(width: 16, height: 16)
                                    .background(Color(hex: 0xFBBF24), in: Circle())
                                    .offset(y: -6)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }

            Spacer().frame(height: 24)

            if !room.chatRooms.isEmpty {
                SectionLabel("채팅방")
                Spacer().frame(height: 12)
                ForEach(room.chatRooms) { chatRoom in
                    Button { onOpenChat(chatRoom.id) } label: {
                        ChatRoomRow(name: chatRoom.name)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("planlist.chat.\(chatRoom.id)")
                    Spacer().frame(height: 8)
                }
                Spacer().frame(height: 16)
            }

            HStack(alignment: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel("REMAINING BUDGET")
                    Spacer().frame(height: 4)
                    Text("\(wpThousands(room.remainingBudget))만 원")
                        .font(WPFont.hak(20, .black))
                        .foregroundStyle(WPColor.textPrimary)
                }
                Spacer(minLength: 8)
                Text("/ \(wpThousands(room.budget))만 원")
                    .font(WPFont.hak(12, .bold))
                    .foregroundStyle(WPColor.gray400)
            }

            Spacer().frame(height: 12)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(WPColor.primary.opacity(0.04))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [WPColor.primary, Color(hex: 0xFF94A1)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(WPColor.cardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }

    /// 예산이 0이면 나눗셈이 무한대가 되어 막대가 꽉 찬 것처럼 보인다. 0~1로 고정한다.
    private var progress: CGFloat {
        guard room.budget > 0 else { return 0 }
        return min(max(CGFloat(room.remainingBudget) / CGFloat(room.budget), 0), 1)
    }
}

/// 웹: `Room #1` 검정 알약 + 하트, 그 아래 "OOO의 웨딩 플랜", 우측 화살표 버튼
private struct CardHeader: View {
    var index: Int
    var ownerName: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(verbatim: "Room #\(index + 1)")
                        .font(WPFont.hak(10, .black))
                        .tracking(1.5)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(WPColor.textPrimary, in: Capsule())

                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(WPColor.primary)
                }

                Spacer().frame(height: 4)

                // 백엔드 필드 오타 onwerName 을 그대로 매핑한 값이다.
                Text("\(ownerName.isEmpty ? "이름 없음" : ownerName)의 웨딩 플랜")
                    .font(WPFont.hak(24, .black))
                    .foregroundStyle(WPColor.textPrimary)
            }

            Spacer(minLength: 8)

            Image(systemName: "arrow.right")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(WPColor.primary)
                .frame(width: 40, height: 40)
                .background(
                    WPColor.primary.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        }
    }
}

/// 웹: `text-[10px] font-extrabold text-gray-300 uppercase tracking-widest`
private struct SectionLabel: View {
    var text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(WPFont.hak(10, .black))
            .tracking(1.5)
            .foregroundStyle(WPColor.gray300)
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
