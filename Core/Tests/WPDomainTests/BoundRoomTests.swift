import XCTest
@testable import WPDomain
@testable import WPModels

/// 신랑·신부 초대는 **귀속**이다 — 수락하면 그 방이 내 플랜이 된다.
///
/// **조언자(`READ`)는 귀속이 아니다.** 판단 근거는 `/plan/room/list` 의
/// `members[].permission` 하나이고, 백엔드에 새 필드를 만들지 않았다.
final class BoundRoomTests: XCTestCase {

    private func plan(_ roomId: Int, _ members: [(String, PlanPermission)]) -> Plan {
        Plan(
            roomId: roomId,
            onwerName: "방장",
            weddingDate: "2026-12-19",
            budget: 5000,
            remainingBudget: 2000,
            planCount: 3,
            chatRooms: [],
            members: members.map { Member(planUserId: $0.0, name: $0.0, permission: $0.1) }
        )
    }

    // MARK: - 찾기

    func test_내가_배우자인_방을_찾는다() {
        let rooms = [
            plan(1, [("owner", .owner), ("me", .read)]),
            plan(2, [("owner2", .owner), ("me", .spouse)]),
        ]
        XCTAssertEqual(BoundRoom.find(in: rooms, planUserId: "me")?.roomId, 2)
    }

    func test_조언자는_귀속이_아니다() {
        // 남의 플랜을 같이 보며 거드는 자리라 자기 플랜을 그대로 둔다.
        let rooms = [plan(1, [("owner", .owner), ("me", .read)])]
        XCTAssertNil(BoundRoom.find(in: rooms, planUserId: "me"))
    }

    func test_방장은_귀속이_아니다() {
        let rooms = [plan(1, [("me", .owner)])]
        XCTAssertNil(BoundRoom.find(in: rooms, planUserId: "me"))
    }

    func test_예전_WRITE_권한도_귀속이_아니다() {
        // `WRITE` 는 정책 이전에 붙은 값이다. 편집은 되지만 귀속은 아니다.
        let rooms = [plan(1, [("owner", .owner), ("me", .write)])]
        XCTAssertNil(BoundRoom.find(in: rooms, planUserId: "me"))
    }

    func test_roomId가_0이면_방이_아니다() {
        let rooms = [plan(0, [("me", .spouse)])]
        XCTAssertNil(BoundRoom.find(in: rooms, planUserId: "me"))
    }

    func test_내_id를_모르면_귀속을_판단하지_않는다() {
        let rooms = [plan(1, [("someone", .spouse)])]
        XCTAssertNil(BoundRoom.find(in: rooms, planUserId: nil))
        XCTAssertNil(BoundRoom.find(in: rooms, planUserId: "   "))
    }

    func test_id는_공백과_대소문자를_무시하고_맞춘다() {
        let rooms = [plan(1, [("  ME  ", .spouse)])]
        XCTAssertEqual(BoundRoom.find(in: rooms, planUserId: "me")?.roomId, 1)
    }

    func test_배우자_방이_여럿이면_처음_것을_쓴다() {
        // 배우자 자리는 방마다 한 곳뿐이라(부분 유니크) 실제로는 안 생긴다.
        let rooms = [
            plan(3, [("me", .spouse)]),
            plan(4, [("me", .spouse)]),
        ]
        XCTAssertEqual(BoundRoom.find(in: rooms, planUserId: "me")?.roomId, 3)
    }

    // MARK: - 권한

    func test_내_권한을_읽는다() {
        let room = plan(1, [("owner", .owner), ("me", .spouse)])
        XCTAssertEqual(BoundRoom.myPermission(in: room, planUserId: "me"), .spouse)
        XCTAssertNil(BoundRoom.myPermission(in: room, planUserId: "stranger"))
    }

    // MARK: - 캐시

    func test_아직_모를_때만_가림막을_덮는다() {
        // 귀속이 **아닌 대부분의 사용자도** 매번 흰 막을 보면 고치려던 것보다 나쁘다.
        XCTAssertTrue(BoundRoom.Cache.unknown.needsCover)
        XCTAssertFalse(BoundRoom.Cache.notBound.needsCover)
        XCTAssertFalse(BoundRoom.Cache.bound(roomId: 2).needsCover)
    }

    func test_캐시에서_방_id를_꺼낸다() {
        XCTAssertEqual(BoundRoom.Cache.bound(roomId: 7).roomId, 7)
        XCTAssertNil(BoundRoom.Cache.notBound.roomId)
        XCTAssertNil(BoundRoom.Cache.unknown.roomId)
    }
}
