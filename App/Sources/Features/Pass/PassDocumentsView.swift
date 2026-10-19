import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import WPModels
import WPDomain
import WPNetworking
import WPUtils

// MARK: - 일정의 서류 칸 (안드로이드 `ui/pass/PassDocsRow.kt`)

/// 일정 상세·수정하기의 **서류 칸** — 안드로이드 `PassDocsRowBody` 와 같은 모양.
///
/// - 패스 없음: 칸은 보이고 누르면 준비 패스 소개(이런 기능이 있다는 걸 알아야 사고 싶어진다).
/// - 패스 있음: 상세는 보기만(`canAdd == false`), 수정하기에서 붙이고 지운다.
/// - 만료: 개수는 보이고 열리지 않는다 + 전부 내려받기.
///
/// **받기 전에는 아무것도 그리지 않는다**(안드로이드와 같음) — 산 사람에게 자물쇠가 한 번
/// 번쩍이면 "결제가 날아갔나" 하고 놀란다.
struct PassDocumentsView: View {
    let scheduleId: Int
    var canAdd = false
    /// 캡처용 — 올리는 중인 `+` 칸(안드로이드 `pass-docs-uploading`)을 그대로 띄운다
    var initiallyBusy = false
    @EnvironmentObject private var env: AppEnvironment
    @State private var page: PassFilePage?
    @State private var loadFailed = false
    /// 올리기·지우기·열기의 실패 문장(안드로이드 `PassFilesViewModel.message`) — 타일 아래 빨간 줄
    @State private var message: String?
    @State private var entitlement: PassState?
    @State private var thumbnails: [Int: UIImage] = [:]
    @State private var importing = false
    @State private var busy = false
    @State private var pass = false
    @State private var downloadAll = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var deleting: PassFileItem?
    @State private var preview: DownloadedDocument?
    @State private var opening = false
    @State private var cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    private var hasPass: Bool { page?.canOpen == true }
    private var expired: Bool { entitlement?.expired == true }
    private var files: [PassFileItem] { page?.list ?? [] }

    var body: some View {
        // Group 은 수식어를 자식에게 나눠 주므로, 받기 전(자식 없음)에도 `.task` 가 붙도록 한 장으로 둔다
        VStack(spacing: 0) {
            if page != nil || loadFailed { card }
        }
        .frame(maxWidth: .infinity)
        .task { if initiallyBusy { busy = true }; await load() }
        .sheet(item: $preview) { DocumentPreview(url: $0.url) }
        .sheet(isPresented: $downloadAll) { if let room = page?.roomId { PassDownloadView(roomId: room) } }
        .fullScreenCover(isPresented: $pass) { PassView(roomId: page?.roomId) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
            Task {
                do {
                    guard let url = try result.get().first else { return }
                    let picked = try PassFileUploader.read(url)
                    try await upload(picked)
                } catch { message = PassFileUploader.failureMessage(error) }
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                do { try await upload(try await PassFileUploader.read(item)) }
                catch { message = PassFileUploader.failureMessage(error) }
                selectedPhoto = nil
            }
        }
        .alert("이 서류를 지울까요?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { file in
            Button("그대로 두기", role: .cancel) { deleting = nil }
            Button("지우기", role: .destructive) { Task { await delete(file) } }
        } message: { file in
            Text("\(file.fileName) · 지우면 되돌릴 수 없어요.")
        }
    }

    private var card: some View {
        PassDocsCardChrome(count: files.count, locked: page != nil && !hasPass) {
            if page == nil {
                // 목록을 못 받았다 — 안드로이드 `서류를 불러오지 못했어요` 줄과 같은 자리·모양. 눌러 다시 받는다
                Button { Task { await load() } } label: {
                    Text("서류를 불러오지 못했어요. 다시 시도해 주세요.").wpTypography(11.5, lineHeight: 17).foregroundStyle(WPColor.danger)
                        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).padding(.top, 12).accessibilityIdentifier("documents.retry")
            } else {
                // 잠긴 칸은 설명 문단 대신 예시 타일(Android `LockedDocsPreview`, 2026-10-17 사용자 "설명보다 사진 + 레이아웃")
                if !hasPass && !expired { LockedDocsPreview().padding(.top, 12) }
                else { PassParagraph(text: description, size: 13, lineHeight: 19, color: WPColor.fgMuted).padding(.top, 12) }
                if !hasPass { lockedFoot } else { tiles }
            }
        } onOpen: { pass = true }
    }

    private var description: String {
        if hasPass { return canAdd ? "사진·PDF · 한 개 25MB 까지 · 방장·배우자만 볼 수 있어요" : "방장·배우자만 볼 수 있어요 · 서류는 수정하기에서 붙이고 지워요" }
        return "\(PassDocRules.lockedDocsNote(files.count)). 전부 내려받기는 90일 동안 됩니다."
    }

    private var lockedFoot: some View {
        // 끝난 뒤에도 받아 가는 길 — 위 문장이 약속한 것이다(안드로이드 `onDownloadAll`)
        PassDocsLockedFoot(expired: expired,
                           onDownloadAll: expired && !files.isEmpty && page?.roomId != nil ? { downloadAll = true } : nil,
                           onPass: { pass = true })
    }

    @ViewBuilder private var tiles: some View {
        // 보기만 하는 자리에 붙인 서류가 없으면 빈 줄을 그리지 않는다(위 문장이 어디서 붙이는지 말한다)
        if canAdd || !files.isEmpty || message != nil {
            FlowRow(spacing: 8, lineSpacing: 8) {
                ForEach(files, id: \.id) { file in fileTile(file) }
                if canAdd {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        ZStack {
                            if busy { ProgressView().tint(WPColor.primary).scaleEffect(0.8) }
                            else { WPMaterialPathIcon(paths: DocIcon.add, size: 20, color: WPColor.fgSubtle) }
                        }.frame(width: 52, height: 52)
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(WPColor.strokeSubtle, lineWidth: 1))
                    }.buttonStyle(DocButtonStyle()).accessibilityLabel("사진 올리기").disabled(busy)
                    Button { importing = true } label: {
                        Text("PDF").wpTypography(12, .bold).foregroundStyle(WPColor.fgSubtle).frame(width: 52, height: 52)
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(WPColor.strokeSubtle, lineWidth: 1))
                    }.buttonStyle(DocButtonStyle()).accessibilityLabel("PDF 올리기").disabled(busy)
                }
            }.padding(.top, 10)
            if let message {
                Text(message).wpTypography(11.5, lineHeight: 17).foregroundStyle(WPColor.danger)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 8)
            }
        }
    }

    /// 서류 한 장. **누르면 열고, 길게 누르면 지운다**(수정하기에서만) — 52pt 타일 위에 지우기 버튼을
    /// 두면 열려다 지우게 된다(안드로이드 `FileTile`).
    private func fileTile(_ file: PassFileItem) -> some View {
        ZStack {
            WPColor.docsTileFill
            if let image = thumbnails[file.id] { Image(uiImage: image).resizable().scaledToFill() }
            else { WPMaterialPathIcon(paths: WPIconPaths.descriptionOutlined, size: 20, color: WPColor.docsTileIcon) }
        }
        .frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { if !opening { Task { await open(file) } } }
        .onLongPressGesture { if canAdd { deleting = file } }
        .accessibilityElement().accessibilityLabel(file.fileName).accessibilityAddTraits(.isButton)
    }

    private func load() async {
        loadFailed = false
        do {
            let loaded: PassFilePage = try await env.api.send(Endpoint.scheduleFiles(scheduleId))
            if !loaded.canOpen, let room = loaded.roomId { entitlement = try? await env.api.send(Endpoint.pass(roomId: room)) }
            page = loaded
            message = nil
            thumbnails = thumbnails.filter { id, _ in loaded.list.contains { $0.id == id } }
            if loaded.canOpen {
                for file in loaded.list where PassDocRules.isPhoto(file.contentType) && thumbnails[file.id] == nil {
                    guard !Task.isCancelled else { return }
                    if let image = await PassFileUploader.thumbnail(env: env, file: file, into: cache) { thumbnails[file.id] = image }
                }
            }
        } catch {
            if page == nil { loadFailed = true } else { message = "서류를 불러오지 못했어요. 다시 시도해 주세요." }
        }
    }
    private func open(_ file: PassFileItem) async {
        guard !opening else { return }; opening = true; defer { opening = false }
        do {
            let result: PassFileUrl = try await env.api.send(Endpoint.fileURL(file.id, inline: true))
            preview = DownloadedDocument(url: try await DocumentDownload.fetch(result.url, name: file.fileName, into: cache))
        } catch { message = PassFileUploader.failureMessage(error, fallback: "파일을 열지 못했어요.") }
    }
    private func delete(_ file: PassFileItem) async {
        deleting = nil
        guard !busy else { return }; busy = true; defer { busy = false }
        do { try await env.api.sendIgnoringData(Endpoint.deleteFile(file.id)) }
        catch { message = "서류를 지우지 못했어요. 잠시 후 다시 시도해 주세요." }
        // 지우기는 실패해도 다시 받는다 — 이미 지워진 파일(404)이 목록에 남지 않게
        let failure = message
        await load()
        if failure != nil { message = failure }
    }
    private func upload(_ picked: PickedDocument) async throws {
        guard !busy else { return }; busy = true; message = nil; defer { busy = false }
        try await PassFileUploader.upload(env: env, scheduleId: scheduleId, picked)
        await load()
    }
}

// MARK: - 올리기·미리보기 공용

/// 올리기 자리를 받지 못함 — 사용자 문장과 서버 사유를 함께 든다
struct DocUploadError: LocalizedError {
    var reason: String? = nil
    var message: String
    var errorDescription: String? { message }
}

/// 고른 파일 — 사진은 앨범, PDF 는 파일 앱에서 고른다(안드로이드와 같이 둘을 나눔).
struct PickedDocument: Equatable {
    var data: Data
    var name: String
    var type: String
}

enum PassDocRules {
    static func isPhoto(_ contentType: String?) -> Bool { contentType?.hasPrefix("image/") == true }
    /// 잠긴 서류 칸의 한 줄. 개수를 함께 말한다(안드로이드 `PassPlans.lockedDocsNote`)
    static func lockedDocsNote(_ count: Int) -> String {
        count > 0 ? "서류 \(count)개 · 패스를 다시 켜면 열려요" : "패스가 있으면 계약서·영수증을 여기에 보관해요"
    }
    /// `9월 24일` — 안드로이드 `DocumentRules.dateLabel`(KST)
    static func dateLabel(_ iso: String?) -> String {
        guard let date = KstInstant.kstDate(iso) else { return "" }
        return "\(date.month)월 \(date.day)일"
    }
}

