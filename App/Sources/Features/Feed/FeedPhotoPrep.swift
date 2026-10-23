import CoreGraphics
import Foundation
import ImageIO
import libwebp
import WPDomain

/// 후기 사진을 **WebP 로만** 굽는다 — 안드로이드 `data/FeedPhotoPrep.kt` · 웹 `lib/feedImages.ts`.
///
/// 서버는 `image/webp` 만 받는다(R2 무료 용량). 원본(JPEG · HEIC · PNG)을 그대로 올리는 길을 만들지 말 것.
/// - 긴 변 1280px 이하로 줄인다(작으면 그대로). EXIF 방향을 따른다 — 세로 사진이 눕지 않게.
/// - 품질 80 → 65 → 50 으로, 1MB 이하가 될 때까지. 셋 다 넘으면 거절.
///
/// iOS ImageIO 는 WebP 를 읽기만 하고 쓰지 못해 libwebp 로 굽는다(안드로이드는 OS 인코더).
enum FeedPhotoPrep {
    struct Failure: LocalizedError {
        var message: String
        var errorDescription: String? { message }
    }

    /// 큰 원본을 둘 이상 동시에 풀지 않게 한 줄로 세운다(안드로이드 `decodeLock`)
    private static let queue = DispatchQueue(label: "app.weddingplant.feed-photo-prep")

    static func prepare(_ data: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try autoreleasepool { try encode(decode(data)) } })
            }
        }
    }

    /// 디코드할 때 줄인다(HEIC 포함) — 원본 크기로 풀었다 줄이면 4,000만 화소 사진에서 메모리가 모자란다.
    static func decode(_ data: Data, maxEdge: Int = FeedRules.photoMaxEdge) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else {
            throw Failure(message: FeedRules.photoUnreadable)
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = (properties?[kCGImagePropertyPixelWidth] as? Int) ?? 0
        let height = (properties?[kCGImagePropertyPixelHeight] as? Int) ?? 0
        let longEdge = max(width, height)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // EXIF 방향을 픽셀에 반영한다
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            // 작은 사진은 키우지 않는다
            kCGImageSourceThumbnailMaxPixelSize: longEdge > 0 ? min(maxEdge, longEdge) : maxEdge,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw Failure(message: FeedRules.photoUnreadable)
        }
        return image
    }

    static func encode(_ image: CGImage) throws -> Data {
        let width = image.width, height = image.height
        let stride = width * 4
        var pixels = [UInt8](repeating: 0, count: stride * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: stride, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { throw Failure(message: FeedRules.photoTooLarge) }
        // CGContext 는 미리 곱한 알파만 그린다 — libwebp 는 곱하지 않은 RGBA 를 받는다(사진 대부분은 불투명이라 그대로)
        for index in Swift.stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Int(pixels[index + 3])
            guard alpha > 0, alpha < 255 else { continue }
            for channel in 0..<3 { pixels[index + channel] = UInt8(min(255, Int(pixels[index + channel]) * 255 / alpha)) }
        }
        for quality in FeedRules.photoQualities {
            var output: UnsafeMutablePointer<UInt8>?
            let size = pixels.withUnsafeBufferPointer { buffer in
                WebPEncodeRGBA(buffer.baseAddress, Int32(width), Int32(height), Int32(stride), quality, &output)
            }
            defer { WebPFree(output) }
            if size > 0, size <= FeedRules.photoMaxBytes, let output {
                return Data(bytes: output, count: size)
            }
        }
        throw Failure(message: FeedRules.photoTooLarge)
    }
}
