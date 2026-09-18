import Foundation
import WPModels

/// 웹 `lib/boundRoom.ts` 이식 — **신랑·신부로 초대를 받으면 그 방이 내 플랜이 된다**(귀속).
///
/// 부부는 결혼식을 두 번 하지 않는다. 배우자 초대를 수락한 사람은 방장의 플랜을
/// "참여 플랜" 하나로 곁들여 보는 게 아니라 **그 플랜을 자기 플랜으로 쓴다** —
/// 홈·캘린더·예산이 전부 그 방을 본다.
///
/// 초대 전에 만든 개인 플랜은 **화면에서만 내려간다.** DB 에 그대로 있고 방에서
/// 나가면 다시 홈에 뜬다 — 그래서 경고 문구를 "사라집니다" 로 쓰지 말 것.
/// 나중에 "사라진다더니 남아 있네" 가 되면 다음 경고까지 못 믿는다.
///
/// **조언자(`READ`)는 귀속이 아니다.** 남의 플랜을 같이 보며 거드는 자리라 자기
/// 플랜을 그대로 두고, 경고도 띄우지 않고, 바로 참여한다.
///
/// 판단 근거는 `/plan/room/list` 의 `members[].permission` 하나다 —
/// **백엔드에 새 필드를 만들지 않았다.**
public enum BoundRoom {

    /// 이 방에서 내 권한. 멤버가 아니면 `nil`.
    public static func myPermission(in plan: Plan, planUserId: String?) -> PlanPermission? {
        let me = (planUserId ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        guard !me.isEmpty else { return nil }
        return plan.members.first {
            $0.planUserId.trimmingCharacters(in: .whitespaces).lowercased() == me
        }?.permission
    }

    /// 내가 배우자로 들어간 방.
    ///
    /// 배우자 자리는 방마다 한 곳뿐이라(백엔드 부분 유니크 인덱스) 처음 찾은 것을 쓴다.
    public static func find(in plans: [Plan], planUserId: String?) -> Plan? {
        plans.first { plan in
            plan.roomId > 0 && myPermission(in: plan, planUserId: planUserId) == .spouse
        }
    }

    /// 세션에 적어 두는 값.
    ///
    /// **귀속 여부를 캐시하지 않으면** 귀속이 **아닌 대부분의 사용자도** 방 화면에
    /// 들어올 때마다 `/plan/room/list` 를 기다리는 동안 흰 막을 본다 —
    /// 고치려던 것보다 나쁜 화면이다.
    ///
    /// 캐시가 "귀속 아님" 이면 가리지 않고, 아는 방이 있으면 묻기 전에 먼저 옮긴다.
    /// 어느 쪽이든 뒤에서 다시 물어 값을 고쳐 둔다(그 사이 초대를 수락했을 수 있다).
    public enum Cache: Hashable, Sendable {
        /// 아직 안 물어봤다.
        case unknown
        /// 물어봤고 귀속이 아니다.
        case notBound
        /// 이 방에 귀속돼 있다.
        case bound(roomId: Int)

        public var roomId: Int? {
            if case .bound(let id) = self { return id }
            return nil
        }

        /// 가림막을 덮어야 하는지. **아직 모를 때만** 덮는다.
        public var needsCover: Bool { self == .unknown }
    }
}
