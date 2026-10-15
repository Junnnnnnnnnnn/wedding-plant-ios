import SwiftUI
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 후기 올리기 — 안드로이드 `ui/feed/FeedPostSheet.kt`(웹 `app/components/FeedPostModal.tsx`) 이식.
///
/// **후기는 글을 새로 쓰는 게 아니다.** 완료한 일정을 고르고 별점과 한 줄만 얹는다 —
/// 업체명·실제 지출·지역은 이미 그 일정에 들어 있다.
///
/// 짜임도 안드로이드와 같다 — **머리글 · 본문(굴림) · 조작 줄**. 예전 iOS 는 내비게이션 막대
/// (`닫기 · 후기 쓰기`)와 시스템 토글로 짜여 안드로이드와 다른 앱처럼 보였다. 통째로 구르면
/// 낮은 폰에서 `후기 올리기` 가 화면 밖으로 밀려, 조작 줄은 스크롤 밖에 붙인다.
///
/// 웹과 다른 점: **장소를 다시 고르는 단계가 없다**(앱에 카카오 장소 검색이 없다). 장소는
/// 필수가 아니라 등록은 된다.
struct FeedPostSheet: View {
    var initialScheduleId: Int? = nil
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
    @State private var headHeight: CGFloat = 100
    @State private var bodyHeight: CGFloat = 200
    @State private var footHeight: CGFloat = 0

    private var canSubmit: Bool { selected != nil && !loading && !loadFailed && !postables.isEmpty }
    /// 안드로이드 `heightIn(max = 640.dp)` — 내용만큼, 길면 640 에서 본문이 구른다.
    private var sheetHeight: CGFloat { min(640, headHeight + bodyHeight + (canSubmit ? footHeight : 0)) }

