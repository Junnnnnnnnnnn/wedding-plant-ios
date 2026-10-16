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
/// 장소 검색 결과에서 주소와 좌표를 선택하고, 검색 실패 시 입력을 유지합니다.
struct AddPlanView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore
    @Environment(\.dismiss) private var dismiss
    /// 탭 셸이 덮어 그렸을 때의 닫기(탭바가 남는 Android `ADD_PLAN`). 창으로 띄웠으면 비어 있어 `dismiss` 를 쓴다.
    @Environment(\.addPlanClose) private var closeOverride

    @StateObject private var model: AddPlanViewModel
    @State private var locationRejection = 0
    @State private var showCategoryModal = false
    @State private var showDatePicker = false
    @State private var showTimePicker = false
    /// 영수증 줄 자물쇠 → 준비 패스 소개. 이 화면 위에 덮여 적던 플랜이 그대로 남는다(Android `PassIntroSheet`).
    @State private var showPassIntro = false

    /// 저장이 끝났을 때 목록을 새로 고치도록 알린다.
    var onSaved: () -> Void

    init(
        editId: Int? = nil,
        roomId: Int? = nil,
        initialDate: String? = nil,
        prefill: AddPlanViewModel.Prefill? = nil,
        onSaved: @escaping () -> Void
    ) {
        _model = StateObject(
            wrappedValue: AddPlanViewModel(
                editId: editId,
                roomId: roomId,
                initialDate: initialDate,
                prefill: prefill
            )
        )
        self.onSaved = onSaved
    }

    /// 처음 보일 스크롤 자리. 캡처 테스트가 Android `docs-edit`(서류 칸까지 굴린 수정 화면)와 같은 자리를 찍을 때만 쓴다.
    var scrollAnchor: UnitPoint? = nil

    init(model: AddPlanViewModel, scrollAnchor: UnitPoint? = nil, onSaved: @escaping () -> Void = {}) {
        _model = StateObject(wrappedValue: model); self.onSaved = onSaved; self.scrollAnchor = scrollAnchor
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

                            if let message = model.errorMessage {
                                InfoBanner(message: message, actionLabel: "닫기") {
                                    model.errorMessage = nil
                                }
                                .padding(16)
                            }

                            // 서류는 **수정하기에서** 붙이고 지운다(Android 2026-10-10). 새 플랜은 아직 붙일 자리(일정 id)가 없다.
                            // 카드 둘레(가로 24 · 아래 18)는 Android `PassDocsRow` 의 바깥 여백 그대로다.
                            if let id = model.editId, id > 0 {
                                Spacer().frame(height: 16)
                                PassDocumentsView(scheduleId: id, canAdd: true)
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 18)
                            }
                            Spacer().frame(height: 24)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .defaultScrollAnchor(scrollAnchor)

                // 저장 바는 스크롤 영역 **밖**에 붙는다. 안에 두면 목록 맨 끝까지
                // 내려가야 닿는다. 제목·카테고리·결제 유형이 다 있을 때만(웹 showSaveBar).
                if model.canSave && !model.loadingDetail {
                    saveBar
                }
            }
        }
        // 분홍 머리 면이 상태바 뒤까지 깔리도록 위로 넓힌다.
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .task { await model.load(env: env, guest: guest) }
        .fullScreenCover(isPresented: $model.saved) {
            PlanBloomSuccess(title: model.title, amount: Double(model.amount) ?? 0, remaining: model.remainingBudget, action: model.isEditMode ? .update : .create) {
                model.saved = false; onSaved(); close()
            }
        }
        .sheet(isPresented: $showCategoryModal) {
            WeddingCategoryPicker(categories: model.categories, added: model.addedCategories, selected: model.category, recentNames: model.recentCategoryNames) { category, added in
                for name in added { model.addCategory(name) }
                model.category = category
                model.categorySelectedByUser = true
                model.recentCategoryNames = WeddingCategories.pushRecent(model.recentCategoryNames, picked: category.name)
                showCategoryModal = false
            }
        }
        .background {
            // 저장 완료 카드와 같은 뷰에 두 번째 fullScreenCover 를 걸지 않으려고 배경에 단다.
            Color.clear.fullScreenCover(isPresented: $showPassIntro, onDismiss: { Task { await model.loadReceiptPass(env: env) } }) {
                PassView(roomId: model.receiptRoomId)
            }
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

    private func close() {
        if let closeOverride { closeOverride() } else { dismiss() }
    }

    // MARK: - 분홍 머리 면

    private var head: some View {
        BrandHead(corner: 24) {
            HStack(spacing: 0) {
                Button { close() } label: {
                    WPMaterialIcon(kind: .back).frame(width: 20, height: 20).foregroundStyle(.white).frame(width: 32, height: 32)
                }.buttonStyle(.plain).accessibilityLabel("뒤로가기")
                .offset(x: -8)
                .accessibilityIdentifier("addplan.back")

                Text(model.isEditMode ? "플랜 수정" : "플랜 추가")
                    .wpTypography(18, .bold)
                    .tracking(-0.02 * 18)
                    .foregroundStyle(.white)

                Spacer(minLength: 0)
            }

            Spacer().frame(height: 12)

            // 같은 칸을 시트에 또 두지 않는다 — 제목은 여기 하나뿐이다.
            WPTmoneyInput(text: $model.title, placeholder: "어떤 지출인가요?", size: 24, bold: true,
                color: .white, placeholderColor: .white.withAlphaComponent(0.5), tracking: -0.72, identifier: "addplan.title")
            Spacer().frame(height: 4)
            Text("제목을 누르면 입력할 수 있어요").wpTypography(14).foregroundStyle(.white.opacity(0.8))
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
                            .wpTypography(16)
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
                    CategorySuggestions(names: model.suggestedCategories) { model.selectCategory(named: $0) }
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
                .wpTypography(14, selected ? .bold : .regular)
                .foregroundStyle(selected ? .white : WPColor.fgMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
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
            HStack {
                Text("금액").wpTypography(13, .bold).foregroundStyle(WPColor.fgMuted)
                Spacer(minLength: 12)
                Text("천원 단위는 반올림·반내림 해주세요").wpTypography(11).foregroundStyle(WPColor.fgSubtle)
            }.padding(.bottom, 8)
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                WPTmoneyInput(text: Binding(get: { model.amount }, set: { model.setAmount($0) }),
                    placeholder: "0", size: 24, bold: true, placeholderColor: UIColor(Self.placeholderGray),
                    alignment: .right, keyboard: .decimalPad, identifier: "addplan.amount")
                Text("만 원").wpTypography(14).foregroundStyle(WPColor.fgMuted)
            }.padding(.horizontal, 16).padding(.vertical, 12)
                .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 12))
            // **금액 바로 아래에 둔다.** 돈 이야기라 금액 옆이 맞고, 일정 완료(상세)와는 다른 축이다.
            Spacer().frame(height: 10)
            paidToggle
            // 영수증은 **결제 체크 바로 아래**(결제한 순간이 영수증을 쥔 순간). 패스가 있으면 어디에 붙이는지만
            // 알리고 다시 팔지 않는다(Android · 웹 f6f0405).
            if model.isPaid, let hasPass = model.receiptPass {
                ReceiptRow(hasPass: hasPass, editing: model.isEditMode) { showPassIntro = true }
                    .padding(.top, 8)
            }
        }
    }

    /// 웹 `data-paid-toggle` — "이미 결제했어요".
    private var paidToggle: some View {
        // 완료한 플랜은 결제한 것 — 켠 채 잠근다(Android `checked = isPaidNow || completed`)
        let checked = model.isPaid || model.completed
        return Button { if !model.completed { model.isPaid.toggle() } } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(checked ? WPColor.positive : Color.white)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            checked ? WPColor.positive : Color(hex: 0xD4D7DC),
                            lineWidth: 2
                        )
                    if checked {
                        // Material `Icons.Filled.Check` 11dp — Android 와 같은 경로
                        WPMaterialPathIcon(paths: WPIconPaths.check, size: 11, color: .white)
                    }
                }
                .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text("이미 결제했어요".wpKeepAll)
                        .wpTypography(13.5, .bold)
                        .foregroundStyle(checked ? WPColor.positive : WPColor.fgMuted)
                    Text((model.completed ? "완료한 플랜은 결제한 것으로 잡혀요" : "일정이 남아 있어도 쓴 돈으로 잡혀요").wpKeepAll)
                        .wpTypography(12)
                        .foregroundStyle(WPColor.fgSubtle)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                checked ? Color(hex: 0xEEF6F2) : WPColor.fill,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        // `.disabled` 는 쓰지 않는다 — 잠근 칸이 흐려지면 Android(켠 채 그대로)와 달라진다. 누름은 위에서 막는다.
        .buttonStyle(.plain)
        .accessibilityAddTraits(checked ? .isSelected : [])
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
                        Text((model.dateUndecided ? "미정" : model.date.weddingDateText).wpKeepAll)
                            .wpTypography(16)
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
                            .wpTypography(12, .bold)
                            .foregroundStyle(model.dateUndecided ? .white : WPColor.fgMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
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
                             ? "-- --:--"
                             : formatKoreanTime(model.startTime))
                            .wpTypography(16)
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
                                .wpTypography(12, .bold)
                                .foregroundStyle(WPColor.fgMuted)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(WPColor.fill, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button { showTimePicker = true } label: {
                            WPMaterialIcon(kind: .clock).frame(width: 18, height: 18).foregroundStyle(WPColor.fgNeutral)
                        }.buttonStyle(.plain).accessibilityLabel("시각 고르기")
                    }
                }
            }
        }
    }

    // MARK: 위치 · 메모

    /// 검색 버튼과 키보드 엔터가 같은 길로 — 빈 칸이면 흔들고 거절 햅틱(웹 d513e95)
    private func searchLocation() {
        if model.location.trimmingCharacters(in: .whitespaces).isEmpty {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            locationRejection += 1
        }
        Task { await model.searchPlaces(env: env) }
    }

    private var locationRow: some View {
        SheetRow {
            StackLabel("위치")
            // 빈 칸으로 검색하면 흔들기(0,-6,6,-4,4,0 / 400ms) · 빨간 테두리 · `위치를 입력해주세요` · 거절 햅틱(웹 d513e95).
            // 버튼은 늘 눌린다 — 꺼 두면 왜 안 되는지 몰랐다. 칸에 초점은 주지 않는다(키보드는 칸을 직접 눌렀을 때만).
            HStack(spacing: 8) {
                WPTmoneyInput(text: Binding(get: { model.location }, set: { model.setLocation($0) }),
                    placeholder: "예식장, 스튜디오 등", placeholderColor: UIColor(Self.placeholderGray), identifier: "addplan.location",
                    // 엔터 = 검색(Android `ImeAction.Search` · 웹 form submit)
                    returnKey: .search, onSubmit: { searchLocation() })
                    .padding(.horizontal, 16).padding(.vertical, 12).frame(minHeight: 44)
                    .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(model.locationError ? WPColor.danger : .clear, lineWidth: 1))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(model.locationError ? WPColor.danger.opacity(0.1) : .clear, lineWidth: 2).padding(-2))
                    .keyframeAnimator(initialValue: CGFloat.zero, trigger: locationRejection) { view, offset in
                        view.offset(x: offset)
                    } keyframes: { _ in
                        CubicKeyframe(-6, duration: 0.08)
                        CubicKeyframe(6, duration: 0.08)
                        CubicKeyframe(-4, duration: 0.08)
                        CubicKeyframe(4, duration: 0.08)
                        CubicKeyframe(0, duration: 0.08)
                    }

                let canSearch = !model.location.trimmingCharacters(in: .whitespaces).isEmpty
                Button { searchLocation() } label: {
                    Group {
                        if model.searching {
                            ProgressView().tint(.white).controlSize(.small)
                        } else {
                            // Material `Icons.Filled.Search` 18dp
                            WPMaterialIcon(kind: .search).frame(width: 18, height: 18)
                                .foregroundStyle(canSearch ? .white : WPColor.fgSubtle)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(canSearch ? Self.invertedFill : WPColor.fill, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("장소 검색")
                .accessibilityIdentifier("addplan.search")
            }

            if model.locationError {
                Text("위치를 입력해주세요").wpTypography(12).foregroundStyle(WPColor.danger).padding(.top, 8)
            }

            if !model.searchResults.isEmpty {
                // Android: 테두리 카드 한 장씩 — 이름 15 굵게(stone900) · 주소 13(stone600)
                VStack(spacing: 8) {
                    ForEach(model.searchResults) { place in
                        Button { model.selectPlace(place) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(place.placeName)
                                    .wpTypography(15, .bold)
                                    .foregroundStyle(WPColor.stone900)
                                Text(addressText(place))
                                    .wpTypography(13)
                                    .foregroundStyle(WPColor.stone600)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(WPColor.stone200, lineWidth: 1))
                            .contentShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 12)
            } else if model.searchUnavailable {
                Text("장소 검색은 백엔드에 `/plan/place/search` 가 추가되면 동작합니다. 그전까지는 아래 지도를 탭해 위치를 지정하세요.")
                    .wpTypography(12)
                    .foregroundStyle(WPColor.fgSubtle)
                    .padding(.top, 8)
            } else if let message = model.searchError {
                Text(message)
                    .wpTypography(13)
                    .foregroundStyle(WPColor.danger)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            } else if model.hasSearched {
                Text("검색 결과가 없습니다.")
                    .wpTypography(13)
                    .foregroundStyle(WPColor.stone500)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(WPColor.stone50, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(WPColor.stone200, lineWidth: 1))
                    .padding(.top, 8)
            }

            // 장소 이름을 적으면 카카오맵이 붙는다(Android `KakaoMapView(onMapClick)` 와 같은 SDK).
            if !model.location.trimmingCharacters(in: .whitespaces).isEmpty {
                // 좌표가 아직 없으면 서울시청을 기준점으로 띄우고 눌러서 고르게 한다
                KakaoMapView(
                    latitude: model.hasCoordinates ? model.locationLat : Self.defaultLat,
                    longitude: model.hasCoordinates ? model.locationLng : Self.defaultLng,
                    onMapClick: { lat, lng in model.setCoords(lat: lat, lng: lng) }
                )
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(WPColor.stone200, lineWidth: 1))
                .padding(.top, 12)
                Text(model.hasCoordinates
                     ? String(format: "좌표 %.5f, %.5f — 지도를 탭하면 위치를 바꿀 수 있어요.", model.locationLat, model.locationLng)
                     : "지도를 탭해 위치를 지정하세요.")
                    .wpTypography(11)
                    .foregroundStyle(WPColor.fgSubtle)
                    .padding(.top, 6)
            }
        }
    }

    /// 좌표를 아직 못 고른 상태에서 지도를 띄울 기준점 — 서울시청
    static let defaultLat = 37.5665
    static let defaultLng = 126.9780

    private func addressText(_ place: PlaceSearchResult) -> String {
        if let road = place.roadAddressName, !road.trimmingCharacters(in: .whitespaces).isEmpty {
            return road
        }
        return place.addressName
    }

    /// Android `FillInput(singleLine = false, minHeight = 76, bottomPadding = 32)` — 글은 왼쪽 16 · 위 12 에서 시작하고
    /// 적는 만큼 칸이 자란다. 아래 32 는 오른쪽 아래 `n/500` 자리다.
    private var memoRow: some View {
        SheetRow {
            StackLabel("메모")
            ZStack(alignment: .bottomTrailing) {
                // 줄바꿈을 받아야 해서 TextEditor 다. 안쪽 여백(가로 5 · 위아래 8)을 빼서 글이 Android 처럼
                // 왼쪽 16 · 위 12 에서 시작하고, 아래 32 를 비운다.
                TextEditor(text: Binding(get: { model.memo }, set: { model.setMemo($0) }))
                    .font(WPFont.tmoney(14))
                    .foregroundStyle(WPColor.fgNeutral)
                    .tint(WPColor.primary)
                    .scrollContentBackground(.hidden)
                    .scrollDisabled(true)
                    .frame(minHeight: 76 - 11 - 24)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 11)
                    // Android 은 줄 높이 1.5 라 글이 위 12 보다 반 줄 여백만큼 내려와 있다 — 캡처로 맞춘 값
                    .padding(.top, 11)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .topLeading) {
                        if model.memo.isEmpty {
                            Text("메모 남기기")
                                .font(WPFont.tmoney(14))
                                .foregroundStyle(Self.placeholderGray)
                                .padding(.leading, 16)
                                .padding(.top, 19)
                                .allowsHitTesting(false)
                        }
                    }
                    .accessibilityIdentifier("addplan.memo")

                Text(verbatim: "\(model.memo.count)/500")
                    .wpTypography(12)
                    .foregroundStyle(WPColor.fgSubtle)
                    .padding(.trailing, 16)
                    .padding(.bottom, 8)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - 저장 바 · 뼈대

    private var saveBar: some View {
        VStack(spacing: 0) {
            Hairline(color: Color.black.opacity(0.1))
            SaveButton(text: model.saveButtonText, enabled: !model.saving) {
                Task { await model.save(env: env, guest: guest) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .background(Color.white)
    }

    /// 수정할 일정을 받는 동안 — 폼과 같은 "라벨 | 값" 줄 모양의 뼈대(Android 와 같은 치수).
    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: 0) {
                    SkeletonBox(width: 56, height: 16)
                    Spacer().frame(width: 40)
                    SkeletonBox(height: 44, corner: 12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                Hairline(color: WPColor.stone100)
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
                .wpTypography(13, .bold)
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
            .wpTypography(13, .bold)
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
                .wpTypography(16, .bold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    enabled ? WPColor.primary : WPColor.primary.opacity(0.7),
                    in: RoundedRectangle(cornerRadius: 12)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier("addplan.save")
    }
}

/// 제목으로 추천된 카테고리 칩 줄 — Android `CategorySuggestions`.
/// 웹 `h-9 px-3 rounded-lg bg-stone-100 border border-stone-200`, 글자 `text-sm font-medium text-stone-600`. 가로로 구른다.
/// 고른 칩을 따로 칠하지 않는다(웹 칩은 늘 `bg-stone-100`) — 칩으로 고르면 줄 자체가 접히고, 제목을 고치면 다시 나온다.
private struct CategorySuggestions: View {
    var names: [String]
    var onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(names, id: \.self) { name in
                    Button { onSelect(name) } label: {
                        Text(name).wpTypography(14, .medium).foregroundStyle(WPColor.stone600).lineLimit(1)
                            .padding(.horizontal, 12).frame(height: 36)
                            .background(WPColor.stone100, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(WPColor.stone200, lineWidth: 1))
                    }.buttonStyle(.plain)
                    .accessibilityIdentifier("addplan.suggest.\(name)")
                }
            }
        }.scrollIndicators(.hidden)
    }
}

private struct DatePickerSheet: View {
    @Binding var date: KstDate
    var onChange: (KstDate) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("일자 선택")
                .wpTypography(18, .semibold)
                .foregroundStyle(WPColor.textPrimary)
                .padding(.top, 24)

            // 지출 일자는 과거도 정상이므로 하한을 두지 않는다.
            DateWheelPicker(value: Binding(
                get: { date },
                set: { onChange($0) }
            ))

            Button { dismiss() } label: {
                Text("확인")
                    .wpTypography(16, .bold)
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
                    .wpTypography(18, .bold)
                    .foregroundStyle(WPColor.textPrimary)

                Spacer().frame(height: 12)

                // 이모지는 웹 원문 그대로다.
                Text("비로그인 상태에서는 최대 3개까지만 플랜을 추가할 수 있어요. 📌\n\n또한 비로그인 상태에서는 데이터가 저장되지 않아요.\n\n더 많은 플랜을 관리하고 싶다면 로그인해 보세요!")
                    .wpTypography(14)
                    .lineSpacing(6)
                    .foregroundStyle(WPColor.stone500)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 20)

                Button(action: onConfirm) {
                    Text("로그인하러 가기")
                        .wpTypography(15, .bold)
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
                    .wpTypography(16, .bold)
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

/// `영수증 붙이기` 줄 — Android `ReceiptRow`(웹 f6f0405). 패스가 있으면 **누를 수 없는 안내**(저장 뒤 서류 칸에 붙인다),
/// 없으면 자물쇠 + 준비 패스 소개. 모양은 둘 다 `rounded-xl bg-[#f7f8f9] px-3 py-2.5`.
private struct ReceiptRow: View {
    var hasPass: Bool
    var editing: Bool
    var onOpenGate: () -> Void

    /// lucide `Paperclip` — Android `LucideIcons.PaperclipBold`(획 3)
    private static let paperclip = ["m16 6-8.414 8.586a2 2 0 0 0 2.829 2.829l8.414-8.586a4 4 0 1 0-5.657-5.657l-8.379 8.551a6 6 0 1 0 8.485 8.485l8.379-8.551"]

    var body: some View {
        let row = HStack(spacing: 10) {
            WPLucideIcon(paths: hasPass ? Self.paperclip : WPIconPaths.lock, size: 10, color: WPColor.brand700, strokeWidth: 3)
                .frame(width: 18, height: 18)
                .background(WPColor.brand100, in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text("영수증 붙이기").wpTypography(13.5, .bold).foregroundStyle(WPColor.fgMuted)
                // 서류는 **수정하기에서만** 붙인다(2026-10-10) — 새 플랜은 아직 붙일 자리(일정)가 없다
                Text((!hasPass ? "준비 패스가 있으면 서류 칸에 붙일 수 있어요"
                      : editing ? "아래 서류 칸에 바로 붙여요"
                      : "저장한 뒤 수정하기에서 서류 칸에 붙여요").wpKeepAll)
                    .wpTypography(12)
                    .foregroundStyle(WPColor.fgSubtle)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 12))

        if hasPass {
            row.accessibilityElement(children: .combine)
        } else {
            Button(action: onOpenGate) { row.contentShape(RoundedRectangle(cornerRadius: 12)) }
                .buttonStyle(.plain)
                .accessibilityIdentifier("addplan.receipt")
        }
    }
}
