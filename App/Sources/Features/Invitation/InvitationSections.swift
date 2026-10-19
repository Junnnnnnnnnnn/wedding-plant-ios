import SwiftUI
import WPDomain
import WPModels

struct InvitationGuestbookSection: View {
    let content: InvitationContent
    let editing: Bool
    var motionEnabled = true
    let toast: (String) -> Void
    private var p: InvitationPalette { .init(content.template) }
    private let muted = Color(hex: 0xBFCEC3)
    var body: some View {
        VStack(spacing: 0) {
            Text("A GARDEN FULL OF WISHES").font(.custom("KakaoSmallSans-Regular", size: 9)).tracking(2).foregroundStyle(p.bright)
            Text("축하의 정원").font(.custom("KakaoSmallSans-Light", size: 27)).tracking(-1.2).foregroundStyle(Color(hex: 0xF8EDCF)).padding(.top, 20)
            Text("바다 앞 작은 결혼식에\n당신의 따뜻한 마음도 함께해 주세요.").wpTypography(12, face: .kakao, lineHeight: 22.8).padding(.vertical, -2).multilineTextAlignment(.center).foregroundStyle(muted).padding(.top, 16)
            HStack(spacing: 8) {
                Circle().fill(Color(hex: 0xACD0B5)).frame(width: 5, height: 5).background(Circle().fill(Color(hex: 0xACD0B5).opacity(0.35)).padding(-2.5))
                Text("공개하면 하객이 남긴 축하가 여기 모여요").font(.custom("KakaoSmallSans-Regular", size: 10)).foregroundStyle(muted).frame(maxWidth: .infinity, alignment: .leading)
                InvIconView(InvIcon.heart, size: 12, color: p.bright)
                Text("—개의 축하").font(.custom("KakaoSmallSans-Regular", size: 9))
            }.foregroundStyle(p.bright).padding(.horizontal, 24).padding(.top, 32).padding(.bottom, 16)
            SeasideGardenView(wishes: [
                .init(id: "example-1", name: "축하의 별", message: "두 사람의 모든 계절을 응원해요", avatar: 3),
                .init(id: "example-2", name: "행복한 마음", message: "오래오래, 지금처럼 다정하게", avatar: 16),
                .init(id: "example-3", name: "작은 꽃", message: "세상에서 가장 빛나는 날이 되길", avatar: 1),
                .init(id: "example-4", name: "따뜻한 축복", message: "함께 걷는 길에 늘 꽃이 피기를", avatar: 19)
            ], groom: content.groom, bride: content.bride, labelNote: "예시 글", motionEnabled: motionEnabled).aspectRatio(320.0 / 440, contentMode: .fit)
            VStack(spacing: 16) {
                Button { toast("미리보기에서는 보내지 않아요") } label: {
                    HStack(spacing: 12) {
                        InvIconView(InvIcon.send, size: 15, color: p.deep)
                        Text("축하 글 남기기").font(.custom("KakaoSmallSans-Regular", size: 12)).frame(maxWidth: .infinity, alignment: .leading)
                        InvIconView(InvIcon.arrowRight, size: 16, color: p.deep)
                    }.foregroundStyle(p.deep).padding(.horizontal, 20).padding(.vertical, 12).frame(minHeight: 50).background(p.bright, in: RoundedRectangle(cornerRadius: 2)).overlay(RoundedRectangle(cornerRadius: 2).stroke(p.gold))
                }.buttonStyle(.plain).allowsHitTesting(!editing)
                Button { toast("공개하면 하객이 남긴 축하 글을 모아 볼 수 있어요") } label: {
                    HStack(spacing: 8) { InvIconView(InvIcon.users, size: 14, color: p.bright); Text("축하 글 전체 보기").font(.custom("KakaoSmallSans-Regular", size: 11)) }
                        .foregroundStyle(p.bright).padding(8).frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).allowsHitTesting(!editing)
            }.padding(.horizontal, 24).padding(.top, 24)
        }.frame(maxWidth: .infinity).padding(.top, 64).padding(.bottom, 40).background(p.night)
    }
}

