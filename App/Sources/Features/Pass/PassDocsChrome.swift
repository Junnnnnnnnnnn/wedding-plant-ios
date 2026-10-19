import SwiftUI

// MARK: - 서류 칸의 공용 껍데기 (Android `PassDocsRowBody`)
//
// 일정 상세 · 수정하기의 서류 칸(`PassDocumentsView`)과 새 플랜의 담아 두기 칸(`PendingDocsCard`)이 같은 모양을 쓴다 —
// 저장한 뒤 수정하기에서 같은 서류를 다시 보므로, 두 칸이 어긋나면 다른 기능처럼 읽힌다.

/// 흰 카드(24) · 머리 줄(폴더 · `서류 N` · 잠겼으면 `준비 패스` 배지) · 잠겼으면 무지개 테두리와 카드 전체 누름(소개).
struct PassDocsCardChrome<Content: View>: View {
    var count: Int
    var locked: Bool
    @ViewBuilder var content: Content
    var onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                WPMaterialPathIcon(paths: DocIcon.folderOpenOutlined, size: 14, color: WPColor.primary)
                Spacer().frame(width: 6)
                // 웹 `text-[12px] text-[#7d727a]` — 굵게 쓰지 않는다
                Text(count == 0 ? "서류" : "서류 \(count)").wpTypography(12, lineHeight: 18).foregroundStyle(WPColor.detailLabel)
                if locked {
                    Spacer().frame(width: 6)
                    HStack(spacing: 4) {
                        WPMaterialPathIcon(paths: DocIcon.lockOutlined, size: 10, color: WPColor.brand700)
                        Text("준비 패스").wpTypography(10.5, .bold, lineHeight: 16).foregroundStyle(WPColor.brand700)
                    }.padding(.horizontal, 8).padding(.vertical, 2).background(WPColor.brand100, in: Capsule())
                }
                Spacer(minLength: 0)
            }
            content
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(WPColor.detailBorder, lineWidth: 1))
        // 무지개 테두리는 **잠긴 칸에만**(Android `passHighlightBorder(enabled = !hasPass)`)
        .overlay { if locked { PassHighlightBorder(radius: 24) } }
        .shadow(color: .black.opacity(0.06), radius: 1, y: 0.5)
        // 패스가 없으면 카드 전체가 소개를 연다(안드로이드 `clickable(onOpen)`)
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .onTapGesture { if locked { onOpen() } }
    }
}

/// 잠긴 칸의 바닥 — (끝난 패스면) 전부 내려받기 · 구분선 · `준비 패스 알아보기`/`패스 다시 켜기`
struct PassDocsLockedFoot: View {
    var expired: Bool
    var onDownloadAll: (() -> Void)?
    var onPass: () -> Void

    var body: some View {
        if let onDownloadAll {
            Button(action: onDownloadAll) {
                HStack(spacing: 6) {
                    WPMaterialPathIcon(paths: DocIcon.fileDownloadOutlined, size: 14, color: WPColor.fgMuted)
                    Text("전부 내려받기").wpTypography(12.5, .bold).foregroundStyle(WPColor.fgMuted)
                }.padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.white, in: Capsule()).overlay(Capsule().strokeBorder(WPColor.detailBorder, lineWidth: 1))
            }.buttonStyle(.plain).padding(.top, 12).accessibilityIdentifier("documents.downloadAll")
        }
        Rectangle().fill(WPColor.detailBorder).frame(height: 1).padding(.top, 16)
        Button(action: onPass) {
            HStack(spacing: 0) {
                Text(expired ? "패스 다시 켜기" : "준비 패스 알아보기").wpTypography(12.5, .bold).foregroundStyle(WPColor.docsPassLink)
                Spacer(minLength: 8)
                WPMaterialPathIcon(paths: DocIcon.callMade, size: 16, color: WPColor.docsPassLink)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).padding(.top, 14).accessibilityIdentifier("documents.pass")
    }
}

/// 사진 올리기(앨범) 칸 — 52 · 테두리 · `+`, 올리는 중이면 스피너
struct DocsAddTileLabel: View {
    var busy: Bool
    var body: some View {
        ZStack {
            if busy { ProgressView().tint(WPColor.primary).scaleEffect(0.8) }
            else { WPMaterialPathIcon(paths: DocIcon.add, size: 20, color: WPColor.fgSubtle) }
        }.frame(width: 52, height: 52)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(WPColor.strokeSubtle, lineWidth: 1))
    }
}

/// 계약서 PDF 칸 — 앨범에는 PDF 가 없어 파일 앱으로 고른다
struct DocsPdfTileLabel: View {
    var body: some View {
        Text("PDF").wpTypography(12, .bold).foregroundStyle(WPColor.fgSubtle).frame(width: 52, height: 52)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(WPColor.strokeSubtle, lineWidth: 1))
    }
}

// MARK: - 잠긴 칸의 예시 (Android `LockedDocsPreview`, 웹 main 1bec002)

/// 설명 문단 대신 붙은 모양을 먼저 보인다(2026-10-17 사용자 "설명을 쓰는 것보다 사진 + 레이아웃을 넣는 게 더 직관적").
/// 타일은 패스가 있을 때의 칸과 같은 52 라 "사면 여기가 이렇게 찬다" 로 읽힌다. 마지막 `+` 의 자물쇠가 붙이는 자리가
/// 잠겨 있다는 것까지 그림으로 말한다. 누름은 카드 전체가 받는다(소개).
struct LockedDocsPreview: View {
    private static let paperLine = Color(hex: 0xD7C9CE)     // Android `V2PaperLine`
    private static let docsLine = Color(hex: 0xD8CBD2)      // `V2DocsPaperLine`
    private static let ink = Color(hex: 0x4E384C)           // `V2DemoInk`

