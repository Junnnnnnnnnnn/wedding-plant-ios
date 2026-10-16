import Foundation

/// `POST /plan/room/mine` — 결제할 방. 서버가 귀속(SPOUSE) 방을 먼저, 없으면 내 방을, 그것도 없으면 만들어 준다(멱등).
///
/// 안드로이드 `data/model/Models.kt` 의 `MyRoom` 과 같다.
public struct MyRoom: Codable, Sendable, Equatable {
    public var roomId: Int
    /// `OWNER` | `SPOUSE`. 빠져 오면 방장으로 읽는다(안드로이드 기본값과 같음).
    public var permission: String

    public init(roomId: Int, permission: String = "OWNER") {
        self.roomId = roomId
        self.permission = permission
    }

    private enum CodingKeys: String, CodingKey { case roomId, permission }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = try c.decode(LooseInt.self, forKey: .roomId).wrappedValue else {
            throw DecodingError.dataCorruptedError(forKey: .roomId, in: c, debugDescription: "roomId 가 숫자가 아니다")
        }
        roomId = id
        permission = try c.decodeIfPresent(String.self, forKey: .permission) ?? "OWNER"
    }

    /// 신랑·신부로 묶인 방인가 — 그렇다면 그 방이 곧 귀속 방이다.
    public var isSpouse: Bool { permission.uppercased() == "SPOUSE" }
}
