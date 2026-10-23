import Combine
import Foundation
import PhotosUI
import SwiftUI
import UIKit
import WPDomain
import WPModels
import WPNetworking

/// 시트에 담은 사진 한 장. 고른 사진은 WebP 로 바꾼 바이트(`bytes`), 원래 있던 사진은 서버 키(`key`)와 미리보기 주소(`preview`).
struct FeedPhoto: Identifiable, Equatable {
    let id = UUID()
    var preview: String? = nil
    var bytes: Data? = nil
    /// 바이트로 그린 미리보기 — 화면을 그릴 때마다 다시 풀지 않게 한 번만
    var local: UIImage? = nil
    var key: String? = nil

    var preparing: Bool { bytes == nil && key == nil }

    static func == (lhs: FeedPhoto, rhs: FeedPhoto) -> Bool {
        lhs.id == rhs.id && lhs.key == rhs.key && lhs.bytes == rhs.bytes && lhs.preview == rhs.preview
    }
}

/// 한 번 연 후기 시트의 작업 — 안드로이드 `ui/feed/FeedPostEditor.kt` 이식.
///
/// 올리기와 고치기가 **같은 칸**을 쓴다(웹 `FeedPostModal` 이 `editing` 을 받으면 고치기로 열린다).
/// 성공한 사진 업로드 키는 저장이 실패해도 이 시트 안에서 다시 쓴다 — 다시 눌러도 같은 사진을 또 올리지 않는다.
@MainActor
final class FeedPostEditor: ObservableObject {
    let editing: FeedPost?
    private let initialPlace: FeedPlace?

    @Published private(set) var selected: PostableSchedule?
    @Published var rating: Int
    @Published var body: String
    @Published var isAmountPublic: Bool
    @Published var role: String
    @Published private(set) var place: FeedPlace?
    @Published private(set) var keyword: String
    @Published private(set) var places: [PlaceSearchResult] = []
    @Published private(set) var searching = false
    @Published private(set) var placeError: String?
    @Published private(set) var photos: [FeedPhoto]
    @Published private(set) var photoNote: String?
    @Published private(set) var error: String?
    @Published private(set) var saving = false
    @Published private(set) var deleting = false
    @Published private(set) var uploading: String?
    @Published var confirmingDelete = false

    private var baseImages: [String]
    private var searchTask: Task<Void, Never>?
    private var photoTask: Task<Void, Never>?
    private var searchGeneration = 0

    var busy: Bool { saving || deleting }
    var preparing: Bool { photos.contains { $0.preparing } }

    init(editing: FeedPost? = nil) {
        self.editing = editing
        let place = editing.flatMap(FeedPlace.init(post:))
        initialPlace = place
        self.place = place
        rating = editing?.rating ?? 5
        body = editing?.body ?? ""
        isAmountPublic = editing?.isAmountPublic ?? true
        // 안드로이드 `editing?.authorRole ?: "BRIDE"` — 새 후기는 신부가 먼저 골라져 있다
        role = editing?.authorRole ?? "BRIDE"
        keyword = editing?.title ?? ""
        photos = Self.existingPhotos(editing)
        baseImages = editing?.imageKeys ?? []
    }

    // MARK: - 일정 · 업체

    /// 다른 일정을 고르면 적던 값을 비운다 — 앞 일정의 사진 · 별점이 다른 업체 후기로 올라가면 안 된다.
    func selectSchedule(_ schedule: PostableSchedule, env: AppEnvironment) {
        guard !busy, selected?.scheduleId != schedule.scheduleId else { return }
        photoTask?.cancel()
        photos = []
        rating = 5
        body = ""
        isAmountPublic = true
        error = nil
        photoNote = nil
        selected = schedule
        place = nil
        let location = schedule.location?.trimmingCharacters(in: .whitespaces) ?? ""
        updateKeyword(location.isEmpty ? schedule.title : location)
        // 일정의 좌표와 맞는 결과만 저절로 고른다. 이름이 같은 다른 지점은 저절로 고르지 않는다.
        if schedule.locationLat != nil, schedule.locationLng != nil { search(env: env, auto: true) }
    }

    func updateKeyword(_ value: String) {
        guard !busy else { return }
        keyword = value
        cancelSearch()
        places = []
        placeError = nil
    }

    func pickPlace(_ value: FeedPlace?) {
        guard !busy else { return }
        cancelSearch()
        place = value
        places = []
        placeError = nil
    }

    private func cancelSearch() {
        searchTask?.cancel()
        searchGeneration += 1
        searching = false
    }