enum PassFileUploader {
    static func read(_ item: PhotosPickerItem) async throws -> PickedDocument {
        guard let raw = try await item.loadTransferable(type: Data.self), let image = UIImage(data: raw),
              let jpeg = image.jpegData(compressionQuality: 0.9) else { throw APIError.backend(message: "파일을 읽지 못했어요. 다시 선택해 주세요.") }
        return PickedDocument(data: jpeg, name: "사진-\(UUID().uuidString.prefix(8)).jpg", type: "image/jpeg")
    }
    static func read(_ url: URL) throws -> PickedDocument {
        let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard DocumentRules.validSize(size) else { throw APIError.backend(message: "파일은 0바이트보다 크고 25MB 이하여야 해요.") }
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType?.preferredMIMEType ?? "application/pdf"
        return PickedDocument(data: try Data(contentsOf: url, options: .mappedIfSafe), name: url.lastPathComponent, type: type)
    }
    static func upload(env: AppEnvironment, scheduleId: Int, _ picked: PickedDocument) async throws {
        guard DocumentRules.validSize(picked.data.count) else { throw APIError.backend(message: "파일은 0바이트보다 크고 25MB 이하여야 해요.") }
        guard DocumentRules.contentTypes.contains(picked.type) else { throw APIError.backend(message: "사진과 PDF 만 올릴 수 있어요.") }
        let slot: PassFileUpload
        do {
            slot = try await env.api.send(Endpoint.fileUpload(scheduleId: scheduleId, fileName: picked.name, contentType: picked.type, sizeBytes: picked.data.count))
        } catch { throw DocUploadError(reason: reason(error), message: slotFailure(error)) }
        do { try await SignedStorage.upload(url: slot.uploadUrl, contentType: picked.type, bytes: picked.data) }
        catch { throw APIError.backend(message: "파일 전송에 실패했어요. 다시 시도해 주세요.") }
        do { try await env.api.sendIgnoringData(Endpoint.completeFile(slot.fileId)) }
        catch { throw APIError.backend(message: "저장을 확인하지 못했어요. 다시 시도해 주세요.") }
    }
    /// 서버가 준 거절 사유(`reason`) — 새 플랜의 담아 둔 서류가 남은 것을 멈출지 정한다(`DocumentRules.stopReasons`)
    private static func reason(_ error: Error) -> String? {
        guard case let .http(_, body)? = error as? APIError, let data = body?.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object["reason"] as? String
    }
    /// 올리기 자리를 못 받았을 때 — 사유가 있으면 앱 문장, 서버 문장은 한국어이고 401·5xx 가 아닐 때만
    /// (안드로이드 `DocumentTransfer.uploadFailureMessage`).
    private static func slotFailure(_ error: Error) -> String {
        if case let .http(status, body)? = error as? APIError,
           let data = body?.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            switch object["reason"] as? String {
            case "PASS_REQUIRED": return "준비 패스가 있어야 서류를 올릴 수 있어요."
            case "UNSUPPORTED_TYPE": return "사진과 PDF 만 올릴 수 있어요."
            case "FILE_TOO_LARGE": return "파일 하나는 25MB 까지 올릴 수 있어요."
            default: break
            }
            if status != 401, status < 500, let message = object["message"] as? String, message.unicodeScalars.contains(where: { (0xAC00...0xD7A3).contains($0.value) }) { return message }
        }
        return failureMessage(error)
    }
    static func failureMessage(_ error: Error, fallback: String? = nil) -> String {
        if let fallback, case let .http(status, _)? = error as? APIError, status == 401 || status >= 500 { return fallback }
        return (error as? LocalizedError)?.errorDescription ?? fallback ?? error.localizedDescription
    }
    /// 사진 미리보기 — 목록 응답에는 주소가 없어(패스 잠금) 한 장씩 받는다.
    /// 테스트 캡처용 — 네트워크 없이 사진 미리보기를 채운다
    nonisolated(unsafe) static var previewForTests: ((PassFileItem) -> UIImage?)?
    static func thumbnail(env: AppEnvironment, file: PassFileItem, into cache: URL) async -> UIImage? {
        if let previewForTests { return previewForTests(file) }
        guard let result: PassFileUrl = try? await env.api.send(Endpoint.fileURL(file.id, inline: true)),
              let url = try? await DocumentDownload.fetch(result.url, name: "\(file.id)-" + file.fileName, into: cache) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

// MARK: - 서류 보관함 (안드로이드 `ui/documents/DocumentsScreen.kt`, 웹 `DocumentsWorkspace`)

struct StoredDocument: Identifiable, Equatable {
    var file: PassFileItem
    var schedule: ScheduleItem
    var canOpen: Bool
    var id: Int { file.id }
    var isPhoto: Bool { PassDocRules.isPhoto(file.contentType) }
    var isPDF: Bool { file.contentType == "application/pdf" }
}

@MainActor
final class DocumentsWorkspaceModel: ObservableObject {
    static let defaultRoomName = "우리의 결혼 준비"
    @Published var loading = true
    @Published var busy = false
    @Published var roomId: Int?
    @Published var roomName = DocumentsWorkspaceModel.defaultRoomName
    @Published var hasPass = false
    @Published var schedules: [ScheduleItem] = []
    @Published var files: [StoredDocument] = []
    /// 모르면 nil(플랜이 없어 파일 목록을 안 받음) — 지어낸 "1 GB" 를 그리지 않는다
    @Published var usedBytes: Int?
    @Published var quotaBytes: Int?
    @Published var error: String?
    @Published var message: String?
    @Published var previews: [Int: UIImage] = [:]
    @Published var givenUp: Set<Int> = []
    @Published var dialogError: String?
    @Published var uploadClosed = false
    @Published var deleteClosed = false
    @Published var opened: DownloadedDocument?
    private let cache = FileManager.default.temporaryDirectory.appendingPathComponent("documents-" + UUID().uuidString)
    private var previewing: Set<Int> = []

    private struct RoomName: Decodable { var name: String?; var onwerName: String? }
    private struct Failure: LocalizedError { let errorDescription: String? }

    func refresh(env: AppEnvironment, requestedRoom: Int?, showSkeleton: Bool = false) async {
        loading = showSkeleton || roomId == nil
        error = nil
        do {
            /*
              방이 없는 것은 오류가 아니다(혼자 쓰는 사람은 결제·초대 전까지 방이 없다). 빈 보관함으로 그린다 —
              패스가 없으니 잠금 안내가 함께 뜬다(안드로이드 DocumentsViewModel).
            */
            guard let room = requestedRoom ?? roomId else {
                roomId = nil; roomName = Self.defaultRoomName; hasPass = false; schedules = []; files = []
                usedBytes = nil; quotaBytes = nil; previews = [:]; loading = false
                return
            }
            let info: RoomName
            do { info = try await env.api.send(Endpoint.room(shareCode: String(room))) }
            catch { throw Failure(errorDescription: "서류가 연결된 플랜을 확인하지 못했어요.") }
            var pages = SchedulePages(), number = 1, all: [ScheduleItem] = []
            do {
                while number <= 100 {
                    let result: SchedulePage = try await env.api.send(Endpoint.allSchedules(roomId: room, page: number))
                    if try pages.append(result) { break }
                    number += 1
                }
                all = pages.result
            } catch { throw Failure(errorDescription: "플랜을 불러오지 못했어요. 다시 시도해 주세요.") }
            // 패스 조회 하나 실패로 보관함 전체를 오류로 만들지 않는다 — 잠긴 것으로 두고 목록을 그린다
            let pass: PassState? = try? await env.api.send(Endpoint.pass(roomId: room))
            var loaded: [(ScheduleItem, PassFilePage)] = []
            do {
                for chunk in stride(from: 0, to: all.count, by: 4).map({ Array(all[$0..<min($0 + 4, all.count)]) }) {
                    try await withThrowingTaskGroup(of: (Int, PassFilePage).self) { group in
                        for schedule in chunk {
                            group.addTask { (schedule.id, try await env.api.send(Endpoint.scheduleFiles(schedule.id))) }
                        }
                        var byId: [Int: PassFilePage] = [:]
                        for try await (id, page) in group { byId[id] = page }
                        for schedule in chunk { if let page = byId[schedule.id] { loaded.append((schedule, page)) } }
                    }
                }
            } catch { throw Failure(errorDescription: "일부 서류를 불러오지 못했어요. 다시 시도해 주세요.") }
            let previousRoom = roomId, previousPass = hasPass
            let stored = loaded.flatMap { schedule, page in page.list.map { StoredDocument(file: $0, schedule: schedule, canOpen: page.canOpen) } }
            roomId = room
            let name = info.name?.trimmingCharacters(in: .whitespaces) ?? ""
            let owner = info.onwerName?.trimmingCharacters(in: .whitespaces) ?? ""
            roomName = !name.isEmpty ? name : !owner.isEmpty ? owner : Self.defaultRoomName
            hasPass = pass.map { $0.hasPass && !$0.expired } ?? (previousRoom == room ? previousPass : false)
            schedules = all
            files = stored
            previews = previews.filter { id, _ in stored.contains { $0.id == id } }
            givenUp = []
            usedBytes = loaded.map(\.1.usedBytes).max()
            quotaBytes = loaded.first?.1.quotaBytes
            loading = false
        } catch {
            loading = false
            self.error = (error as? LocalizedError)?.errorDescription ?? "서류를 불러오지 못했어요."
        }
    }

    func requestPreview(env: AppEnvironment, _ document: StoredDocument) {
        guard hasPass, document.canOpen, document.isPhoto, previews[document.id] == nil,
              !givenUp.contains(document.id), !previewing.contains(document.id) else { return }
        previewing.insert(document.id)
        Task {
            let image = await PassFileUploader.thumbnail(env: env, file: document.file, into: cache)
            previewing.remove(document.id)
            if let image { previews[document.id] = image } else { givenUp.insert(document.id) }
        }
    }

    func upload(env: AppEnvironment, scheduleId: Int, file: PickedDocument, requestedRoom: Int?) async {
        guard !busy else { return }
        guard hasPass else { dialogError = "준비 패스가 있어야 서류를 올릴 수 있어요."; return }
        guard schedules.contains(where: { $0.id == scheduleId }) else { dialogError = "연결할 플랜을 먼저 선택해 주세요."; return }
        busy = true; message = nil; dialogError = nil
        defer { busy = false }
        do {
            try await PassFileUploader.upload(env: env, scheduleId: scheduleId, file)
            message = "플랜에 연결해 보관했어요."; uploadClosed = true
            await refresh(env: env, requestedRoom: requestedRoom, showSkeleton: true)
        } catch { dialogError = PassFileUploader.failureMessage(error) }
    }

    func delete(env: AppEnvironment, _ document: StoredDocument, requestedRoom: Int?) async {
        guard !busy else { return }
        busy = true; message = nil; dialogError = nil
        defer { busy = false }
        do {
            try await env.api.sendIgnoringData(Endpoint.deleteFile(document.id))
            message = "서류를 삭제했어요."; deleteClosed = true
            await refresh(env: env, requestedRoom: requestedRoom, showSkeleton: true)
        } catch { dialogError = "서류를 삭제하지 못했어요. 다시 시도해 주세요." }
    }

    func open(env: AppEnvironment, _ document: StoredDocument) async {
        guard !busy else { return }
        busy = true; dialogError = nil
        defer { busy = false }
        do {
            let result: PassFileUrl = try await env.api.send(Endpoint.fileURL(document.id, inline: true))
            opened = DownloadedDocument(url: try await DocumentDownload.fetch(result.url, name: document.file.fileName, into: cache))
        } catch {
            if case let .http(_, body)? = error as? APIError, body?.contains("PASS_REQUIRED") == true { dialogError = "준비 패스 이용 시 열 수 있어요." }
            else { dialogError = PassFileUploader.failureMessage(error, fallback: "파일을 열지 못했어요.") }
        }
    }
}

/// 웹 `DocumentView` — 전체 서류 / 플랜별 보관함 / 보관 현황
enum DocumentWorkspaceTab: String, CaseIterable { case library = "전체 서류", plans = "플랜별 보관함", overview = "보관 현황" }
private enum DocKind: String, CaseIterable { case all = "전체", pdf = "PDF", image = "사진" }
private enum DocSort: String, CaseIterable { case recent = "최근 등록순", size = "용량 큰 순" }

private struct FolderGroup: Identifiable {
    var id: Int
    var title: String
    var categoryName: String
    var files: [StoredDocument]
    var tone: UInt32
    var sizeBytes: Int { files.reduce(0) { $0 + $1.file.sizeBytes } }
}

/// 서류 보관함 화면 — 머리(빵부스러기·제목·서류 올리기)는 고정이고 아래만 구른다.
/// 앱의 C안(분홍 머리 면) 대신 웹이 따로 디자인한 이 화면의 모양을 그대로 따른다(안드로이드와 같음).
struct DocumentsWorkspaceView: View {
    var roomId: Int?
    var initialTab: DocumentWorkspaceTab = .library
    /// 캡처용 — 처음부터 열어 둘 서류 상세(안드로이드 `InspectorDialog` 캡처와 같은 상태)
    var initialSelectedId: Int?
    var initialConfirmDelete = false
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = DocumentsWorkspaceModel()
    @State private var tab: DocumentWorkspaceTab = .library
    @State private var query = ""
    @State private var kind: DocKind = .all
    @State private var sort: DocSort = .recent
    @State private var folder: Int?
    @State private var selectedId: Int?
    @State private var uploadOpen = false
    @State private var downloadAll = false
    @State private var started = false

    private var groups: [FolderGroup] {
        model.schedules.enumerated().map { index, schedule in
            FolderGroup(id: schedule.id, title: schedule.title, categoryName: schedule.categoryName,
                        files: model.files.filter { $0.schedule.id == schedule.id }, tone: WPColor.docsFolderTones[index % WPColor.docsFolderTones.count])
        }
    }
    private var visible: [StoredDocument] {
        let q = query.lowercased()
        let filtered = model.files.filter { d in
            (folder == nil || d.schedule.id == folder) && {
                switch kind { case .all: return true; case .pdf: return d.isPDF; case .image: return d.isPhoto }
            }() && (q.isEmpty || "\(d.file.fileName) \(d.schedule.title) \(d.schedule.categoryName)".lowercased().contains(q))
        }
        return sort == .size ? filtered.sorted { $0.file.sizeBytes > $1.file.sizeBytes } : filtered.sorted { ($0.file.createdAt ?? "") > ($1.file.createdAt ?? "") }
    }
    private var remaining: Int? { model.usedBytes.flatMap { used in model.quotaBytes.map { max(0, $0 - used) } } }
    private var percent: Double {
        guard let used = model.usedBytes, let quota = model.quotaBytes, quota > 0 else { return 0 }
        return min(100, max(0, Double(used) / Double(quota) * 100))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            WPColor.docsPage.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView { content.padding(.horizontal, 16).padding(.top, 19).padding(.bottom, 24) }
                    .scrollDismissesKeyboard(.interactively)
            }
            if let message = model.message { toast(message).padding(16) }
            if let document = model.files.first(where: { $0.id == selectedId }) { inspector(document) }
            if uploadOpen { UploadDocumentDialog(groups: groups.map { ($0.id, "\($0.title) · \($0.categoryName)") }, initialFolder: folder,
                                                  busy: model.busy, error: model.dialogError,
                                                  onUpload: { id, file in Task { await model.upload(env: env, scheduleId: id, file: file, requestedRoom: roomId) } },
                                                  onError: { model.dialogError = $0 },
                                                  onDismiss: { if !model.busy { uploadOpen = false } }) }
        }
        .task {
            guard !started else { return }; started = true; tab = initialTab
            await model.refresh(env: env, requestedRoom: roomId)
            selectedId = initialSelectedId
        }
        .onChange(of: model.uploadClosed) { _, closed in if closed { uploadOpen = false; model.uploadClosed = false } }
        .onChange(of: model.deleteClosed) { _, closed in if closed { selectedId = nil; model.deleteClosed = false } }
        .sheet(item: $model.opened) { DocumentPreview(url: $0.url) }
        .sheet(isPresented: $downloadAll) { if let room = model.roomId { PassDownloadView(roomId: room) } }
        .accessibilityIdentifier("documents.workspace")
    }

    // MARK: 머리

    private var header: some View {
        let canUpload = model.hasPass && !model.loading && model.error == nil && !model.schedules.isEmpty
        return VStack(alignment: .leading, spacing: 0) {
            Button { dismiss() } label: {
                HStack(spacing: 7) {
                    WPLucideIcon(paths: DocIcon.arrowLeft, size: 13, color: WPColor.docsCrumb)
                    docText("우리 플랜", 11, WPColor.docsCrumb)
                    WPLucideIcon(paths: DocIcon.chevronRight, size: 11, color: WPColor.docsCrumb)
                    docText("서류 보관함", 11, WPColor.docsCrumb)
                }.padding(.vertical, 2).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("우리 플랜으로").accessibilityIdentifier("documents.back")
            FlowRow(spacing: 8, lineSpacing: 8, verticalAlignment: .center) {
                docText("둘이 모은, 소중한 기록.", 23, WPColor.docsInk, bold: true, tracking: -1)
                HStack(spacing: 4) {
                    WPLucideIcon(paths: DocIcon.flower2, size: 12, color: WPColor.docsBadgeText)
                    docText("준비 패스", 8, WPColor.docsBadgeText, bold: true)
                }.padding(.horizontal, 7).padding(.vertical, 5).background(WPColor.docsBadgeBg, in: RoundedRectangle(cornerRadius: 20))
            }.padding(.top, 13)
            docText("계약서부터 영수증까지, 연결된 플랜과 함께 보관해요.", 10, WPColor.docsLead).padding(.top, 8)
            Button { model.dialogError = nil; uploadOpen = true } label: {
                HStack(spacing: 6) {
                    WPLucideIcon(paths: DocIcon.plus, size: 17, color: .white)
                    docText("서류 올리기", 11, .white, bold: true)
                }.padding(.horizontal, 13).padding(.vertical, 10)
                    .background(DocsCSSGradient(angle: 110, colors: [WPColor.docsUploadStart, WPColor.docsUploadEnd]).clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous)))
                    .shadow(color: WPColor.primary.opacity(canUpload ? 0.3 : 0), radius: 6, y: 3)
                    .opacity(canUpload ? 1 : 0.45)
            }.buttonStyle(DocButtonStyle()).disabled(!canUpload).padding(.top, 16).accessibilityIdentifier("documents.upload")
        }
        .padding(.horizontal, 17).padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Rectangle().fill(WPColor.docsHeaderLine).frame(height: 1) }
    }

    // MARK: 본문

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            contextRow
            viewTabs
            if model.loading {
                VStack(spacing: 12) {
                    SkeletonBox(height: 150, corner: 17)
                    SkeletonBox(height: 86, corner: 15)
                    Spacer().frame(height: 8)
                    SkeletonBox(height: 220, corner: 17)
                }
            } else if let error = model.error {
                VStack(spacing: 14) {
                    docText(error, 14, WPColor.docsInk, bold: true).multilineTextAlignment(.center)
                    Button { Task { await model.refresh(env: env, requestedRoom: roomId) } } label: {
                        Text("다시 불러오기").underline().foregroundColor(WPColor.docsRetry).wpTypography(12, face: .kakao).padding(4)
                    }.buttonStyle(.plain).accessibilityIdentifier("documents.reload")
                }.frame(maxWidth: .infinity).padding(.horizontal, 20).padding(.vertical, 50)
            } else {
                if !model.hasPass { lockedNote }
                switch tab {
                case .library:
                    VStack(spacing: 12) { storageCard; statsCard }.padding(.bottom, 20)
                case .plans:
                    folderIntro
                    folderGrid
                case .overview:
                    VStack(spacing: 15) { capacityCard; breakdownCard }.padding(.bottom, 26)
                }
                listCard
                bottomNote
            }
        }
    }

    private var contextRow: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle().fill(.white)
                Circle().fill(WPColor.docsAvatarBg).padding(2)
                WPMaterialPathIcon(paths: [DocIcon.heart], size: 10, color: WPColor.docsAvatarHeart)
                    .overlay(WPLucideIcon(paths: [DocIcon.heart], size: 10, color: WPColor.docsAvatarHeart))
            }.frame(width: 25, height: 25)
            HStack(spacing: 0) {
                docText(model.roomName, 10, WPColor.docsContextStrong, bold: true)
                Spacer().frame(width: 7)
                docText("의 서류 보관함", 10, WPColor.docsContext)
            }
        }.padding(.bottom, 18)
    }

    private var viewTabs: some View {
        HStack(alignment: .bottom, spacing: 22) {
            ForEach(DocumentWorkspaceTab.allCases, id: \.self) { item in
                let active = item == tab
                Button { tab = item; folder = nil } label: {
                    docText(item.rawValue, 11, active ? WPColor.docsTabActive : WPColor.docsTab, bold: active)
                        .padding(.horizontal, 2).padding(.bottom, 13)
                        .overlay(alignment: .bottom) { if active { Rectangle().fill(WPColor.docsTabUnderline).frame(height: 2) } }
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("documents.tab.\(item.rawValue)")
            }
            Spacer(minLength: 0)
        }
        .overlay(alignment: .bottom) { Rectangle().fill(WPColor.docsLine).frame(height: 1) }
        .padding(.bottom, 20)
    }

    private var lockedNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            docText("현재 준비 패스가 비활성 상태예요. 보관된 서류의 목록과 연결된 플랜을 확인할 수 있어요.", 12, WPColor.docsLocked)
                .fixedSize(horizontal: false, vertical: true)
            if !model.files.isEmpty, model.roomId != nil {
                // 웹 잠금 안내 안의 "전부 내려받기" — 패스가 끝나도 보관 기간 안에는 받아 간다
                Button { downloadAll = true } label: {
                    docText("전부 내려받기", 12.5, WPColor.docsLocked, bold: true).padding(.horizontal, 14).padding(.vertical, 8).background(.white, in: Capsule())
                }.buttonStyle(.plain)
            }
        }.padding(13).frame(maxWidth: .infinity, alignment: .leading)
            .background(WPColor.docsLockedBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.bottom, 20)
    }

    // MARK: 전체 서류

    private var storageCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                overline(DocIcon.cloud, "두 사람이 함께 쓰는 공간")
                if let remaining {
                    docText(DocumentRules.formatStorage(remaining), 23, WPColor.docsStorageTitle, bold: true, tracking: -0.9).padding(.top, 13)
                    docText("더 담을 수 있어요", 11, WPColor.docsStorageTitle).padding(.top, 4)
                } else {
                    docText("소중한 기록을 한곳에", 23, WPColor.docsStorageTitle, bold: true, tracking: -0.9).padding(.top, 13)
                }
                docText(model.usedBytes != nil && model.quotaBytes != nil
                        ? "\(DocumentRules.formatStorage(model.usedBytes)) 사용 / 전체 \(DocumentRules.formatStorage(model.quotaBytes))"
                        : "플랜에 첫 서류를 연결해 보세요.", 10, WPColor.docsStorageSub).padding(.top, 7)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(WPColor.docsTrack)
                        if percent > 0 {
                            DocsCSSGradient(angle: 90, colors: [WPColor.docsTrackStart, WPColor.docsTrackEnd])
                                .frame(width: g.size.width * percent / 100).clipShape(Capsule())
                        }
                    }
                }.frame(height: 6).padding(.top, 19)
                docText(model.quotaBytes != nil ? "\(Int(percent.rounded()))% 사용 중" : "용량 정보는 서류 조회 후 표시돼요", 8, WPColor.docsStorageFoot).padding(.top, 10)
            }.frame(maxWidth: .infinity, alignment: .leading)
            // 웹 storageArt — 기울인 열린 폴더 + 확인 표시
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    WPSVGPath(DocIcon.folderOpen).fill(WPColor.docsArtFill)
                    WPSVGPath(DocIcon.folderOpen).stroke(WPColor.docsArtStroke, style: StrokeStyle(lineWidth: 55.0 / 24, lineCap: .round, lineJoin: .round))
                }.frame(width: 55, height: 55)
                WPLucideIcon(paths: DocIcon.check, size: 12, color: WPColor.docsArtCheck)
                    .padding(3).background(.white, in: Circle()).padding(3).background(WPColor.docsArtCheckRing, in: Circle())
                    .offset(x: 3)
            }.rotationEffect(.degrees(-7))
        }
        .padding(19)
        .background(DocsCSSGradient(angle: 115, colors: [WPColor.docsStorageStart, WPColor.docsStorageEnd]).clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous)))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).strokeBorder(WPColor.docsStorageStroke, lineWidth: 1))
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            stat(DocIcon.fileText, model.files.count, "보관 중인 서류")
            Rectangle().fill(WPColor.docsStatsDivider).frame(width: 1, height: 46)
            stat(DocIcon.link2, groups.filter { !$0.files.isEmpty }.count, "서류가 연결된 플랜")
        }
        .padding(.horizontal, 10).padding(.vertical, 16)
        .background(.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(WPColor.docsLine, lineWidth: 1))
    }

    private func stat(_ icon: [String], _ value: Int, _ label: String) -> some View {
        VStack(spacing: 7) {
            HStack(alignment: .center, spacing: 7) {
                WPLucideIcon(paths: icon, size: 16, color: WPColor.docsStatsIcon)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(verbatim: "\(value)").tracking(-1).foregroundColor(WPColor.docsInk).wpTypography(23, .bold, face: .kakao, lineHeight: 27.6)
                    docText("개", 11, WPColor.docsStatsUnit)
                }
            }
            docText(label, 9, WPColor.docsStatsLabel)
        }.frame(maxWidth: .infinity)
    }

    // MARK: 플랜별 보관함

    private var folderIntro: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                docText("플랜을 열면, 서류도 함께.", 21, WPColor.docsInk, bold: true, tracking: -0.8)
                docText("어느 일정의 기록인지 헤매지 않도록 플랜별로 모았어요.", 11, WPColor.docsFolderIntroSub, lineHeight: 19.8)
            }
            HStack(spacing: 8) {
                WPLucideIcon(paths: DocIcon.hardDrive, size: 17, color: WPColor.docsQuotaText)
                docText(DocumentRules.formatStorage(remaining), 10, WPColor.docsQuotaText, bold: true)
                docText(remaining == nil ? "용량 정보 없음" : "남음", 10, WPColor.docsQuotaText)
            }.padding(.horizontal, 13).padding(.vertical, 10)
                .background(WPColor.docsQuotaBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(WPColor.docsQuotaStroke, lineWidth: 1))
        }.padding(.bottom, 21)
    }

    private var folderGrid: some View {
        let all = groups
        return VStack(spacing: 11) {
            ForEach(Array(stride(from: 0, to: all.count, by: 2)), id: \.self) { start in
                HStack(spacing: 11) {
                    folderCard(all[start])
                    if start + 1 < all.count { folderCard(all[start + 1]) } else { Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
                }
            }
        }.padding(.bottom, 20)
    }

    private func folderCard(_ group: FolderGroup) -> some View {
        // 웹 color-mix: 테두리 = 색 80% + 흰색, 바탕 = 색 35% + 흰색 → 흰색, 아이콘 선 = 색 75% + 짙은 자주
        let color = Color(hex: group.tone)
        let stroke = WPColor.docsMix(group.tone, 0xFFFFFF, 0.2)
        let tint = WPColor.docsMix(group.tone, 0xFFFFFF, 0.65)
        let line = WPColor.docsMix(group.tone, 0x65404D, 0.25)
        let selected = folder == group.id
        return Button { folder = selected ? nil : group.id } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    ZStack {
                        WPSVGPath(DocIcon.folder).fill(color)
                        WPSVGPath(DocIcon.folder).stroke(line, style: StrokeStyle(lineWidth: 1.2 * 33 / 24, lineCap: .round, lineJoin: .round))
                    }.frame(width: 33, height: 33)
                    Spacer(minLength: 0)
                    WPLucideIcon(paths: DocIcon.arrowUpRight, size: 16, color: line)
                }.padding(.bottom, 14)
                docText(group.categoryName, 9, WPColor.docsFolderCategory, lines: 1).padding(.top, 8)
                docText(group.title, 12, WPColor.docsInk, bold: true, lines: 1).padding(.top, 8)
                HStack {
                    docText("서류 \(group.files.count)개", 8, WPColor.docsFolderMeta)
                    Spacer(minLength: 0)
                    docText(DocumentRules.formatStorage(group.sizeBytes), 8, WPColor.docsFolderMeta)
                }.padding(.top, 18)
                RoundedRectangle(cornerRadius: 3).fill(color).frame(height: 3).padding(.top, 10)
            }
            .padding(.horizontal, 13).padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DocsCSSGradient(angle: 135, colors: [tint, .white]).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(stroke, lineWidth: 1))
            // 웹 outline(2px, offset 3px) — 자리를 차지하지 않게 카드 바깥에
            .overlay { if selected { RoundedRectangle(cornerRadius: 17, style: .continuous).strokeBorder(WPColor.docsFolderSelected, lineWidth: 2).padding(-5) } }
            .contentShape(Rectangle())
        }.buttonStyle(.plain).frame(maxWidth: .infinity)
    }

    // MARK: 보관 현황

    private var capacityCard: some View {
        VStack(spacing: 0) {
            overline(DocIcon.hardDrive, "우리의 저장 공간")
            ZStack {
                Circle().fill(WPColor.docsRingTrack)
                if percent > 0 { DocsPie(fraction: percent / 100).fill(WPColor.docsRing) }
                Circle().fill(WPColor.docsRingInner).frame(width: 102, height: 102)
                VStack(spacing: 5) {
                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                        Text(verbatim: model.quotaBytes == nil ? "—" : "\(Int(percent.rounded()))").tracking(-1).foregroundColor(WPColor.docsRingValue)
                            .wpTypography(35, .bold, face: .kakao, lineHeight: 42)
                        if model.quotaBytes != nil { docText("%", 16, WPColor.docsRingValue, bold: true) }
                    }
                    docText(model.quotaBytes == nil ? "정보 없음" : "사용 중", 10, WPColor.docsRingLabel)
                }
            }.frame(width: 126, height: 126).padding(.top, 18)
            docText(remaining.map { "\(DocumentRules.formatStorage($0)) 남았어요" } ?? "아직 용량 정보가 없어요", 19, WPColor.docsCapacityTitle, bold: true).padding(.top, 18)
            docText(model.quotaBytes == nil ? "플랜에 첫 서류를 연결해 보세요." : "전체 \(DocumentRules.formatStorage(model.quotaBytes)) 중 \(DocumentRules.formatStorage(model.usedBytes)) 사용", 10, WPColor.docsCapacitySub).padding(.top, 8)
            Button {
                sort = .size; tab = .library; query = ""; kind = .all; folder = nil
            } label: {
                HStack(spacing: 6) {
                    docText("큰 파일부터 정리하기", 11, WPColor.docsCapacityButton)
                    WPLucideIcon(paths: DocIcon.arrowUpRight, size: 14, color: WPColor.docsCapacityButton)
                }.padding(12).frame(maxWidth: 250)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(WPColor.docsCapacityButtonStroke, lineWidth: 1))
            }.buttonStyle(.plain).padding(.top, 20)
        }
        .padding(21).frame(maxWidth: .infinity)
        .background(DocsCSSGradient(angle: 150, colors: [WPColor.docsQuotaBg, WPColor.docsCapacityEnd]).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(WPColor.docsQuotaStroke, lineWidth: 1))
    }

    private var breakdownCard: some View {
        let linked = groups.filter { !$0.files.isEmpty }
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                docText("어느 플랜에 담았을까요?", 14, WPColor.docsInk, bold: true)
                Spacer(minLength: 8)
                docText("\(linked.count)개 플랜", 11, WPColor.docsSectionAside)
            }.padding(.horizontal, 15).padding(.vertical, 18)
            ForEach(linked) { group in
                Button { tab = .plans; folder = group.id } label: {
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3).fill(Color(hex: group.tone)).frame(width: 7, height: 7)
                            docText(group.title, 12, WPColor.docsInk, lines: 1)
                            Spacer(minLength: 0)
                            docText("\(group.files.count)개 · \(DocumentRules.formatStorage(group.sizeBytes))", 10, WPColor.docsBreakdownSub)
                        }
                        GeometryReader { g in
                            let used = model.usedBytes ?? 0
                            let share = used > 0 ? min(1, max(0, Double(group.sizeBytes) / Double(used))) : 0
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 5).fill(WPColor.docsUsageTrack)
                                if share > 0 { RoundedRectangle(cornerRadius: 5).fill(Color(hex: group.tone)).frame(width: g.size.width * share) }
                            }
                        }.frame(height: 5)
                    }.padding(.horizontal, 17).padding(.vertical, 11).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            HStack(spacing: 11) {
                WPLucideIcon(paths: DocIcon.shieldCheck, size: 20, color: WPColor.docsKeep)
                VStack(alignment: .leading, spacing: 5) {
                    docText("기록도, 둘만의 공간에.", 11, WPColor.docsKeep)
                    docText("연결된 플랜의 방장과 배우자만 서류를 볼 수 있어요.", 9, WPColor.docsKeepSub, lineHeight: 14.4)
                }
                Spacer(minLength: 0)
            }.padding(14).background(WPColor.docsKeepBg, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .padding(.horizontal, 17).padding(.top, 16)
        }
        .padding(.bottom, 16)
        .background(.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).strokeBorder(WPColor.docsLine, lineWidth: 1))
    }

    // MARK: 목록

    private var listCard: some View {
        let shown = tab == .overview ? Array(visible.prefix(4)) : visible
        let title = tab == .overview ? "최근 보관한 기록" : folder.flatMap { id in groups.first { $0.id == id }?.title } ?? "보관한 서류"
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    docText(title, 14, WPColor.docsInk, bold: true, lines: 1)
                    Text(verbatim: "\(shown.count)").foregroundColor(WPColor.docsSectionCount).wpTypography(12, face: .kakao)
                }
                Spacer(minLength: 8)
                if folder != nil {
                    Button { folder = nil } label: { docText("전체 플랜 보기", 11, WPColor.docsSectionAction).padding(4) }.buttonStyle(.plain)
                }
                if tab == .overview {
                    Button { tab = .library } label: {
                        HStack(spacing: 4) {
                            docText("전체 서류 보기", 11, WPColor.docsSectionAction)
                            WPLucideIcon(paths: DocIcon.chevronRight, size: 13, color: WPColor.docsSectionAction)
                        }.padding(4)
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 15).padding(.vertical, 18)
            if tab != .overview { filters.padding(.horizontal, 14).padding(.bottom, 16) }
            if shown.isEmpty {
                VStack(spacing: 14) {
                    WPLucideIcon(paths: [DocIcon.folderOpen], size: 24, color: WPColor.docsEmptyIcon)
                    docText(model.files.isEmpty ? "첫 번째 서류를 보관해 보세요" : "조건에 맞는 서류가 없어요", 14, WPColor.docsInk, bold: true).multilineTextAlignment(.center)
                    docText(model.files.isEmpty ? "어느 플랜의 계약서·영수증인지 함께 기억해 드릴게요." : "파일 이름이나 연결된 플랜 이름으로 다시 찾아보세요.", 11, WPColor.docsEmptySub)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity).padding(.horizontal, 20).padding(.vertical, 50)
            } else {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, document in
                    fileRow(document)
                    if index < shown.count - 1 { Rectangle().fill(WPColor.docsRowLine).frame(height: 1) }
                }
            }
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).strokeBorder(WPColor.docsLine, lineWidth: 1))
    }

    private var filters: some View {
        VStack(spacing: 9) {
            HStack(spacing: 9) {
                WPLucideIcon(paths: DocIcon.search, size: 16, color: WPColor.docsSearchIcon)
                TextField("", text: $query, prompt: Text("서류 이름 또는 연결된 플랜 검색").foregroundColor(WPColor.docsSearchHint))
                    .font(Font(WPTypeface.kakao.uiFont(11, .regular))).foregroundStyle(WPColor.docsSearchText).tint(WPColor.docsTabActive)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("documents.search")
            }.padding(.horizontal, 12).padding(.vertical, 10)
                .background(WPColor.docsSearchBg, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(WPColor.docsSearchStroke, lineWidth: 1))
            HStack(spacing: 4) {
                ForEach(DocKind.allCases, id: \.self) { item in
                    let active = item == kind
                    Button { kind = item } label: {
                        docText(item.rawValue, 10, active ? WPColor.docsKindActive : WPColor.docsKind)
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(active ? WPColor.docsKindActiveBg : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }.buttonStyle(.plain)
                }
                Spacer(minLength: 0)
                Menu {
                    ForEach(DocSort.allCases, id: \.self) { item in Button(item.rawValue) { sort = item } }
                } label: {
                    HStack(spacing: 4) {
                        docText(sort.rawValue, 10, WPColor.docsSort)
                        WPLucideIcon(paths: DocIcon.chevronDown, size: 13, color: WPColor.docsSort)
                    }.padding(.vertical, 7).padding(.horizontal, 2)
                }.accessibilityLabel("정렬")
            }
        }
    }

    private func fileRow(_ document: StoredDocument) -> some View {
        Button { model.dialogError = nil; selectedId = document.id } label: {
            HStack(spacing: 8) {
                HStack(spacing: 9) {
                    fileIcon(document, width: 31, height: 37, iconSize: 17)
                    VStack(alignment: .leading, spacing: 5) {
                        docText(document.file.fileName, 11, WPColor.docsInk, lines: 1)
                        docText("\(document.isPDF ? "PDF 문서" : "사진") · \(document.schedule.title)", 8, WPColor.docsFileSub, lines: 1)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                docText(DocumentRules.formatStorage(document.file.sizeBytes), 9, WPColor.docsSize)
                WPLucideIcon(paths: DocIcon.chevronRight, size: 14, color: WPColor.docsRowChevron)
            }.padding(.horizontal, 13).padding(.vertical, 15).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .onAppear { model.requestPreview(env: env, document) }
            .accessibilityIdentifier("documents.file.\(document.id)")
    }

    private func fileIcon(_ document: StoredDocument, width: CGFloat, height: CGFloat, iconSize: CGFloat, white: Bool = false, usePreview: Bool = true) -> some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        return Group {
            if usePreview, document.isPhoto, let image = model.previews[document.id] {
                Image(uiImage: image).resizable().scaledToFill().frame(width: width, height: height).background(.white).clipShape(shape)
                    .overlay(shape.strokeBorder(WPColor.docsPreviewStroke, lineWidth: 1))
            } else {
                WPLucideIcon(paths: document.isPhoto ? DocIcon.image : DocIcon.fileText, size: iconSize, color: document.isPhoto ? WPColor.docsPhotoIcon : WPColor.docsPdfIcon)
                    .frame(width: width, height: height)
                    .background(white ? .white : document.isPhoto ? WPColor.docsPhotoBg : WPColor.docsPdfBg, in: shape)
                    .overlay(shape.strokeBorder(document.isPhoto ? WPColor.docsPhotoStroke : WPColor.docsPdfStroke, lineWidth: 1))
            }
        }
    }

    private var bottomNote: some View {
        HStack(alignment: .top, spacing: 6) {
            WPLucideIcon(paths: DocIcon.link2, size: 13, color: WPColor.docsNote).padding(.top, 3)
            docText("서류는 등록할 때 선택한 플랜에 연결돼요. 플랜 상세에서도 같은 서류를 볼 수 있어요.", 9, WPColor.docsNote, lineHeight: 16.2)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(.horizontal, 3).padding(.top, 19)
    }

    private func toast(_ message: String) -> some View {
        HStack(spacing: 10) {
            docText(message, 12, .white)
            Button { model.message = nil } label: {
                WPLucideIcon(paths: DocIcon.x, size: 14, color: .white).padding(6).contentShape(Circle())
            }.buttonStyle(.plain).accessibilityLabel("안내 닫기")
        }.padding(.leading, 17).padding(.trailing, 10).padding(.vertical, 8)
            .background(WPColor.docsToastBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: 서류 상세

    private func inspector(_ document: StoredDocument) -> some View {
        DocDialog(onDismiss: { if !model.busy { selectedId = nil } }) {
            InspectorBody(document: document, roomName: model.roomName, preview: model.previews[document.id],
                          givenUp: model.givenUp.contains(document.id), hasPass: model.hasPass, busy: model.busy, error: model.dialogError,
                          initialConfirm: initialConfirmDelete,
                          icon: { fileIcon(document, width: 48, height: 57, iconSize: 17, white: true, usePreview: false) },
                          onClose: { if !model.busy { selectedId = nil } },
                          onOpen: { Task { await model.open(env: env, document) } },
                          onDelete: { Task { await model.delete(env: env, document, requestedRoom: roomId) } })
                .onAppear { model.requestPreview(env: env, document) }
        }
    }

    private func overline(_ icon: [String], _ text: String) -> some View {
        HStack(spacing: 6) {
            WPLucideIcon(paths: icon, size: 14, color: WPColor.docsOverline)
            docText(text, 9, WPColor.docsOverline)
        }
    }
}

private struct InspectorBody<Icon: View>: View {
    let document: StoredDocument
    let roomName: String
    let preview: UIImage?
    let givenUp: Bool
    let hasPass: Bool
    let busy: Bool
    let error: String?
    var initialConfirm = false
    @ViewBuilder let icon: () -> Icon
    let onClose: () -> Void
    let onOpen: () -> Void
    let onDelete: () -> Void
    @State private var confirmDelete = false
    @State private var started = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DocDialogHeader(label: "서류 상세", closeLabel: "서류 상세 닫기", enabled: !busy, onClose: onClose)
            if document.isPhoto, let preview {
                Image(uiImage: preview).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(10).frame(maxWidth: .infinity, minHeight: 130)
                    .background(DocsStripes().clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(WPColor.docsPreviewBoxStroke, lineWidth: 1))
            } else {
                VStack(spacing: 12) {
                    icon()
                    Text(caption).tracking(2).foregroundColor(WPColor.docsPreviewCaption).wpTypography(8, face: .kakao)
                }.frame(maxWidth: .infinity).frame(height: 130)
                    .background(DocsStripes().clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(WPColor.docsPreviewBoxStroke, lineWidth: 1))
            }
            docText(document.file.fileName, 21, WPColor.docsDialogInk, bold: true, tracking: -0.5).fixedSize(horizontal: false, vertical: true).padding(.top, 22)
            docText("\(DocumentRules.formatStorage(document.file.sizeBytes)) · \(PassDocRules.dateLabel(document.file.createdAt)) 보관", 11, WPColor.docsFileMeta, lineHeight: 19.8).padding(.top, 9)
            VStack(alignment: .leading, spacing: 0) {
                docText("이 서류가 연결된 플랜", 10, WPColor.docsLinkedLabel, lineHeight: 24)
                HStack(spacing: 0) {
                    WPLucideIcon(paths: DocIcon.link2, size: 17, color: WPColor.docsDialogInk)
                    Spacer().frame(width: 7)
                    docText(document.schedule.title, 14, WPColor.docsDialogInk, bold: true, lines: 1).frame(maxWidth: .infinity, alignment: .leading)
                    WPLucideIcon(paths: DocIcon.arrowUpRight, size: 16, color: WPColor.docsDialogInk)
                }.padding(.top, 12).padding(.bottom, 8)
                docText("\(document.schedule.categoryName) · \(roomName)", 10, WPColor.docsLinkedSub, lineHeight: 24)
            }.padding(17).frame(maxWidth: .infinity, alignment: .leading)
                .background(WPColor.docsLinkedBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(WPColor.docsLinkedStroke, lineWidth: 1))
                .padding(.top, 23)
            HStack(spacing: 6) {
                WPLucideIcon(paths: DocIcon.shieldCheck, size: 14, color: WPColor.docsAccess)
                docText("이 플랜의 방장과 배우자만 열 수 있어요.", 10, WPColor.docsAccess)
            }.padding(.vertical, 18)
            if let error {
                docText(error, 12, WPColor.docsError, lineHeight: 20.4).fixedSize(horizontal: false, vertical: true).padding(.vertical, 10)
            }
            /*
              사진은 이미 위에 떠 있으므로 버튼을 내지 않는다. PDF 는 화면 안에 그릴 수 없어 이 버튼이
              유일한 통로다. 사진인데 미리보기를 못 받았으면 버튼이 다시 나온다 — 볼 방법이 아예 없는 창은 만들지 않는다.
            */
            if !(document.isPhoto && preview != nil) {
                let openable = hasPass && document.canOpen
                DocPrimaryButton(label: busy ? "처리 중…" : openable ? "원본 파일 열기" : "준비 패스 이용 시 열 수 있어요",
                                 icon: DocIcon.arrowUpRight, iconSize: 15, enabled: !busy && openable, action: onOpen)
                    .padding(.top, error != nil ? 17 : 0).accessibilityIdentifier("documents.open")
            }
            if confirmDelete || (initialConfirm && !started) {
                VStack(alignment: .leading, spacing: 12) {
                    docText("이 파일을 삭제할까요? 연결된 플랜에서도 사라져요.", 11, WPColor.docsDialogInk).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 14) {
                        Button { confirmDelete = false; started = true } label: { docText("취소", 11, WPColor.docsConfirmAction) }.buttonStyle(.plain)
                        Button(action: onDelete) { docText("삭제하기", 11, WPColor.docsConfirmAction) }.buttonStyle(.plain).accessibilityIdentifier("documents.confirmDelete")
                    }.disabled(busy).opacity(busy ? 0.45 : 1)
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(WPColor.docsConfirmBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(WPColor.docsConfirmStroke, lineWidth: 1))
                    .padding(.top, document.isPhoto && preview != nil && error == nil ? 0 : 14)
            } else {
                Button { confirmDelete = true } label: {
                    HStack(spacing: 5) {
                        WPLucideIcon(paths: DocIcon.trash2, size: 13, color: WPColor.docsDelete)
                        docText("이 서류 삭제", 10, WPColor.docsDelete)
                    }.frame(maxWidth: .infinity).padding(.top, 14).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("documents.delete")
            }
        }
    }

    private var caption: String {
        if document.isPDF { return "PDF DOCUMENT" }
        if document.isPhoto && givenUp { return "미리보기를 불러오지 못했어요" }
        if document.isPhoto && hasPass && document.canOpen { return "사진을 불러오는 중…" }
        return "PHOTO"
    }
}

/// 서류 보관 창 — 플랜을 고르고 파일을 올린다.
private struct UploadDocumentDialog: View {
    let groups: [(Int, String)]
    let initialFolder: Int?
    let busy: Bool
    let error: String?
    let onUpload: (Int, PickedDocument) -> Void
    let onError: (String) -> Void
    let onDismiss: () -> Void
    @State private var scheduleId: Int?
    @State private var file: PickedDocument?
    @State private var photo: PhotosPickerItem?
    @State private var importing = false
    @State private var started = false

    var body: some View {
        DocDialog(onDismiss: onDismiss) {
            VStack(alignment: .leading, spacing: 0) {
                DocDialogHeader(label: "서류 보관", closeLabel: "서류 올리기 닫기", enabled: !busy, onClose: onDismiss)
                docText("어느 플랜의 서류인가요?", 21, WPColor.docsDialogInk, bold: true, tracking: -0.5)
                docText("먼저 연결할 플랜을 고르고 파일을 올려주세요.", 11, WPColor.docsFileMeta, lineHeight: 19.8).padding(.top, 9)
                docText("연결할 플랜", 12, WPColor.docsDialogInk).padding(.top, 24)
                Menu {
                    ForEach(groups, id: \.0) { group in Button(group.1) { scheduleId = group.0 } }
                } label: {
                    HStack(spacing: 0) {
                        docText(groups.first { $0.0 == scheduleId }?.1 ?? "플랜을 선택해 주세요", 12, WPColor.docsDialogInk, lines: 1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        WPLucideIcon(paths: DocIcon.chevronDown, size: 16, color: WPColor.docsDialogInk)
                    }.padding(12)
                        .background(WPColor.docsSelectBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(WPColor.docsSelectStroke, lineWidth: 1))
                }.padding(.top, 9).accessibilityIdentifier("documents.planSelect")
                PhotosPicker(selection: $photo, matching: .images) {
                    VStack(spacing: 13) {
                        WPLucideIcon(paths: DocIcon.upload, size: 27, color: WPColor.docsDrop)
                        docText(file?.name ?? "앨범에서 사진 고르기", 13, WPColor.docsDrop, bold: true).multilineTextAlignment(.center)
                        docText("한 파일 최대 25MB", 10, WPColor.docsDrop)
                    }.padding(25).frame(maxWidth: .infinity)
                        .background(WPColor.docsSelectBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(WPColor.docsDropStroke, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                }.buttonStyle(.plain).disabled(busy).padding(.top, 20).accessibilityIdentifier("documents.dropzone")
                // 계약서 PDF — 앨범에는 PDF 가 없다
                Button { importing = true } label: {
                    docText("PDF 파일 고르기", 12, WPColor.docsDrop, bold: true).frame(maxWidth: .infinity).padding(.vertical, 12).contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(busy).padding(.top, 6)
                if let error {
                    docText(error, 12, WPColor.docsError, lineHeight: 20.4).fixedSize(horizontal: false, vertical: true).padding(.vertical, 10)
                }
                DocPrimaryButton(label: busy ? "보관하는 중…" : "플랜에 연결해 보관하기", icon: DocIcon.plus, iconSize: 16,
                                 enabled: file != nil && scheduleId != nil && !busy) {
                    if let file, let scheduleId { onUpload(scheduleId, file) }
                }.padding(.top, 17).accessibilityIdentifier("documents.uploadSubmit")
            }
        }
        .onAppear { if !started { started = true; scheduleId = initialFolder } }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task {
                do { file = try await PassFileUploader.read(item) } catch { onError(PassFileUploader.failureMessage(error)) }
                photo = nil
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
            do { if let url = try result.get().first { file = try PassFileUploader.read(url) } }
            catch { onError(PassFileUploader.failureMessage(error)) }
        }
    }
}

/// 웹 `<dialog>` — 가운데 뜨는 흰 카드(폭 435 이하, 좌우 19 여백), 뒤는 자주빛 막.
/// 막을 눌러도 닫지 않는다(웹 `<dialog>` 는 X·Esc 로만 닫힘 — 고른 플랜·파일이 실수로 사라지지 않게).
private struct DocDialog<Content: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content
    var body: some View {
        ZStack {
            WPColor.docsScrim.ignoresSafeArea()
            ScrollView {
                content().padding(24)
                    .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(WPColor.docsDialogStroke, lineWidth: 1))
                    .frame(maxWidth: 435)
                    .padding(.horizontal, 19).padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .defaultScrollAnchor(.center)
        }
        .transition(.opacity)
    }
}

private struct DocDialogHeader: View {
    let label: String
    let closeLabel: String
    let enabled: Bool
    let onClose: () -> Void
    var body: some View {
        HStack(spacing: 0) {
            docText(label, 11, WPColor.docsDialogLabel).frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onClose) {
                WPLucideIcon(paths: DocIcon.x, size: 20, color: WPColor.docsDialogLabel).padding(5).contentShape(Circle())
            }.buttonStyle(DocButtonStyle()).disabled(!enabled).opacity(enabled ? 1 : 0.45).accessibilityLabel(closeLabel).accessibilityIdentifier("documents.dialogClose")
        }.padding(.bottom, 20)
    }
}

private struct DocPrimaryButton: View {
    let label: String
    let icon: [String]
    let iconSize: CGFloat
    let enabled: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                docText(label, 12, .white)
                WPLucideIcon(paths: icon, size: iconSize, color: .white)
            }.padding(13).frame(maxWidth: .infinity)
                .background(DocsCSSGradient(angle: 110, colors: [WPColor.docsUploadStart, WPColor.docsPrimaryEnd]).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)))
                .opacity(enabled ? 1 : 0.45)
        }.buttonStyle(DocButtonStyle()).disabled(!enabled)
    }
}

/// `.plain` 은 꺼진 버튼을 한 번 더 흐리게 그려 안드로이드(알파 0.45 한 번)보다 옅어진다 — 흐림은 화면이 직접 정한다.
struct DocButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.opacity(configuration.isPressed ? 0.85 : 1) }
}

