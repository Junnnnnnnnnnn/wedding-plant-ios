import CoreGraphics
import Foundation
import WPDomain

/// 청첩장 사진을 올릴 모양으로 — Android `data/InvitationPhotoPrep.kt` · 웹 `invitationPhoto(file)` 와 같은 결과
/// (긴 변 1600px 이하, 흰 바탕, **WebP 80**).
///
/// 예전에는 JPEG 85 로 올렸다. 앱과 웹이 같은 R2 에 올리므로 JPEG 로 남겨 두면 앱에서 올린 사진만 용량을 더 먹는다
/// (Android c857963). 링크 미리보기(카카오톡은 JPG · PNG 만 읽음)는 웹 서버가 표지를 JPEG 로 바꿔 내보내 앱은 할 일이 없다.
///
/// 디코드는 피드와 같은 ImageIO 축소(HEIC 포함, EXIF 방향 반영) — 원본을 통째로 풀지 않아 원본 크기 상한을 두지 않는다
/// (웹은 브라우저가 원본을 메모리에 올려 50MB 상한이 있다). 서버 상한(8MB)은 결과 바이트에 건다.
enum InvitationPhotoPrep {
    static let unreadable = "사진을 읽지 못했어요."
    static let failed = "사진을 준비하지 못했어요."

    private static let queue = DispatchQueue(label: "app.weddingplant.invitation-photo-prep")

    static func prepare(_ data: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try autoreleasepool { try make(data) } })
            }
        }
    }

    static func make(_ data: Data) throws -> Data {
        let image: CGImage
        do { image = try FeedPhotoPrep.decode(data, maxEdge: InvitationRules.photoMaxEdge) }
        catch { throw FeedPhotoPrep.Failure(message: unreadable) }
        return try FeedPhotoPrep.encode(image, qualities: [InvitationRules.photoWebpQuality],
                                        maxBytes: InvitationRules.photoMaxUploadBytes, failure: failed, opaqueWhite: true)
    }
}
