import SwiftUI
import PhotosUI
import WPDomain
import WPModels

// MARK: - 새 플랜의 서류 담기 (Android `PendingDocsCard` · `PendingDocUploader`, 2026-10-16)
//
// 사용자 "패스를 팔아야 하는 입장에서 플랜 등록할 때 첨부 파일 올릴 수 있게 · 패스가 아니면 못 하고 무지개 테두리".
// 서류는 일정에 붙는데 새 플랜은 아직 일정 id 가 없어서, 고른 것을 기기에 담아 두었다가 저장이 id 를 받으면 올린다.

/// 저장 전에 담아 둔 서류 한 장 — 파일은 임시 폴더에 두고 주소만 든다(25MB 짜리 열 개를 메모리에 들지 않게)
struct PendingDoc: Identifiable, Equatable {
    /// 같은 것을 두 번 담지 않게 가르는 값 — 사진은 앨범의 항목 id, PDF 는 파일 주소
    let key: String
    let file: URL
    let name: String
    let type: String
    let thumbnail: UIImage?
    var id: String { key }
    var photo: Bool { PassDocRules.isPhoto(type) }
    static func == (a: PendingDoc, b: PendingDoc) -> Bool { a.key == b.key }
}

enum PendingDocReader {
    private static var folder: URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pending-docs", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 올릴 수 없는 것(형식 · 크기)은 **고른 자리에서** 거절한다 — 저장 뒤에 거절당하면 플랜은 이미 저장돼 되돌릴 수 없다
    /// (Android `DocumentTransfer.inspect`). 올릴 때 `PassFileUploader.upload` 가 같은 검사를 한 번 더 한다.
    static func read(_ item: PhotosPickerItem) async throws -> PendingDoc {
        let picked = try await PassFileUploader.read(item)
        guard DocumentRules.validSize(picked.data.count) else { throw DocUploadError(message: "파일은 0바이트보다 크고 25MB 이하여야 해요.") }
        return try store(picked, key: item.itemIdentifier ?? UUID().uuidString, thumbnail: thumbnail(picked.data))
    }

    static func read(_ url: URL) throws -> PendingDoc {
        let picked = try PassFileUploader.read(url)
        guard DocumentRules.contentTypes.contains(picked.type) else { throw DocUploadError(message: "사진 또는 PDF를 선택해 주세요.") }
        return try store(picked, key: url.absoluteString, thumbnail: PassDocRules.isPhoto(picked.type) ? thumbnail(picked.data) : nil)
    }