/// 웹 이 화면의 글꼴은 KakaoSmallSans(`--font-kakao`) 다.
private func docText(_ text: String, _ size: CGFloat, _ color: Color, bold: Bool = false, tracking: CGFloat = 0, lineHeight: CGFloat? = nil, lines: Int? = nil) -> some View {
    Text(text).tracking(tracking).foregroundColor(color).lineLimit(lines)
        .wpTypography(size, bold ? .bold : .regular, face: .kakao, lineHeight: lineHeight)
}

/// CSS `linear-gradient(<angle>deg, …)` — 상자 크기에 맞춰 그라데이션 선 길이를 잡는다(안드로이드 `cssGradientBackground`).
struct DocsCSSGradient: View {
    var angle: Double
    var colors: [Color]
    var body: some View {
        GeometryReader { g in
            let w = max(g.size.width, 1), h = max(g.size.height, 1)
            let r = angle * .pi / 180
            let dx = sin(r), dy = -cos(r)
            let half = (abs(w * dx) + abs(h * dy)) / 2
            LinearGradient(colors: colors,
                           startPoint: UnitPoint(x: (w / 2 - dx * half) / w, y: (h / 2 - dy * half) / h),
                           endPoint: UnitPoint(x: (w / 2 + dx * half) / w, y: (h / 2 + dy * half) / h))
        }
    }
}