    var body: some View {
        FlowRow(spacing: 8, lineSpacing: 8) {
            tile("계약서") { contract }
            tile("영수증") { receipt }
            tile("사진") {
                // 얼굴이 칸 안에 들게 위쪽을 조금 더 남긴다(Android `BiasAlignment(0, -0.35)`)
                if let image = UIImage(named: "pass_invite_portrait"), image.size.width > 0 {
                    let scale = max(52 / image.size.width, 52 / image.size.height)
                    let width = image.size.width * scale, height = image.size.height * scale
                    Image(uiImage: image).resizable()
                        .frame(width: width, height: height)
                        .offset(x: 0, y: (height - 52) * (0.5 - 0.325))
                        .frame(width: 52, height: 52)
                }
            }
            ZStack(alignment: .topTrailing) {
                WPMaterialPathIcon(paths: DocIcon.add, size: 20, color: WPColor.fgSubtle).frame(width: 52, height: 52)
                WPMaterialPathIcon(paths: DocIcon.lockOutlined, size: 10, color: Color(hex: 0xCC1873))
                    .frame(width: 16, height: 16).background(Color(hex: 0xFFF1F7), in: Circle()).padding(4)
            }
            .frame(width: 52, height: 52)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(WPColor.detailBorder, lineWidth: 1))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("계약서 · 영수증 · 사진을 붙인 예시")
    }

    /// 예시 서류 한 칸 — 진짜 타일과 같은 바탕 · 크기, 아래에 무엇인지 한 낱말(글꼴은 1.3배에서 멈춘다)
    private func tile<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(spacing: 6) {
            ZStack { WPColor.docsTileFill; content() }
                .frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(label).wpTypography(11, lineHeight: 14).foregroundStyle(WPColor.detailLabel).lineLimit(1).fixedSize()
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
        }
    }

    /// 계약서 — 비스듬히 놓인 종이 · 제목 줄 · 본문 줄 · 도장
    private var contract: some View {
        Canvas { ctx, size in
            let rect = CGRect(origin: .zero, size: size)
            let paper = Path(roundedRect: rect, cornerRadius: 2)
            ctx.fill(paper, with: .color(.white))
            ctx.stroke(paper, with: .color(Self.paperLine), lineWidth: 1)
            let pad: CGFloat = 5, w = size.width - pad * 2
            ctx.fill(Path(CGRect(x: pad + w * 0.2, y: 5, width: w * 0.6, height: 2)), with: .color(Self.ink.opacity(0.5)))
            for (i, k) in [1, 0.85, 1, 0.6].enumerated() {
                ctx.fill(Path(CGRect(x: pad, y: 11 + CGFloat(i) * 4.5, width: w * k, height: 1.5)), with: .color(Self.docsLine))
            }
            let c = CGPoint(x: size.width - pad - 2, y: size.height - 7)
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - 3.5, y: c.y - 3.5, width: 7, height: 7)), with: .color(WPColor.danger.opacity(0.7)), lineWidth: 1.2)
        }
        .frame(width: 30, height: 38)
        .shadow(color: .black.opacity(0.08), radius: 0.5, y: 0.5)
        .rotationEffect(.degrees(-5))
    }

    /// 영수증 — 좁은 종이 · 아래 톱니 · 품목과 값 · 점선 아래 합계
    private var receipt: some View {
        Canvas { ctx, size in
            let tooth: CGFloat = 2.5, teeth = 5, step = size.width / CGFloat(teeth)
            var paper = Path()
            paper.move(to: .zero); paper.addLine(to: CGPoint(x: size.width, y: 0)); paper.addLine(to: CGPoint(x: size.width, y: size.height - tooth))
            for i in stride(from: teeth - 1, through: 0, by: -1) {
                paper.addLine(to: CGPoint(x: step * CGFloat(i) + step / 2, y: size.height))
                paper.addLine(to: CGPoint(x: step * CGFloat(i), y: size.height - tooth))
            }
            paper.closeSubpath()
            ctx.fill(paper, with: .color(.white))
            ctx.stroke(paper, with: .color(Self.paperLine), lineWidth: 1)
            let pad: CGFloat = 4, w = size.width - pad * 2
            ctx.fill(Path(CGRect(x: pad + w * 0.15, y: 4, width: w * 0.7, height: 2)), with: .color(Self.ink.opacity(0.5)))
            for i in 0..<3 {
                let y = 10 + CGFloat(i) * 4
                ctx.fill(Path(CGRect(x: pad, y: y, width: w * 0.5, height: 1.5)), with: .color(Self.docsLine))
                ctx.fill(Path(CGRect(x: pad + w * 0.7, y: y, width: w * 0.3, height: 1.5)), with: .color(Self.docsLine))
            }
            var dash = Path(); dash.move(to: CGPoint(x: pad, y: 23)); dash.addLine(to: CGPoint(x: size.width - pad, y: 23))
            ctx.stroke(dash, with: .color(Self.docsLine), style: StrokeStyle(lineWidth: 1, dash: [2, 1.5]))
            ctx.fill(Path(CGRect(x: pad, y: 27, width: w * 0.35, height: 2)), with: .color(Self.ink.opacity(0.6)))
            ctx.fill(Path(CGRect(x: pad + w * 0.55, y: 27, width: w * 0.45, height: 2)), with: .color(WPColor.primary))
        }
        .frame(width: 24, height: 40)
        .rotationEffect(.degrees(4))
    }
}
