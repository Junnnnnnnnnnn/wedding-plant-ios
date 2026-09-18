import SwiftUI
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 후기 쓰기 — 웹 `app/components/FeedPostModal.tsx`.
///
/// **후기는 글을 새로 쓰는 게 아니다.** 완료한 일정을 고르고 **별점과 한 줄만**
/// 얹는다 — 업체명·실제 지출·지역은 이미 그 일정에 들어 있다. 콘텐츠 제작 비용이
/// 0 이라야 콜드 스타트를 넘긴다.
///
/// **별도 라우트가 아니라 모달이다.** 진입점은 피드 상단과 일정 상세의 완료 상태
/// 두 곳이다.
///
/// 웹과 다른 점: **장소를 다시 고르는 단계가 없다.** 앱에 카카오 장소 검색이 아직
/// 없기 때문이다(`/plan/place/search` 미구현). **장소는 필수가 아니므로**
/// 안 보내면 서버가 장소 없는 후기로 받는다 — 청첩장·예물·신혼여행처럼 지도에
/// 없는 게 정상인 카테고리가 있고, 막으면 공급이 죽는다.
struct FeedPostSheet: View {
    var onPosted: () -> Void

    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var postables: [PostableSchedule] = []
    @State private var loading = true
    /// 목록을 못 불러온 경우. **"없음" 과 구별해야 한다.**
    @State private var loadFailed = false
    @State private var selected: PostableSchedule?
    @State private var rating = 5
    @State private var body_ = ""
    @State private var isAmountPublic = true
    @State private var role = "UNKNOWN"
    @State private var submitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("완료한 일정에 별점과 한 줄만 얹으면 됩니다.")
                        .font(WPFont.hak(13.5))
                        .foregroundStyle(WPColor.fgSubtle)
                        .padding(.bottom, 18)

