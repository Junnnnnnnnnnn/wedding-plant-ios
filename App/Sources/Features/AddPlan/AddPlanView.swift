import SwiftUI
import WPDomain
import WPModels
import WPUtils

/// 웹 `app/add-plen/AddPlanView.tsx` 의 **폰** 이식 — 시안 C안 07.
///
/// 폰은 카드 8장이 아니라 **시트 한 장**이다. 카드마다 테두리·그림자·여백이
/// 붙어 채우는 칸보다 껍데기가 더 컸고, 저장 버튼까지 두 번 스크롤해야 닿았다.
///
/// - **제목 칸이 분홍 머리 면 안에** 있다. 이 화면에서 가장 먼저 정해지고 끝까지
///   안 바뀌는 값이라, 아래로 스크롤해도 무엇을 만들고 있는지 보인다. 면은
///   스크롤 영역 안이라 내용과 함께 올라간다.
/// - 줄은 구분선 + **84pt 라벨 열**. `결제 유형`·`금액`·`위치`·`메모` 는 라벨을
///   위에 얹는다.
/// - 입력 칸은 테두리 없는 `#f7f8f9` 면.
/// - 저장 버튼은 시트 아래 바닥에 붙는다(웹 `sticky bottom-0`). 예전에는 목록 맨
///   끝이라 탭바에 가렸다.
/// - **단계형 흐름은 그대로** — 결제 유형을 고르기 전에는 금액·장소 칸이 나오지
///   않는다.
///
/// 웹의 **카카오맵 임베드와 키워드 검색은 아직 없다.** 백엔드 프록시
/// (`/plan/place/search`)가 없어 404 라, 장소를 자유 입력으로 받고 좌표는 0 으로
/// 보낸다(백엔드가 허용하는 형태).
struct AddPlanView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var model: AddPlanViewModel
    @State private var showCategoryModal = false
    @State private var showDatePicker = false
    @State private var showTimePicker = false

    /// 저장이 끝났을 때 목록을 새로 고치도록 알린다.
    var onSaved: () -> Void

    init(editId: Int? = nil, roomId: Int? = nil, initialDate: String? = nil, onSaved: @escaping () -> Void) {
        _model = StateObject(
            wrappedValue: AddPlanViewModel(editId: editId, roomId: roomId, initialDate: initialDate)
        )
        self.onSaved = onSaved
    }

    var body: some View {
        ZStack {
            Color.white

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        head

                        if model.loadingDetail {
                            loadingSkeleton
                        } else {
                            sheet
                        }

                        if let message = model.errorMessage {
                            InfoBanner(message: message, actionLabel: "닫기") {
                                model.errorMessage = nil
                            }
                            .padding(16)
                        }
                    }
                }
                .scrollIndicators(.hidden)

                // 저장 바는 스크롤 영역 **밖**에 붙는다. 안에 두면 목록 맨 끝까지
                // 내려가야 닿는다.
                if model.canSave {
                    saveBar
                }
            }
        }
        // 분홍 머리 면이 상태바 뒤까지 깔리도록 위로 넓힌다.
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .task { await model.load(env: env, guest: guest) }
        .onChange(of: model.saved) { _, saved in
            if saved {
                onSaved()
                dismiss()
            }
        }
        .sheet(isPresented: $showCategoryModal) {
            CategoryModal(
                categories: model.categories,
                added: model.addedCategories,
                onSelect: { model.category = $0; showCategoryModal = false },
                onAdd: { model.addCategory($0); showCategoryModal = false }
            )
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(date: $model.date) { model.setDate($0) }
        }
        .sheet(isPresented: $showTimePicker) {
            TimePickerSheet(time: model.startTime) { model.startTime = $0 }
        }
        .overlay {
            // 웹 GuestPlanLimitModal — 비로그인은 플랜 3개까지
            if model.guestLimitReached {
                GuestLimitModal {
                    model.guestLimitReached = false
                    env.isAuthenticated = false
                }
            }
        }
    }

    // MARK: - 분홍 머리 면

    private var head: some View {
        BrandHead(corner: 24) {
            HStack(spacing: 0) {
                HeadIconButton(systemName: "arrow.left", label: "뒤로가기", size: 32, iconSize: 20) {
                    dismiss()
                }
                .offset(x: -8)

                Text(model.isEditMode ? "플랜 수정" : "플랜 추가")
                    .font(WPFont.hak(18, .bold))
                    .tracking(-0.02 * 18)
                    .foregroundStyle(.white)

                Spacer(minLength: 0)
            }

            Spacer().frame(height: 12)

            // 같은 칸을 시트에 또 두지 않는다 — 제목은 여기 하나뿐이다.
            TextField(
                "",
                text: Binding(get: { model.title }, set: { model.title = $0 }),
                prompt: Text("어떤 지출인가요?").foregroundColor(.white.opacity(0.5))
            )
            .font(WPFont.tmoney(24, .bold))
            .tracking(-0.03 * 24)
            .foregroundStyle(.white)
            .tint(.white)
            .textFieldStyle(.plain)
            .accessibilityIdentifier("addplan.title")
        }
    }

    // MARK: - 시트

    @ViewBuilder
    private var sheet: some View {
        RevealSection(visible: model.showCategory) {
            SheetRow {
                LabelGrid("카테고리") {
                    Button { showCategoryModal = true } label: {
                        Text(model.category?.name ?? "카테고리 선택")
                            .font(WPFont.hak(16))
                            .foregroundStyle(
                                model.category != nil ? WPColor.fgNeutral : Self.placeholderGray
                            )
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("addplan.category")
                }

                // 제목에서 추천되는 카테고리. 맞는 게 없으면 아무것도 보이지 않는다.
                if !model.suggestedCategories.isEmpty {
                    Spacer().frame(height: 12)
                    CategorySuggestions(
                        names: model.suggestedCategories,
                        selected: model.category?.name
                    ) { model.selectCategory(named: $0) }
                }
            }
        }

        RevealSection(visible: model.showPayType) {
            SheetRow {
                StackLabel("결제 유형")
                HStack(spacing: 8) {
                    ForEach(PlanPayType.allCases) { type in
                        payTypeChip(type)
                    }
                }
            }
        }

        RevealSection(visible: model.showRestFields) {
            amountRow
            dateRow
            if !model.dateUndecided {
                timeRow
            }
            locationRow
            memoRow
        }
    }

    private func payTypeChip(_ type: PlanPayType) -> some View {
        let selected = model.payType == type
        return Button { model.payType = type } label: {
            Text(type.label)
                .font(WPFont.hak(14, .bold))
                .foregroundStyle(selected ? .white : WPColor.fgMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    selected ? Self.invertedFill : WPColor.fill,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: 금액 + 결제 여부

    private var amountRow: some View {
        SheetRow {
            StackLabel("금액")
            HStack(spacing: 8) {
                TextField(
                    "",
                    text: Binding(get: { model.amount }, set: { model.setAmount($0) }),
                    prompt: Text("0").foregroundColor(Self.placeholderGray)
                )
                .font(WPFont.tmoney(16, .bold))
                .foregroundStyle(WPColor.fgNeutral)
                .multilineTextAlignment(.trailing)
                // `type="number"` 를 쓰지 않는 것과 같은 이유로 숫자 키패드 + 문자열이다.
                .keyboardType(.numberPad)
                .accessibilityIdentifier("addplan.amount")

                Text("만원")
                    .font(WPFont.hak(14))
                    .foregroundStyle(WPColor.fgSubtle)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            // **돈 이야기라 금액 옆이 맞다.** 완료 토글(보드·상세)과는 다른 축이라
            // 거기 섞지 않는다.
            Spacer().frame(height: 8)
            paidToggle
        }
    }

    /// 웹 `data-paid-toggle` — "이미 결제했어요".
    private var paidToggle: some View {
        Button { model.isPaid.toggle() } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(model.isPaid ? WPColor.positive : Color.white)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            model.isPaid ? WPColor.positive : Color(hex: 0xD4D7DC),
                            lineWidth: 2
                        )
                    if model.isPaid {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text("이미 결제했어요")
                        .font(WPFont.hak(13.5, .bold))
                        .foregroundStyle(model.isPaid ? WPColor.positive : WPColor.fgMuted)
                    Text("일정이 남아 있어도 쓴 돈으로 잡혀요")
                        .font(WPFont.hak(11.5))
                        .foregroundStyle(WPColor.fgSubtle)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                model.isPaid ? Color(hex: 0xEEF6F2) : WPColor.fill,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("addplan.paid")
    }

    // MARK: 일자 · 시각

    private var dateRow: some View {
        SheetRow {
            LabelGrid("일자") {
                HStack(spacing: 8) {
                    Button { showDatePicker = true } label: {
                        // **보이는 날짜와 저장하는 날짜는 다른 포맷이다.**
                        // 여기는 `2026년 9월 12일 (토)`, 저장은 `YYYY-MM-DD`.
                        Text(model.dateUndecided ? "날짜 미정" : model.date.weddingDateText)
                            .font(WPFont.hak(16))
                            .foregroundStyle(
                                model.dateUndecided ? Self.placeholderGray : WPColor.fgNeutral
                            )
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(model.dateUndecided)

                    Button { model.toggleDateUndecided() } label: {
                        Text("미정")
                            .font(WPFont.hak(13, .bold))
                            .foregroundStyle(model.dateUndecided ? .white : WPColor.fgMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                model.dateUndecided ? Self.invertedFill : WPColor.fill,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("addplan.dateUndecided")
                }
            }
        }
    }

    /// **시각은 선택이다.** 날짜만 잡아 두는 일정이 훨씬 많아 비어 있는 게 기본이고,
    /// `날짜 미정` 이면 줄 자체를 감춘다.
    private var timeRow: some View {
        SheetRow {
            LabelGrid("시각") {
                HStack(spacing: 8) {
                    Button { showTimePicker = true } label: {
                        Text(formatKoreanTime(model.startTime).isEmpty
                             ? "시각 미정"
                             : formatKoreanTime(model.startTime))
                            .font(WPFont.hak(16))
                            .foregroundStyle(
                                model.startTime == nil ? Self.placeholderGray : WPColor.fgNeutral
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if model.startTime != nil {
                        Button { model.startTime = nil } label: {
                            Text("지우기")
                                .font(WPFont.hak(13, .bold))
                                .foregroundStyle(WPColor.fgMuted)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(WPColor.fill, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: 위치 · 메모

    private var locationRow: some View {
        SheetRow {
            StackLabel("위치")
            HStack(spacing: 8) {
                TextField(
                    "",
                    text: Binding(get: { model.location }, set: { model.setLocation($0) }),
                    prompt: Text("예식장, 스튜디오 등").foregroundColor(Self.placeholderGray)
                )
                .font(WPFont.tmoney(16))
                .foregroundStyle(WPColor.fgNeutral)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button {
                    Task { await model.searchPlaces(env: env) }
                } label: {
                    Group {
                        if model.searching {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 42, height: 42)
                    .background(Self.invertedFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(model.location.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("장소 검색")
            }

            if !model.searchResults.isEmpty {
                Spacer().frame(height: 4)
                ForEach(model.searchResults) { place in
                    Button { model.selectPlace(place) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.placeName)
                                .font(WPFont.tmoney(14, .bold))
                                .foregroundStyle(WPColor.fgNeutral)
                            Text(addressText(place))
                                .font(WPFont.hak(12))
                                .foregroundStyle(WPColor.fgSubtle)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } else if model.searchUnavailable {
                Spacer().frame(height: 4)
                Text("장소 검색은 백엔드에 `/plan/place/search` 가 추가되면 동작해요. 그전까지는 장소명을 직접 입력해 주세요.")
                    .font(WPFont.hak(12))
                    .foregroundStyle(WPColor.fgSubtle)
            } else if model.hasSearched {
                Spacer().frame(height: 4)
                Text("검색 결과가 없어요.")
                    .font(WPFont.hak(12))
                    .foregroundStyle(WPColor.fgSubtle)
            }
        }
    }

    private func addressText(_ place: PlaceSearchResult) -> String {
        if let road = place.roadAddressName, !road.trimmingCharacters(in: .whitespaces).isEmpty {
            return road
        }
        return place.addressName
    }

    private var memoRow: some View {
        SheetRow {
            StackLabel("메모")
            ZStack(alignment: .bottomTrailing) {
                TextEditor(text: Binding(get: { model.memo }, set: { model.setMemo($0) }))
                    .font(WPFont.tmoney(15))
                    .foregroundStyle(WPColor.fgNeutral)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 88)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if model.memo.isEmpty {
                            Text("메모 남기기")
                                .font(WPFont.tmoney(15))
                                .foregroundStyle(Self.placeholderGray)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 14)
                                .allowsHitTesting(false)
                        }
                    }

                Text(verbatim: "\(model.memo.count)/500")
                    .font(WPFont.hak(11))
                    .foregroundStyle(WPColor.fgSubtle)
                    .padding(.trailing, 10)
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: - 저장 바 · 뼈대

    private var saveBar: some View {
        VStack(spacing: 0) {
            Hairline()
            SaveButton(text: model.saveButtonText, enabled: !model.saving) {
                Task { await model.save(env: env, guest: guest) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
        .background(Color.white)
    }

    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<4, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    Hairline()
                    SkeletonBox(width: 84, height: 14)
                        .padding(.top, 12)
                    SkeletonBox(height: 40)
                        .padding(.bottom, 12)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - 색

    /// 입력 칸 placeholder. 웹 `#b0b4bb`
    static let placeholderGray = Color(hex: 0xB0B4BB)
    /// 고른 칩·검색 버튼의 짙은 면. 웹 `#2a3038` (SEED `bg-neutral-inverted`)
    static let invertedFill = Color(hex: 0x2A3038)
}

// MARK: - 시트 줄

/// 구분선 + 안쪽 여백. 시트의 모든 줄이 이 모양이다.
private struct SheetRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Hairline()
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

/// **84pt 라벨 열** + 값. 값이 짧은 줄(카테고리·일자·시각)이 쓴다.
private struct LabelGrid<Content: View>: View {
    var label: String
    @ViewBuilder var content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(WPFont.hak(13, .bold))
                .foregroundStyle(WPColor.fgMuted)
                .frame(width: 84, alignment: .leading)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// 라벨을 값 **위에** 얹는 줄. `결제 유형`·`금액`·`위치`·`메모` 가 쓴다 —
/// 84pt 를 라벨에 떼어 주면 값이 들어갈 자리가 안 남는다.
private struct StackLabel: View {
    var label: String

    init(_ label: String) { self.label = label }

    var body: some View {
        Text(label)
            .font(WPFont.hak(13, .bold))
            .foregroundStyle(WPColor.fgMuted)
            .padding(.bottom, 8)
    }
}

/// 시각 고르기. 웹은 `<input type="time">` 이라 기기 기본 UI 를 쓴다 —
/// 여기서도 시스템 휠을 그대로 쓴다.
private struct TimePickerSheet: View {
    var time: String?
    var onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picked = Date()

    var body: some View {
        NavigationStack {
            DatePicker(
                "",
                selection: $picked,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .padding()
            .navigationTitle("시각")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("확인") {
                        onSelect(Self.text(from: picked))
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(320)])
        .onAppear {
            if let time, let parsed = Self.date(from: time) { picked = parsed }
        }
    }

    /// `"HH:mm"` 으로 굳힌다. 기기 로케일이 12시간제여도 저장 값은 같아야 한다.
    private static func text(from date: Date) -> String {
        let parts = KST.calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    private static func date(from text: String) -> Date? {
        let bits = text.split(separator: ":")
        guard bits.count == 2, let hour = Int(bits[0]), let minute = Int(bits[1]) else { return nil }
        var components = KST.calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return KST.calendar.date(from: components)
    }
}

// MARK: - 조각들


/// 웹의 섹션 등장 애니메이션 (opacity + y 20px, 0.4s)
private struct RevealSection<Content: View>: View {
    var visible: Bool
    @ViewBuilder var content: Content

    var body: some View {
        Group {
            if visible {
                content
                    .transition(.opacity.combined(with: .offset(y: 20)))
            }
        }
        .animation(.easeOut(duration: 0.4), value: visible)
    }
}

private struct SaveButton: View {
    var text: String
    var enabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(WPFont.hak(18, .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    enabled ? WPColor.primary : WPColor.primary.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .shadow(color: WPColor.primary.opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier("addplan.save")
    }
}

/// 제목에서 추천되는 카테고리 칩. 색은 **8색 파스텔 팔레트**(리스트의 6색과 다르다).
private struct CategorySuggestions: View {
    var names: [String]
    var selected: String?
    var onSelect: (String) -> Void

    var body: some View {
        FlowRow(spacing: 6, lineSpacing: 6) {
            ForEach(names, id: \.self) { name in
                let isSelected = name == selected
                Button { onSelect(name) } label: {
                    Text(name)
                        .font(WPFont.hak(13, .semibold))
                        .foregroundStyle(isSelected ? .white : WPColor.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            isSelected
                                ? AnyShapeStyle(WPColor.primary)
                                : AnyShapeStyle(Color(hex: PlanRules.categoryPastelHex(name))),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 웹의 카테고리 선택 모달
private struct CategoryModal: View {
    var categories: [PlanCategory]
    var added: [String]
    var onSelect: (PlanCategory) -> Void
    var onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [WPColor.primary, Color(hex: 0xFF94A1)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 6)

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 24)

                HStack {
                    Text("카테고리")
                        .font(WPFont.hak(20, .black))
                        .foregroundStyle(WPColor.textPrimary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(WPColor.gray400)
                            .frame(width: 36, height: 36)
                            .background(WPColor.gray50, in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                Spacer().frame(height: 16)

                HStack(spacing: 8) {
                    TextField("새 카테고리", text: $newName)
                        .font(WPFont.hak(15))
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(WPColor.stone50, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button {
                        onAdd(newName)
                        newName = ""
                    } label: {
                        Text("추가")
                            .font(WPFont.hak(15, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .frame(height: 48)
                            .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Spacer().frame(height: 20)

                ScrollView {
                    FlowRow(spacing: 8, lineSpacing: 8) {
                        ForEach(allNames, id: \.self) { name in
                            Button {
                                onSelect(categories.first { $0.name == name } ?? PlanCategory(name: name, type: "USER"))
                            } label: {
                                HStack(spacing: 4) {
                                    Text(name)
                                        .font(WPFont.hak(14, .semibold))
                                        .foregroundStyle(WPColor.textPrimary)
                                    if isUserMade(name) {
                                        Text("my")
                                            .font(WPFont.hak(9, .black))
                                            .foregroundStyle(WPColor.primary)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color(hex: PlanRules.categoryPastelHex(name)), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color.white)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
    }

    private var allNames: [String] {
        (categories.map(\.name) + added).reduce(into: [String]()) { result, name in
            if !result.contains(name) { result.append(name) }
        }
    }

    private func isUserMade(_ name: String) -> Bool {
        added.contains(name) || categories.first { $0.name == name }?.isUserMade == true
    }
}

private struct DatePickerSheet: View {
    @Binding var date: KstDate
    var onChange: (KstDate) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("일자 선택")
                .font(WPFont.hak(18, .semibold))
                .foregroundStyle(WPColor.textPrimary)
                .padding(.top, 24)

            // 지출 일자는 과거도 정상이므로 하한을 두지 않는다.
            DateWheelPicker(value: Binding(
                get: { date },
                set: { onChange($0) }
            ))

            Button { dismiss() } label: {
                Text("확인")
                    .font(WPFont.hak(16, .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .background(Color.white)
        .presentationDetents([.height(420)])
        .presentationCornerRadius(32)
    }
}

/// 웹 `GuestPlanLimitModal`
private struct GuestLimitModal: View {
    var onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 0) {
                Text("로그인 없이 이용 중이시네요!")
                    .font(WPFont.hak(18, .bold))
                    .foregroundStyle(WPColor.textPrimary)

                Spacer().frame(height: 12)

                // 이모지는 웹 원문 그대로다.
                Text("비로그인 상태에서는 최대 3개까지만 플랜을 추가할 수 있어요. 📌\n\n또한 비로그인 상태에서는 데이터가 저장되지 않아요.\n\n더 많은 플랜을 관리하고 싶다면 로그인해 보세요!")
                    .font(WPFont.hak(14))
                    .lineSpacing(6)
                    .foregroundStyle(WPColor.stone500)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 20)

                Button(action: onConfirm) {
                    Text("로그인하러 가기")
                        .font(WPFont.hak(15, .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 384)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 24)
        }
    }
}


/// 웹: 흰 반투명 알약 + 그림자
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
        .accessibilityIdentifier("addplan.back")
    }
}
