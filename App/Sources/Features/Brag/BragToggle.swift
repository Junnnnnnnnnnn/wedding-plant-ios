import SwiftUI
import WPDomain
import WPModels

/// 홈 예산 패널 아래의 자랑하기 토글.
///
/// **켜기 전에는 반드시 안내 모달을 거친다.** 끄는 것은 되돌릴 수 있으므로 확인을
/// 받지 않는다.
///
/// 올라가 있는 동안 아래에 붙는 `좋아요 N · 보러 가기` 줄이 **폰에서 자랑하기로
/// 들어가는 유일한 문**이다. 넓은 화면에는 레일이 있지만 폰에는 없다 —
/// **지우지 말 것.**
struct BragToggle: View {
    @ObservedObject var model: BragToggleViewModel
    var onOpenBrag: () -> Void

    @EnvironmentObject private var env: AppEnvironment
    @State private var showConsent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("자랑하기")
                        .font(WPFont.hak(15, .bold))
                        .foregroundStyle(WPColor.textPrimary)
                    Text(model.published ? "내 플랜이 올라가 있어요" : "내 웨딩 플랜을 자랑해 보세요")
                        .font(WPFont.hak(12.5))
                        .foregroundStyle(WPColor.fgSubtle)
                }
                Spacer(minLength: 8)

                Toggle("", isOn: Binding(
                    get: { model.published },
                    set: { wantsOn in
                        if wantsOn {
                            // 켜기 전에는 무엇이 공개되는지 먼저 말한다.
                            showConsent = true
                        } else {
                            Task { await model.unpublish(env: env) }
                        }
                    }
                ))
                .labelsHidden()
                .tint(WPColor.primary)
                .disabled(model.pending)
                .accessibilityIdentifier("brag.toggle")
            }

            if model.published {
                Spacer().frame(height: 10)
                Button(action: onOpenBrag) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                        Text("좋아요 \(model.status?.likeCount ?? 0)")
                            .font(WPFont.hak(13, .bold))
                        Text("·")
                            .font(WPFont.hak(13))
                        Text("보러 가기")
                            .font(WPFont.hak(13, .bold))
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(WPColor.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(hex: 0xFFF2F6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("brag.open")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(WPColor.cardBorder, lineWidth: 1)
        )
        .task { await model.load(env: env) }
        .sheet(isPresented: $showConsent) {
            BragConsentSheet {
                showConsent = false
                Task { await model.publish(env: env) }
            } onCancel: {
                showConsent = false
            }
        }
    }
}

/// 켜기 전 안내.
///
/// **공개 범위는 이 문구 한 곳이 상한이다.** 넓혀야 하면 **이 문구를 먼저 고치고**
/// 응답을 고친다 — 순서를 뒤집으면 동의받지 않은 것을 공개하게 된다.
///
/// 일정의 **시각과 메모는 `BragPlanItem` 에 넣지 말 것.**
struct BragConsentSheet: View {
    var onConfirm: () -> Void
    var onCancel: () -> Void

    /// 웹 `BragToggle` 의 `OPEN_FIELDS`.
    private let openFields = [
        "닉네임",
        "결혼식 날짜",
        "총예산",
        "카테고리별 지출과 소계",
        "일정 제목",
        "일정별 금액",
        "일정 장소",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("이런 것이 공개돼요")
                        .font(WPFont.hak(18, .bold))
                        .foregroundStyle(WPColor.textPrimary)

                    Spacer().frame(height: 14)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(openFields, id: \.self) { field in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(WPColor.primary)
                                Text(field)
                                    .font(WPFont.hak(14))
                                    .foregroundStyle(WPColor.fgNeutral)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Spacer().frame(height: 14)

                    Text("다른 사람은 보기와 좋아요만 할 수 있어요. 언제든 내릴 수 있고, 내려도 좋아요는 남아 다시 올리면 이어집니다.")
                        .font(WPFont.hak(13))
                        .lineSpacing(6)
                        .foregroundStyle(WPColor.fgSubtle)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 22)

                    Button(action: onConfirm) {
                        Text("올리기")
                            .font(WPFont.hak(16, .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("brag.consent.confirm")
                }
                .padding(20)
            }
            .background(WPColor.background)
            .navigationTitle("자랑하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onCancel)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
