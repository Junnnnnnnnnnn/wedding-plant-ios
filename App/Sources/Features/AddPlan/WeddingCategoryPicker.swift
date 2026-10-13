import SwiftUI
import WPModels
import WPDomain

struct WeddingCategoryPicker: View {
    let categories: [PlanCategory]
    let added: [String]
    let selected: PlanCategory?
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
    private var all: [PlanCategory] { WeddingCategories.all(categories, added: added.map { PlanCategory(name: $0, type: "USER") } + pending) }
    private var filtered: [PlanCategory] { WeddingCategories.filter(all, group: group, query: query) }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if geometry.size.height >= 420 { header; if !adding { filters } }
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Color.clear.frame(height: 0).id("top")
                            if geometry.size.height < 420 { header; if !adding { filters } }
                            if adding { addForm } else { grid }
                        }.padding(.horizontal, 20).padding(.bottom, 16)
                    }.scrollDismissesKeyboard(.interactively)
                        .onChange(of: query) { _, _ in proxy.scrollTo("top") }
                        .onChange(of: group) { _, _ in proxy.scrollTo("top") }
                }
                footer
            }.background(Color(hex: 0xFFFCFD))
        }.presentationDetents([.large]).presentationDragIndicator(.visible).presentationCornerRadius(24)
            .onAppear { draft = selected }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(adding ? "직접 추가" : "어떤 준비인가요?").font(WPFont.hak(22, .bold))
                    Text(adding ? "우리에게 필요한 준비를 적어주세요" : "플랜에 맞는 카테고리를 골라주세요").font(WPFont.hak(12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { if adding { adding = false } else { dismiss() } } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("카테고리 닫기")
            }
            if !adding {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("카테고리 검색", text: $query).font(WPFont.hak(14)).accessibilityIdentifier("category.search")
                    if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("검색 지우기") }
                }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xEDE3E8)))
            }
        }.padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 14)
    }
    private var filters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                filter("전체", index: nil)
                ForEach(0..<WeddingCategories.groups.count, id: \.self) { index in
                    if all.contains(where: { WeddingCategories.group($0.name) == index }) { filter(WeddingCategories.groups[index], index: index) }
                }
            }.padding(.horizontal, 20)
        }.scrollIndicators(.hidden).padding(.bottom, 14)
    }
    private func filter(_ name: String, index: Int?) -> some View {
        Button { group = index } label: {
            Text(name).font(WPFont.hak(12, .semibold)).padding(.horizontal, 12).padding(.vertical, 9)
                .foregroundStyle(group == index ? .white : Color(hex: 0x7E6675))
                .background(group == index ? Color(hex: 0xA84C78) : Color(hex: 0xF5EDF1), in: Capsule())
        }.buttonStyle(.plain)
    }
    private var grid: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("\(filtered.count)개의 카테고리").font(WPFont.hak(11)).foregroundStyle(.secondary); Spacer(); Button("직접 추가") { adding = true; error = "" }.font(WPFont.hak(12, .bold)).accessibilityIdentifier("category.add") }
            if filtered.isEmpty { Text("검색 결과가 없어요").font(WPFont.hak(15)).frame(maxWidth: .infinity).padding(.vertical, 40) }
            LazyVGrid(columns: [.init(.flexible(), spacing: 8), .init(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(filtered, id: \.name) { item in
                    let chosen = draft.map { WeddingCategories.normalize($0.name) == WeddingCategories.normalize(item.name) } ?? false
                    Button { draft = item; notice = ""; UISelectionFeedbackGenerator().selectionChanged() } label: {
                        HStack(spacing: 8) {
                            WeddingCategoryIcon(name: item.name)
                            Text(item.name).font(WPFont.hak(12, .semibold)).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                            if chosen { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: 0xA84C78)).font(.system(size: 15)) }
                        }.padding(10).frame(minHeight: 68).foregroundStyle(Color(hex: 0x3E3039))
                            .background(chosen ? Color(hex: 0xFAEDF3) : .white, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(chosen ? Color(hex: 0xBF7398) : Color(hex: 0xEEE6EA), lineWidth: chosen ? 1.5 : 1))
                    }.buttonStyle(.plain).accessibilityLabel(item.name)
                }
            }
        }
    }
    private var addForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("카테고리 이름", text: $newName).font(WPFont.hak(16)).padding(16).background(.white, in: RoundedRectangle(cornerRadius: 12)).accessibilityIdentifier("category.name")
            Text("같은 이름이 있으면 이미 있는 카테고리를 선택해요.").font(WPFont.hak(12)).foregroundStyle(.secondary)
            if !error.isEmpty { Text(error).font(WPFont.hak(12)).foregroundStyle(.red) }
        }.padding(.top, 20)
    }
    private var footer: some View {
        HStack(spacing: 8) {
            if adding {
                Button("취소") { adding = false; error = "" }; Spacer()
                action("추가하기", enabled: true, action: addCategory)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(draft == nil ? "플랜에 사용할 카테고리" : "선택한 카테고리").font(WPFont.hak(10)).foregroundStyle(.secondary)
                    Text(draft?.name ?? "하나를 선택해주세요").font(WPFont.hak(13, .bold)).lineLimit(1)
                    if !notice.isEmpty { Text(notice).font(WPFont.hak(10)).foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if draft != nil { Button("선택 해제") { draft = nil; notice = "" }.font(WPFont.hak(11)) }
                action("선택 완료", enabled: draft != nil) {
                    guard let draft else { return }
                    let resolved = all.first { WeddingCategories.normalize($0.name) == WeddingCategories.normalize(draft.name) } ?? draft
                    let names = pending.filter { item in !categories.contains { WeddingCategories.normalize($0.name) == WeddingCategories.normalize(item.name) } }.map(\.name)
                    confirm(resolved, names)
                }
            }
        }.padding(20).background(.white).overlay(alignment: .top) { Divider() }
    }
    private func action(_ name: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(name).font(WPFont.hak(14, .bold)).padding(.horizontal, 18).frame(height: 44).foregroundStyle(.white).background(Color(hex: 0xA84C78).opacity(enabled ? 1 : 0.35), in: RoundedRectangle(cornerRadius: 12)) }.disabled(!enabled).accessibilityIdentifier(adding ? "category.create" : "category.confirm")
    }
    private func addCategory() {
        let name = WeddingCategories.clean(newName)
        guard !name.isEmpty else { error = "카테고리 이름을 입력해주세요"; return }
        if let existing = all.first(where: { WeddingCategories.normalize($0.name) == WeddingCategories.normalize(name) }) {
            draft = existing; notice = "이미 있는 카테고리를 선택했어요"
        } else {
            let item = PlanCategory(name: name, color: "#E8DDF5", type: "USER")
            pending.append(item); draft = item; notice = "새 카테고리를 선택했어요. 선택 완료를 눌러 적용하세요."
        }
        query = ""; group = nil; adding = false; error = ""
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