/// 웹 conic-gradient — 12시에서 시계 방향으로 사용량만큼
private struct DocsPie: Shape {
    var fraction: Double
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        p.move(to: c)
        p.addArc(center: c, radius: min(rect.width, rect.height) / 2, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * fraction), clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// 웹 `.documentPreview` 의 45도 빗금 바탕(8px 면 + 1px 선)
private struct DocsStripes: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(WPColor.docsStripeA))
            let step = 9 * 1.4142
            var x = -size.height
            while x < size.width {
                var line = Path(); line.move(to: CGPoint(x: x, y: 0)); line.addLine(to: CGPoint(x: x + size.height, y: size.height))
                context.stroke(line, with: .color(WPColor.docsStripeB), lineWidth: 1)
                x += step
            }
        }
    }
}

// MARK: - 전부 내려받기 시트 (안드로이드 `ui/pass/DownloadAllSheet.kt`)

/// 그 방에 올린 사진·문서를 파일마다 내려받는 시트. 주소가 5분짜리라 **열 때마다** 새로 받고,
/// 받은 지 4분이 넘었으면 누를 때 다시 받아 새 주소로 내려받는다(웹 `URL_FRESH_MS`).
struct PassDownloadView: View {
    let roomId: Int
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var files: [PassDownloadItem]?
    @State private var error: String?
    @State private var fetchedAt = Date.distantPast
    @State private var downloading: Int?
    @State private var shared: [URL] = []
    @State private var sharing = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("서류 전부 내려받기").wpTypography(15.5, .bold).foregroundStyle(WPColor.textPrimary)
                    Text("패스가 끝나도 90일 동안 받을 수 있어요. 파일마다 눌러 저장해 주세요.").wpTypography(12, lineHeight: 19.5)
                        .foregroundStyle(WPColor.docsExportText).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button { dismiss() } label: {
                    WPLucideIcon(paths: DocIcon.x, size: 16, color: WPColor.gray400).frame(width: 32, height: 32).contentShape(Circle())
                }.buttonStyle(.plain).accessibilityLabel("닫기")
            }.padding(.horizontal, 20).padding(.bottom, 16).padding(.top, 28)
            Rectangle().fill(WPColor.strokeSubtle).frame(height: 1)
            ScrollView {
                VStack(spacing: 0) {
                    if let error {
                        VStack(spacing: 10) {
                            Text(error).wpTypography(13).foregroundStyle(WPColor.danger)
                            Button { Task { await load() } } label: {
                                Text("다시 불러오기").wpTypography(12.5, .bold).foregroundStyle(WPColor.stone600)
                                    .padding(.horizontal, 16).padding(.vertical, 9).overlay(Capsule().strokeBorder(WPColor.gray200, lineWidth: 1))
                            }.buttonStyle(.plain)
                        }.frame(maxWidth: .infinity).padding(.vertical, 18)
                    } else if let files {
                        if files.isEmpty {
                            Text("내려받을 서류가 없어요.").wpTypography(13).foregroundStyle(WPColor.fgSubtle).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 18)
                        } else {
                            ForEach(Array(files.enumerated()), id: \.offset) { index, item in row(index, item).padding(.bottom, 6) }
                        }
                    } else {
                        VStack(spacing: 8) { ForEach(0..<3, id: \.self) { _ in SkeletonBox(height: 48, corner: 12) } }
                    }
                }.padding(.horizontal, 20).padding(.vertical, 16)
            }
            Rectangle().fill(WPColor.strokeSubtle).frame(height: 1)
            Text("누른 파일이 하나씩 저장돼요.").wpTypography(11.5).foregroundStyle(WPColor.passSheetFaint)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 14)
        }
        .background(.white)
        .presentationDetents([.medium, .large]).presentationCornerRadius(22).presentationDragIndicator(.visible)
        .task { await load() }
        .sheet(isPresented: $sharing) { ActivityShareSheet(items: shared) }
    }

    private func row(_ index: Int, _ item: PassDownloadItem) -> some View {
        HStack(spacing: 0) {
            WPMaterialPathIcon(paths: WPIconPaths.descriptionOutlined, size: 16, color: WPColor.docsDownloadIcon)
            Spacer().frame(width: 10)
            Text(item.fileName).wpTypography(13.5).foregroundStyle(WPColor.textPrimary).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(width: 8)
            Button { Task { await download(index, item) } } label: {
                HStack(spacing: 4) {
                    if downloading == index { ProgressView().scaleEffect(0.6).frame(width: 14, height: 14) }
                    else { WPMaterialPathIcon(paths: DocIcon.fileDownloadOutlined, size: 14, color: WPColor.stone600) }
                    Text("내려받기").wpTypography(12.5, .bold).foregroundStyle(WPColor.stone600)
                }.padding(.horizontal, 12).padding(.vertical, 7).overlay(Capsule().strokeBorder(WPColor.gray200, lineWidth: 1))
            }.buttonStyle(.plain).disabled(downloading != nil)
        }.padding(.horizontal, 14).padding(.vertical, 10)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(WPColor.strokeSubtle, lineWidth: 1))
    }

    private func load() async {
        error = nil; files = nil
        do {
            let result: PassDownloadAll = try await env.api.send(Endpoint.allFiles(roomId: roomId))
            files = result.list.filter { URL(string: $0.url)?.scheme == "https" }; fetchedAt = Date()
        } catch { self.error = "목록을 불러오지 못했어요. 잠시 후 다시 시도해 주세요." }
    }

    /// 오래된 주소면 새로 받아 같은 자리·같은 이름의 파일을 내려받는다
    private func download(_ index: Int, _ item: PassDownloadItem) async {
        downloading = index; defer { downloading = nil }
        var target = item
        if Date().timeIntervalSince(fetchedAt) > 4 * 60 {
            guard let result: PassDownloadAll = try? await env.api.send(Endpoint.allFiles(roomId: roomId)) else { error = "목록을 불러오지 못했어요. 잠시 후 다시 시도해 주세요."; return }
            let fresh = result.list.filter { URL(string: $0.url)?.scheme == "https" }
            files = fresh; fetchedAt = Date()
            guard let same = (fresh.indices.contains(index) && fresh[index].fileName == item.fileName ? fresh[index] : nil) ?? fresh.first(where: { $0.fileName == item.fileName }) else { return }
            target = same
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("웨딩플랜트-서류-" + UUID().uuidString)
        do { shared = [try await DocumentDownload.fetch(target.url, name: target.fileName, into: directory)]; sharing = true }
        catch { self.error = PassFileUploader.failureMessage(error, fallback: "내려받지 못했어요. 다시 시도해 주세요.") }
    }
}

