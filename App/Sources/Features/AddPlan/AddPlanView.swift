import SwiftUI
import WPDomain
import WPModels
import WPUtils

/// 웹 `app/add-plen/page.tsx` 이식.
///
/// 웹의 **카카오맵 임베드와 장소 키워드 검색은 아직 없다.**
/// 카카오맵 iOS SDK 는 콘솔에서 제품을 따로 활성화해야 하고,
/// 장소 검색은 백엔드 프록시(`/plan/place/search`)가 아직 없어 404 다.
/// 지금은 장소를 자유 입력으로 받고 좌표는 0 으로 보낸다 (백엔드가 허용하는 형태).
struct AddPlanView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var model: AddPlanViewModel
    @State private var showCategoryModal = false
    @State private var showDatePicker = false

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
            WPScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BackPill { dismiss() }

                    Spacer().frame(height: 12)

                    Text("계획을 추가해보세요")
                        .font(WPFont.hak(24, .black))
                        .foregroundStyle(WPColor.primary)
                    Text(model.isEditMode ? "플랜 수정" : "플랜 추가")
                        .font(WPFont.hak(32, .black))
                        .foregroundStyle(WPColor.textPrimary)

                    Spacer().frame(height: 20)

                    if model.loadingDetail {
                        ProgressView()
                            .tint(WPColor.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                    } else {
                        form
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
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

    @ViewBuilder
    private var form: some View {
        // 제목 (항상)
        FormCard(label: "제목", required: true) {
            WPFormInput(
                text: Binding(get: { model.title }, set: { model.title = $0 }),
                placeholder: "어떤 지출인가요?",
                useUserFont: true
            )
            .accessibilityIdentifier("addplan.title")
        }

        RevealSection(visible: model.showCategory) {
            FormCard(label: "카테고리", required: true) {
                HStack(spacing: 8) {
                    Button { showCategoryModal = true } label: {
                        Text(model.category?.name ?? "카테고리 선택")
                            .font(WPFont.hak(16, .semibold))
                            .foregroundStyle(model.category != nil ? WPColor.primary : WPColor.stone400)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(
                                model.category != nil ? WPColor.primary.opacity(0.08) : WPColor.stone50,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(
                                        model.category != nil
                                            ? WPColor.primary.opacity(0.25)
                                            : WPColor.stone200,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("addplan.category")

                    Button { showCategoryModal = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18))
                            .foregroundStyle(WPColor.stone400)
                            .frame(width: 56, height: 56)
                            .background(WPColor.stone50, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(WPColor.stone200, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("카테고리 추가")
                }

                // 제목에서 추천되는 카테고리. 맞는 게 없으면 아무것도 보이지 않는다.
                if !model.suggestedCategories.isEmpty {
                    Spacer().frame(height: 10)
                    CategorySuggestions(
                        names: model.suggestedCategories,
                        selected: model.category?.name
                    ) { model.selectCategory(named: $0) }
                }
            }
        }

        RevealSection(visible: model.showPayType) {
            FormCard(label: "결제 유형", required: true) {
                HStack(spacing: 8) {
                    ForEach(PlanPayType.allCases) { type in
                        let selected = model.payType == type
                        Button { model.payType = type } label: {
                            Text(type.label)
                                .font(WPFont.hak(15, .semibold))
                                .foregroundStyle(selected ? WPColor.primary : WPColor.stone400)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    selected ? WPColor.primary.opacity(0.08) : WPColor.stone50,
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(
                                            selected ? WPColor.primary.opacity(0.3) : WPColor.stone200,
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }

        RevealSection(visible: model.showRestFields) {
            VStack(spacing: 0) {
                amountCard
                dateCard
                locationCard
                memoCard
            }
        }

        if let message = model.errorMessage {
            Spacer().frame(height: 8)
            InfoBanner(message: message, actionLabel: "닫기") {
                model.errorMessage = nil
            }
        }

        if model.canSave {
            Spacer().frame(height: 32)
            SaveButton(text: model.saveButtonText, enabled: !model.saving) {
                Task { await model.save(env: env, guest: guest) }
            }
        }
    }

    // MARK: 각 필드

    private var amountCard: some View {
        FormCard(label: "금액") {
            ZStack(alignment: .trailing) {
                WPFormInput(
                    text: Binding(get: { model.amount }, set: { model.setAmount($0) }),
                    placeholder: "0",
                    numeric: true,
                    alignment: .trailing,
                    trailingPadding: 52
                )
                .accessibilityIdentifier("addplan.amount")

                Text("만원")
                    .font(WPFont.hak(15, .medium))
                    .foregroundStyle(WPColor.stone500)
                    .padding(.trailing, 16)
            }
        }
    }

    private var dateCard: some View {
        FormCard(label: "일자") {
            HStack(spacing: 8) {
                Button { showDatePicker = true } label: {
                    Text(model.dateUndecided ? "미정" : model.date.weddingDateText)
                        .font(WPFont.hak(16, .medium))
                        .foregroundStyle(model.dateUndecided ? WPColor.stone300 : WPColor.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            model.dateUndecided ? WPColor.stone50 : WPColor.primary.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    model.dateUndecided ? WPColor.stone200 : WPColor.primary.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)

                Button { model.toggleDateUndecided() } label: {
                    Text("미정")
                        .font(WPFont.hak(14, .medium))
                        .foregroundStyle(model.dateUndecided ? .white : WPColor.stone400)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            model.dateUndecided ? WPColor.stone900 : WPColor.stone50,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    model.dateUndecided ? WPColor.stone900 : WPColor.stone200,
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("addplan.dateUndecided")
            }
        }
    }

    private var locationCard: some View {
        FormCard(label: "위치") {
            HStack(spacing: 8) {
                WPFormInput(
                    text: Binding(get: { model.location }, set: { model.setLocation($0) }),
                    placeholder: "예식장, 스튜디오 등",
                    useUserFont: true
                )

                Button {
                    Task { await model.searchPlaces(env: env) }
                } label: {
                    Group {
                        if model.searching {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 56, height: 56)
                    .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(model.location.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("장소 검색")
            }

            if !model.searchResults.isEmpty {
                Spacer().frame(height: 8)
                ForEach(model.searchResults) { place in
                    Button { model.selectPlace(place) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.placeName)
                                .font(WPFont.tmoney(14, .semibold))
                                .foregroundStyle(WPColor.textPrimary)
                            Text(addressText(place))
                                .font(WPFont.hak(12))
                                .foregroundStyle(WPColor.stone400)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } else if model.searchUnavailable {
                Spacer().frame(height: 8)
                Text("장소 검색은 백엔드에 `/plan/place/search` 가 추가되면 동작해요. 그전까지는 장소명을 직접 입력해 주세요.")
                    .font(WPFont.hak(12))
                    .foregroundStyle(WPColor.stone400)
            } else if model.hasSearched {
                Spacer().frame(height: 8)
                Text("검색 결과가 없어요.")
                    .font(WPFont.hak(12))
                    .foregroundStyle(WPColor.stone400)
            }
        }
    }

    private func addressText(_ place: PlaceSearchResult) -> String {
        if let road = place.roadAddressName, !road.trimmingCharacters(in: .whitespaces).isEmpty {
            return road
        }
        return place.addressName
    }

    private var memoCard: some View {
        FormCard(label: "메모") {
            ZStack(alignment: .bottomTrailing) {
                WPFormInput(
                    text: Binding(get: { model.memo }, set: { model.setMemo($0) }),
                    placeholder: "메모 남기기",
                    useUserFont: true,
                    multiline: true,
                    minHeight: 100
                )
                Text(verbatim: "\(model.memo.count)/500")
                    .font(WPFont.hak(12))
                    .foregroundStyle(WPColor.stone400)
                    .padding(.trailing, 12)
                    .padding(.bottom, 12)
            }
        }
    }
}

// MARK: - 조각들

/// 웹: `bg-white p-5 rounded-2xl shadow-sm border border-stone-100` + 라벨
private struct FormCard<Content: View>: View {
    var label: String
    var required: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 2) {
                Text(label)
                    .font(WPFont.hak(14, .bold))
                    .foregroundStyle(WPColor.textPrimary)
                if required {
                    Text("*")
                        .font(WPFont.hak(14, .bold))
                        .foregroundStyle(WPColor.primary)
                }
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(WPColor.stone100, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
        .padding(.bottom, 12)
    }
}

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
    var categories: [Category]
    var added: [String]
    var onSelect: (Category) -> Void
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
                                onSelect(categories.first { $0.name == name } ?? Category(name: name, type: "USER"))
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

/// 폼 전용 입력창. 배경·테두리를 직접 그린다.
private struct WPFormInput: View {
    @Binding var text: String
    var placeholder: String
    var numeric: Bool = false
    var useUserFont: Bool = false
    var alignment: TextAlignment = .leading
    var trailingPadding: CGFloat = 16
    var multiline: Bool = false
    var minHeight: CGFloat = 56

    var body: some View {
        Group {
            if multiline {
                TextEditor(text: $text)
                    .font(font)
                    .foregroundStyle(WPColor.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: minHeight, alignment: .topLeading)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(placeholder)
                                .font(font)
                                .foregroundStyle(WPColor.stone300)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
            } else {
                TextField("", text: $text, prompt: promptText)
                    .font(font)
                    .foregroundStyle(WPColor.textPrimary)
                    .multilineTextAlignment(alignment)
                    .keyboardType(numeric ? .numberPad : .default)
                    .frame(height: minHeight)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, trailingPadding)
        .background(WPColor.stone50, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(WPColor.stone200, lineWidth: 1)
        )
        .tint(WPColor.primary)
    }

    private var font: Font {
        useUserFont ? WPFont.tmoney(16, .medium) : WPFont.hak(16, .medium)
    }

    private var promptText: Text {
        Text(placeholder)
            .font(font)
            .foregroundColor(WPColor.stone300)
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
