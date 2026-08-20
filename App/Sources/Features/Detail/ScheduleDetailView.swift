import SwiftUI
import WPModels
import WPUtils

/// 웹 `app/schedule-detail/page.tsx` 이식.
///
/// 웹은 장소가 있으면 카카오맵을 카드 안에 임베드하지만, 여기서는 **카카오맵 iOS SDK 를
/// 아직 붙이지 않아** 장소명과 "카카오맵에서 보기" 링크까지만 제공한다.
/// (일정 추가 화면 작업과 함께 처리)
struct ScheduleDetailView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @StateObject private var model: ScheduleDetailViewModel
    @State private var showDeleteConfirm = false
    @State private var showEdit = false

    init(scheduleId: Int) {
        _model = StateObject(wrappedValue: ScheduleDetailViewModel(scheduleId: scheduleId))
    }

    var body: some View {
        ZStack {
            WPScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BackPill { dismiss() }

                    if model.loading {
                        LoadingCard()
                    } else if let detail = model.detail {
                        Spacer().frame(height: 24)
                        HeroCard(detail: detail)

                        Spacer().frame(height: 8)
                        LocationCard(detail: detail) { url in
                            openURL(url)
                        }

                        if let memo = detail.memo, !memo.trimmingCharacters(in: .whitespaces).isEmpty {
                            Spacer().frame(height: 16)
                            MemoCard(memo: memo)
                        }

                        let extras = detail.addCategoryNameList.filter {
                            !$0.trimmingCharacters(in: .whitespaces).isEmpty
                        }
                        if !extras.isEmpty {
                            Spacer().frame(height: 12)
                            ExtraCategoriesCard(categories: extras)
                        }

                        Spacer().frame(height: 16)
                        ActionButtons(deleting: model.deleting) {
                            showEdit = true
                        } onDelete: {
                            showDeleteConfirm = true
                        }
                    } else {
                        ErrorCard(message: model.errorMessage) {
                            Task { await model.load(env: env, guest: guest) }
                        } onHome: {
                            dismiss()
                        }
                    }

                    if let message = model.errorMessage, model.detail != nil {
                        Spacer().frame(height: 12)
                        InfoBanner(message: message, actionLabel: "닫기") {
                            model.errorMessage = nil
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden()
        .task { await model.load(env: env, guest: guest) }
        .fullScreenCover(isPresented: $showEdit) {
            // 수정은 추가와 같은 화면이다. editId 만 넘기면 상세를 불러와 채운다.
            AddPlanView(editId: model.scheduleId) {
                Task { await model.load(env: env, guest: guest) }
            }
            .environmentObject(env)
            .environmentObject(guest)
        }
        .onChange(of: model.deleted) { _, deleted in
            if deleted { dismiss() }
        }
        .onChange(of: model.sessionExpired) { _, expired in
            if expired { dismiss() }
        }
        // overlay 로 띄우면 딤이 하단 탭바를 덮지 못한다. 탭바는 이 화면의 형제 뷰라
        // 화면 안쪽 overlay 범위 밖이기 때문이다. 배경이 투명한 전체 화면으로 올린다.
        .fullScreenCover(isPresented: $showDeleteConfirm) {
            DeleteConfirmDialog(deleting: model.deleting) {
                showDeleteConfirm = false
            } onConfirm: {
                showDeleteConfirm = false
                Task { await model.delete(env: env, guest: guest) }
            }
            .presentationBackground(.clear)
        }
    }
}

// MARK: - 삭제 확인

/// 웹 main 의 삭제 확인 다이얼로그 이식.
///
/// **취소가 왼쪽, 삭제가 오른쪽**이다. 순서를 바꾸지 말 것 — 기본 다이얼로그는
/// 확인 버튼이 오른쪽에 좁게 붙어, 실제로 취소 대신 삭제를 눌러 플랜을 날린 적이 있다.
private struct DeleteConfirmDialog: View {
    var deleting: Bool
    var onDismiss: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                Text("이 플랜을 삭제할까요?")
                    .font(WPFont.hak(18, .bold))
                    .foregroundStyle(WPColor.textPrimary)

                Spacer().frame(height: 8)

                Text("삭제하면 되돌릴 수 없습니다.")
                    .font(WPFont.hak(14))
                    .foregroundStyle(WPColor.gray500)

                Spacer().frame(height: 20)

                HStack(spacing: 8) {
                    Button(action: onDismiss) {
                        Text("취소")
                            .font(WPFont.hak(14, .bold))
                            .foregroundStyle(WPColor.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(WPColor.gray200, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onConfirm) {
                        Text(deleting ? "삭제 중..." : "삭제하기")
                            .font(WPFont.hak(14, .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                WPColor.primary.opacity(deleting ? 0.6 : 1),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(deleting)
                }
            }
            .padding(24)
            .frame(maxWidth: 384)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - 조각들

/// 웹: 흰 반투명 알약 + 그림자, `#ee2b8c` 텍스트
private struct BackPill: View {
    var onBack: () -> Void

    var body: some View {
        Button(action: onBack) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .semibold))
                Text("뒤로가기")
                    .font(WPFont.hak(16, .bold))
            }
            .foregroundStyle(WPColor.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.85), in: Capsule())
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("detail.back")
    }
}

private struct LoadingCard: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(WPColor.primary)
            Text("불러오는 중...")
                .font(WPFont.hak(16, .semibold))
                .foregroundStyle(WPColor.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
    }
}

private struct ErrorCard: View {
    var message: String?
    var onRetry: () -> Void
    var onHome: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("플랜을 찾을 수 없어요")
                .font(WPFont.hak(18, .semibold))
                .foregroundStyle(WPColor.primary)

            Spacer().frame(height: 8)

            Text(message ?? "")
                .font(WPFont.hak(14))
                .foregroundStyle(WPColor.stone500)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 16)

            HStack(spacing: 12) {
                Button(action: onHome) {
                    Text("돌아가기")
                        .font(WPFont.hak(14, .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(WPColor.primary, in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onRetry) {
                    Text("다시 시도")
                        .font(WPFont.hak(14, .semibold))
                        .foregroundStyle(WPColor.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .overlay(Capsule().stroke(WPColor.primary, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.top, 40)
    }
}

/// 웹: `bg-[#f14d8e] rounded-[32px] p-7` + 우상단 상태 스티커
private struct HeroCard: View {
    var detail: ScheduleDetail

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(detail.categoryName)
                        .font(WPFont.hak(12, .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer().frame(height: 6)

                Text(detail.title)
                    .font(WPFont.tmoney(24, .black)) // 웹 font-user-content
                    .foregroundStyle(.white)

                Spacer().frame(height: 6)

                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(dateText)
                        .font(WPFont.hak(12, .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Spacer().frame(height: 12)
                Rectangle()
                    .fill(.white.opacity(0.25))
                    .frame(height: 1)
                Spacer().frame(height: 12)

                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("지출 금액")
                            .font(WPFont.hak(12))
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer().frame(height: 6)
                        Text(amountText)
                            .font(WPFont.hak(24, .black))
                            .foregroundStyle(.white)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("결제 방식")
                            .font(WPFont.hak(12))
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer().frame(height: 2)
                        Text(detail.payTypeLabel)
                            .font(WPFont.hak(14, .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Color.white.opacity(0.2),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(hex: 0xF14D8E),
                in: RoundedRectangle(cornerRadius: 32, style: .continuous)
            )
            .shadow(color: WPColor.primary.opacity(0.3), radius: 16, y: 8)

            StatusSticker(completed: detail.isCompleted)
                .offset(x: 16, y: -28)
        }
    }

    private var dateText: String {
        detail.startDate.flatMap { KstDate(dateString: $0) }?.weddingDateText ?? "일정 미정"
    }

    private var amountText: String {
        guard let amount = detail.amount else { return "미정" }
        return "\(wpThousands(amount))만 원"
    }
}

/// 웹: 96px 원형 스티커, 완료=초록 +12°, 예정=주황 -12°, 흰 테두리 4px
private struct StatusSticker: View {
    var completed: Bool

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: completed ? "checkmark" : "clock")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
            Text(completed ? "완료" : "예정")
                .font(WPFont.hak(14, .black))
                .tracking(1)
                .foregroundStyle(.white)
        }
        .frame(width: 88, height: 88)
        .background(
            LinearGradient(
                colors: completed
                    ? [Color(hex: 0x4ADE80), Color(hex: 0x16A34A)]
                    : [Color(hex: 0xFDBA74), Color(hex: 0xF97316)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: Circle()
        )
        .padding(4)
        .background(Color.white, in: Circle())
        .rotationEffect(.degrees(completed ? 12 : -12))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .animation(.spring(response: 0.4, dampingFraction: 0.5), value: completed)
    }
}

private struct InfoCard<Content: View>: View {
    var symbol: String
    var iconTint: Color
    var iconBackground: [Color]
    var label: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(iconTint)
                .padding(8)
                .background(
                    LinearGradient(
                        colors: iconBackground,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(WPFont.hak(12, .bold))
                    .tracking(0.6)
                    .foregroundStyle(WPColor.primary.opacity(0.55))
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

private struct LocationCard: View {
    var detail: ScheduleDetail
    var onOpenMap: (URL) -> Void

    var body: some View {
        InfoCard(
            symbol: "mappin.circle.fill",
            iconTint: Color(hex: 0x4A90E2),
            iconBackground: [Color(hex: 0xE5F3FF), Color(hex: 0xD0E7FF)],
            label: "장소"
        ) {
            Text(locationText)
                .font(WPFont.tmoney(14, .bold))
                .foregroundStyle(WPColor.textPrimary)

            if let url = detail.kakaoMapURL {
                Spacer().frame(height: 8)
                Button {
                    onOpenMap(url)
                } label: {
                    Text("카카오맵에서 보기")
                        .font(WPFont.hak(12, .semibold))
                        .foregroundStyle(WPColor.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(Capsule().stroke(WPColor.primary, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var locationText: String {
        guard let location = detail.location,
              !location.trimmingCharacters(in: .whitespaces).isEmpty
        else { return "장소 미정" }
        return location
    }
}

private struct MemoCard: View {
    var memo: String

    var body: some View {
        InfoCard(
            symbol: "doc.text.fill",
            iconTint: Color(hex: 0xFF9800),
            iconBackground: [Color(hex: 0xFFF3E0), Color(hex: 0xFFE0B2)],
            label: "메모"
        ) {
            Text(memo)
                .font(WPFont.tmoney(16, .semibold))
                .foregroundStyle(WPColor.textPrimary)
                .lineSpacing(8)
        }
    }
}

private struct ExtraCategoriesCard: View {
    var categories: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("추가 카테고리")
                .font(WPFont.hak(14))
                .foregroundStyle(WPColor.gray500)

            Spacer().frame(height: 12)

            // 개수가 많아지면 줄바꿈되어야 한다.
            FlowRow(spacing: 8) {
                ForEach(categories, id: \.self) { name in
                    Text(name)
                        .font(WPFont.hak(14, .bold))
                        .foregroundStyle(WPColor.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: 0xFFF0F7), in: Capsule())
                        .overlay(Capsule().stroke(WPColor.primary.opacity(0.07), lineWidth: 1))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

private struct ActionButtons: View {
    var deleting: Bool
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                Text("수정하기")
                    .font(WPFont.hak(16, .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: WPColor.primary.opacity(0.25), radius: 8, y: 4)
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Text(deleting ? "삭제 중..." : "삭제하기")
                    .font(WPFont.hak(16, .bold))
                    .foregroundStyle(WPColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(WPColor.gray100, lineWidth: 2)
                    )
            }
            .buttonStyle(.plain)
            .disabled(deleting)
            .accessibilityIdentifier("detail.delete")
        }
    }
}