struct PassExportButton: View {
    let roomId: Int
    @State private var showExport = false
    var body: some View {
        Button("예산·일정 파일로 받기") { showExport = true }.font(WPFont.hak(14))
            .sheet(isPresented: $showExport) { CalendarExportSheet(roomId: roomId) }
    }
}

// MARK: - 문단

/// 안드로이드 `keepAll()` 문단 — 어절로 꺾고 UIKit 의 한글 줄 재배치(pushOut)를 끈다.
/// SwiftUI `Text` 는 마지막 줄에 한 어절만 남지 않게 앞 줄을 밀어 내려 안드로이드와 꺾이는 자리가 달라진다.
struct PassParagraph: UIViewRepresentable {
    let text: String
    var size: CGFloat
    var lineHeight: CGFloat
    var color: Color
    var weight: Font.Weight = .regular
    var face: WPTypeface = .hak
    var alignment: NSTextAlignment = .left
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel(); label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }
    func updateUIView(_ label: UILabel, context: Context) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = lineHeight; paragraph.maximumLineHeight = lineHeight
        paragraph.lineBreakMode = .byWordWrapping; paragraph.lineBreakStrategy = []; paragraph.alignment = alignment
        let font = face.uiFont(size, weight)
        // 줄 높이 안에서 글자를 가운데에 — Compose `LineHeightStyle.Alignment.Center` 와 같게
        let offset = (lineHeight - font.lineHeight) / 4
        label.attributedText = NSAttributedString(string: text.wpKeepAll, attributes: [.font: font, .paragraphStyle: paragraph, .foregroundColor: UIColor(color), .baselineOffset: offset])
        label.accessibilityLabel = text
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let width = proposal.width ?? 300
        let natural = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(lineHeight, ceil(natural.height / lineHeight) * lineHeight))
    }
}

