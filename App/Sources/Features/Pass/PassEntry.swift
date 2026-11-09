import SwiftUI
struct PassEntryButton: View {
    var motionEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sheen: CGFloat = -1
    @State private var played = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "ticket").font(.system(size: 16))
                Text("준비 패스 ›").font(WPFont.hak(15, .bold))
            }.foregroundStyle(WPColor.passEntryInk).padding(.horizontal, 13).frame(minHeight: 44)
                .background(WPColor.passEntryGold, in: Capsule())
                .overlay { GeometryReader { g in
                    if motionEnabled && !reduceMotion {
                        LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 60).offset(x: sheen * g.size.width)
                    }
                }.clipShape(Capsule()).allowsHitTesting(false) }
                .task(id: motionEnabled) {
                    guard motionEnabled && !reduceMotion && !played else { sheen = -1; return }
                    played = true
                    for _ in 0..<2 {
                        sheen = -1
                        withAnimation(.easeInOut(duration: 1.1)) { sheen = 1.5 }
                        do { try await Task.sleep(for: .milliseconds(1500)) } catch { sheen = -1; return }
                    }
                    sheen = -1
                }
        }.buttonStyle(.plain).accessibilityIdentifier("main.passEntry")
    }
}
struct PassSuggestion: View {
    let open: () -> Void
    let hide: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("준비 패스").font(WPFont.hak(18, .bold))
                Spacer()
                Button("7일간 숨기기", action: hide).font(WPFont.hak(12)).foregroundStyle(WPColor.fgMuted).frame(minHeight: 44)
            }
            Text("둘이 함께 준비할수록 편해지는\n우리만의 결혼 준비 도구").font(WPFont.hak(13)).foregroundStyle(WPColor.fgMuted).fixedSize(horizontal: false, vertical: true)
            Text("서류 보관  ·  엑셀로 받기  ·  결제일 알림  ·  광고 제거").font(WPFont.hak(11)).foregroundStyle(WPColor.primary).fixedSize(horizontal: false, vertical: true)
            Button(action: open) {
                Text("준비 패스 살펴보기 ›").font(WPFont.hak(15, .bold)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(minHeight: 44)
                    .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain)
        }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 20))
            .overlay { PassHighlightBorder(radius: 20) }.padding(16)
            .accessibilityIdentifier("main.passSuggestion")
    }
}
/// 광고 SDK 바깥, 광고를 받은 경우에만 표시한다.
struct AdRemoveEntry: View {
    @State private var open = false
    var body: some View {
        HStack {
            Spacer()
            Button("광고 제거 ›") { open = true }.font(WPFont.hak(12)).foregroundStyle(WPColor.fgMuted).frame(minHeight: 44)
        }.passCover(isPresented: $open, onPassChanged: {}) { PassView() }
    }
}