                    if loading {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonBox(height: 64, corner: 14)
                                .padding(.bottom, 8)
                        }
                    } else if loadFailed {
                        notice("완료한 일정을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")
                    } else if postables.isEmpty {
                        notice("아직 후기로 올릴 완료 일정이 없어요. 일정을 완료로 표시하면 여기에 나타납니다.")
                    } else {
                        schedulePicker
                        if selected != nil {
                            Spacer().frame(height: 22)
                            ratingRow
                            Spacer().frame(height: 22)
                            amountRow
                            Spacer().frame(height: 22)
                            roleRow
                            Spacer().frame(height: 22)
                            bodyRow
                        }
                    }

                    if let errorMessage {
                        Spacer().frame(height: 14)
                        InfoBanner(message: errorMessage, actionLabel: "닫기") {
                            self.errorMessage = nil
                        }
                    }
                }
                .padding(20)
            }
            .background(WPColor.background)
            .navigationTitle("후기 쓰기")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if selected != nil { submitBar }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    // MARK: - 조각

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(WPFont.hak(13))
            .lineSpacing(5)
            .foregroundStyle(WPColor.fgSubtle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var schedulePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("어떤 일정인가요?")
            ForEach(postables) { item in
                Button { selected = item } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            // **업체명은 고른 장소 이름이 일정 제목을 이긴다** —
                            // 일정 제목은 `본식 촬영` 같은 개인 메모인 경우가 많다.
                            Text(displayTitle(item))
                                .font(WPFont.tmoney(15, .bold))
                                .foregroundStyle(WPColor.fgNeutral)
                                .lineLimit(1)
                            Text(subtitle(item))
                                .font(WPFont.hak(12.5))
                                .foregroundStyle(WPColor.fgSubtle)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: selected?.id == item.id ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundStyle(selected?.id == item.id ? WPColor.primary : WPColor.fgDisabled)
                    }
                    .padding(14)
                    .background(
                        selected?.id == item.id ? Color(hex: 0xFFF7FA) : Color.white,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                selected?.id == item.id
                                    ? WPColor.primary.opacity(0.3)
                                    : WPColor.strokeWeak,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var ratingRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("만족도")
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { n in
                    Button { rating = n } label: {
                        Image(systemName: "star.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(n <= rating ? Color(hex: 0xFFB020) : Color(hex: 0xE9E1E5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(n)점")
                }
            }
        }
    }

    /// **비공개면 `amount` 필드 자체가 안 나간다** — 0 으로 채우면 "0원" 이 된다.
    private var amountRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("금액 공개")
            Toggle(isOn: $isAmountPublic) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isAmountPublic ? "금액을 공개해요" : "금액은 비공개로 할게요")
                        .font(WPFont.hak(14, .bold))
                        .foregroundStyle(WPColor.fgNeutral)
                    Text("공개하면 다른 사람이 시세를 가늠하는 데 도움이 돼요")
                        .font(WPFont.hak(12))
                        .foregroundStyle(WPColor.fgSubtle)
                }
            }
            .tint(WPColor.primary)
        }
    }

    /// `"D-131 신부"` 문장의 뒷부분. **응답에 `planUserId` 는 없다.**
    private var roleRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("어느 쪽인가요?")
            HStack(spacing: 8) {
                ForEach([("BRIDE", "신부"), ("GROOM", "신랑"), ("UNKNOWN", "밝히지 않음")], id: \.0) { value, label in
                    Button { role = value } label: {
                        Text(label)
                            .font(WPFont.hak(13.5, .bold))
                            .foregroundStyle(role == value ? .white : WPColor.fgMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                role == value ? Color(hex: 0x2A3038) : WPColor.fill,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var bodyRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("한 줄 (선택)")
            ZStack(alignment: .topLeading) {
                TextEditor(text: $body_)
                    .font(WPFont.tmoney(15))
                    .foregroundStyle(WPColor.fgNeutral)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 96)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                if body_.isEmpty {
                    // **별점만 있는 후기가 정상이다.** 비우면 아예 안 보낸다.
                    Text("좋았던 점이나 아쉬웠던 점을 한 줄로")
                        .font(WPFont.tmoney(15))
                        .foregroundStyle(Color(hex: 0xB0B4BB))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var submitBar: some View {
        VStack(spacing: 0) {
            Hairline()
            Button {
                Task { await submit() }
            } label: {
                Text(submitting ? "올리는 중..." : "후기 올리기")
                    .font(WPFont.hak(16, .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(submitting)
            .opacity(submitting ? 0.7 : 1)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .accessibilityIdentifier("feed.post.submit")
        }
        .background(Color.white)
    }

    // MARK: - 값

    private func displayTitle(_ item: PostableSchedule) -> String {
        let place = item.location?.trimmingCharacters(in: .whitespaces) ?? ""
        return place.isEmpty ? item.title : place
    }

    private func subtitle(_ item: PostableSchedule) -> String {
        var parts = [item.categoryName].filter { !$0.isEmpty }
        if let amount = item.amount, amount > 0 {
            parts.append("\(withThousands(amount))만원")
        }
        if let date = KstDate(dateString: item.startDate ?? "") {
            parts.append(date.monthDayText)
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - 통신

    private func load() async {
        defer { loading = false }
        guard let page = try? await env.api.send(
            Endpoint.feedPostable(), decoding: PostablePage.self
        ) else {
            loadFailed = true
            return
        }
        postables = page.list
    }

    private func submit() async {
        guard let selected, !submitting else { return }
        submitting = true
        defer { submitting = false }

        // 장소는 보내지 않는다 — 일정의 `location` 은 주소가 아니라 **업체명**이라
        // `address` 로 넘기면 백엔드가 그걸 잘라 지역을 만들다 늘 빈다.
        let request = FeedPostRequest(
            scheduleId: selected.scheduleId,
            rating: rating,
            body: body_,
            isAmountPublic: isAmountPublic,
            authorRole: role
        )

        do {
            try await env.api.sendIgnoringData(Endpoint.createFeedPost(request))
            onPosted()
            dismiss()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

private struct SectionLabel: View {
    var text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(WPFont.hak(13, .bold))
            .foregroundStyle(WPColor.fgMuted)
    }
}
