import Foundation
import WPModels

public enum WeddingCategories {
    public static let groups = ["예식·행사", "의상·뷰티", "촬영·청첩장", "가족·선물·소품", "신혼여행·신혼집", "직접 추가"]
    public static let names: [String] = ["상견례", "웨딩홀", "식대·음료", "예식장 꽃장식", "사회자", "주례", "축가·연주", "하객 교통·숙박", "드레스", "턱시도·예복", "웨딩슈즈·액세서리", "헤어·메이크업", "네일·페디큐어", "피부 관리", "체형 관리", "웨딩 관리·시술", "스튜디오 촬영", "야외·셀프 촬영", "본식 스냅", "본식 영상", "모바일 청첩장", "종이 청첩장", "청첩장 모임", "식전 영상·포토테이블", "커플링·예물", "예단", "혼주 의상·한복", "혼주 헤어·메이크업", "부모님 선물", "하객 답례품", "부케·부토니에", "폐백", "신혼여행 항공·교통", "신혼여행 숙소", "신혼여행 경비", "신혼집 계약", "인테리어", "혼수 가전·가구", "이사·입주 청소", "기타"]
    public static func clean(_ raw: String) -> String {
        raw.replacingOccurrences(of: #"[\s\p{Z}\uFEFF]+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    public static func normalize(_ raw: String) -> String { clean(raw).lowercased() }
    public static func searchKey(_ raw: String) -> String { normalize(raw).replacingOccurrences(of: #"[\s·/]"#, with: "", options: .regularExpression) }
    public static func icon(_ name: String) -> Int { names.firstIndex { normalize($0) == normalize(name) } ?? (normalize(name) == "스드메" ? 8 : 39) }
    public static func group(_ name: String) -> Int { names.firstIndex { normalize($0) == normalize(name) }.map { $0 / 8 } ?? (normalize(name) == "스드메" ? 1 : 5) }
    public static func merge(_ api: [PlanCategory]) -> [PlanCategory] {
        let colors = ["#FFE4E9", "#E8DDF5", "#FFE5D9", "#FFF0D6", "#D5F0E5"]
        let defaults = names.enumerated().map { PlanCategory(name: $0.element, color: colors[$0.offset / 8], type: "SYSTEM") } + [PlanCategory(name: "스드메", color: "#E8DDF5", type: "SYSTEM")]
        return all(defaults, added: api, replace: true)
    }
    public static func all(_ categories: [PlanCategory], added: [PlanCategory], replace: Bool = false) -> [PlanCategory] {
        var result: [PlanCategory] = []
        for category in categories + added {
            if let index = result.firstIndex(where: { normalize($0.name) == normalize(category.name) }) {
                if replace { result[index] = category }
            } else { result.append(category) }
        }
        return result
    }
    /// 빈 검색어는 전부 맞습니다. Foundation `contains("")` 는 false 라 빈 칸에서 목록이 0개로 보였습니다.
    public static func filter(_ all: [PlanCategory], group: Int?, query: String) -> [PlanCategory] {
        let q = searchKey(query)
        return all.filter { (group == nil || self.group($0.name) == group) && (q.isEmpty || searchKey($0.name).contains(q)) }
    }
    /// 그룹 머리의 점 색 — Android `WeddingCategories.GROUPS`·`CUSTOM` 의 color (마지막이 직접 추가)
    public static let groupColors: [UInt32] = [0xD06D9C, 0xA17CB5, 0xB17D67, 0xBA8A51, 0x639589, 0x8E729F]
    /// 필터 칩 — 5그룹 + 직접 추가 그룹에 하나라도 있으면 `직접 추가` (Android `CategoryPickerRules.groups`)
    public static func groupIndices(_ all: [PlanCategory]) -> [Int] {
        Array(0..<5) + (all.contains { group($0.name) == 5 } ? [5] : [])
    }
    public static func count(_ all: [PlanCategory], group index: Int?) -> Int {
        guard let index else { return all.count }
        return all.filter { group($0.name) == index }.count
    }
    /// 최근 고른 이름 → 지금 목록의 항목, 최대 4개
    public static func recent(_ all: [PlanCategory], names: [String]) -> [PlanCategory] {
        Array(names.compactMap { name in all.first { normalize($0.name) == normalize(name) } }.prefix(4))
    }
    /// 확정한 뒤의 최근 목록 — 맨 앞에 넣고 같은 이름은 빼고 4개까지(화면 메모리뿐, 저장 안 함)
    public static func pushRecent(_ previous: [String], picked: String) -> [String] {
        Array(([picked] + previous.filter { normalize($0) != normalize(picked) }).prefix(4))
    }
    public static let emptyNameError = "카테고리 이름을 입력해주세요"
    public static let noticeExisting = "이미 있는 카테고리를 선택했어요"
    public static let noticeCreated = "새 카테고리를 선택했어요. 선택 완료를 눌러 적용하세요."
}
