import WPModels

/// Same gates and insertion points as Android domain/AdRules.kt.
public enum AdGate: Sendable { case unknown, show, hide }

public enum AdRules {
    public static func gate(loggedIn: Bool, roomResolved: Bool, roomId: Int?, pass: PassState?) -> AdGate {
        guard loggedIn, roomResolved else { return .unknown }
        guard roomId != nil else { return .show }
        guard let pass else { return .unknown }
        return pass.hasPass && !pass.expired ? .hide : .show
    }
    public static func adAfter(index: Int, count: Int, first: Int, every: Int) -> Bool {
        guard index >= 0, index < count - 1, every > 0 else { return false }
        let step = index + 1 - first
        return step >= 0 && step % every == 0
    }
    public static func homeAdVisible(gate: AdGate, isMyPlan: Bool, thisMonthCount: Int, hasMoreBelow: Bool) -> Bool {
        gate == .show && isMyPlan && thisMonthCount > 0 && hasMoreBelow
    }
}