    /// 데모 · 화면 테스트용 — 앨범 · 파일 앱 없이 사진 한 장과 PDF 한 장을 담은 상태(`-WPPendingDocsSample`)
    static func samples() -> [PendingDoc] {
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 240, height: 320)).jpegData(withCompressionQuality: 0.8) { ctx in
            UIColor(red: 0.98, green: 0.84, blue: 0.9, alpha: 1).setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 240, height: 320))
            UIColor(red: 0.93, green: 0.17, blue: 0.55, alpha: 1).setFill(); ctx.fill(CGRect(x: 60, y: 90, width: 120, height: 140))
        }
        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 280)).pdfData { ctx in ctx.beginPage() }
        return [
            try? store(PickedDocument(data: photo, name: "영수증.jpg", type: "image/jpeg"), key: "sample-photo", thumbnail: thumbnail(photo)),
            try? store(PickedDocument(data: pdf, name: "계약서.pdf", type: "application/pdf"), key: "sample-pdf", thumbnail: nil),
        ].compactMap { $0 }
    }

    static func data(_ doc: PendingDoc) throws -> PickedDocument {
        PickedDocument(data: try Data(contentsOf: doc.file), name: doc.name, type: doc.type)
    }

    static func discard(_ docs: [PendingDoc]) {
        for doc in docs { try? FileManager.default.removeItem(at: doc.file) }
    }

    private static func store(_ picked: PickedDocument, key: String, thumbnail: UIImage?) throws -> PendingDoc {
        let file = folder.appendingPathComponent(UUID().uuidString + "-" + picked.name)
        do { try picked.data.write(to: file, options: .atomic) }
        catch { throw DocUploadError(message: "파일을 읽지 못했어요. 다시 선택해 주세요.") }
        return PendingDoc(key: key, file: file, name: picked.name, type: picked.type, thumbnail: thumbnail)
    }

    /// 52pt 타일용 썸네일 — 원본을 화면에 그대로 두면 열 장이 수십 MB 를 먹는다
    private static func thumbnail(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 180,
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// 새 플랜에 담아 둔 서류를 저장 뒤 그 일정에 올리는 일 — **앱 수명 동안** 돈다.
///
/// Android 는 처음에 화면의 뷰모델에서 돌렸다가, 올리는 동안 탭 · 뒤로가기 · 알림으로 화면을 떠나면 남은 서류가 조용히
/// 빠졌다(플랜은 이미 저장돼 사용자는 다 올라간 줄 안다). 그래서 화면은 진행만 따라 그리고, 올리기와 실패 안내는 여기서
/// 끝까지 한다 — 화면이 남아 있든 없든 못 올린 것은 토스트로 한 번 알린다.
@MainActor
final class PendingDocUploader {
    static let shared = PendingDocUploader()

    /// 못 올린 수를 돌려준다. 기다리던 화면이 사라져도(작업 취소) 올리기는 멈추지 않는다.
    func upload(env: AppEnvironment, scheduleId: Int, docs: [PendingDoc], onProgress: @escaping (Int, Int) -> Void) async -> Int {
        let job = Task { @MainActor () -> Int in
            var failed = 0
            var stopMessage: String?
            for (index, doc) in docs.enumerated() {
                onProgress(index, docs.count)
                do {
                    try await PassFileUploader.upload(env: env, scheduleId: scheduleId, try PendingDocReader.data(doc))
                } catch {
                    failed += 1
                    // 남은 파일도 같은 답을 받는다 — 다 읽고 보낸 뒤에야 거절당하지 않게 멈춘다
                    if let reason = (error as? DocUploadError)?.reason, DocumentRules.stopReasons.contains(reason) {
                        stopMessage = (error as? LocalizedError)?.errorDescription
                        failed += docs.count - index - 1
                        break
                    }
                }
            }
            PendingDocReader.discard(docs)
            announce(failed: failed, stopMessage: stopMessage)
            return failed
        }
        return await job.value
    }

    /// 못 올린 것이 있으면 한 번 알린다 — 화면이 이미 없을 수 있어 앱의 토스트로
    func announce(failed: Int, stopMessage: String? = nil) {
        guard failed > 0 else { return }
        AppToast.shared.show(DocumentRules.pendingNotice(failed: failed, stopMessage: stopMessage), long: true)
    }
}

// MARK: - 칸

/// 새 플랜 등록의 **서류 칸**.
///
/// - **패스 없음** — 수정하기의 잠긴 서류 칸과 같은 모양: 무지개 테두리 · 예시 타일, 누르면 준비 패스 소개.
///   등록하는 순간이 계약서를 손에 쥔 순간이라 여기서 보여야 팔린다.
/// - **패스 있음** — 담은 것을 타일로 보이고(사진은 썸네일), `+`(앨범) · `PDF`(파일)로 더 담는다. 아직 올리지 않은
///   것이라 오른쪽 위 `×` 로 바로 뺀다(올린 서류는 길게 눌러 묻지만 여기는 묻지 않는다).
struct PendingDocsCard: View {
    var hasPass: Bool
    var docs: [PendingDoc]
    var message: String?
    /// 저장 · 올리는 중 — 더 담거나 빼지 못한다
    var busy: Bool
    var reading: Bool
    var onOpenPass: () -> Void
    var onPickPhotos: ([PhotosPickerItem]) -> Void
    var onPickPdfs: ([URL]) -> Void
    var onRemove: (PendingDoc) -> Void

    @State private var photoItems: [PhotosPickerItem] = []
    @State private var importing = false

    var body: some View {
        if !hasPass {
            PassDocsCardChrome(count: 0, locked: true) {
                LockedDocsPreview().padding(.top, 12)
                PassDocsLockedFoot(expired: false, onDownloadAll: nil, onPass: onOpenPass)
            } onOpen: { onOpenPass() }
            .accessibilityIdentifier("addplan.docs.locked")
        } else {
            PassDocsCardChrome(count: docs.count, locked: false) {
                Text("사진·PDF · 한 개 25MB 까지 · 저장하면 이 플랜에 함께 올라가요".wpKeepAll)
                    .wpTypography(13, lineHeight: 19).foregroundStyle(WPColor.fgMuted)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 12)
                FlowRow(spacing: 8, lineSpacing: 8) {
                    ForEach(docs) { doc in tile(doc) }
                    // 다 찼으면 담는 칸을 내리지 않는다 — 눌러 봐야 "10개까지" 만 듣는다
                    if docs.count < DocumentRules.maxStaged {
                        PhotosPicker(selection: $photoItems, maxSelectionCount: DocumentRules.maxStaged - docs.count,
                                     matching: .images, photoLibrary: .shared()) {
                            DocsAddTileLabel(busy: reading)
                        }
                        .buttonStyle(DocButtonStyle()).disabled(busy || reading)
                        .accessibilityLabel("사진 담기").accessibilityIdentifier("addplan.docs.photo")
                        Button { importing = true } label: { DocsPdfTileLabel() }
                            .buttonStyle(DocButtonStyle()).disabled(busy || reading)
                            .accessibilityLabel("PDF 담기").accessibilityIdentifier("addplan.docs.pdf")
                    }
                }.padding(.top, 10)
                if let message {
                    Text(message.wpKeepAll).wpTypography(11.5, lineHeight: 17).foregroundStyle(WPColor.danger)
                        .fixedSize(horizontal: false, vertical: true).padding(.top, 8)
                        .accessibilityIdentifier("addplan.docs.message")
                }
            } onOpen: {}
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                onPickPhotos(items); photoItems = []
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
                if let urls = try? result.get(), !urls.isEmpty { onPickPdfs(urls) }
            }
        }
    }

    /// 담아 둔 한 장 — 사진은 썸네일, PDF 는 문서 아이콘. 오른쪽 위 `×` 로 뺀다
    private func tile(_ doc: PendingDoc) -> some View {
        ZStack {
            WPColor.docsTileFill
            if let image = doc.thumbnail { Image(uiImage: image).resizable().scaledToFill() }
            else { WPMaterialPathIcon(paths: WPIconPaths.descriptionOutlined, size: 20, color: WPColor.docsTileIcon) }
        }
        .frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement().accessibilityLabel(doc.name)
        .overlay(alignment: .topTrailing) {
            if !busy {
                // 누름 자리는 32, 그림은 16 — 52 타일 위라 그림을 키우면 사진을 가린다
                Button { onRemove(doc) } label: {
                    Image(systemName: "xmark").font(.system(size: 7, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 16, height: 16).background(Color.black.opacity(0.6), in: Circle())
                        .padding(4).frame(width: 32, height: 32, alignment: .topTrailing).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(doc.name) 빼기")
            }
        }
    }
}
