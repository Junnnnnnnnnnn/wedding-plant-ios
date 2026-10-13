import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import WPModels
import WPDomain
import WPNetworking

struct PassDocumentsView: View {
    let scheduleId: Int
    var canAdd = false
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.openURL) private var openURL
    @State private var page: PassFilePage?
    @State private var error: String?
    @State private var importing = false
    @State private var busy = false
    @State private var pass = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var deleting: PassFileItem?
    @State private var preview: DownloadedDocument?
    @State private var opening = false
    @State private var cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("사진 · 서류").font(WPFont.hak(17, .bold)); Spacer(); Text("\(page?.list.count ?? 0)").font(WPFont.hak(13)) }
            if let page {
                if !page.canOpen { Button("준비 패스로 사진·서류 열기") { pass = true }.font(WPFont.hak(14)) }
                ForEach(page.list, id: \.id) { file in
                    HStack {
                        Button { Task { await open(file) } } label: {
                            Label(file.fileName, systemImage: file.contentType.hasPrefix("image/") ? "photo" : "doc")
                                .lineLimit(1).font(WPFont.hak(13))
                        }.disabled(!page.canOpen || busy || opening)
                        Spacer()
                        if canAdd { Button(role: .destructive) { deleting = file } label: { Image(systemName: "trash") }.disabled(busy || !page.canOpen) }
                    }.padding(.vertical, 6)
                }
                if page.canOpen && canAdd {
                    HStack {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) { Label("사진 올리기", systemImage: "photo.badge.plus") }
                        Spacer()
                        Button { importing = true } label: { Label("문서 올리기", systemImage: "doc.badge.plus") }
                    }.font(WPFont.hak(13)).disabled(busy)
                    Text("\(DocumentRules.formatStorage(page.usedBytes)) / \(DocumentRules.formatStorage(page.quotaBytes))")
                        .font(WPFont.hak(11)).foregroundStyle(.secondary)
                }
                if let roomId = page.roomId {
                    NavigationLink("전부 내려받기") { PassDownloadView(roomId: roomId) }.font(WPFont.hak(13))
                }
            } else if error == nil { ProgressView() }
            if busy { ProgressView("올리는 중…").font(WPFont.hak(13)) }
            if let error { Text(error).font(WPFont.hak(12)).foregroundStyle(.red); Button("다시 시도") { Task { await load() } } }
        }.padding(18).background(WPColor.fill, in: RoundedRectangle(cornerRadius: 16))
            .task { await load() }
            .sheet(item: $preview) { DocumentPreview(url: $0.url) }
            .fullScreenCover(isPresented: $pass) { PassView(roomId: page?.roomId) }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: false) { result in
                Task {
                    do {
                        guard let url = try result.get().first else { return }
                        let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType?.preferredMIMEType ?? "application/pdf"
                        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                        guard DocumentRules.validSize(size) else { throw APIError.backend(message: "파일은 0바이트보다 크고 25MB 이하여야 해요.") }
                        try await upload(Data(contentsOf: url, options: .mappedIfSafe), name: url.lastPathComponent, type: type)
                    } catch { self.error = error.localizedDescription }
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task {
                    do {
                        guard let raw = try await item.loadTransferable(type: Data.self), let image = UIImage(data: raw), let jpeg = image.jpegData(compressionQuality: 0.9) else { throw APIError.backend(message: "사진을 읽지 못했어요.") }
                        try await upload(jpeg, name: "사진-\(UUID().uuidString.prefix(8)).jpg", type: "image/jpeg")
                    } catch { self.error = error.localizedDescription }
                    selectedPhoto = nil
                }
            }
            .confirmationDialog("이 파일을 지울까요?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("삭제", role: .destructive) {
                    guard let file = deleting else { return }
                    Task { do { try await env.api.sendIgnoringData(Endpoint.deleteFile(file.id)); await load() } catch { self.error = error.localizedDescription }; deleting = nil }
                }
            }
    }
    private func load() async { error = nil; do { page = try await env.api.send(Endpoint.scheduleFiles(scheduleId)) } catch { self.error = error.localizedDescription } }
    private func open(_ file: PassFileItem) async {
        guard !opening else { return }; opening = true; defer { opening = false }
        do {
            let result: PassFileUrl = try await env.api.send(Endpoint.fileURL(file.id, inline: true))
            let url = try await DocumentDownload.fetch(result.url, name: file.fileName, into: cache)
            preview = DownloadedDocument(url: url)
        } catch { self.error = error.localizedDescription }
    }
    private func upload(_ bytes: Data, name: String, type: String) async throws {
        guard !busy else { return }; busy = true; error = nil; defer { busy = false }
        guard DocumentRules.validSize(bytes.count) else { throw APIError.backend(message: "파일은 0바이트보다 크고 25MB 이하여야 해요.") }
        guard DocumentRules.contentTypes.contains(type) else { throw APIError.backend(message: "사진과 PDF만 올릴 수 있어요.") }
        let slot: PassFileUpload = try await env.api.send(Endpoint.fileUpload(scheduleId: scheduleId, fileName: name, contentType: type, sizeBytes: bytes.count))
        try await SignedStorage.upload(url: slot.uploadUrl, contentType: type, bytes: bytes)
        try await env.api.sendIgnoringData(Endpoint.completeFile(slot.fileId))
        await load()
    }
}
struct PassDownloadView: View {
    let roomId: Int
    @EnvironmentObject private var env: AppEnvironment
    @State private var files: [PassDownloadItem] = []
    @State private var error: String?
    @State private var loaded = false
    @State private var progress = 0
    @State private var busy = false
    @State private var downloaded: [URL] = []
    @State private var sharing = false
    @State private var downloadTask: Task<Void, Never>?
    var body: some View {
        List {
            Text("준비 패스가 끝나도 90일 동안 내려받을 수 있어요.").font(.footnote)
            if !loaded { ProgressView() }
            else if files.isEmpty { Text("보관한 서류가 없어요") }
            else {
                Button(busy ? "내려받는 중 \(progress) / \(files.count)" : "파일 \(files.count)개 전부 내려받기") {
                    downloadTask = Task { await download() }
                }.disabled(busy)
                if busy { Button("취소", role: .cancel) { downloadTask?.cancel() } }
            }
            ForEach(Array(files.enumerated()), id: \.offset) { _, file in Label(file.fileName, systemImage: "doc") }
            if let error { Text(error).foregroundStyle(.red); Button("다시 불러오기") { Task { await load() } } }
        }.navigationTitle("전부 내려받기").task { await load() }
            .sheet(isPresented: $sharing) { ActivityShareSheet(items: downloaded) }
            .onDisappear { downloadTask?.cancel() }
    }
    private func load() async {
        error = nil
        do { let result: PassDownloadAll = try await env.api.send(Endpoint.allFiles(roomId: roomId)); files = result.list; loaded = true }
        catch { self.error = error.localizedDescription }
    }
    private func download() async {
        guard !busy else { return }; busy = true; progress = 0; error = nil; defer { busy = false }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("웨딩플랜트-서류-" + UUID().uuidString)
        do {
            // Refresh expiring storage links immediately before downloading.
            let result: PassDownloadAll = try await env.api.send(Endpoint.allFiles(roomId: roomId)); files = result.list
            var urls: [URL] = []
            for file in files {
                try Task.checkCancellation()
                urls.append(try await DocumentDownload.fetch(file.url, name: file.fileName, into: directory)); progress += 1
            }
            downloaded = urls; sharing = !urls.isEmpty
        } catch {
            try? FileManager.default.removeItem(at: directory)
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
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
