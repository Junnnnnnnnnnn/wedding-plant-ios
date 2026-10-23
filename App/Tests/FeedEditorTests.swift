import ImageIO
import UniformTypeIdentifiers
import XCTest
import WPDomain
import WPModels
import WPNetworking
@testable import WeddingPlant

/// 후기 고치기 · 사진 올리기의 HTTP 계약 — 안드로이드 `FeedParityTest` 와 같은 경우를 같은 순서의 응답으로 본다.
/// 운영 계정 · 서버에는 요청하지 않는다(가짜 전송 계층 + R2 PUT 은 `SignedStorage.testUploader`).
@MainActor
final class FeedEditorTests: XCTestCase {
    private let base = FeedPost(id: 720, categoryName: "스튜디오", title: "햇살 스튜디오", amount: 120, isAmountPublic: true,
                                rating: 4, body: "따뜻한 분위기에서 편하게 촬영했어요.", authorRole: "BRIDE", isMine: true)
    private var transport: QueueTransport!
    private var env: AppEnvironment!
    private var puts: PutLog!

    override func setUp() async throws {
        transport = QueueTransport()
        let url = URL(string: "https://feed-editor.test")!
        let store = InMemoryTokenStore(token: DemoData.token)
        env = AppEnvironment(api: APIClient(baseURL: url, transport: transport, tokenStore: store), tokenStore: store, baseURL: url, isDemo: true)
        puts = PutLog()
        let log = puts!
        SignedStorage.testUploader = { url, type, bytes in await log.add(url, type, bytes) }
    }

    override func tearDown() async throws { SignedStorage.testUploader = nil }

