import WPModels

/// 광고를 그려도 되나 — 안드로이드 `domain/AdRules.kt` 와 같은 판정·자리.
///
/// 광고는 **앱만** 넣는다(웹에는 없음). 준비 패스가 켜진 플랜이면 두 사람 모두 광고가 없다 —
/// 패스는 방에 붙고, 신랑·신부의 "내 방" 은 방장의 방이라 배우자도 같은 답을 받는다.
public enum AdGate: Sendable {
    /// 아직 모름 — 켠 직후·로그인 직후, 내 방이나 그 방의 패스를 못 받았을 때. **광고 0** 이고 자리도 만들지 않는다.
    /// "모름" 을 "패스 없음" 으로 읽으면 돈을 낸 사람에게 광고가 번쩍인다.
    case unknown
    /// 패스가 없음을 확인했다. 광고를 보인다
    case show
    /// 패스를 쓰는 중. 광고 0 — 광고 SDK 도 띄우지 않는다
    case hide
}

public enum AdRules {
    /// 피드: 3번째 후기 다음, 이후 8개마다(3 · 11 · 19 …)
    public static let feedFirst = 3
    public static let feedEvery = 8
    /// 자랑하기: 카드가 커서 피드보다 성기게 — 2번째 카드 다음, 이후 6장마다(2 · 8 · 14 …)
    public static let bragFirst = 2
    public static let bragEvery = 6

    /// - Parameters:
    ///   - loggedIn: 토큰이 있는가. 없으면 판정하지 않는다
    ///   - roomResolved: 내 방을 **확인했는가**. 묻지 못했으면 false
    ///   - roomId: 확인한 내 방. nil 이면 방이 없음을 확인한 것 — 혼자 쓰는 사람, 패스가 붙을 곳이 없음
    ///   - pass: 그 방의 패스. nil 이면 아직 못 받음
    public static func gate(loggedIn: Bool, roomResolved: Bool, roomId: Int?, pass: PassState?) -> AdGate {
        guard loggedIn, roomResolved else { return .unknown }
        guard roomId != nil else { return .show }
        guard let pass else { return .unknown }
        return pass.hasPass && !pass.expired ? .hide : .show
    }

    /// 목록의 `index` 번째 글(0부터) **다음에** 광고를 끼우나.
    ///
    /// 뒤에 글이 더 있을 때만 끼운다 — 광고로 목록이 끝나면 "더 보기" 바로 위가 광고가 되고, 글이 적은
    /// 목록에서는 광고가 콘텐츠보다 눈에 띈다.
    public static func adAfter(index: Int, count: Int, first: Int, every: Int) -> Bool {
        guard index >= 0, index < count - 1, every > 0 else { return false }
        let step = index + 1 - first
        return step >= 0 && step % every == 0
    }

    /// `adAfter` 가 true 인 자리가 몇 번째 광고인가(0부터)
    public static func adSlot(index: Int, first: Int, every: Int) -> Int { (index + 1 - first) / every }

    /// 홈 ① 을 보이나. 내 홈이고 「이번 달에 할 일」에 카드가 하나라도 있을 때만 — 빈 상태·뼈대·오류 화면에는
    /// 넣지 않는다(콘텐츠 없는 화면 광고는 AdMob 정책 위반). 남의 플랜·공유 미리보기도 넣지 않는다.
    ///
    /// **아래에 묶음이 더 있을 때만**(`hasMoreBelow`) — 없으면 광고가 목록 끝이 되어 자랑하기 · 탭바 바로 위에 붙는다
    /// (콘텐츠와 내비게이션 사이 광고는 Google 이 권하지 않는 자리).
    public static func homeAdVisible(gate: AdGate, isMyPlan: Bool, thisMonthCount: Int, hasMoreBelow: Bool) -> Bool {
        gate == .show && isMyPlan && thisMonthCount > 0 && hasMoreBelow
    }
}
