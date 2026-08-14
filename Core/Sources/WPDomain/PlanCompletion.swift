import Foundation
import WPModels

/// 플랜 기본 정보(이름·결혼일·예산)가 모두 채워졌는지 판단한다.
///
/// 웹 `lib/api.ts:isPlanDataComplete` 를 그대로 옮긴 것.
/// `AuthRedirectToMain` 과 로그인 후 라우팅이 이 판정에 의존하므로 동작을 바꾸지 말 것.
public enum PlanCompletion {
    /// - Note: 웹과 동일하게 **예산 0원도 "입력됨"으로 본다** (`null` 여부만 본다).
    ///   사용자가 의도적으로 0을 넣은 경우를 미입력으로 되돌리지 않기 위함.
    public static func isComplete(name: String?, weddingDate: String?, budget: Int?) -> Bool {
        let hasName = !(name ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        let hasWeddingDate = !(weddingDate ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        let hasBudget = budget != nil
        return hasName && hasWeddingDate && hasBudget
    }

    public static func isComplete(_ user: PlanUser?) -> Bool {
        guard let user else { return false }
        return isComplete(name: user.name, weddingDate: user.weddingDate, budget: user.budget)
    }
}