// MARK: - 아이콘 경로 (안드로이드 `LucideIcons` · Material 원본 경로)

enum DocIcon {
    static let arrowLeft = ["m12 19-7-7 7-7", "M19 12H5"]
    static let chevronRight = ["m9 18 6-6-6-6"]
    static let chevronDown = ["m6 9 6 6 6-6"]
    static let plus = ["M5 12h14", "M12 5v14"]
    static let x = ["M18 6 6 18", "m6 6 12 12"]
    static let check = ["M20 6 9 17l-5-5"]
    static let arrowUpRight = ["M7 7h10v10", "M7 17 17 7"]
    static let cloud = ["M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z"]
    static let flower2 = [
        "M12 5a3 3 0 1 1 3 3m-3-3a3 3 0 1 0-3 3m3-3v1M9 8a3 3 0 1 0 3 3M9 8h1m5 0a3 3 0 1 1-3 3m3-3h-1m-2 3v-1",
        "M10 8a2 2 0 1 0 4 0a2 2 0 1 0 -4 0",
        "M12 10v12",
        "M12 22c4.2 0 7-1.667 7-5-4.2 0-7 1.667-7 5Z",
        "M12 22c-4.2 0-7-1.667-7-5 4.2 0 7 1.667 7 5Z",
    ]
    static let heart = "M2 9.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5"
    static let folder = "M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"
    static let folderOpen = "m6 14 1.5-2.9A2 2 0 0 1 9.24 10H20a2 2 0 0 1 1.94 2.5l-1.54 6a2 2 0 0 1-1.95 1.5H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h3.9a2 2 0 0 1 1.69.9l.81 1.2a2 2 0 0 0 1.67.9H18a2 2 0 0 1 2 2v2"
    static let fileText = [
        "M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z",
        "M14 2v5a1 1 0 0 0 1 1h5", "M10 9H8", "M16 13H8", "M16 17H8",
    ]
    static let link2 = ["M9 17H7A5 5 0 0 1 7 7h2", "M15 7h2a5 5 0 1 1 0 10h-2", "M8 12L16 12"]
    static let hardDrive = [
        "M22 12L2 12",
        "M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z",
        "M6 16L6.01 16", "M10 16L10.01 16",
    ]
    static let shieldCheck = [
        "M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z",
        "m9 12 2 2 4-4",
    ]
    static let search = ["m21 21-4.34-4.34", "M3 11a8 8 0 1 0 16 0a8 8 0 1 0 -16 0"]
    static let image = [
        "M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-14a2 2 0 0 1 2 -2z",
        "M7 9a2 2 0 1 0 4 0a2 2 0 1 0 -4 0",
        "m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21",
    ]
    static let trash2 = ["M10 11v6", "M14 11v6", "M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6", "M3 6h18", "M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"]
    static let upload = ["M12 3v12", "m17 8-5-5-5 5", "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"]
    /// Material `Icons.Outlined.FolderOpen`
    static let folderOpenOutlined = ["M20 6h-8l-2-2H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm0 12H4V8h16v10z"]
    /// Material `Icons.Outlined.Lock`
    static let lockOutlined = ["M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zM9 6c0-1.66 1.34-3 3-3s3 1.34 3 3v2H9V6zm9 14H6V10h12v10zm-6-3c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2z"]
    /// Material `Icons.AutoMirrored.Outlined.CallMade`
    static let callMade = ["M9 5v2h6.59L4 18.59 5.41 20 17 8.41V15h2V5H9z"]
    /// Material `Icons.Filled.Add`
    static let add = ["M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"]
    /// Material `Icons.Outlined.FileDownload`
    static let fileDownloadOutlined = ["M18 15v3H6v-3H4v3c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2v-3h-2zm-1-4-1.41-1.41L13 12.17V4h-2v8.17L8.41 9.59 7 11l5 5 5-5z"]
    /// Material `Icons.Outlined.Download`
    static let downloadOutlined = ["M19 9h-4V3H9v6H5l7 7 7-7zm-8 2V5h2v6h1.17L12 13.17 9.83 11H11zm-6 7h14v2H5z"]
    /// Material `Icons.Outlined.Notifications`
    static let notificationsOutlined = ["M12 22c1.1 0 2-.9 2-2h-4c0 1.1.89 2 2 2zm6-6v-5c0-3.07-1.64-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.63 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2zm-2 1H8v-6c0-2.48 1.51-4.5 4-4.5s4 2.02 4 4.5v6z"]
    /// Material `Icons.Outlined.LocalFlorist`
    static let localFloristOutlined = ["M8.66 13.07c.15 0 .29-.01.43-.03C9.56 14.19 10.69 15 12 15s2.44-.81 2.91-1.96c.14.02.29.03.43.03 1.73 0 3.14-1.41 3.14-3.14 0-.71-.25-1.39-.67-1.93.43-.54.67-1.22.67-1.93 0-1.73-1.41-3.14-3.14-3.14-.15 0-.29.01-.43.03C14.44 1.81 13.31 1 12 1s-2.44.81-2.91 1.96c-.14-.02-.29-.03-.43-.03-1.73 0-3.14 1.41-3.14 3.14 0 .71.25 1.39.67 1.93-.43.54-.67 1.22-.67 1.93 0 1.73 1.41 3.14 3.14 3.14zM12 13c-.62 0-1.12-.49-1.14-1.1l.12-1.09c.32.12.66.19 1.02.19s.71-.07 1.03-.19l.11 1.09c-.02.61-.52 1.1-1.14 1.1zm3.34-1.93c-.24 0-.46-.07-.64-.2l-.81-.57c.55-.45.94-1.07 1.06-1.79l.88.38c.4.18.66.59.66 1.03 0 .63-.51 1.15-1.15 1.15zm-.65-4.43c.2-.13.41-.2.64-.2.63 0 1.14.51 1.14 1.14 0 .44-.25.85-.66 1.03l-.88.38c-.12-.72-.51-1.34-1.06-1.79l.82-.56zM12 3c.62 0 1.12.49 1.14 1.1l-.11 1.09C12.71 5.07 12.36 5 12 5s-.7.07-1.02.19l-.12-1.09c.02-.61.52-1.1 1.14-1.1zM8.66 4.93c.24 0 .46.07.64.2l.81.56c-.55.45-.94 1.07-1.06 1.79l-.88-.38c-.4-.17-.66-.58-.66-1.02 0-.63.52-1.15 1.15-1.15zM8.17 9.9l.88-.38c.12.72.51 1.34 1.06 1.79l-.81.56c-.18.13-.41.2-.64.2-.63 0-1.14-.51-1.14-1.14-.01-.44.25-.85.65-1.03zM12 22c4.97 0 9-4.03 9-9-4.97 0-9 4.03-9 9zm2.44-2.44c.71-1.9 2.22-3.42 4.12-4.12-.71 1.9-2.22 3.41-4.12 4.12zM3 13c0 4.97 4.03 9 9 9 0-4.97-4.03-9-9-9zm2.44 2.44c1.9.71 3.42 2.22 4.12 4.12-1.9-.71-3.41-2.22-4.12-4.12z"]
}

