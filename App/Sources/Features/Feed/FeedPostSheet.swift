import PhotosUI
import SwiftUI
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 후기 올리기 · 고치기 — 안드로이드 `ui/feed/FeedPostSheet.kt`(웹 `app/components/FeedPostModal.tsx`) 이식.
///
/// **후기는 글을 새로 쓰는 게 아니다.** 완료한 일정을 고르고 별점과 한 줄(+ 사진 3장까지)만 얹는다 —
/// 업체명·실제 지출·지역은 이미 그 일정에 들어 있다.
///
/// 올리기와 고치기가 **같은 칸**을 쓴다. 고치기는 별점 · 한 줄 · 업체 · 사진 · 금액 공개 · 신랑/신부를 채워서 열고,
/// 카테고리 · 금액은 일정에서 옮긴 값이라 맨 위 요약 줄에만 보인다(비공개면 `금액 비공개`).
///
/// 짜임은 **머리글 · 본문(굴림) · 조작 줄** — 통째로 구르면 낮은 폰에서 `후기 올리기` 가 화면 밖으로 밀려, 조작 줄은
/// 스크롤 밖에 붙인다. **올리거나 내리는 동안은 닫지 않는다**(바깥 끌기 · ✕) — 웹은 닫아도 저장이 계속돼서, 곧바로
/// 연 다음 창을 그 결과가 닫았다.
struct FeedPostSheet: View {
    var initialScheduleId: Int? = nil
    var editing: FeedPost? = nil
    var onPosted: () -> Void = {}
    var onSaved: (FeedPost) -> Void = { _ in }
    var onDeleted: (Int) -> Void = { _ in }

    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @StateObject private var editor: FeedPostEditor

    @State private var postables: [PostableSchedule] = []
    @State private var loading = true
    /// 목록을 못 불러온 경우. **"없음" 과 구별해야 한다.**
    @State private var loadFailed = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @FocusState private var keywordFocused: Bool
    @State private var headHeight: CGFloat = 100
    @State private var bodyHeight: CGFloat = 200
    @State private var footHeight: CGFloat = 0

    init(initialScheduleId: Int? = nil, editing: FeedPost? = nil, onPosted: @escaping () -> Void = {},
         onSaved: @escaping (FeedPost) -> Void = { _ in }, onDeleted: @escaping (Int) -> Void = { _ in },
         editor: FeedPostEditor? = nil) {
        self.initialScheduleId = initialScheduleId
        self.editing = editing
        self.onPosted = onPosted
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        _editor = StateObject(wrappedValue: editor ?? FeedPostEditor(editing: editing))
    }

    private var isEdit: Bool { editing != nil }
    private var ready: Bool { isEdit || (editor.selected != nil && !loading && !loadFailed) }
    /// 안드로이드 `heightIn(max = 720.dp)` — 내용만큼, 길면 720 에서 본문이 구른다.
    private var sheetHeight: CGFloat { min(720, headHeight + bodyHeight + (ready ? footHeight : 0)) }

    var body: some View {
        VStack(spacing: 0) {
            header
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headHeight = ceil($0) }
            ScrollView {
                content
                    .padding(.horizontal, 24).padding(.bottom, 20)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bodyHeight = ceil($0) }
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            if ready {
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
        .interactiveDismissDisabled(editor.busy)
        .task { if !isEdit { await load() } }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            editor.addPhotos(items)
            pickerItems = []
        }
    }

