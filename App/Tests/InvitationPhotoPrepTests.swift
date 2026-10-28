import ImageIO
import UniformTypeIdentifiers
import XCTest
import WPDomain
@testable import WeddingPlant

/// 청첩장 사진 — Android `InvitationWorkflowAuditTest.heicExifAndTransparentPngProduceOrientedOpaqueWebp` 와 같은 경우.
/// HEIC · EXIF 회전 JPEG · 투명 PNG 가 모두 **세로로 선 · 불투명한 WebP**(긴 변 1600 이하)가 된다.
final class InvitationPhotoPrepTests: XCTestCase {
    func testRotatedJpegBecomesUprightWebpAtSixteenHundred() async throws {
        let bytes = try await InvitationPhotoPrep.prepare(try encoded(canvas(width: 3200, height: 1600), type: .jpeg, orientation: 6))
        XCTAssertEqual(String(decoding: bytes[0..<4], as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: bytes[8..<12], as: UTF8.self), "WEBP")
        XCTAssertLessThanOrEqual(bytes.count, InvitationRules.photoMaxUploadBytes)
        let image = try decoded(bytes)
        XCTAssertEqual([image.width, image.height], [800, 1600], "EXIF 90° 를 따라 세로로 서고 긴 변은 1600")
    }

    func testHeicIsReadAndConverted() async throws {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.heic.identifier as CFString, 1, nil) else {
            throw XCTSkip("이 시뮬레이터는 HEIC 를 만들지 못한다")
        }
        CGImageDestinationAddImage(destination, try canvas(width: 1000, height: 1500), nil)
        guard CGImageDestinationFinalize(destination) else { throw XCTSkip("HEIC 인코더 없음") }
        let image = try decoded(try await InvitationPhotoPrep.prepare(data as Data))
        XCTAssertEqual([image.width, image.height], [1000, 1500], "1600 보다 작으면 키우지 않는다")
    }

    func testTransparentPngIsFlattenedOntoWhite() async throws {
        let context = try XCTUnwrap(CGContext(data: nil, width: 40, height: 40, bitsPerComponent: 8, bytesPerRow: 0,
                                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.clear(CGRect(x: 0, y: 0, width: 40, height: 40))
        let png = try encoded(try XCTUnwrap(context.makeImage()), type: .png, orientation: nil)
        let image = try decoded(try await InvitationPhotoPrep.prepare(png))
        let pixel = try rgba(image, x: 20, y: 20)
        XCTAssertEqual(pixel[3], 255, "알파가 없어진다")
        XCTAssertGreaterThan(pixel[0], 245, "투명은 흰 바탕 — 검정이 아니다")
        XCTAssertGreaterThan(pixel[1], 245)
        XCTAssertGreaterThan(pixel[2], 245)
    }

    func testJunkIsRefusedInPlainWords() async {
        do {
            _ = try await InvitationPhotoPrep.prepare(Data("not an image".utf8))
            XCTFail("사진이 아니면 거절")
        } catch {
            XCTAssertEqual((error as? FeedPhotoPrep.Failure)?.message, "사진을 읽지 못했어요.")
        }
    }

    // MARK: - 도우미

    private func canvas(width: Int, height: Int) throws -> CGImage {
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(red: 239 / 255, green: 183 / 255, blue: 193 / 255, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try XCTUnwrap(context.makeImage())
    }

    private func encoded(_ image: CGImage, type: UTType, orientation: Int?) throws -> Data {
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
        let properties: CFDictionary? = orientation.map {
            [kCGImagePropertyOrientation: NSNumber(value: $0),
             kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFOrientation: NSNumber(value: $0)]] as CFDictionary
        }
        CGImageDestinationAddImage(destination, image, properties)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func decoded(_ data: Data) throws -> CGImage {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        return try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    private func rgba(_ image: CGImage, x: Int, y: Int) throws -> [UInt8] {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return pixel
    }
}