    func search(env: AppEnvironment, auto: Bool = false) {
        let query = keyword.trimmingCharacters(in: .whitespaces)
        guard !busy, !query.isEmpty else { return }
        searchTask?.cancel()
        searchGeneration += 1
        let generation = searchGeneration
        let target = selected
        searching = true
        placeError = nil
        searchTask = Task {
            let result: Result<PlaceSearchPage, Error>
            do { result = .success(try await env.api.send(Endpoint.searchPlaces(query: query, size: auto ? 15 : 8), decoding: PlaceSearchPage.self)) }
            catch { result = .failure(error) }
            guard generation == searchGeneration else { return }
            searching = false
            switch result {
            case .success(let page):
                let valid = page.list.filter { $0.lat.isFinite && $0.lng.isFinite }
                if auto {
                    place = valid.first { item in
                        guard let lat = target?.locationLat, let lng = target?.locationLng else { return false }
                        return abs(item.lat - lat) < 0.002 && abs(item.lng - lng) < 0.002
                    }.map(FeedPlace.init(result:))
                } else {
                    places = valid
                    if valid.isEmpty { placeError = "검색 결과가 없어요. 다른 검색어로 찾아 주세요." }
                }
            case .failure:
                if !auto { placeError = "장소를 찾지 못했어요. 잠시 후 다시 시도해 주세요." }
            }
        }
    }

    // MARK: - 사진

    /// 고르는 순간 **자리부터 잡고**(`줄이는 중`) 한 장씩 차례로 바꾼다 — 한꺼번에 풀면 구형 폰이 버겁다(웹에서 겪음).
    func addPhotos(_ items: [PhotosPickerItem]) {
        guard !busy, !preparing, !items.isEmpty else { return }
        let accepted = FeedRules.acceptPhotos(existing: photos.count, picked: items.count)
        photoNote = accepted.note
        let picked = Array(items.prefix(accepted.count))
        let pending = picked.map { _ in FeedPhoto() }
        photos += pending
        photoTask = Task {
            for (item, photo) in zip(picked, pending) {
                guard !Task.isCancelled, photos.contains(where: { $0.id == photo.id }) else { continue }
                do {
                    guard let raw = try await item.loadTransferable(type: Data.self) else { throw FeedPhotoPrep.Failure(message: FeedRules.photoUnreadable) }
                    let bytes = try await FeedPhotoPrep.prepare(raw)
                    guard !Task.isCancelled else { return }
                    setPhoto(photo.id) { $0.bytes = bytes; $0.local = UIImage(data: bytes) }
                } catch {
                    guard !Task.isCancelled else { return }
                    photos.removeAll { $0.id == photo.id }
                    photoNote = (error as? FeedPhotoPrep.Failure)?.message ?? "사진을 준비하지 못했어요."
                }
            }
        }
    }

    /// 테스트 · 데모가 고르기 화면 없이 사진을 담는다(이미 바꾼 WebP)
    func addPreparedPhoto(_ bytes: Data) {
        photos.append(FeedPhoto(bytes: bytes, local: UIImage(data: bytes)))
    }

    func removePhoto(_ id: UUID) {
        guard !busy else { return }
        photos.removeAll { $0.id == id }
    }