/// Local uploads stay visible before the server assigns a read URL. Only object keys are saved.
struct InvitationPhotoImage: View {
    let url: URL
    var mode: ContentMode = .fill
    var body: some View {
        GeometryReader { geometry in
            Group {
                if url.isFileURL, let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: mode)
                } else {
                    AsyncImage(url: url) { image in image.resizable().aspectRatio(contentMode: mode) } placeholder: { Color.gray.opacity(0.12) }
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
    }
}

struct InvitationGallery: View {
    let content: InvitationContent
    let editing: Bool
    let select: (Int) -> Void
    let add: () -> Void
    private var p: InvitationPalette { .init(content.template) }
    private var slots: Int { editing ? max(20, content.photos.count) : content.photos.count }
    private var rows: [InvitationRules.GalleryRow] { InvitationRules.galleryRows(count: slots, layout: InvitationRules.normalize(content.design).galleryLayout) }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("THE MOMENTS").tracking(2).foregroundStyle(p.gold)
                Spacer()
                Text("기억을 모아, 사랑을 담아").foregroundStyle(p.muted)
            }.font(.custom("KakaoSmallSans-Regular", size: 9))
            GeometryReader { geometry in title(size: min(64, max(46, (geometry.size.width + 48) * 0.13))) }
                .frame(height: 120).padding(.top, 24)
            Text("우리의 가장 빛나는 순간들.\n사진을 누르면 조금 더 가까이 볼 수 있어요.")
                .wpTypography(12, face: .kakao, lineHeight: 22.8).padding(.vertical, -2).foregroundStyle(p.muted).padding(.top, 24)
            // An adaptive layout measures width without imposing a fixed height on the scroll view.
            GalleryRowsLayout(rows: rows) {
                ForEach(0..<slots, id: \.self) { index in tile(index) }
            }.padding(.top, 28).id("galleryGrid")
            if editing {
                Text("사진 \(content.photos.count) / 20장 · 빈 자리를 누르면 사진을 올려요")
                    .font(.custom("KakaoSmallSans-Regular", size: 9)).foregroundStyle(p.muted)
                    .frame(maxWidth: .infinity).padding(.top, 28)
            }
        }.padding(.horizontal, 24).padding(.top, 72).padding(.bottom, 56).background(p.paper)
    }
    private func title(size: CGFloat) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Every little").font(.custom("NotoSerif", size: size)).foregroundStyle(p.ink)
                Text("moment.").font(.custom("NotoSerif-Italic", size: size)).foregroundStyle(p.gold)
            }.tracking(-2)
            Spacer(minLength: 0)
            InvitationFlower().stroke(p.gold, lineWidth: 1.2).frame(width: 36, height: 36).padding(.trailing, 12).padding(.bottom, 6)
        }
    }
    private func tile(_ index: Int) -> some View {
        Button { if index < content.photos.count { select(index) } else { add() } } label: {
            GeometryReader { geometry in
                ZStack {
                    p.placeholder
                    if index < content.photos.count {
                        if let url = content.photos[index].url.flatMap(URL.init(string:)) {
                            InvitationPhotoImage(url: url).frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        }
                        VStack {
                            HStack {
                                Text(String(format: "%02d", index + 1)).font(.custom("NotoSerif", size: 13)).shadow(radius: 5)
                                Spacer()
                                if index == 0 && editing { Text("표지").font(.custom("KakaoSmallSans-Bold", size: 10)).padding(6).background(p.forest, in: Capsule()) }
                            }
                            Spacer()
                            HStack { Spacer(); InvIconView(InvIcon.maximize, size: 15, color: Color(hex: 0xF8EDCF)) }
                        }.padding(10).foregroundStyle(Color(hex: 0xF8EDCF))
                    } else {
                        let next = index == content.photos.count
                        (next ? p.placeholder : p.soft)
                        Rectangle().strokeBorder(next ? p.gold : p.rule, style: StrokeStyle(lineWidth: next ? 1.5 : 1, dash: next ? [] : [6,5]))
                        VStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                            Text(next ? "사진 올리기" : String(format: "%02d", index + 1)).font(.custom("KakaoSmallSans-Regular", size: 10))
                        }.foregroundStyle(next ? p.ink : p.muted)
                    }
                }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
            }
        }.buttonStyle(.plain).accessibilityLabel(index < content.photos.count ? "\(index + 1)번 사진 보기" : "사진 올리기")
    }
}

private struct GalleryRowsLayout: Layout {
    let rows: [InvitationRules.GalleryRow]
    private func frames(width: CGFloat) -> [CGRect] {
        var result: [CGRect] = []; var y: CGFloat = 0
        let gap: CGFloat = 8, col = (width - 40) / 6
        func span(_ n: Int) -> CGFloat { col * CGFloat(n) + gap * CGFloat(n - 1) }
        for row in rows {
            switch row {
            case .mosaic(_, let top, let bottom):
                let w = span(4), h = w * 1.5, small = (h - gap) / 2
                result.append(CGRect(x: 0, y: y, width: w, height: h))
                if top != nil { result.append(CGRect(x: w + gap, y: y, width: span(2), height: small)) }
                if bottom != nil { result.append(CGRect(x: w + gap, y: y + small + gap, width: span(2), height: small)) }
                y += h + gap
            case .even(let indices, let perRow, let aspect):
                let w = span(perRow == 2 ? 3 : 2), h = w / aspect
                for offset in indices.indices { result.append(CGRect(x: CGFloat(offset) * (w + gap), y: y, width: w, height: h)) }
                y += h + gap
            }
        }
        return result
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = max(48, proposal.width ?? 320)
        return CGSize(width: width, height: frames(width: width).map(\.maxY).max() ?? 0)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, frame) in frames(width: bounds.width).enumerated() where index < subviews.count {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), anchor: .topLeading, proposal: ProposedViewSize(frame.size))
        }
    }
}

