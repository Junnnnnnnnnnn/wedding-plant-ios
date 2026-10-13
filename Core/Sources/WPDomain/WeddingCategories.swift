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
    public static func filter(_ all: [PlanCategory], group: Int?, query: String) -> [PlanCategory] {
        all.filter { (group == nil || self.group($0.name) == group) && searchKey($0.name).contains(searchKey(query)) }
    }
}