// MARK: - 색 (안드로이드 `WpColors.Docs*` 와 같은 값 — 웹 app/documents/documents.module.css)

extension WPColor {
    static let docsPage = Color(hex: 0xFCFAFB)
    static let docsInk = Color(hex: 0x392632)
    static let docsHeaderLine = Color(hex: 0xEEE4EA)
    static let docsCrumb = Color(hex: 0xA68B9B)
    static let docsBadgeBg = Color(hex: 0xFFF1B8)
    static let docsBadgeText = Color(hex: 0x8D5B32)
    static let docsLead = Color(hex: 0xA08797)
    static let docsUploadStart = Color(hex: 0xEC328B)
    static let docsUploadEnd = Color(hex: 0xFB796F)
    static let docsPrimaryEnd = Color(hex: 0xF78573)
    static let docsContext = Color(hex: 0xA38C9A)
    static let docsContextStrong = Color(hex: 0x6D4C61)
    static let docsAvatarBg = Color(hex: 0xF6D6E5)
    static let docsAvatarHeart = Color(hex: 0xC96B98)
    static let docsLine = Color(hex: 0xEEE2E9)
    static let docsTab = Color(hex: 0xA18797)
    static let docsTabActive = Color(hex: 0xCA3C7A)
    static let docsTabUnderline = Color(hex: 0xEE438D)
    static let docsStorageStart = Color(hex: 0xFFF0F6)
    static let docsStorageEnd = Color(hex: 0xFFF0E4)
    static let docsStorageStroke = Color(hex: 0xF7DFE9)
    static let docsOverline = Color(hex: 0xB97991)
    static let docsStorageTitle = Color(hex: 0x74394F)
    static let docsStorageSub = Color(hex: 0xB78C9D)
    static let docsTrack = Color(hex: 0xF1D9E3)
    static let docsTrackStart = Color(hex: 0xEA2B84)
    static let docsTrackEnd = Color(hex: 0xFFB083)
    static let docsStorageFoot = Color(hex: 0xB08B9A)
    static let docsArtStroke = Color(hex: 0xEF83AC)
    static let docsArtFill = Color(hex: 0xFFC6D9)
    static let docsArtCheck = Color(hex: 0xD96C94)
    static let docsArtCheckRing = Color(hex: 0xFFE5EE)
    static let docsStatsDivider = Color(hex: 0xF0E6EC)
    static let docsStatsIcon = Color(hex: 0xC791AB)
    static let docsStatsUnit = Color(hex: 0xB99CAB)
    static let docsStatsLabel = Color(hex: 0xA88D9D)
    static let docsSectionCount = Color(hex: 0xBD7297)
    static let docsSectionAside = Color(hex: 0xBBA1B0)
    static let docsSectionAction = Color(hex: 0xBC7296)
    static let docsSearchBg = Color(hex: 0xFBF7FA)
    static let docsSearchStroke = Color(hex: 0xF0E7ED)
    static let docsSearchIcon = Color(hex: 0xC1A6B6)
    static let docsSearchText = Color(hex: 0x745668)
    static let docsSearchHint = Color(hex: 0xBCA5B2)
    static let docsKind = Color(hex: 0xB299A9)
    static let docsKindActiveBg = Color(hex: 0xFCEAF3)
    static let docsKindActive = Color(hex: 0xC05186)
    static let docsSort = Color(hex: 0x9E7E92)
    static let docsRowLine = Color(hex: 0xF5EEF2)
    static let docsRowChevron = Color(hex: 0xC5AABB)
    static let docsFileSub = Color(hex: 0xB6A0AD)
    static let docsPdfBg = Color(hex: 0xFFF0F4)
    static let docsPdfIcon = Color(hex: 0xD27199)
    static let docsPdfStroke = Color(hex: 0xF8DFE9)
    static let docsPhotoBg = Color(hex: 0xEDF6F0)
    static let docsPhotoIcon = Color(hex: 0x75A891)
    static let docsPhotoStroke = Color(hex: 0xDCEFE4)
    static let docsPreviewStroke = Color(hex: 0xF0E2EA)
    static let docsSize = Color(hex: 0xAA92A1)
    static let docsNote = Color(hex: 0xB198A8)
    static let docsFolderIntroSub = Color(hex: 0xA0899A)
    static let docsQuotaBg = Color(hex: 0xFFF1F6)
    static let docsQuotaStroke = Color(hex: 0xF4DCE7)
    static let docsQuotaText = Color(hex: 0xB65D86)
    static let docsFolderCategory = Color(hex: 0xA58C9D)
    static let docsFolderMeta = Color(hex: 0xAA929F)
    static let docsFolderSelected = Color(hex: 0xC86998)
    /// 플랜별 폴더 색(웹 `tones`) — 플랜 순서대로 돌아가며 쓴다
    static let docsFolderTones: [UInt32] = [0xF7BFD8, 0xBDE3D5, 0xD5CBF6, 0xF6D3AE]
    static let docsCapacityEnd = Color(hex: 0xFFF7EC)
    static let docsRing = Color(hex: 0xEF569A)
    static let docsRingTrack = Color(hex: 0xF1DDE6)
    static let docsRingInner = Color(hex: 0xFFF5F2)
    static let docsRingValue = Color(hex: 0xA9577B)
    static let docsRingLabel = Color(hex: 0xB3869B)
    static let docsCapacityTitle = Color(hex: 0x835367)
    static let docsCapacitySub = Color(hex: 0xB891A0)
    static let docsCapacityButton = Color(hex: 0xB6658A)
    static let docsCapacityButtonStroke = Color(hex: 0xF0D9E4)
    static let docsBreakdownSub = Color(hex: 0xB298A8)
    static let docsUsageTrack = Color(hex: 0xF8F3F6)
    static let docsKeepBg = Color(hex: 0xF5F9F5)
    static let docsKeep = Color(hex: 0x729C87)
    static let docsKeepSub = Color(hex: 0x8DAA99)
    static let docsEmptyIcon = Color(hex: 0xDCA4BF)
    static let docsEmptySub = Color(hex: 0xAD8E9F)
    static let docsRetry = Color(hex: 0xC05786)
    static let docsLockedBg = Color(hex: 0xFFF4DF)
    static let docsLocked = Color(hex: 0xA76635)
    static let docsToastBg = Color(hex: 0x4A3040)
    static let docsDialogStroke = Color(hex: 0xEDDAE5)
    static let docsDialogInk = Color(hex: 0x492F3E)
    /// 웹 `::backdrop` #2d142954
    static let docsScrim = Color(hex: 0x542D1429)
    static let docsDialogLabel = Color(hex: 0xB492A7)
    static let docsPreviewBoxStroke = Color(hex: 0xF4E3EB)
    static let docsStripeA = Color(hex: 0xFFF9FC)
    static let docsStripeB = Color(hex: 0xFFF5F9)
    static let docsPreviewCaption = Color(hex: 0xC09EB0)
    static let docsFileMeta = Color(hex: 0xA5899A)
    static let docsLinkedBg = Color(hex: 0xFCF6FA)
    static let docsLinkedStroke = Color(hex: 0xF0E2EB)
    static let docsLinkedLabel = Color(hex: 0xAE879F)
    static let docsLinkedSub = Color(hex: 0xAE92A3)
    static let docsAccess = Color(hex: 0xB294A5)
    static let docsDelete = Color(hex: 0xAD94A2)
    static let docsConfirmBg = Color(hex: 0xFFF5F5)
    static let docsConfirmStroke = Color(hex: 0xF5DDDD)
    static let docsConfirmAction = Color(hex: 0xB75570)
    static let docsError = Color(hex: 0xBE4B62)
    static let docsSelectStroke = Color(hex: 0xEEDEE7)
    static let docsSelectBg = Color(hex: 0xFFFBFD)
    static let docsDropStroke = Color(hex: 0xE8BBD0)
    static let docsDrop = Color(hex: 0xBC789A)
    /// 일정 서류 칸 — 안드로이드 `PassDocsRow` 의 타일 면·아이콘·`준비 패스 알아보기`
    static let docsTileFill = Color(hex: 0xFAF6F8)
    static let docsTileIcon = Color(hex: 0x7A6C74)
    static let docsPassLink = Color(hex: 0xBA1C68)
    /// 전부 내려받기 시트 — 안드로이드 `ExportFileTabText` · `DownloadFileIcon`
    static let docsExportText = Color(hex: 0x6B7079)
    static let docsDownloadIcon = Color(hex: 0xB0A6AD)
    static let plansMuted = Color(hex: 0x6B6570)
    static let plansBody = Color(hex: 0x403A44)
    static let plansConsent = Color(hex: 0x3D2C35)
    static let plansStroke = Color(hex: 0xEFEAEE)
    static let plansConsentStroke = Color(hex: 0xF0E6EB)
    static let plansPicked = Color(hex: 0xFFFAFC)
    static let plansRadio = Color(hex: 0xD8D2D7)
    static let plansQuietTag = Color(hex: 0xF3EEF1)
    static let plansBuyDisabled = Color(hex: 0xE9DFE5)
    static let plansBuyDisabledText = Color(hex: 0xB2A8AE)

    /// 웹 color-mix — `a` 를 `b` 쪽으로 `t` 만큼(안드로이드 `lerp`)
    static func docsMix(_ a: UInt32, _ b: UInt32, _ t: Double) -> Color {
        func channel(_ v: UInt32, _ shift: UInt32) -> Double { Double((v >> shift) & 0xFF) / 255 }
        func mix(_ shift: UInt32) -> Double { channel(a, shift) * (1 - t) + channel(b, shift) * t }
        return Color(.sRGB, red: mix(16), green: mix(8), blue: mix(0), opacity: 1)
    }
}