struct InvitationLocation: View {
    let content: InvitationContent
    let editing: Bool
    let toast: (String) -> Void
    @Environment(\.openURL) private var openURL
    private var p: InvitationPalette { .init(content.template) }
    private var location: InvitationLocationBody { InvitationRules.normalize(content.design).location }
    private var address: String { location.address.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var query: String { address.isEmpty ? content.venue.trimmingCharacters(in: .whitespacesAndNewlines) : address }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("OUR PLACE").font(.custom("KakaoSmallSans-Regular", size: 9)).tracking(3).foregroundStyle(p.muted)
            HStack { Text("오시는 길").font(.custom("KakaoSmallSans-Regular", size: 21)).tracking(-0.7); Spacer(); InvitationFlower().stroke(p.gold, lineWidth: 1).frame(width: 26, height: 26) }.padding(.top, 12).padding(.bottom, 32)
            row("WHERE") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(content.venue.isEmpty ? "예식장 이름과 주소가 들어갈 자리" : content.venue).font(.custom("KakaoSmallSans-Regular", size: 14))
                    if !address.isEmpty { Text(address).font(.custom("KakaoSmallSans-Regular", size: 11)).foregroundStyle(p.muted) }
                }
            }
            if !location.guide.isEmpty { row("HOW") { Text(location.guide).wpTypography(13, face: .kakao, lineHeight: 24.7).padding(.vertical, -3) } }
            Button { openMap("https://map.kakao.com/link/search/") } label: {
                VStack(spacing: 12) {
                    InvIconView(query.isEmpty ? InvIcon.leaf : InvIcon.mapPin, size: 27, color: p.placeholderDark, weight: 1)
                    Text("두 사람에게 오는 길").font(.custom("KakaoSmallSans-Regular", size: 12))
                    Text(query.isEmpty ? "장소를 적으면 지도로 이어져요" : "카카오맵에서 \(content.venue.isEmpty ? address : content.venue) 찾기").font(.custom("KakaoSmallSans-Regular", size: 10))
                }.foregroundStyle(p.placeholderDark).frame(maxWidth: .infinity).frame(height: 164)
                    .background(p.placeholder).overlay { HatchLines().stroke(p.ink.opacity(0.08), lineWidth: 1).clipped() }
                    .overlay(Rectangle().stroke(p.rule))
            }.buttonStyle(.plain).allowsHitTesting(!editing && !query.isEmpty).padding(.top, 12)
            if !query.isEmpty {
                HStack(spacing: 8) {
                    mapButton("네이버 지도") { openMap("https://map.naver.com/p/search/") }
                    if !address.isEmpty { mapButton("주소 복사") { UIPasteboard.general.string = address; toast("예식장 주소를 복사했어요") } }
                }.padding(.top, 8).allowsHitTesting(!editing)
            }
        }.foregroundStyle(p.ink).padding(.horizontal, 32).padding(.vertical, 48).background(p.soft)
    }
    private func row<V: View>(_ title: String, @ViewBuilder value: () -> V) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.custom("KakaoSmallSans-Regular", size: 9)).tracking(1.7).foregroundStyle(p.muted).frame(width: 56, alignment: .leading)
            value().frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.vertical, 20).overlay(alignment: .top) { Rectangle().fill(p.rule).frame(height: 1) }
    }
    private func mapButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { HStack(spacing: 6) { if title == "주소 복사" { InvIconView(InvIcon.copy, size: 12, color: p.forest) }; Text(title) }.foregroundStyle(p.forest).font(.custom("KakaoSmallSans-Regular", size: 12)).frame(maxWidth: .infinity).frame(minHeight: 44).background(p.paper).overlay(Rectangle().stroke(p.rule)) }.buttonStyle(.plain)
    }
    private func openMap(_ base: String) {
        if let encoded = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics), let url = URL(string: base + encoded) { openURL(url) }
    }
}
private struct HatchLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(); let diag = rect.width + rect.height, dx = cos(Double.pi * 35 / 180), dy = sin(Double.pi * 35 / 180)
        for d in stride(from: -diag, to: diag, by: 33) {
            let x = d * dy, y = -d * dx + rect.height / 2
            path.move(to: CGPoint(x: x - dx * diag, y: y - dy * diag)); path.addLine(to: CGPoint(x: x + dx * diag, y: y + dy * diag))
        }
        return path
    }
}

