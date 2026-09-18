import Foundation
import WPModels

/// 예산 도넛의 구간 계산. 웹 `app/budget-detail/components/BudgetDonut.tsx` 와 같은 식이다.
///
/// **자본을 넘긴 경우가 이 화면에서 제일 깨지기 쉽다.** 원은 100% 를 넘길 수 없어
/// 그냥 그리면 124% 도 "꽉 참" 으로만 보인다. 그래서 분모를 자본이 아니라
/// `max(자본, 사용+예정)` 으로 두고, **자본 위치에 눈금**을 찍는다. 눈금을 넘어간
/// 만큼이 빨간 초과 구간이다 — 홈 대시보드의 막대를 원으로 만 것과 같고 색의 뜻도 같다.
///
/// - 분홍 = 실제로 나간 돈
/// - 빨강 = 자본을 넘겨 나간 돈
/// - 회색 = 아직 안 쓴 예정
/// - 트랙 = 여유
///
/// **화면이 이 값을 그대로 그린다.** 안드로이드는 계산식을 화면과 테스트에 각각
/// 적어 두어 테스트가 사본을 검사하고 있는데, 여기서는 한 곳만 둔다.
public struct BudgetDonutSegments: Hashable, Sendable {
    /// 초기 자본.
    public let capital: Int
    /// 결제된(나간) 돈.
    public let used: Int
    /// 아직 안 쓴 예정.
    public let planned: Int

    public init(capital: Int, used: Int, planned: Int) {
        self.capital = capital
        self.used = used
        self.planned = planned
    }

    public init(_ detail: AmountDetail) {
        self.init(
            capital: detail.initialCapital,
            used: detail.usedAmount,
            planned: detail.plannedUseAmount
        )
    }

    /// 도넛 한 바퀴가 나타내는 값. **자본이 아니다** — 넘긴 만큼도 그려야 한다.
    public var total: Int { max(capital, used + planned) }

    /// 분홍 구간. 넘긴 경우 "사용 전체" 가 아니라 **자본까지**다.
    /// 범례를 `자본 내 사용` / `자본 초과` 로 나눈 이유 — 그냥 `사용` 이라 쓰면
    /// 옆 표의 합과 어긋나 보인다.
    public var withinCapital: Int { min(used, capital) }

    /// 빨간 구간. 사용이 자본을 넘긴 만큼.
    public var overUsed: Int { max(0, used - capital) }

    /// 도넛 가운데의 `남은 금액` — 자본에서 **예정과 사용을 모두** 뺀 값.
    /// 위 요약과 가운데가 같은 숫자여야 한다.
    public var remaining: Int { capital - planned - used }

    /// 자본을 넘긴 총액. 0 보다 크면 눈금을 찍는다.
    ///
    /// **사용이 자본을 안 넘고 예정 때문에만 넘는 경우**에는 빨간 구간이 없어서
    /// 이 눈금이 유일한 표시다.
    public var overAmount: Int { max(0, used + planned - capital) }

    /// 사용률(%). **반올림한다** — 웹 `Math.round` 와 같아야 한다.
    public var usedPercent: Int {
        guard capital > 0 else { return 0 }
        return Int((Double(used) / Double(capital) * 100).rounded())
    }

    /// `사용 후 잔액` — **사용만** 뺀 값. 가운데의 ``remaining`` 과 다른 수치다.
    /// 도넛의 분홍 구간 밖 전부라, 같은 그림의 다른 구간이다.
    public var savings: Int { capital - used }

    /// 값을 도넛 한 바퀴(100) 기준 길이로 바꾼다.
    public func ratio(_ value: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(value) / Double(total) * 100
    }

    /// 자본 눈금의 위치. 넘기지 않았으면 `nil` — 그때는 의미가 없다.
    public var capitalMark: Double? {
        guard overAmount > 0 else { return nil }
        return ratio(capital)
    }

    /// 세 구간이 한 바퀴 안에 들어가는지. 넘으면 도넛이 겹쳐 그려진다.
    public var fitsInRing: Bool {
        withinCapital + overUsed + planned <= total
    }
}
