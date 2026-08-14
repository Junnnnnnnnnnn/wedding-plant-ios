import Foundation
import WPUtils

/// 비로그인(게스트) 상태에서 입력한 값 보관.
///
/// 웹은 `sessionStorage` 의 `weddingData` 에 담고, 안드로이드는 `GuestStore` 를 쓴다.
/// iOS 에서는 `UserDefaults` 를 쓴다 — 민감 정보가 아니고 앱 재실행 후에도 남아야 한다.
/// (로그인 시 백엔드로 옮기는 마이그레이션 규칙은 Core 의 `GuestMigration` 에 있다)
@MainActor
final class GuestStore: ObservableObject {
    private enum Key {
        static let name = "wp_guest_name"
        static let budget = "wp_guest_budget"
        static let weddingDate = "wp_guest_wedding_date"
        static let completedSetting = "wp_guest_completed_setting"
        static let requiredAgreementDate = "wp_guest_required_agreement_date"
        static let adAgreementDate = "wp_guest_ad_agreement_date"
    }

    /// 게스트가 동의한 약관 날짜.
    struct AgreementSnapshot: Equatable {
        var requiredAgreementDate: String
        var adAgreementDate: String?
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var name: String {
        get { defaults.string(forKey: Key.name) ?? "" }
        set { defaults.set(newValue, forKey: Key.name) }
    }

    /// 단위는 만원. 미입력이면 nil.
    var budget: Int? {
        get { defaults.object(forKey: Key.budget) as? Int }
        set { defaults.set(newValue, forKey: Key.budget) }
    }

    var weddingDate: KstDate? {
        get {
            guard let raw = defaults.string(forKey: Key.weddingDate) else { return nil }
            return KstDate(dateString: raw)
        }
        set { defaults.set(newValue?.dateString, forKey: Key.weddingDate) }
    }

    /// 웹의 `HAS_COMPLETED_GUEST_SETTING_KEY`.
    /// 로그인 후 게스트 데이터 마이그레이션 분기를 탈 자격이 있는지 판단하는 플래그다.
    var hasCompletedSetting: Bool {
        get { defaults.bool(forKey: Key.completedSetting) }
        set { defaults.set(newValue, forKey: Key.completedSetting) }
    }

    /// 웹의 `plan_guest_agreement`. 로그인 시 백엔드로 동기화된다.
    var agreement: AgreementSnapshot? {
        guard let required = defaults.string(forKey: Key.requiredAgreementDate) else { return nil }
        return AgreementSnapshot(
            requiredAgreementDate: required,
            adAgreementDate: defaults.string(forKey: Key.adAgreementDate)
        )
    }

    func saveAgreement(requiredAgreementDate: String, adAgreementDate: String?) {
        defaults.set(requiredAgreementDate, forKey: Key.requiredAgreementDate)
        defaults.set(adAgreementDate, forKey: Key.adAgreementDate)
    }

    func save(name: String, budget: Int?, weddingDate: KstDate?) {
        self.name = name
        self.budget = budget
        self.weddingDate = weddingDate
        self.hasCompletedSetting = true
        objectWillChange.send()
    }

    func clear() {
        for key in [
            Key.name, Key.budget, Key.weddingDate, Key.completedSetting,
            Key.requiredAgreementDate, Key.adAgreementDate,
        ] {
            defaults.removeObject(forKey: key)
        }
        objectWillChange.send()
    }
}
