import SwiftUI
import QuickLook
import WPNetworking

struct DocumentPreview: UIViewControllerRepresentable {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(url, dismiss: { dismiss() }) }
    func makeUIViewController(context: Context) -> UINavigationController {
        let preview = QLPreviewController()
        preview.dataSource = context.coordinator
        preview.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "닫기", style: .done,
            target: context.coordinator, action: #selector(Coordinator.close))
        preview.navigationItem.leftBarButtonItem?.accessibilityIdentifier = "document.close"
        return UINavigationController(rootViewController: preview)
    }
    func updateUIViewController(_ controller: UINavigationController, context: Context) {}
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        let dismiss: () -> Void
        init(_ url: URL, dismiss: @escaping () -> Void) { self.url = url; self.dismiss = dismiss }
        @objc func close() { dismiss() }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}
struct DownloadedDocument: Identifiable { let url: URL; var id: URL { url } }

enum DocumentDownload {
    /// Signed storage request deliberately uses no API authorization header.
    static func fetch(_ raw: String, name: String, into directory: URL) async throws -> URL {
        guard let url = URL(string: raw), url.scheme?.lowercased() == "https" else { throw APIError.invalidURL("파일 주소가 올바르지 않아요.") }
        let (temporary, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw APIError.backend(message: "파일을 내려받지 못했어요. 다시 시도해 주세요.") }
        try Task.checkCancellation()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let safeName = URL(fileURLWithPath: name).lastPathComponent
        let destination = directory.appendingPathComponent(safeName.isEmpty ? "문서" : safeName)
        var unique = destination
        if FileManager.default.fileExists(atPath: unique.path) { unique = directory.appendingPathComponent(UUID().uuidString.prefix(8) + "-" + safeName) }
        try FileManager.default.moveItem(at: temporary, to: unique)
        return unique
    }
}
