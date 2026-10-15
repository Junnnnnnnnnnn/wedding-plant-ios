import SwiftUI
import WPDomain
import WPModels
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers

struct InvitationSavedDetails: View {
    let content: InvitationContent
    let total: Int?
    let canEdit: Bool
    let busy: Bool
    let onEdit: (String) -> Void
    let onPublish: () -> Void
    let onPreview: () -> Void
    /// 공개·비공개를 바꾼 뒤의 한 줄(안드로이드 `shareNote`)
    var shareNote: String? = nil
    @State private var copied = false
    @State private var exportQR = false
    private var url: String { AppConfig.webBaseURL + "/invitation/" + content.slug }
    private var guestbookOn: Bool { InvitationRules.normalize(content.design).sections.contains { $0.type == "guestbook" && $0.visible } }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 7) {
                InvSprout(size: 15, color: content.published ? WPColor.invAccent : WPColor.invLandMuted)
                Text(content.published ? "공개 중" : "공개 전").font(invitationFont(12))
            }.foregroundStyle(content.published ? WPColor.invAccent : WPColor.invLandMuted).accessibilityElement(children: .combine)
            heading.wpTypography(23, face: .kakao, lineHeight: 32.2).tracking(-0.9).foregroundStyle(WPColor.invInk)
            VStack(alignment: .leading, spacing: 8) {
                panelTitle(content.published ? "링크와 QR로 초대해요" : "공개하면 열리는 것")
                if content.published { shareCard } else { disclosure }
                if content.published && !guestbookOn {
                    Text("댓글 관리 칸을 꺼 둬서 하객이 축하를 남길 수 없어요. 청첩장 고치기에서 다시 켤 수 있어요.".wpKeepAll).wpTypography(12, face: .kakao, lineHeight: 19.2).foregroundStyle(WPColor.invLandMuted)
                }
                if let shareNote {
                    Text(shareNote.wpKeepAll).wpTypography(12, face: .kakao, lineHeight: 19.2).foregroundStyle(WPColor.invAccent).accessibilityIdentifier("invitation.shareNote")
                }
            }.padding(.top, 6)
            VStack(spacing: 8) {
                Button("청첩장 고치기") { onEdit("layout") }.buttonStyle(InvitationLandingButton(primary: true)).disabled(!canEdit)
                if !content.published {
                    Button(busy ? "공개하는 중…" : "공개하고 링크 받기", action: onPublish).buttonStyle(InvitationLandingButton(primary: false)).disabled(!canEdit || busy)
                    Button("미리보기", action: onPreview).buttonStyle(InvitationLandingButton(primary: false))
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                panelTitle("우리 청첩장에 담긴 것 · 눌러서 고치기")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(InvitationRules.studioItems(content), id: \.key) { item in
                        Button { onEdit(item.key) } label: {
                            VStack(spacing: 4) {
                                InvitationPixelIcon(name: "item" + item.key.prefix(1).uppercased() + item.key.dropFirst()).frame(width: 32, height: 32)
                                    .saturation(item.visible ? 1 : 0).opacity(item.visible ? 1 : 0.4).padding(.bottom, 2)
                                Text(item.name).font(invitationFont(12.5, bold: true)).foregroundStyle(WPColor.invInk)
                                Text(item.visible ? item.note : "꺼 둠").font(invitationFont(10.5)).foregroundStyle(item.filled && item.visible ? WPColor.invAccent : WPColor.invLandMuted).lineLimit(1)
                            }.padding(.horizontal, 6).padding(.top, 12).padding(.bottom, 10).frame(maxWidth: .infinity, minHeight: 96)
                                .background(item.filled && item.visible ? WPColor.invSoft : WPColor.invWhite, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(item.visible && !item.filled ? WPColor.invDash : WPColor.invLine, style: StrokeStyle(lineWidth: 1, dash: item.filled && item.visible ? [] : [3,3])))
                        }.buttonStyle(.plain).disabled(!canEdit).accessibilityIdentifier("invitation.item.\(item.key)")
                    }
                }
            }.padding(.top, 6)
            Text("청첩장은 서버에 저장돼요 — 신랑·신부 누구나 어느 기기에서든 고칠 수 있어요.").wpTypography(11, face: .kakao, lineHeight: 16).foregroundStyle(WPColor.invLandMuted)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .task(id: copied) { if copied { try? await Task.sleep(for: .seconds(2)); if !Task.isCancelled { copied = false } } }
            .fileExporter(isPresented: $exportQR, document: InvitationQRDocument(data: qrImage?.pngData() ?? Data()), contentType: .png, defaultFilename: "wedding-invitation-qr") { _ in }
    }
    private var heading: Text {
        // 안드로이드 `Heading` — 한 줄은 보통, 한 줄은 굵은 초록
        let bold = { (text: String) in Text(text).font(invitationFont(23, bold: true)).foregroundColor(WPColor.invAccent) }
        if !content.published { return Text("우리 청첩장이 완성됐어요.\n") + bold("공개하면 링크가 생겨요.") }
        if let total, total > 0 { return bold("하객 \(total)명") + Text("이\n축하를 남겼어요.") }
        return Text("청첩장이 열렸어요.\n") + bold("주소와 QR로 초대해요.")
    }
    private func panelTitle(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            WPColor.invLine.frame(height: 1)
            Text(title).font(invitationFont(11)).tracking(1).foregroundStyle(WPColor.invLandMuted)
        }
    }
    private var disclosure: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("주소를 아는 누구나 로그인 없이 봐요 — 이름·예식 날짜와 장소·초대의 말·사진·축하 글, 그리고 켜 둔 칸에 적은 부모님 성함·주소·안내·계좌번호까지.".wpKeepAll).foregroundStyle(WPColor.invInk)
            Text("주소 끝은 처음 만든 사람의 이메일을 바꾼 값이라 되돌려 읽을 수 있어요. 검색에는 나오지 않고, 언제든 비공개로 돌릴 수 있어요.".wpKeepAll).foregroundStyle(WPColor.invLandMuted)
        }.wpTypography(12, face: .kakao, lineHeight: 20.4).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.vertical, 12)
            .background(WPColor.invGarden, in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(WPColor.invLine))
    }
    private var shareCard: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 6) {
                if let qrImage { Image(uiImage: qrImage).resizable().interpolation(.none).frame(width: 104, height: 104).background(.white).clipShape(RoundedRectangle(cornerRadius: 6)).accessibilityLabel("청첩장 주소 QR 코드") }
                Button { exportQR = true } label: { Text("QR 저장").underline().frame(minHeight: 28).contentShape(Rectangle()) }.buttonStyle(.plain).font(invitationFont(12)).foregroundStyle(WPColor.invLandMuted)
            }
            VStack(alignment: .leading, spacing: 8) {
                Button { UIPasteboard.general.string = url; copied = true } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(url.replacingOccurrences(of: "https://", with: "")).wpTypography(13, face: .kakao, lineHeight: 19.5).foregroundStyle(WPColor.invForest).multilineTextAlignment(.leading)
                        HStack(spacing: 4) {
                            InvIconView(copied ? InvIcon.check : InvIcon.copy, size: 12, color: copied ? WPColor.invAccent : WPColor.invLandMuted)
                            Text(copied ? "복사했어요" : "눌러서 복사").font(invitationFont(11.5, bold: copied))
                        }.foregroundStyle(copied ? WPColor.invAccent : WPColor.invLandMuted)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).padding(.vertical, 6).contentShape(Rectangle())
                }.buttonStyle(.plain).padding(.leading, -8).accessibilityIdentifier("invitation.address")
                Button(action: onPublish) {
                    HStack(spacing: 5) { InvIconView(InvIcon.lock, size: 12, color: WPColor.invLandMuted); Text(busy ? "바꾸는 중…" : "비공개로 돌리기").underline() }.frame(minHeight: 28).contentShape(Rectangle())
                }.buttonStyle(.plain).font(invitationFont(12)).foregroundStyle(WPColor.invLandMuted).opacity(!canEdit || busy ? 0.55 : 1).disabled(!canEdit || busy)
            }
        }.padding(12).background(WPColor.invGarden, in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(WPColor.invLine))
    }
    private var qrImage: UIImage? { InvitationQRCode.image(url) }
}

enum InvitationQRCode {
    static func image(_ value: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(value.utf8); filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let colors = CIFilter.falseColor(); colors.inputImage = output
        colors.color0 = CIColor(color: UIColor(WPColor.invForest)); colors.color1 = CIColor(color: .white)
        let scale = max(1, floor(480 / output.extent.width))
        guard let colored = colors.outputImage?.transformed(by: .init(scaleX: scale, y: scale)), let image = CIContext().createCGImage(colored, from: colored.extent) else { return nil }
        return UIImage(cgImage: image)
    }
}

private struct InvitationQRDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
