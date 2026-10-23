import XCTest
@testable import WPDomain
@testable import WPModels

/// 내 후기 고치기 · 사진 · 카테고리 칩 — 안드로이드 `FeedEditTest` · `domain/FeedCategoriesTest` 와 같은 경우.
final class FeedEditTests: XCTestCase {
    private let place = FeedPlace(placeId: "123", placeName: "업체", address: "서울", lat: 37.5, lng: 127.0)

    private func json(_ request: FeedEditRequest) throws -> [String: Any] {
        let data = try JSONEncoder().encode(request)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? [String: Any])
    }

    func testRatingOnlyPreservesConcurrentPhotosAndPlace() throws {
        let body = try json(FeedRules.editRequest(rating: 4, body: "  ", isAmountPublic: false, authorRole: "BRIDE",
                                                  initialPlace: place, place: place, baseImages: ["a", "b"], images: ["a", "b"]))
        XCTAssertEqual(body["body"] as? String, "")
        XCTAssertNil(body["images"])
        XCTAssertNil(body["baseImages"])
        XCTAssertNil(body["place"])
        XCTAssertNil(body["amount"])
        XCTAssertNil(body["categoryName"])
        XCTAssertEqual(body["rating"] as? Int, 4)
    }

    func testRemovalAndReorderingIncludeOriginalBase() throws {
        let body = try json(FeedRules.editRequest(rating: 5, body: "한 줄", isAmountPublic: true, authorRole: "UNKNOWN",
                                                  initialPlace: place, place: nil, baseImages: ["a", "b"], images: ["b", "c"]))
        XCTAssertTrue(body["place"] is NSNull)
        XCTAssertEqual(body["images"] as? [String], ["b", "c"])
        XCTAssertEqual(body["baseImages"] as? [String], ["a", "b"])
        let reordered = try json(FeedRules.editRequest(rating: 5, body: "", isAmountPublic: true, authorRole: "GROOM",
                                                       initialPlace: nil, place: nil, baseImages: ["a", "b"], images: ["b", "a"]))
        XCTAssertNotNil(reordered["images"])
        XCTAssertNil(reordered["place"])
    }

    func testNewPlaceIsSentAndCoordinateOnlyPlaceOmitsBlankId() throws {
        var other = place
        other.placeId = ""
        other.placeName = "다른 업체"
        let body = try json(FeedRules.editRequest(rating: 5, body: "", isAmountPublic: true, authorRole: "BRIDE",
                                                  initialPlace: place, place: other, baseImages: [], images: []))
        let sent = try XCTUnwrap(body["place"] as? [String: Any])
        XCTAssertNil(sent["placeId"])
        XCTAssertEqual(sent["placeName"] as? String, "다른 업체")
        XCTAssertEqual(sent["lat"] as? Double, 37.5)
    }

    func testOldResponsesDecodeWithoutPhotos() throws {
        let old = try JSONDecoder().decode(FeedPost.self, from: Data(#"{"id":5,"isMine":true}"#.utf8))
        XCTAssertTrue(old.images.isEmpty)
        XCTAssertNil(old.imageKeys)
        let mine = try JSONDecoder().decode(FeedPost.self, from: Data(#"{"id":6,"images":["https://x/1.webp"],"imageKeys":["feed/1.webp"]}"#.utf8))
        XCTAssertEqual(mine.images, ["https://x/1.webp"])
        XCTAssertEqual(mine.imageKeys, ["feed/1.webp"])
    }

    func testPlaceFromPostNeedsAddressOrId() {
        XCTAssertNil(FeedPlace(post: FeedPost(id: 1, title: "업체")))
        let from = FeedPlace(post: FeedPost(id: 1, title: "업체", address: "서울 강남구", lat: 37.5, lng: 127))
        XCTAssertEqual(from?.placeName, "업체")
        XCTAssertEqual(from?.address, "서울 강남구")
        let result = FeedPlace(result: PlaceSearchResult(placeId: "9", placeName: "청담", addressName: "지번", roadAddressName: " ", lat: 1, lng: 2))
        XCTAssertEqual(result.address, "지번")
        XCTAssertEqual(result.placeId, "9")
    }

    func testNewPostSendsImagesOnlyWhenPresent() throws {
        let none = try JSONSerialization.jsonObject(with: JSONEncoder().encode(
            FeedPostRequest(scheduleId: 1, rating: 5, isAmountPublic: true, authorRole: "BRIDE"))) as? [String: Any]
        XCTAssertNil(none?["images"])
        let some = try JSONSerialization.jsonObject(with: JSONEncoder().encode(
            FeedPostRequest(scheduleId: 1, rating: 5, isAmountPublic: true, authorRole: "BRIDE", placeName: "햇살",
                            address: "서울", lat: 37.5, lng: 127, images: ["feed/0.webp", "feed/1.webp"]))) as? [String: Any]
        XCTAssertEqual(some?["images"] as? [String], ["feed/0.webp", "feed/1.webp"])
        XCTAssertNil(some?["place"])
        XCTAssertNil(some?["placeId"])
        XCTAssertEqual(some?["placeName"] as? String, "햇살")
    }

    func testPhotoLimitKeepsTheFirstPicked() {
        XCTAssertEqual(FeedRules.acceptPhotos(existing: 0, picked: 4).count, 3)
        XCTAssertEqual(FeedRules.acceptPhotos(existing: 0, picked: 4).note, "사진은 3장까지예요. 앞의 3장만 담았어요.")
        XCTAssertEqual(FeedRules.acceptPhotos(existing: 2, picked: 2).note, "사진은 3장까지예요. 앞의 1장만 담았어요.")
        XCTAssertNil(FeedRules.acceptPhotos(existing: 1, picked: 2).note)
        XCTAssertEqual(FeedRules.acceptPhotos(existing: 3, picked: 1).count, 0)
    }

    // MARK: - 칩

    private let categories = ["상견례", "드레스"]

    func testChipsKeepServerOrderForAllAndExistingSelection() {
        XCTAssertEqual(FeedRules.chips(categories, selected: nil), categories)
        XCTAssertEqual(FeedRules.chips(categories, selected: "드레스"), categories)
    }

    func testMissingSelectionStaysAtEndUntilReturningToAll() {
        XCTAssertEqual(FeedRules.chips(categories, selected: "웨딩홀"), categories + ["웨딩홀"])
        XCTAssertEqual(FeedRules.chips([], selected: "상견례"), ["상견례"])
        XCTAssertEqual(FeedRules.chips([], selected: nil), [])
    }
}
