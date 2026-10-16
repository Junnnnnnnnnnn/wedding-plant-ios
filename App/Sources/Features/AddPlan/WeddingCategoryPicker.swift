import SwiftUI
import UIKit
import WPModels
import WPDomain

/// 카테고리 선택기 — Android `ui/addplan/CategoryPickerSheet.kt`(웹 `CategoryPicker.tsx` d513e95 폰 바닥 시트) 이식.
///
/// - **누르기만 해서는 적용되지 않습니다.** `선택 완료` 가 유일한 적용이고, 내려 닫기·X 는 취소입니다
///   (고른 것도, 이번에 직접 추가해 둔 이름도 버립니다). 직접 추가 화면의 X·취소는 목록으로 돌아갑니다.
/// - 열어도 검색 칸에 초점을 주지 않습니다(Android 키보드 규칙 — 칸을 직접 눌렀을 때만).
/// - 치수·색·문구는 Android 와 한 글자도 다르지 않게 둡니다. 판정은 `WeddingCategories`(Core).
struct WeddingCategoryPicker: View {
    let categories: [PlanCategory]
    let added: [String]
    let selected: PlanCategory?
    /// 최근 고른 이름(화면 메모리뿐, Android `recentCategoryNames`)
    var recentNames: [String] = []
    let confirm: (PlanCategory, [String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var group: Int?
    @State private var draft: PlanCategory?
    @State private var pending: [PlanCategory] = []
    @State private var adding = false
    @State private var newName = ""
    @State private var notice = ""
    @State private var error = ""
    @FocusState private var searchFocused: Bool
    @FocusState private var nameFocused: Bool
    /// 목록을 내렸는지 — 내렸으면 시트를 끌어 닫지 않습니다(Android `dragScrollsBody`).
    /// **거리가 아니라 참·거짓만** 둡니다: 거리를 상태로 두면 스크롤 프레임마다 시트 전체(타일 40여 개)를
    /// 다시 그려 목록이 드드득 끊겼습니다.
    @State private var listScrolled = false
    /// 붙여 둔 머리·칩을 잡고 아래로 끌면 목록이 먼저 맨 위로 갑니다
    @State private var scrollToTop = 0

    private var all: [PlanCategory] { WeddingCategories.all(categories, added: added.map { PlanCategory(name: $0, color: "#E8DDF5", type: "USER") } + pending) }
    private var filtered: [PlanCategory] { WeddingCategories.filter(all, group: group, query: query) }
    /// 이번에 추가한 것 중 부모 목록에 없는 것 — 저장 때 `addCategoryNameList` 로 갑니다
    private var pendingAdded: [PlanCategory] {
        pending.filter { item in !categories.contains { WeddingCategories.normalize($0.name) == WeddingCategories.normalize(item.name) } }
    }
    /// `직접 추가` 배지 — 서버의 USER + 이번 세션에서 만든 이름(Android `userAddedNames`)
    private func isUserAdded(_ category: PlanCategory) -> Bool {
        let key = WeddingCategories.normalize(category.name)
        return categories.contains { $0.type == "USER" && WeddingCategories.normalize($0.name) == key }
            || added.contains { WeddingCategories.normalize($0) == key }
            || pendingAdded.contains { WeddingCategories.normalize($0.name) == key }
    }

    private static var screen: CGSize {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.size ?? CGSize(width: 390, height: 844)
    }
    /// 웹 폰: 높이 740 고정, 화면 - 55 까지
    private var sheetHeight: CGFloat { min(740, Self.screen.height - 55) }
    private var narrow: Bool { Self.screen.width <= 350 }
    private var side: CGFloat { narrow ? 15 : 20 }

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(PK.handle).frame(width: 36, height: 4).padding(.top, 11)
            // Android 는 420dp 보다 낮으면 머리·필터도 함께 굴립니다. 앱은 세로 고정이라 시트가 늘 그보다 높지만,
            // 키보드로 줄어드는 높이로 판정하면 검색 칸이 스크롤 안팎을 오가며 초점(키보드)을 잃어 시트 높이로만 봅니다.
            if sheetHeight - 15 >= 420 {
                header.modifier(pinnedDrag)
                if adding {
                    ScrollView { addForm }.scrollDismissesKeyboard(.interactively)
                } else {
                    chips.modifier(pinnedDrag)
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                Color.clear.frame(height: 0).id("top")
                                list
                            }
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .modifier(PickerScrollReader { listScrolled = $0 })
                        .onChange(of: query) { _, _ in proxy.scrollTo("top", anchor: .top) }
                        .onChange(of: group) { _, _ in proxy.scrollTo("top", anchor: .top) }
                        .onChange(of: scrollToTop) { _, _ in withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("top", anchor: .top) } }
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        header
                        if adding { addForm } else { chips; list }
                    }
                }.scrollDismissesKeyboard(.interactively)
            }
            Spacer(minLength: 0)
            footer.modifier(pinnedDrag)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .foregroundStyle(PK.ink)
        /*
          **목록을 내려 둔 채 머리·그룹 칩·바닥 줄을 잡고 끌어도 시트가 닫히지 않습니다**(Android 2026-10-12
          사용자 보고 — `dragScrollsBody`). 그 자리는 스크롤 밖이라 끌기를 시트가 곧바로 받았습니다. SwiftUI 시트는
          끌기를 목록으로 넘길 수 없어, 목록이 맨 위가 아닐 때는 끌어 닫기를 막고 아래로 끈 만큼 목록을 맨 위로
          올립니다 — 한 번 더 끌면 그때 닫힙니다. 닫기 X·바깥 누름은 그대로 닫습니다.
        */
        .interactiveDismissDisabled(listScrolled && !adding)
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(26)
        .presentationBackground(Color.white)
        .onAppear { draft = selected }
        // 목록 ↔ 직접 추가를 오갈 때는 키보드를 내립니다(Android `DismissKeyboardOn(adding)`)
        .onChange(of: adding) { _, _ in searchFocused = false; nameFocused = false }
    }

    /// 붙여 둔 자리(머리 · 칩 · 바닥 줄)를 아래로 끌면 목록을 맨 위로 — 목록 안의 끌기는 목록이 받습니다
    private var pinnedDrag: PinnedDrag {
        PinnedDrag { if listScrolled, !adding { scrollToTop += 1 } }
    }

    // MARK: 머리

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text((adding ? "우리만의 카테고리" : "카테고리를 골라주세요").wpKeepAll)
                        .tracking(-0.6)
                        .pickerText(narrow ? 21 : 23, .black, lineHeight: (narrow ? 21 : 23) * 1.4)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(adding ? "우리만의 카테고리" : "카테고리를 골라주세요")
                    Text((adding ? "필요한 준비를 원하는 이름으로 추가해요." : "찾는 건 빠르게, 모르는 건 둘러보며.").wpKeepAll)
                        .pickerText(12).foregroundStyle(PK.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button { if adding { cancelAdd() } else { dismiss() } } label: {
                    LucideGlyph(kind: .x).stroke(PK.closeIcon, style: LucideGlyph.style(18))
                        .frame(width: 18, height: 18)
                        .frame(width: 34, height: 34)
                        .background(PK.closeBg, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(adding ? "카테고리 추가 취소" : "닫기")
                .accessibilityIdentifier("category.close")
            }
            if !adding { searchBox.padding(.top, 17) }
        }
        .padding(.horizontal, side).padding(.top, 20).padding(.bottom, 14)
    }

    private var searchBox: some View {
        HStack(spacing: 10) {
            LucideGlyph(kind: .search).stroke(PK.searchIcon, style: LucideGlyph.style(18)).frame(width: 18, height: 18)
            TextField("", text: $query, prompt: Text("드레스, 청첩장, 신혼여행…").foregroundColor(PK.searchHint))
                .font(Font(WPTypeface.hak.uiFont(14, .regular)))
                .foregroundStyle(PK.searchText)
                .tint(WPColor.primary)
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .padding(.vertical, 12)
                .accessibilityLabel("카테고리 검색")
                .accessibilityIdentifier("category.search")
            if !query.isEmpty {
                Button { query = "" } label: {
                    LucideGlyph(kind: .x).stroke(PK.searchIcon, style: LucideGlyph.style(13)).frame(width: 13, height: 13)
                        .frame(width: 20, height: 20).background(PK.searchClear, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("검색어 지우기")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(RoundedRectangle(cornerRadius: 13).fill(PK.searchBg))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(searchFocused ? PK.searchFocus : PK.searchLine, lineWidth: 1))
        // 웹 포커스: 바깥 3px 옅은 분홍 링(자리를 차지하지 않습니다)
        .background(RoundedRectangle(cornerRadius: 16).fill(PK.searchRing).padding(-3).opacity(searchFocused ? 1 : 0))
        // 돋보기·둘레를 눌러도 칸을 누른 것으로(Android `focusFieldOnTap`)
        .contentShape(Rectangle())
        .onTapGesture { searchFocused = true }
    }

    // MARK: 필터 칩

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                chip("전체", count: all.count, index: nil)
                ForEach(WeddingCategories.groupIndices(all), id: \.self) { index in
                    chip(WeddingCategories.groups[index], count: WeddingCategories.count(all, group: index), index: index)
                }
            }
            .padding(.horizontal, side)
        }
        .scrollIndicators(.hidden)
        .padding(.bottom, 14)
    }

    private func chip(_ label: String, count: Int, index: Int?) -> some View {
        let on = group == index
        let color = on ? Color.white : PK.chipText
        return Button { group = index } label: {
            HStack(spacing: 6) {
                Text(label).pickerText(11, on ? .bold : .regular).foregroundStyle(color).lineLimit(1).fixedSize()
                Text("\(count)").pickerText(10).foregroundStyle(color.opacity(0.6)).lineLimit(1).fixedSize()
            }
            .padding(.horizontal, 11).padding(.vertical, 7)
            .frame(minHeight: 34)
            .background(Capsule().fill(on ? PK.chipOn : Color.white))
            .overlay(Capsule().strokeBorder(on ? PK.chipOn : PK.chipLine, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) \(count)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: 목록

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            metaLine
            let recent = WeddingCategories.recent(all, names: recentNames)
            if !recent.isEmpty && query.isEmpty && group == nil { recentBlock(recent) }
            if filtered.isEmpty {
                emptyResult
            } else {
                ForEach(WeddingCategories.groupIndices(all), id: \.self) { index in
                    let choices = filtered.filter { WeddingCategories.group($0.name) == index }
                    if !choices.isEmpty { groupSection(index, choices) }
                }
            }
            addButton
        }
        .padding(.horizontal, side).padding(.top, 3).padding(.bottom, 22)
    }

    private var metaLine: some View {
        HStack(spacing: 0) {
            (Text(query.isEmpty ? "카테고리 " : "검색 결과 ")
                + Text("\(filtered.count)개").font(Font(WPTypeface.hak.uiFont(12, .bold))).foregroundColor(PK.metaStrong))
                .pickerText(12).foregroundStyle(PK.meta)
            Spacer(minLength: 0)
            Text("한 개 선택").pickerText(11).foregroundStyle(PK.meta)
        }
        .padding(.bottom, 15)
    }

    private func recentBlock(_ recent: [PlanCategory]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                LucideGlyph(kind: .clock).stroke(PK.recentTitle, style: LucideGlyph.style(13)).frame(width: 13, height: 13)
                Text("최근 선택한 카테고리").pickerText(11).foregroundStyle(PK.recentTitle)
            }
            FlowRow(spacing: 6, lineSpacing: 6) {
                ForEach(recent, id: \.name) { item in
                    // 웹은 라벨이 **정확히** 같을 때만 눌림으로 칠합니다(aria-pressed)
                    let on = draft?.name == item.name
                    Button { pick(item) } label: {
                        Text(item.name).pickerText(12).foregroundStyle(on ? WPColor.primary : PK.recentText)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 9).fill(on ? PK.recentOnBg : PK.recentBg))
                            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(on ? WPColor.primary : PK.recentLine, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.name)
                    .accessibilityIdentifier("category.recent.\(item.name)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.top, 9)
        }
        .padding(.bottom, 18)
    }

    private func groupSection(_ index: Int, _ choices: [PlanCategory]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Circle().fill(Color(hex: WeddingCategories.groupColors[index])).frame(width: 5, height: 5)
                (Text(WeddingCategories.groups[index]) + Text(" ")
                    + Text("\(choices.count)").font(Font(WPTypeface.hak.uiFont(11, .regular))).foregroundColor(PK.groupCount))
                    .pickerText(13, .bold).foregroundStyle(PK.groupTitle)
            }
            .padding(.bottom, 10)
            // 폰은 2열(웹 `repeat(2, minmax(0, 1fr))`), 칸 사이 8
            VStack(spacing: 8) {
                ForEach(Array(stride(from: 0, to: choices.count, by: 2)), id: \.self) { start in
                    HStack(alignment: .top, spacing: 8) {
                        tile(choices[start])
                        if start + 1 < choices.count { tile(choices[start + 1]) } else { Color.clear.frame(maxWidth: .infinity, maxHeight: 0) }
                    }
                }
            }
        }
        .padding(.top, 20)
    }

    private func tile(_ item: PlanCategory) -> some View {
        let checked = draft.map { WeddingCategories.normalize($0.name) == WeddingCategories.normalize(item.name) } ?? false
        // 카탈로그 이름(우리가 정한 말)만 어절로 꺾습니다 — 사용자가 만든 이름에는 하지 않습니다(Android CLAUDE.md)
        // `·` 앞뒤도 묶어 `신혼여행 항공·` / `교통` 처럼 가운뎃점에서 갈리지 않게 합니다(`신혼여행` / `항공·교통`).
        let label = WeddingCategories.group(item.name) != 5
            ? item.name.wpKeepAll.replacingOccurrences(of: "·", with: "\u{2060}·\u{2060}") : item.name
        return Button { pick(item) } label: {
            HStack(spacing: narrow ? 4 : 5) {
                WeddingCategoryIcon(name: item.name, size: narrow ? 28 : 34)
                VStack(alignment: .leading, spacing: 0) {
                    Text(label)
                        .pickerText(narrow ? 11 : 12, checked ? .bold : .regular, lineHeight: narrow ? 16.5 : 18)
                        .foregroundStyle(checked ? PK.tileOnText : PK.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if isUserAdded(item) { badge("직접 추가") }
                    if item.type == "ROOM" { badge("공유") }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ZStack {
                    Circle().fill(checked ? WPColor.primary : Color.white)
                    Circle().strokeBorder(checked ? WPColor.primary : PK.checkLine, lineWidth: 1)
                    if checked {
                        LucideGlyph(kind: .check).stroke(Color.white, style: LucideGlyph.style(10, width: 3)).frame(width: 10, height: 10)
                    }
                }
                .frame(width: 14, height: 14)
            }
            .padding(narrow ? 7 : 8)
            // 글꼴을 키우면 늘어납니다 — 높이를 못 박지 않습니다
            .frame(maxWidth: .infinity, minHeight: 66)
            .background(RoundedRectangle(cornerRadius: 13).fill(checked ? PK.tileOnBg : Color.white))
            // 웹은 테두리 1 + 바깥 그림자 1(= 2). 앱은 안쪽 2 로 그립니다
            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(checked ? WPColor.primary : PK.tileLine, lineWidth: checked ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(item.name)
        .accessibilityIdentifier("category.tile.\(item.name)")
        .accessibilityAddTraits(checked ? .isSelected : [])
    }

    private func badge(_ text: String) -> some View {
        Text(text).pickerText(9, lineHeight: 12).foregroundStyle(PK.badgeText).lineLimit(1)
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(PK.badgeBg, in: RoundedRectangle(cornerRadius: 4))
            .padding(.top, 3)
    }

    private var emptyResult: some View {
        VStack(spacing: 10) {
            LucideGlyph(kind: .search).stroke(PK.emptyIcon, style: LucideGlyph.style(30)).frame(width: 30, height: 30)
            Text("찾는 카테고리가 없어요").pickerText(15, .bold).foregroundStyle(PK.emptyTitle)
            Text("다른 검색어로 찾거나 직접 추가해보세요.").pickerText(12).foregroundStyle(PK.emptyBody)
        }
        .frame(maxWidth: .infinity, minHeight: 170)
    }

    /// 웹 `.add` — 점선 테두리
    private var addButton: some View {
        Button {
            newName = query; adding = true; error = ""
        } label: {
            HStack(spacing: 6) {
                LucideGlyph(kind: .plus).stroke(PK.addText, style: LucideGlyph.style(16)).frame(width: 16, height: 16)
                Text("원하는 카테고리가 없나요? 직접 추가").pickerText(12).foregroundStyle(PK.addText)
            }
            .padding(.horizontal, 6).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 45)
            .background(RoundedRectangle(cornerRadius: 12).fill(PK.addBg))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(PK.addLine, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.top, 22)
        .accessibilityLabel("원하는 카테고리가 없나요? 직접 추가")
        .accessibilityIdentifier("category.add")
    }

    // MARK: 직접 추가

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            WeddingCategoryIcon(name: "기타", size: 80)
                .frame(maxWidth: .infinity).padding(.top, 5).padding(.bottom, 20)
            Text("카테고리 이름").pickerText(13, .bold).foregroundStyle(PK.groupTitle)
            TextField("", text: $newName, prompt: Text("예: 반려견 웨딩 의상").foregroundColor(PK.searchHint))
                .font(Font(WPTypeface.hak.uiFont(15, .regular)))
                .foregroundStyle(PK.ink)
                .tint(WPColor.primary)
                .focused($nameFocused)
                .submitLabel(.done)
                .autocorrectionDisabled()
                .onSubmit(addCategory)
                // 웹 `maxLength={50}`
                .onChange(of: newName) { _, value in
                    if value.count > 50 { newName = String(value.prefix(50)) }
                    error = ""
                }
                .padding(13)
                .background(RoundedRectangle(cornerRadius: 12).fill(PK.addBg))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(!error.isEmpty ? PK.inputError : (nameFocused ? WPColor.primary : PK.inputLine), lineWidth: 1))
                .contentShape(Rectangle())
                .onTapGesture { nameFocused = true }
                .padding(.top, 10)
                .accessibilityIdentifier("category.name")
            if !error.isEmpty {
                Text(error).pickerText(12).foregroundStyle(PK.error).padding(.top, 12)
            }
            Text("이미 있는 이름이면 기존 카테고리를 선택해요.".wpKeepAll).pickerText(12).foregroundStyle(PK.clear)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
        }
        .padding(.horizontal, side).padding(.top, 10).padding(.bottom, 28)
    }

    // MARK: 바닥 줄

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(PK.footLine).frame(height: 1)
            HStack(spacing: 0) {
                if adding {
                    Button(action: cancelAdd) {
                        Text("취소").pickerText(14).foregroundStyle(PK.cancel).padding(12).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                    confirmButton("추가하기", enabled: true, identifier: "category.create", action: addCategory)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(draft == nil ? "플랜에 사용할 카테고리" : "선택한 카테고리").pickerText(10).foregroundStyle(PK.summaryLabel)
                        Text(draft?.name ?? "하나를 선택해주세요").pickerText(13, .bold).foregroundStyle(PK.summary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 3)
                        if !notice.isEmpty {
                            Text(notice.wpKeepAll).pickerText(10).foregroundStyle(PK.notice)
                                .accessibilityLabel(notice)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 8)
                    HStack(spacing: 7) {
                        if draft != nil {
                            Button { draft = nil; notice = "" } label: {
                                Text("선택 해제").pickerText(narrow ? 10 : 11).foregroundStyle(PK.clear).lineLimit(1).fixedSize()
                                    .padding(.horizontal, 3).padding(.vertical, 9).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        confirmButton("선택 완료", enabled: draft != nil, identifier: "category.confirm") {
                            guard let draft else { return }
                            let resolved = all.first { WeddingCategories.normalize($0.name) == WeddingCategories.normalize(draft.name) } ?? draft
                            confirm(resolved, pendingAdded.map(\.name))
                        }
                    }
                }
            }
            .padding(.horizontal, side).padding(.top, 14).padding(.bottom, 20)
            .background(LinearGradient(colors: [Color.white, PK.footEnd], startPoint: .top, endPoint: .bottom))
        }
    }

    private func confirmButton(_ label: String, enabled: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).pickerText(narrow ? 12 : 13, .bold).foregroundStyle(Color.white).lineLimit(1).fixedSize()
                .padding(.horizontal, narrow ? 12 : 16).padding(.vertical, 12)
                .frame(minHeight: 46)
                .background(RoundedRectangle(cornerRadius: 12).fill(enabled ? WPColor.primary : PK.confirmOff))
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier(identifier)
    }

    // MARK: 동작

    private func pick(_ item: PlanCategory) {
        draft = item; notice = ""
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func cancelAdd() {
        adding = false; error = ""; notice = ""
    }

    private func addCategory() {
        let name = WeddingCategories.clean(newName)
        guard !name.isEmpty else {
            error = WeddingCategories.emptyNameError
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        if let existing = all.first(where: { WeddingCategories.normalize($0.name) == WeddingCategories.normalize(name) }) {
            draft = existing; notice = WeddingCategories.noticeExisting
        } else {
            let item = PlanCategory(name: name, color: "#E8DDF5", type: "USER")
            pending.append(item); draft = item; notice = WeddingCategories.noticeCreated
        }
        query = ""; group = nil; adding = false; error = ""
    }
}

private extension View {
    /// Android 선택기 글자의 세로 자리 — Android 캡처에서 잰 그대로입니다.
    /// - `lineHeight` 를 **직접 준** 글자(제목 32.2 · 타일 이름 18 · 배지 12)는 줄높이를 다 채웁니다(`wpTypography`).
    /// - 테마의 1.5em 을 물려받은 글자는 한 줄이면 **글꼴 높이 그대로**입니다(위아래 여백을 자름). 최근 칩이 32 가 아니라
    ///   26, 부제·메타 줄이 18 이 아니라 12 높이였습니다. 여러 줄이면 줄 사이만 1.5em 으로 벌립니다.
    @ViewBuilder
    func pickerText(_ size: CGFloat, _ weight: Font.Weight = .regular, lineHeight: CGFloat? = nil) -> some View {
        if let lineHeight {
            wpTypography(size, weight, lineHeight: lineHeight)
        } else {
            let font = WPTypeface.hak.uiFont(size, weight)
            self.font(Font(font)).lineSpacing(max(0, size * 1.5 - font.lineHeight))
        }
    }
}

/// Android `WpColors.Picker*`(웹 `CategoryPicker.module.css`) — 선택기에서만 씁니다
private enum PK {
    static let ink = Color(hex: 0x291D27)
    static let handle = Color(hex: 0xE8DFE5)
    static let sub = Color(hex: 0xA18A9A)
    static let closeBg = Color(hex: 0xF7F3F6)
    static let closeIcon = Color(hex: 0x9E8796)
    static let searchLine = Color(hex: 0xECDEE8)
    static let searchBg = Color(hex: 0xFAF7FA)
    static let searchIcon = Color(hex: 0xAA94A2)
    static let searchText = Color(hex: 0x3B2733)
    static let searchHint = Color(hex: 0xAE9AA8)
    static let searchFocus = Color(hex: 0xED80B5)
    static let searchRing = Color(hex: 0x0AEE2B8C)
    static let searchClear = Color(hex: 0xEAE2E8)
    static let chipLine = Color(hex: 0xE9E1E7)
    static let chipText = Color(hex: 0x9B8694)
    static let chipOn = Color(hex: 0x31212E)
    static let meta = Color(hex: 0xA38C9B)
    static let metaStrong = Color(hex: 0x6D5161)
    static let recentTitle = Color(hex: 0xA18898)
    static let recentLine = Color(hex: 0xEDDAE6)
    static let recentBg = Color(hex: 0xFFF8FC)
    static let recentText = Color(hex: 0x8B667D)
    static let recentOnBg = Color(hex: 0xFFE8F3)
    static let groupTitle = Color(hex: 0x785B6C)
    static let groupCount = Color(hex: 0xB3A2AD)
    static let tileLine = Color(hex: 0xEFE6EC)
    static let tileOnBg = Color(hex: 0xFFF2F8)
    static let tileOnText = Color(hex: 0xCF2079)
    static let checkLine = Color(hex: 0xEADCE5)
    static let badgeText = Color(hex: 0x8F759C)
    static let badgeBg = Color(hex: 0xF1EAF5)
    static let addLine = Color(hex: 0xE7C8DB)
    static let addText = Color(hex: 0xA47892)
    static let addBg = Color(hex: 0xFFFAFD)
    static let emptyIcon = Color(hex: 0xC6B2C0)
    static let emptyTitle = Color(hex: 0x775465)
    static let emptyBody = Color(hex: 0xA28A9B)
    static let footLine = Color(hex: 0xF0E5EC)
    static let footEnd = Color(hex: 0xFFFBFD)
    static let summaryLabel = Color(hex: 0xA28B9B)
    static let summary = Color(hex: 0xB31D6B)
    static let notice = Color(hex: 0x977784)
    static let clear = Color(hex: 0xA38B9B)
    static let confirmOff = Color(hex: 0xF6ACD0)
    static let inputLine = Color(hex: 0xEADCE5)
    static let inputError = Color(hex: 0xED4D71)
    static let error = Color(hex: 0xDF3C60)
    static let cancel = Color(hex: 0x9B8694)
}

/// lucide 선 아이콘(24 격자) — Android `LucideIcons` 의 X · Search · Clock3 · Plus · CheckBold
private struct LucideGlyph: Shape {
    enum Kind { case x, search, clock, plus, check }
    let kind: Kind
    /// lucide 기본 선 굵기 2(24 격자 기준)를 그리는 크기에 맞춰 줄입니다
    static func style(_ size: CGFloat, width: CGFloat = 2) -> StrokeStyle {
        StrokeStyle(lineWidth: width * size / 24, lineCap: .round, lineJoin: .round)
    }
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        var path = Path()
        switch kind {
        case .x:
            path.move(to: p(18, 6)); path.addLine(to: p(6, 18))
            path.move(to: p(6, 6)); path.addLine(to: p(18, 18))
        case .search:
            path.addEllipse(in: CGRect(origin: p(3, 3), size: CGSize(width: 16 * s, height: 16 * s)))
            path.move(to: p(21, 21)); path.addLine(to: p(16.66, 16.66))
        case .clock:
            path.addEllipse(in: CGRect(origin: p(2, 2), size: CGSize(width: 20 * s, height: 20 * s)))
            path.move(to: p(12, 6)); path.addLine(to: p(12, 12)); path.addLine(to: p(16, 12))
        case .plus:
            path.move(to: p(5, 12)); path.addLine(to: p(19, 12))
            path.move(to: p(12, 5)); path.addLine(to: p(12, 19))
        case .check:
            path.move(to: p(20, 6)); path.addLine(to: p(9, 17)); path.addLine(to: p(4, 12))
        }
        return path
    }
}

/// 목록을 굴린 거리. iOS 18 부터는 스크롤 뷰가 직접 알려 주는 값을 씁니다(홈 `HomeScrollReader` 와 같은 이유 —
/// iOS 26 에서 내용 안 GeometryReader 의 값이 올라오지 않았습니다). iOS 17 은 재지 않아 예전처럼 끌면 닫힙니다.
private struct PickerScrollReader: ViewModifier {
    let onChange: (Bool) -> Void
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            // 참·거짓으로 바꿔 받아 값이 바뀔 때(맨 위를 벗어나거나 돌아올 때)만 부른다
            content.onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > 4 } action: { _, scrolled in onChange(scrolled) }
        } else {
            content
        }
    }
}

private struct PinnedDrag: ViewModifier {
    let onPullDown: () -> Void
    func body(content: Content) -> some View {
        content.simultaneousGesture(DragGesture(minimumDistance: 12).onEnded { value in
            if value.translation.height > 24 { onPullDown() }
        })
    }
}