    private func setPhoto(_ id: UUID, _ change: (inout FeedPhoto) -> Void) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        change(&photos[index])
    }

    // MARK: - 저장 · 내리기

    func submit(env: AppEnvironment, onPosted: @escaping () -> Void, onSaved: @escaping (FeedPost) -> Void) {
        guard !busy, !preparing, editing != nil || selected != nil else { return }
        saving = true
        error = nil
        // 자동 장소 판정이 저장 요청 뒤에 고른 값을 바꾸지 않게 지금 것으로 묶는다
        cancelSearch()
        Task {
            defer { saving = false; uploading = nil }
            let pending = photos.filter { $0.key == nil }
            for (index, photo) in pending.enumerated() {
                uploading = "사진 올리는 중 \(index + 1)/\(pending.count)"
                guard let bytes = photo.bytes else { return }
                let slot: FeedImageUpload
                do {
                    slot = try await env.api.send(try Endpoint.createFeedImage(sizeBytes: bytes.count), decoding: FeedImageUpload.self)
                } catch {
                    let api = error as? APIError
                    if case .http(503, _)? = api { self.error = FeedRules.EditFailure.slotUnavailable }
                    else if case .http(429, _)? = api { self.error = api?.errorDescription ?? FeedRules.EditFailure.slotFailed }
                    else { self.error = FeedRules.EditFailure.slotFailed }
                    return
                }
                do {
                    try await SignedStorage.upload(url: slot.uploadUrl, contentType: "image/webp", bytes: bytes)
                } catch {
                    self.error = FeedRules.EditFailure.putFailed
                    return
                }
                setPhoto(photo.id) { $0.key = slot.key }
            }
            uploading = nil
            let keys = photos.compactMap(\.key)
            if let editing {
                let request = FeedRules.editRequest(rating: rating, body: body, isAmountPublic: isAmountPublic, authorRole: role,
                                                    initialPlace: initialPlace, place: place, baseImages: baseImages, images: keys)
                do {
                    let saved = try await env.api.send(try Endpoint.updateFeedPost(id: editing.id, request), decoding: FeedPost.self)
                    onSaved(saved)
                } catch {
                    await handleFailure(error, env: env)
                }
            } else if let selected {
                let request = FeedPostRequest(scheduleId: selected.scheduleId, rating: rating, body: body,
                                              isAmountPublic: isAmountPublic, authorRole: role,
                                              placeId: place?.placeId, placeName: place?.placeName, address: place?.address,
                                              lat: place?.lat, lng: place?.lng, images: keys)
                do {
                    try await env.api.sendIgnoringData(try Endpoint.createFeedPost(request))
                    onPosted()
                } catch {
                    await handleFailure(error, env: env)
                }
            }
        }
    }

    private func handleFailure(_ failure: Error, env: AppEnvironment) async {
        let api = failure as? APIError
        let status: Int? = if case .http(let code, _)? = api { code } else { nil }
        let reason = api?.serverReason
        if status == 409, reason == "FEED_CHANGED", let editing {
            // 새로 고른 사진의 키만 지우고 다시 누르게 하면 같은 거절이 끝없이 되풀이된다 — 서버에서 이미 빠진 옛 사진을
            // 계속 보내서다. 서버의 지금 사진 + 이번에 고른 사진으로 다시 맞추고, 적던 별점 · 한 줄은 건드리지 않는다.
            if let latest = try? await env.api.send(Endpoint.feedPost(id: editing.id), decoding: FeedPost.self),
               latest.isMine, let keys = latest.imageKeys {
                photos = Array((Self.existingPhotos(latest) + photos.filter { $0.bytes != nil }).prefix(FeedRules.maxPhotos))
                baseImages = keys
                error = FeedRules.EditFailure.rebased
            } else {
                error = FeedRules.EditFailure.changedElsewhere
            }
        } else if let reason, FeedRules.EditFailure.photoReasons.contains(reason) {
            // 자리가 만료(하루)됐거나 파일이 이상하다 — **새로 고른 사진만** 다시 올린다
            photos = photos.map { photo in
                var next = photo
                if photo.bytes != nil { next.key = nil }
                return next
            }
            error = FeedRules.EditFailure.photoRetry
        } else if editing != nil, status == 403 || status == 404 {
            error = FeedRules.EditFailure.notEditable
        } else if editing != nil {
            error = FeedRules.EditFailure.saveFailed
        } else {
            error = Self.postFailureMessage(api)
        }
    }

    /// 안드로이드 `FeedViewModel.postFailureMessage`
    static func postFailureMessage(_ error: APIError?) -> String {
        if let error, (error.errorDescription ?? "").localizedCaseInsensitiveContains("already posted") { return "이미 후기로 올린 일정이에요." }
        if case .http(404, let body)? = error {
            if (body ?? "").localizedCaseInsensitiveContains("already posted") { return "이미 후기로 올린 일정이에요." }
            return "이 일정은 올릴 수 없어요. 내가 만든 완료 일정만 후기가 돼요."
        }
        if case .http(_, let body)? = error, (body ?? "").localizedCaseInsensitiveContains("already posted") { return "이미 후기로 올린 일정이에요." }
        return "올리지 못했습니다. 잠시 후 다시 시도해 주세요."
    }

    func delete(env: AppEnvironment, onDeleted: @escaping (Int) -> Void) {
        guard let post = editing, !busy, confirmingDelete else { return }
        deleting = true
        error = nil
        Task {
            defer { deleting = false }
            do {
                try await env.api.sendIgnoringData(Endpoint.deleteFeedPost(id: post.id))
                onDeleted(post.id)
            } catch APIError.http(404, _) {
                // 이미 내려간 후기다 — 바라던 결과다
                onDeleted(post.id)
            } catch {
                self.error = FeedRules.EditFailure.deleteFailed
            }
        }
    }

    private static func existingPhotos(_ post: FeedPost?) -> [FeedPhoto] {
        guard let post else { return [] }
        return (post.imageKeys ?? []).enumerated().map { index, key in
            FeedPhoto(preview: post.images.indices.contains(index) ? post.images[index] : nil, key: key)
        }
    }
}