    var body: some View {
        VStack(spacing: 0) {
            header
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headHeight = ceil($0) }
            ScrollView {
                content
                    .padding(.horizontal, 24).padding(.bottom, canSubmit ? 8 : 40)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bodyHeight = ceil($0) }
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            if canSubmit {
                footer
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { footHeight = ceil($0) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
        .presentationBackground(.white)
        .interactiveDismissDisabled(submitting)
        .task { await load() }
    }

    // MARK: - 머리글 · 조작 줄

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("견적 후기 올리기").wpTypography(20, .black).foregroundStyle(WPColor.textPrimary)
                Text("완료한 일정에 별점과 한 줄만 얹으면 됩니다.").wpTypography(12.5).foregroundStyle(WPColor.gray400)
            }
            Spacer(minLength: 0)
            // 웹 머리의 닫기(36, stone-400) — lucide X
            Button { dismiss() } label: {
                WPLucideIcon(paths: ["M18 6 6 18", "m6 6 12 12"], size: 20, color: WPColor.stone400)
                    .frame(width: 36, height: 36).contentShape(Circle())
            }.buttonStyle(.plain).accessibilityLabel("닫기").accessibilityIdentifier("feed.post.close")
        }
        .padding(.leading, 24).padding(.trailing, 16).padding(.top, 28).padding(.bottom, 20)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let errorMessage {
                Text(errorMessage.wpKeepAll).wpTypography(13).foregroundStyle(WPColor.danger)
                    .fixedSize(horizontal: false, vertical: true).padding(.bottom, 10)
            }
            Button { Task { await submit() } } label: {
                Text(submitting ? "올리는 중..." : "후기 올리기")
                    .wpTypography(15, .bold).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .opacity(submitting ? 0.6 : 1)
            }
            .buttonStyle(.plain).disabled(submitting)
            .accessibilityIdentifier("feed.post.submit")
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 28)
        .background(Color.white)
    }

    // MARK: - 본문

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if loading {
                ProgressView().tint(WPColor.primary).frame(maxWidth: .infinity).frame(height: 120)
            } else if loadFailed {
                notice("올릴 수 있는 일정을 불러오지 못했습니다.\n잠시 후 다시 시도해 주세요.")
            } else if postables.isEmpty {
                notice("후기로 올릴 완료 일정이 없어요.\n일정을 완료 처리하면 여기에 나타납니다.")
            } else {
                sectionLabel("어떤 일정인가요")
                Color.clear.frame(height: 8)
                ForEach(postables) { item in
                    postableRow(item)
                    Color.clear.frame(height: 6)
                }
                if selected != nil {
                    Color.clear.frame(height: 20)
                    sectionLabel("만족도")
                    Color.clear.frame(height: 8)
                    ratingPicker
                    Color.clear.frame(height: 20)
                    sectionLabel("한 줄 후기 (선택)")
                    Color.clear.frame(height: 8)
                    bodyInput
                    Color.clear.frame(height: 20)
                    sectionLabel("금액 공개")
                    Color.clear.frame(height: 8)
                    // 비공개면 응답에서 amount 필드 자체가 빠진다 — "0원" 으로 보이지 않게 하는 백엔드 설계다.
                    pills([(true, "금액을 공개합니다"), (false, "금액을 가립니다")], selected: isAmountPublic,
                          active: WPColor.textPrimary) { isAmountPublic = $0 }
                    Color.clear.frame(height: 20)
                    sectionLabel("누구신가요 (선택)")
                    Color.clear.frame(height: 8)
                    pills([("BRIDE", "신부"), ("GROOM", "신랑"), ("UNKNOWN", "밝히지 않음")], selected: role,
                          active: WPColor.primary) { role = $0 }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).wpTypography(13, .bold).foregroundStyle(WPColor.gray500)
    }

    private func notice(_ text: String) -> some View {
        Text(text).wpTypography(13, lineHeight: 20).foregroundStyle(WPColor.gray500)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(WPColor.stone50, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func postableRow(_ item: PostableSchedule) -> some View {
        let on = selected?.scheduleId == item.scheduleId
        return Button { selected = item } label: {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    // 업체명은 고른 장소 이름이 일정 제목을 이긴다 — 일정 제목은 `본식 촬영` 같은 개인 메모가 많다.
                    WPTmoneyText(text: displayTitle(item), size: 14, bold: true, color: UIColor(WPColor.textPrimary), lineHeight: 21)
                        .frame(maxWidth: .infinity, alignment: .leading).clipped()
                    Text(subtitle(item)).wpTypography(12).foregroundStyle(WPColor.gray400)
                }
                if on {
                    WPMaterialPathIcon(paths: WPIconPaths.check, size: 18, color: WPColor.primary)
                }
            }
            .padding(14)
            .background(on ? WPColor.primary.opacity(0.05) : Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(on ? WPColor.primary.opacity(0.3) : WPColor.stone200, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("feed.post.schedule.\(item.scheduleId)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var ratingPicker: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { n in
                Button { rating = n } label: {
                    WPMaterialPathIcon(paths: FeedIconPaths.starFilled, size: 30,
                                       color: n <= rating ? Color(hex: 0xFFB020) : Color(hex: 0xE9E1E5))
                }.buttonStyle(.plain).accessibilityLabel("\(n)점")
            }
        }
    }

    private var bodyInput: some View {
        ZStack(alignment: .topLeading) {
            if body_.isEmpty {
                WPTmoneyText(text: "좋았던 점, 아쉬웠던 점을 한 줄로", size: 13.5, color: UIColor(WPColor.stone300), lineHeight: 20)
                    .allowsHitTesting(false)
            }
            TextField("", text: Binding(get: { body_ }, set: { if $0.count <= 300 { body_ = $0 } }), axis: .vertical)
                .font(Font(WPTypeface.tmoney.uiFont(13.5, .regular)))
                .foregroundStyle(WPColor.textPrimary).tint(WPColor.primary)
                .accessibilityIdentifier("feed.post.body")
        }
        .frame(maxWidth: .infinity, minHeight: 84 - 28, alignment: .topLeading)
        .padding(14)
        .background(WPColor.stone50, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(WPColor.stone200, lineWidth: 1))
    }

    /// 안드로이드 `ToggleRow`·`RolePicker` — 고른 알약만 채운다(금액 공개는 검정, 누구신가요는 분홍).
    private func pills<V: Equatable>(_ options: [(V, String)], selected: V, active: Color, onPick: @escaping (V) -> Void) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let on = option.0 == selected
                Button { onPick(option.0) } label: {
                    Text(option.1).wpTypography(12.5, .bold).foregroundStyle(on ? .white : WPColor.gray500)
                        .padding(.horizontal, 13).padding(.vertical, 7)
                        .background(on ? active : Color.white, in: Capsule())
                        .overlay(Capsule().strokeBorder(on ? active : WPColor.stone200, lineWidth: 1))
                }.buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    // MARK: - 값

    private func displayTitle(_ item: PostableSchedule) -> String {
        let place = item.location?.trimmingCharacters(in: .whitespaces) ?? ""
        return place.isEmpty ? item.title : place
    }

    /// 안드로이드 — `카테고리 · N만원`(천 단위 쉼표 없음, 날짜 없음)
    private func subtitle(_ item: PostableSchedule) -> String {
        var parts = [item.categoryName].filter { !$0.isEmpty }
        if let amount = item.amount, amount > 0 { parts.append("\(Int(amount))만원") }
        return parts.joined(separator: " · ")
    }

    // MARK: - 통신

    private func load() async {
        defer { loading = false }
        guard let page = try? await env.api.send(Endpoint.feedPostable(), decoding: PostablePage.self) else {
            loadFailed = true
            return
        }
        postables = page.list
        if let initialScheduleId { selected = page.list.first { $0.scheduleId == initialScheduleId } }
    }

    private func submit() async {
        guard let selected, !submitting else { return }
        submitting = true
        errorMessage = nil
        defer { submitting = false }
        // 장소는 보내지 않는다 — 일정의 `location` 은 주소가 아니라 업체명이다.
        let request = FeedPostRequest(scheduleId: selected.scheduleId, rating: rating, body: body_,
                                      isAmountPublic: isAmountPublic, authorRole: role)
        do {
            try await env.api.sendIgnoringData(Endpoint.createFeedPost(request))
            onPosted()
            dismiss()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

/// 피드 화면들이 쓰는 Material 경로(24×24) — 안드로이드 `Icons.*` 원본
enum FeedIconPaths {
    /// `Icons.Filled.Star`
    static let starFilled = ["M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"]
    /// `Icons.Filled.Add`
    static let add = ["M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"]
    /// `Icons.Filled.ChevronRight`
    static let chevronRight = ["M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z"]
    /// `Icons.Filled.Close`
    static let close = ["M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"]
    /// `Icons.Filled.Favorite`
    static let favorite = ["M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"]
    /// `Icons.Outlined.FavoriteBorder`
    static let favoriteBorder = ["M16.5 3c-1.74 0-3.41.81-4.5 2.09C10.91 3.81 9.24 3 7.5 3 4.42 3 2 5.42 2 8.5c0 3.78 3.4 6.86 8.55 11.54L12 21.35l1.45-1.32C18.6 15.36 22 12.28 22 8.5 22 5.42 19.58 3 16.5 3zm-4.4 15.55l-.1.1-.1-.1C7.14 14.24 4 11.39 4 8.5 4 6.5 5.5 5 7.5 5c1.54 0 3.04.99 3.57 2.36h1.87C13.46 5.99 14.96 5 16.5 5c2 0 3.5 1.5 3.5 3.5 0 2.89-3.14 5.74-7.9 10.05z"]
}