    private func ok(_ data: String) -> HTTPResponse { .init(status: 200, headers: [:], body: Data(#"{"result":true,"data":\#(data)}"#.utf8)) }
    private func failure(_ status: Int, _ reason: String) -> HTTPResponse {
        .init(status: status, headers: [:], body: Data(#"{"message":"rejected","code":\#(status),"data":{"reason":"\#(reason)"}}"#.utf8))
    }
    private func json(_ post: FeedPost) -> String { String(decoding: try! JSONEncoder().encode(post), as: UTF8.self) }
    private func waitIdle(_ editor: FeedPostEditor) async {
        for _ in 0..<200 where editor.busy || editor.preparing { try? await Task.sleep(for: .milliseconds(20)) }
    }
    private func body(_ request: PreparedRequest) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: request.body ?? Data())) as? [String: Any] ?? [:]
    }
    private func webp() throws -> Data { try FeedPhotoPrep.encode(FeedPhotoPrep.decode(sourcePhoto())) }

    func testPhotoConflictRebasesAndKeepsUploadedKeyForRetry() async throws {
        let post = { var p = self.base; p.imageKeys = ["feed/old.webp"]; return p }()
        let editor = FeedPostEditor(editing: post)
        editor.addPreparedPhoto(try webp())
        editor.body = "작성 중인 글"
        editor.rating = 2
        await transport.enqueue(ok(#"{"key":"feed/new.webp","uploadUrl":"https://r2.test/upload"}"#),
                                failure(409, "FEED_CHANGED"),
                                ok(json({ var p = post; p.imageKeys = ["feed/current.webp"]; p.images = ["https://example.test/current.webp"]; return p }())))
        editor.submit(env: env, onPosted: {}, onSaved: { _ in })
        await waitIdle(editor)
        XCTAssertEqual(editor.body, "작성 중인 글")
        XCTAssertEqual(editor.rating, 2)
        XCTAssertEqual(editor.photos.map(\.key), ["feed/current.webp", "feed/new.webp"])
        XCTAssertTrue(editor.error?.contains("지금 사진으로 다시") == true)
        let first = await transport.recorded
        XCTAssertEqual(first.map(\.url.path), ["/plan/feed/image", "/plan/feed/720", "/plan/feed/public/720"])
        let firstPut = await puts.entries.first
        let put = try XCTUnwrap(firstPut)
        XCTAssertEqual(put.type, "image/webp")
        XCTAssertEqual(String(decoding: put.bytes[8..<12], as: UTF8.self), "WEBP")

        await transport.enqueue(ok(json(post)))
        var saved = false
        editor.submit(env: env, onPosted: {}, onSaved: { _ in saved = true })
        await waitIdle(editor)
        XCTAssertTrue(saved)
        let retryRequest = await transport.recorded.last
        let retry = try XCTUnwrap(retryRequest)
        XCTAssertEqual(retry.method, .patch)
        XCTAssertEqual(body(retry)["baseImages"] as? [String], ["feed/current.webp"])
        XCTAssertEqual(body(retry)["images"] as? [String], ["feed/current.webp", "feed/new.webp"])
        let count = await transport.recorded.count
        XCTAssertEqual(count, 4, "다시 눌러도 이미 올린 사진은 또 올리지 않는다")
    }

    func testRatingOnlySaveSendsNoImagesOrPlaceAndDelete404IsSuccess() async throws {
        let editor = FeedPostEditor(editing: { var p = base; p.imageKeys = ["feed/a.webp"]; return p }())
        XCTAssertEqual(editor.body, base.body)
        XCTAssertEqual(editor.photos.count, 1)
        editor.rating = 3
        await transport.enqueue(ok(json({ var p = base; p.rating = 3; return p }())))
        var saved: FeedPost?
        editor.submit(env: env, onPosted: {}, onSaved: { saved = $0 })
        XCTAssertTrue(editor.busy, "보내는 동안은 닫히지 않는다")
        await waitIdle(editor)
        XCTAssertEqual(saved?.rating, 3)
        let lastPatch = await transport.recorded.last
        let patch = try XCTUnwrap(lastPatch)
        XCTAssertEqual(patch.method, .patch)
        XCTAssertNil(body(patch)["images"])
        XCTAssertNil(body(patch)["place"])
        XCTAssertEqual(body(patch)["rating"] as? Int, 3)

        editor.confirmingDelete = true
        await transport.enqueue(failure(404, "NOT_FOUND"))
        var deleted: Int?
        editor.delete(env: env) { deleted = $0 }
        await waitIdle(editor)
        XCTAssertEqual(deleted, base.id)
        let delete = await transport.recorded.last
        XCTAssertEqual(delete?.method, .delete)
    }

    func testNewPostPhotosAreLimitedAndUseFlatPlacePayload() async throws {
        let editor = FeedPostEditor()
        editor.selectSchedule(PostableSchedule(scheduleId: 51, categoryName: "스튜디오", title: "사진"), env: env)
        editor.pickPlace(FeedPlace(placeId: "", placeName: "햇살", address: "서울", lat: 37.5, lng: 127.0))
        XCTAssertEqual(FeedRules.acceptPhotos(existing: 0, picked: 4).note, "사진은 3장까지예요. 앞의 3장만 담았어요.")
        for _ in 0..<3 { editor.addPreparedPhoto(try webp()) }
        for i in 0..<3 { await transport.enqueue(ok(#"{"key":"feed/\#(i).webp","uploadUrl":"https://r2.test/upload/\#(i)"}"#)) }
        await transport.enqueue(ok("{}"))
        var posted = false
        editor.submit(env: env, onPosted: { posted = true }, onSaved: { _ in })
        await waitIdle(editor)
        XCTAssertTrue(posted)
        let lastRequest = await transport.recorded.last
        let request = try XCTUnwrap(lastRequest)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.url.path, "/plan/feed")
        let payload = body(request)
        XCTAssertNil(payload["place"])
        XCTAssertNil(payload["placeId"])
        XCTAssertEqual(payload["placeName"] as? String, "햇살")
        XCTAssertEqual(payload["authorRole"] as? String, "BRIDE", "새 후기는 신부가 먼저 골라져 있다(안드로이드)")
        XCTAssertEqual(payload["images"] as? [String], ["feed/0.webp", "feed/1.webp", "feed/2.webp"])
        let putCount = await puts.entries.count
        XCTAssertEqual(putCount, 3)
    }

    func testInvalidPhotoKeyRetriesOnlyNewPhotosAndScheduleChangeClearsDraft() async throws {
        let editor = FeedPostEditor(editing: { var p = base; p.imageKeys = ["feed/existing.webp"]; return p }())
        editor.addPreparedPhoto(try webp())
        await transport.enqueue(ok(#"{"key":"feed/expired.webp","uploadUrl":"https://r2.test/upload"}"#), failure(400, "PHOTO_NOT_UPLOADED"))
        editor.submit(env: env, onPosted: {}, onSaved: { _ in })
        await waitIdle(editor)
        XCTAssertEqual(editor.photos[0].key, "feed/existing.webp")
        XCTAssertNil(editor.photos[1].key)
        XCTAssertEqual(editor.error, "사진을 다시 올려야 해요. 한 번 더 눌러 주세요.")
        await transport.enqueue(ok(#"{"key":"feed/fresh.webp","uploadUrl":"https://r2.test/upload2"}"#), ok(json(base)))
        var done = false
        editor.submit(env: env, onPosted: {}, onSaved: { _ in done = true })
        await waitIdle(editor)
        XCTAssertTrue(done)
        let lastPatch = await transport.recorded.last
        let patch = try XCTUnwrap(lastPatch)
        XCTAssertEqual(body(patch)["images"] as? [String], ["feed/existing.webp", "feed/fresh.webp"])

        let fresh = FeedPostEditor()
        fresh.selectSchedule(PostableSchedule(scheduleId: 1, title: "A"), env: env)
        fresh.body = "이전 일정의 글"
        fresh.rating = 1
        fresh.addPreparedPhoto(try webp())
        fresh.selectSchedule(PostableSchedule(scheduleId: 2, title: "B"), env: env)
        XCTAssertTrue(fresh.photos.isEmpty)
        XCTAssertEqual(fresh.body, "")
        XCTAssertEqual(fresh.rating, 5)
    }

    func testSlotFailuresSpeakTheirReason() async throws {
        let editor = FeedPostEditor(editing: base)
        editor.addPreparedPhoto(try webp())
        await transport.enqueue(.init(status: 503, headers: [:], body: Data(#"{"message":"no storage"}"#.utf8)))
        editor.submit(env: env, onPosted: {}, onSaved: { _ in })
        await waitIdle(editor)
        XCTAssertEqual(editor.error, "사진 보관소가 아직 연결되지 않았어요. 사진 없이 올려 주세요.")
        await transport.enqueue(.init(status: 429, headers: [:], body: Data(#"{"message":"오늘은 사진을 더 올릴 수 없어요."}"#.utf8)))
        editor.submit(env: env, onPosted: {}, onSaved: { _ in })
        await waitIdle(editor)
        XCTAssertEqual(editor.error, "오늘은 사진을 더 올릴 수 없어요.", "429 는 서버 문장을 그대로")
        await transport.enqueue(failure(403, "FORBIDDEN"))
        let noPhoto = FeedPostEditor(editing: base)
        noPhoto.submit(env: env, onPosted: {}, onSaved: { _ in })
        await waitIdle(noPhoto)
        XCTAssertEqual(noPhoto.error, "이 후기는 고칠 수 없어요. 이미 내렸거나 가려진 후기예요.")
    }

    // MARK: - WebP

    func testRotatedJpegBecomesUprightWebpUnderLimits() async throws {
        let source = try sourcePhoto()
        let props = CGImageSourceCreateWithData(source as CFData, nil).flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) } as? [CFString: Any]
        XCTAssertEqual(props?[kCGImagePropertyOrientation] as? Int, 6, "원본에 EXIF 90° 가 적혀 있다")
        let decoded = try FeedPhotoPrep.decode(source)
        XCTAssertEqual([decoded.width, decoded.height], [640, 1280])
        let bytes = try await FeedPhotoPrep.prepare(source)
        XCTAssertLessThanOrEqual(bytes.count, FeedRules.photoMaxBytes)
        XCTAssertEqual(String(decoding: bytes[0..<4], as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: bytes[8..<12], as: UTF8.self), "WEBP")
        let (width, height) = try size(bytes)
        XCTAssertEqual(width, 640, "EXIF 90° 를 따라 세로로 선다")
        XCTAssertEqual(height, 1280, "긴 변 1280")
    }

    func testHeicConvertsToWebpWithoutRotatingPortrait() async throws {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.heic.identifier as CFString, 1, nil) else {
            throw XCTSkip("이 시뮬레이터는 HEIC 를 만들지 못한다")
        }
        CGImageDestinationAddImage(destination, try canvas(width: 1200, height: 2400), nil)
        guard CGImageDestinationFinalize(destination) else { throw XCTSkip("HEIC 인코더 없음") }
        let bytes = try await FeedPhotoPrep.prepare(data as Data)
        XCTAssertEqual(String(decoding: bytes[8..<12], as: UTF8.self), "WEBP")
        let (width, height) = try size(bytes)
        XCTAssertEqual(width, 640)
        XCTAssertEqual(height, 1280)
    }

    func testSmallPhotoIsNotEnlargedAndJunkIsRefused() async throws {
        let png = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(png, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try canvas(width: 300, height: 200), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let (width, height) = try size(try await FeedPhotoPrep.prepare(png as Data))
        XCTAssertEqual(width, 300)
        XCTAssertEqual(height, 200)
        do {
            _ = try await FeedPhotoPrep.prepare(Data("not an image".utf8))
            XCTFail("사진이 아니면 거절")
        } catch {
            XCTAssertEqual((error as? FeedPhotoPrep.Failure)?.message, "이 사진은 열 수 없어요. JPG · PNG 사진으로 골라 주세요.")
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

    /// 안드로이드 `sourcePhoto()` — 2400×1200 JPEG 에 EXIF 90° 회전(세로로 찍은 사진)
    private func sourcePhoto() throws -> Data {
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try canvas(width: 2400, height: 1200),
                                   [kCGImagePropertyOrientation: NSNumber(value: 6),
                                    kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFOrientation: NSNumber(value: 6)]] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func size(_ webp: Data) throws -> (Int, Int) {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(webp as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        return (image.width, image.height)
    }
}

/// MockWebServer 의 `enqueue` 처럼 넣은 순서대로 답하고, 나간 요청을 적는다.
private actor QueueTransport: HTTPTransport {
    private var queue: [HTTPResponse] = []
    private(set) var recorded: [PreparedRequest] = []

    func enqueue(_ responses: HTTPResponse...) { queue += responses }

    func send(_ request: PreparedRequest) async throws -> HTTPResponse {
        recorded.append(request)
        guard !queue.isEmpty else { throw APIError.transport("응답이 없다: \(request.url.path)") }
        return queue.removeFirst()
    }
}

private actor PutLog {
    struct Entry { let url: URL; let type: String; let bytes: Data }
    private(set) var entries: [Entry] = []
    func add(_ url: URL, _ type: String, _ bytes: Data) { entries.append(.init(url: url, type: type, bytes: bytes)) }
}