    // MARK: - 머리글 · 조작 줄

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isEdit ? "후기 고치기" : "견적 후기 올리기").wpTypography(20, .black).foregroundStyle(WPColor.textPrimary)
                Text(isEdit ? "저장하면 바로 바뀌어요. 이름 없이 공개되는 건 그대로예요." : "완료한 일정에 별점과 한 줄만 얹으면 됩니다.")
                    .wpTypography(12.5).foregroundStyle(WPColor.gray400)
            }
            Spacer(minLength: 0)
            // 웹 머리의 닫기(36, stone-400) — lucide X. 보내는 동안은 닫지 않는다
            Button { if !editor.busy { dismiss() } } label: {
                WPLucideIcon(paths: ["M18 6 6 18", "m6 6 12 12"], size: 20, color: WPColor.stone400)
                    .frame(width: 36, height: 36).contentShape(Circle())
            }.buttonStyle(.plain).disabled(editor.busy).accessibilityLabel("닫기").accessibilityIdentifier("feed.post.close")
        }
        .padding(.leading, 24).padding(.trailing, 16).padding(.top, 28).padding(.bottom, 20)
    }

    private var submitLabel: String {
        if editor.deleting { return "내리는 중..." }
        if let uploading = editor.uploading { return uploading }
        if editor.preparing { return "사진 준비 중..." }
        if editor.saving { return isEdit ? "저장하는 중..." : "올리는 중..." }
        return isEdit ? "저장" : "후기 올리기"
    }

    private var footer: some View {
        let disabled = editor.busy || editor.preparing
        return VStack(alignment: .leading, spacing: 0) {
            if let error = editor.error {
                Text(error.wpKeepAll).wpTypography(13).foregroundStyle(WPColor.danger)
                    .fixedSize(horizontal: false, vertical: true).padding(.bottom, 10)
                    .accessibilityIdentifier("feed.post.error")
            }
            Button {
                keywordFocused = false
                editor.submit(env: env, onPosted: { onPosted(); dismiss() }, onSaved: { onSaved($0); dismiss() })
            } label: {
                Text(submitLabel)
                    .wpTypography(15, .bold).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .opacity(disabled ? 0.6 : 1)
            }
            .buttonStyle(.plain).disabled(disabled)
            .accessibilityIdentifier("feed.post.submit")
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 28)
        .background(Color.white)
    }

    // MARK: - 본문

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isEdit {
                Text("이름 없이 공개돼요. 공유 링크로 누구나 볼 수 있습니다.".wpKeepAll).wpTypography(13).foregroundStyle(WPColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true).padding(.bottom, 16)
            }
            if let editing {
                notice(summary(editing))
            } else if loading {
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
            }
            if ready {
                Color.clear.frame(height: 20)
                placeField
                Color.clear.frame(height: 20)
                sectionLabel("만족도")
                Color.clear.frame(height: 8)
                ratingPicker
                Color.clear.frame(height: 20)
                sectionLabel("한 줄 후기 (선택)")
                Color.clear.frame(height: 8)
                bodyInput
                Color.clear.frame(height: 20)
                photoField
                Color.clear.frame(height: 20)
                sectionLabel("금액 공개")
                Color.clear.frame(height: 8)
                // 비공개면 응답에서 amount 필드 자체가 빠진다 — "0원" 으로 보이지 않게 하는 백엔드 설계다.
                pills([(true, "금액을 공개합니다"), (false, "금액을 가립니다")], selected: editor.isAmountPublic,
                      active: WPColor.textPrimary) { editor.isAmountPublic = $0 }
                Color.clear.frame(height: 20)
                sectionLabel("누구신가요 (선택)")
                Color.clear.frame(height: 8)
                pills([("BRIDE", "신부"), ("GROOM", "신랑"), ("UNKNOWN", "밝히지 않음")], selected: editor.role,
                      active: WPColor.primary) { editor.role = $0 }
                if isEdit {
                    Color.clear.frame(height: 28)
                    deleteArea
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `스튜디오 · 햇살 스튜디오 · 120만원` — 고칠 수 없는 값이라 요약 줄에만 보인다
    private func summary(_ post: FeedPost) -> String {
        [post.categoryName, post.title, post.amount.map { "\(withThousands($0))만원" } ?? "금액 비공개"].joined(separator: " · ")
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
        let on = editor.selected?.scheduleId == item.scheduleId
        return Button { editor.selectSchedule(item, env: env) } label: {
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
        .disabled(editor.busy)
        .accessibilityIdentifier("feed.post.schedule.\(item.scheduleId)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: - 업체

    /// 업체는 **필수가 아니다** — 청첩장 · 예물처럼 지도에 없는 게 정상인 카테고리가 있고, 막으면 공급이 죽는다.
    /// 일정을 고르면 그 일정의 좌표와 맞는 결과만 저절로 고른다(이름이 같은 다른 지점은 고르지 않는다).
    @ViewBuilder private var placeField: some View {
        sectionLabel("업체 (선택)")
        Color.clear.frame(height: 8)
        if let place = editor.place {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    WPTmoneyText(text: place.placeName, size: 14, bold: true, color: UIColor(WPColor.textPrimary), lineHeight: 20)
                    Text(place.address).wpTypography(12).foregroundStyle(WPColor.gray500)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button { editor.pickPlace(nil) } label: {
                    Text("바꾸기").wpTypography(13).foregroundStyle(WPColor.primary).padding(8)
                }.buttonStyle(.plain).disabled(editor.busy).accessibilityIdentifier("feed.post.place.change")
            }
            .padding(14)
            .background(WPColor.stone50, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("feed.post.place")
        } else {
            HStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    if editor.keyword.isEmpty {
                        Text("업체명으로 찾기").wpTypography(13).foregroundStyle(WPColor.gray500).allowsHitTesting(false)
                    }
                    TextField("", text: Binding(get: { editor.keyword }, set: { editor.updateKeyword($0) }))
                        .font(Font(WPTypeface.tmoney.uiFont(14, .regular)))
                        .foregroundStyle(WPColor.textPrimary).tint(WPColor.primary)
                        .focused($keywordFocused)
                        .submitLabel(.search)
                        .onSubmit { editor.search(env: env) }
                        .disabled(editor.busy)
                        .accessibilityIdentifier("feed.post.place.keyword")
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(keywordFocused ? WPColor.primary : Color(hex: 0x79747E), lineWidth: keywordFocused ? 2 : 1))
                .contentShape(Rectangle())
                .onTapGesture { keywordFocused = true }
                Button { keywordFocused = false; editor.search(env: env) } label: {
                    Text(editor.searching ? "찾는 중..." : "검색").wpTypography(16).foregroundStyle(WPColor.primary).padding(8)
                }.buttonStyle(.plain).disabled(editor.busy || editor.searching).accessibilityIdentifier("feed.post.place.search")
            }
            ForEach(editor.places) { item in
                Button { keywordFocused = false; editor.pickPlace(FeedPlace(result: item)) } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        WPTmoneyText(text: item.placeName, size: 14, bold: true, color: UIColor(WPColor.textPrimary), lineHeight: 20)
                        Text(address(item)).wpTypography(12).foregroundStyle(WPColor.gray500)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(editor.busy)
            }
            if let error = editor.placeError {
                Text(error).wpTypography(12).foregroundStyle(WPColor.danger)
            }
            Text("지도에 없는 업체는 고르지 않아도 돼요.").wpTypography(12).foregroundStyle(WPColor.gray400).padding(.top, 6)
        }
    }

    private func address(_ item: PlaceSearchResult) -> String {
        let road = item.roadAddressName?.trimmingCharacters(in: .whitespaces) ?? ""
        return road.isEmpty ? item.addressName : road
    }

    // MARK: - 별점 · 한 줄

    private var ratingPicker: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { n in
                Button { if !editor.busy { editor.rating = n } } label: {
                    WPMaterialPathIcon(paths: FeedIconPaths.starFilled, size: 30,
                                       color: n <= editor.rating ? Color(hex: 0xFFB020) : Color(hex: 0xE9E1E5))
                }.buttonStyle(.plain).accessibilityLabel("\(n)점").accessibilityIdentifier("feed.post.star.\(n)")
            }
        }
    }

    private var bodyInput: some View {
        ZStack(alignment: .topLeading) {
            if editor.body.isEmpty {
                WPTmoneyText(text: "좋았던 점, 아쉬웠던 점을 한 줄로", size: 13.5, color: UIColor(WPColor.stone300), lineHeight: 20)
                    .allowsHitTesting(false)
            }
            TextField("", text: Binding(get: { editor.body }, set: { if $0.count <= 500, !editor.busy { editor.body = $0 } }), axis: .vertical)
                .font(Font(WPTypeface.tmoney.uiFont(13.5, .regular)))
                .foregroundStyle(WPColor.textPrimary).tint(WPColor.primary)
                .accessibilityIdentifier("feed.post.body")
        }
        .frame(maxWidth: .infinity, minHeight: 84 - 28, alignment: .topLeading)
        .padding(14)
        .background(WPColor.stone50, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(WPColor.stone200, lineWidth: 1))
    }

    // MARK: - 사진

    /// 한 줄 후기 바로 아래. 사진마다 오른쪽 위 `×`, 마지막 칸은 점선 `사진 추가`. 고르는 순간 WebP 로 바꾸고
    /// 바꾸는 동안 그 칸에 `줄이는 중`. **사진 권한은 묻지 않는다** — 사진 고르기는 고른 사진만 건넨다.
    @ViewBuilder private var photoField: some View {
        sectionLabel("사진 (선택 · 3장까지)")
        Color.clear.frame(height: 8)
        HStack(spacing: 8) {
            ForEach(Array(editor.photos.enumerated()), id: \.element.id) { index, photo in
                photoTile(photo, index: index)
            }
            if editor.photos.count < FeedRules.maxPhotos {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images, photoLibrary: .shared()) {
                    Text("사진 추가").wpTypography(12).foregroundStyle(WPColor.gray500)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(WPColor.stone300, style: StrokeStyle(lineWidth: 1, dash: [6, 4])))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(editor.busy || editor.preparing)
                .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                .accessibilityIdentifier("feed.post.photo.add")
                ForEach(0..<max(0, FeedRules.maxPhotos - 1 - editor.photos.count), id: \.self) { _ in
                    Color.clear.frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                }
            }
        }
        if let note = editor.photoNote {
            Text(note).wpTypography(12).foregroundStyle(WPColor.danger).padding(.top, 6)
                .accessibilityIdentifier("feed.post.photo.note")
        }
        Text("사진도 이름 없이 모두에게 공개돼요. 얼굴 · 연락처 · 계약서 번호가 보이지 않는지 확인해 주세요.")
            .wpTypography(11, lineHeight: 17).foregroundStyle(WPColor.gray400)
            .fixedSize(horizontal: false, vertical: true).padding(.top, 8)
    }

    private func photoTile(_ photo: FeedPhoto, index: Int) -> some View {
        Color.clear
            .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
            .overlay {
                if photo.preparing {
                    Text("줄이는 중").wpTypography(12).foregroundStyle(WPColor.textPrimary)
                } else if let local = photo.local {
                    Image(uiImage: local).resizable().scaledToFill()
                } else if let preview = photo.preview {
                    FeedRemoteImage(url: preview)
                } else {
                    Text("사진 \(index + 1)").wpTypography(12).foregroundStyle(WPColor.textPrimary)
                }
            }
            .background(WPColor.stone100)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Button { editor.removePhoto(photo.id) } label: {
                    WPLucideIcon(paths: ["M18 6 6 18", "m6 6 12 12"], size: 16, color: .white)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.6), in: Circle())
                }
                .buttonStyle(.plain).disabled(editor.busy).padding(3)
                .accessibilityLabel("사진 \(index + 1) 빼기")
                .accessibilityIdentifier("feed.post.photo.remove.\(index + 1)")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("feed.post.photo.\(index + 1)")
    }

    // MARK: - 금액 공개 · 누구신가요

    /// 안드로이드 `ToggleRow`·`RolePicker` — 고른 알약만 채운다(금액 공개는 검정, 누구신가요는 분홍).
    private func pills<V: Equatable>(_ options: [(V, String)], selected: V, active: Color, onPick: @escaping (V) -> Void) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let on = option.0 == selected
                Button { if !editor.busy { onPick(option.0) } } label: {
                    Text(option.1).wpTypography(12.5, .bold).foregroundStyle(on ? .white : WPColor.gray500)
                        .lineLimit(1).fixedSize()
                        .padding(.horizontal, 13).padding(.vertical, 7)
                        .background(on ? active : Color.white, in: Capsule())
                        .overlay(Capsule().strokeBorder(on ? active : WPColor.stone200, lineWidth: 1))
                }.buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    // MARK: - 내리기

    /// 맨 아래 옅은 글자 단추. 저장 옆에 같은 무게로 두면 잘못 누른다 — 누르면 같은 자리에 확인 줄이 열린다.
    @ViewBuilder private var deleteArea: some View {
        if !editor.confirmingDelete {
            Button { editor.confirmingDelete = true } label: {
                Text("이 후기 내리기").wpTypography(12).foregroundStyle(WPColor.gray400).padding(.vertical, 10)
            }.buttonStyle(.plain).disabled(editor.busy).accessibilityIdentifier("feed.post.delete")
        } else {
            Text("이 후기를 내릴까요?").wpTypography(14, .bold).foregroundStyle(WPColor.textPrimary)
            Text("되돌릴 수 없고 사진도 함께 지워져요.").wpTypography(12).foregroundStyle(WPColor.gray500)
            HStack(spacing: 20) {
                Button { editor.confirmingDelete = false } label: {
                    Text("취소").wpTypography(16).foregroundStyle(WPColor.textPrimary).padding(.vertical, 12)
                }.buttonStyle(.plain).disabled(editor.busy).accessibilityIdentifier("feed.post.delete.cancel")
                Button { editor.delete(env: env) { onDeleted($0); dismiss() } } label: {
                    Text(editor.deleting ? "내리는 중..." : "내리기").wpTypography(16).foregroundStyle(WPColor.danger).padding(.vertical, 12)
                }.buttonStyle(.plain).disabled(editor.busy).accessibilityIdentifier("feed.post.delete.confirm")
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
        if editor.selected == nil, let initialScheduleId, let item = page.list.first(where: { $0.scheduleId == initialScheduleId }) {
            editor.selectSchedule(item, env: env)
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