struct InvitationAccounts: View {
    let content: InvitationContent
    let editing: Bool
    let toast: (String) -> Void
    @State private var open: String?
    private var p: InvitationPalette { .init(content.template) }
    /// 하객에게는 은행·계좌번호까지 적은 줄만(웹·안드로이드 `readyAccounts`). 편집 중에는 한 글자라도 적은 줄을 보입니다 —
    /// 예금주부터 적는 동안 미리보기가 비어 있으면 "적는 게 반영되지 않는다" 로 읽혔습니다(2026-10-19 사용자 실기기 보고).
    /// 아직 하객에게 안 보이는 줄은 그 아래에 그렇다고 적습니다. 번호(`index`)는 자리 순서 그대로라 편집기의 칸과 짝이 맞습니다.
    private var accounts: [(index: Int, account: InvitationAccountBody)] {
        InvitationRules.normalize(content.design).accounts.enumerated().map { (index: $0.offset, account: $0.element) }.filter { item in
            let a = item.account
            return InvitationRules.isAccountReady(a) || (editing && !(a.name.isEmpty && a.bank.isEmpty && a.number.isEmpty))
        }
    }
    var body: some View {
        VStack(spacing: 12) {
            Text("마음 전하실 곳").font(.custom("KakaoSmallSans-Regular", size: 21)).tracking(-0.7)
            Text("참석이 어려우신 분들을 위해 적어 두었어요.\n보내 주시는 마음, 오래 간직하겠습니다.").wpTypography(12, face: .kakao, lineHeight: 22.8).padding(.vertical, -2).multilineTextAlignment(.center).foregroundStyle(p.muted).padding(.bottom, 20)
            if accounts.isEmpty { Text("은행과 계좌번호를 적은 줄만 하객에게 보여요").font(.custom("KakaoSmallSans-Regular", size: 12)).foregroundStyle(p.muted) }
            ForEach(["groom", "bride"], id: \.self) { side in
                let rows = accounts.filter { $0.account.side == side }
                let expanded = editing || open == side
                if !rows.isEmpty {
                    VStack(spacing: 0) {
                        Button { withAnimation(.timingCurve(0.2, 0.65, 0.25, 1, duration: 0.45)) { open = expanded ? nil : side } } label: {
                            HStack { Text(side == "groom" ? "신랑 측 계좌번호" : "신부 측 계좌번호"); Spacer(); InvIconView(InvIcon.chevronDown, size: 18, color: p.gold, weight: 1.4).rotationEffect(.degrees(expanded ? 180 : 0)) }
                                .font(.custom("KakaoSmallSans-Regular", size: 16)).foregroundStyle(p.forest).padding(.horizontal, 20).frame(minHeight: 56)
                        }.buttonStyle(.plain).allowsHitTesting(!editing)
                        if expanded { ForEach(rows, id: \.index) { row in accountRow(row.account).id("account.\(row.index)") }.transition(.opacity.combined(with: .move(edge: .top))) }
                    }.background(p.soft).overlay(Rectangle().stroke(p.rule)).clipped()
                }
            }
        }.frame(maxWidth: .infinity).foregroundStyle(p.ink).padding(.horizontal, 32).padding(.top, 56).padding(.bottom, 48).background(p.paper)
    }
    private func accountRow(_ account: InvitationAccountBody) -> some View {
        let name = account.name.isEmpty ? (account.role == "신랑" ? content.groom : account.role == "신부" ? content.bride : "성함 미정") : account.name
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) { Text(account.role).font(.custom("KakaoSmallSans-Regular", size: 11)).foregroundStyle(p.muted); Text(name).font(.custom("KakaoSmallSans-Regular", size: 14)) }
                Text(account.bank).font(.custom("KakaoSmallSans-Regular", size: 11)).foregroundStyle(p.muted)
                Text(account.number).font(.custom("KakaoSmallSans-Regular", size: 13)).lineLimit(1)
                if editing && !InvitationRules.isAccountReady(account) {
                    Text("은행과 계좌번호까지 적으면 하객에게 보여요".wpKeepAll).font(.custom("KakaoSmallSans-Regular", size: 11)).foregroundStyle(p.muted)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Button { UIPasteboard.general.string = "\(account.bank) \(account.number)"; toast("\(name) 님 계좌를 복사했어요") } label: {
                HStack(spacing: 4) { InvIconView(InvIcon.copy, size: 13, color: p.forest); Text("복사").font(.custom("KakaoSmallSans-Regular", size: 16)) }
                    .foregroundStyle(p.forest).padding(.horizontal, 14).frame(minHeight: 44).background(p.paper).overlay(Rectangle().stroke(p.gold))
            }.buttonStyle(.plain).allowsHitTesting(!editing)
        }.padding(.vertical, 16).overlay(alignment: .top) { Rectangle().fill(p.rule).frame(height: 1) }.padding(.horizontal, 20)
    }
}
