import SwiftUI
import WPModels

struct InvitationPalette {
    let forest, ink, paper, soft, gold, bright, muted, rule, placeholder: Color
    let deep, night: Color
    init(_ template: String) {
        let values: [UInt32]
        switch template {
        case "ivory": values = [0x5B4A3A,0x57483A,0xFFFDF7,0xF4EFE4,0xA88E5E,0xECDCB8,0x7C6F60,0xE6DCCB,0xE6DDCF]
        case "rose": values = [0x7A3F4C,0x6A4450,0xFFF7F5,0xF9EAE7,0xB97F70,0xF4CFC4,0x876A70,0xECD5D0,0xEFDCD8]
        default: values = [0x183E32,0x29463A,0xF7F4EC,0xEEEADE,0xB5975F,0xEFDAA5,0x767C6E,0xDCD6C5,0xC6C8C4]
        }
        deep = Color(hex: template == "ivory" ? 0x3F342A : template == "rose" ? 0x5A2E38 : 0x112B25)
        night = Color(hex: template == "ivory" ? 0x4A3D31 : template == "rose" ? 0x64343F : 0x162C30)
        forest = Color(hex: values[0]); ink = Color(hex: values[1]); paper = Color(hex: values[2]); soft = Color(hex: values[3]); gold = Color(hex: values[4]); bright = Color(hex: values[5]); muted = Color(hex: values[6]); rule = Color(hex: values[7]); placeholder = Color(hex: values[8])
    }
}

/// Android InvitationBody.Hero: same 700ms delay, 2400ms linear clock and derived curves.
struct InvitationHero: View {
    let content: InvitationContent
    let height: CGFloat
    let started: Date?
    let replay: () -> Void
    let share: () -> Void
    var edit: (() -> Void)?
    var selected = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var p: InvitationPalette { .init(content.template) }
    private let cream = Color(hex: 0xF8EDCF)
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { context in
            let elapsed = started.map { context.date.timeIntervalSince($0) } ?? 4
            let progress = reduceMotion ? 1 : min(1, max(0, (elapsed - 0.7) / 2.4))
            GeometryReader { geometry in
                scene(width: geometry.size.width, progress: progress, elapsed: elapsed)
            }
        }.frame(height: height).clipped().background(p.forest)
    }
    private func scene(width: CGFloat, progress: Double, elapsed: Double) -> some View {
        let eased = 0.3 * progress + 0.7 * progress * progress * (3 - 2 * progress)
        let copy = min(1, max(0, (progress - 0.3) / 0.5))
        return ZStack {
            p.forest
            if let url = content.photos.first?.url.flatMap(URL.init(string:)) {
                InvitationPhotoImage(url: url, mode: .fill)
                    .frame(width: width, height: height).clipped().opacity(min(1, progress * 8)).scaleEffect(1.035 - 0.035 * eased)
            }
            LinearGradient(stops: [.init(color: Color(hex: 0x112B25).opacity(0.3), location: 0), .init(color: .clear, location: 0.38), .init(color: .clear, location: 0.48), .init(color: Color(hex: 0x1A1E1A).opacity(0.78), location: 1)], startPoint: .top, endPoint: .bottom)
            corners.padding(.top, 92).padding(.horizontal, 20).padding(.bottom, 20)
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Text(content.title.isEmpty ? "우리, 결혼합니다" : content.title).font(.custom("KakaoSmallSans-Light", size: min(40, max(30, width * 0.08)))).tracking(-1.7)
                HStack(spacing: 12) {
                    Text(content.groom.isEmpty ? "신랑" : content.groom).tracking(4)
                    Image(systemName: "heart.fill").font(.system(size: 11)).foregroundStyle(p.bright)
                    Text(content.bride.isEmpty ? "신부" : content.bride).tracking(4)
                }.font(.custom("KakaoSmallSans-Regular", size: 15)).padding(.top, 24)
                Text("소중한 당신을, 우리의 시작에 초대합니다.").font(.custom("KakaoSmallSans-Regular", size: 11)).tracking(0.4).padding(.top, 12)
                Image(systemName: "arrow.down").font(.system(size: 17)).foregroundStyle(p.bright).frame(height: 44).padding(.top, 32)
            }.frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(cream).padding(.horizontal, 32).padding(.bottom, 40).opacity(copy).offset(y: (1 - copy) * 12)
            if progress < 1 {
                HStack(spacing: 0) {
                    half(left: true, width: width).rotation3DEffect(.degrees(-104 * eased), axis: (x: 0,y: 1,z: 0), anchor: .leading, perspective: 0.25)
                    half(left: false, width: width).rotation3DEffect(.degrees(104 * eased), axis: (x: 0,y: 1,z: 0), anchor: .trailing, perspective: 0.25)
                }.opacity(104 * eased < 90 ? 1 : 0)
                gateCopy(width: width).opacity(1 - min(1, progress / 0.24))
            }
            if !reduceMotion { sparkle(time: max(0, elapsed) * 1000, burst: progress >= 1) }
            VStack {
                HStack {
                    Button(action: replay) { Text("W").font(.custom("NotoSerif", size: 26)).foregroundStyle(p.bright).frame(width: 44, height: 44).background(Color(hex: 0x112B25).opacity(0.3), in: Circle()).overlay(Circle().stroke(p.bright.opacity(0.35), lineWidth: 1)) }.accessibilityLabel("문 열림 다시 보기")
                    Spacer()
                    Button(action: share) { Image(systemName: "square.and.arrow.up").font(.system(size: 17)).foregroundStyle(cream).frame(width: 44, height: 44) }.accessibilityLabel("청첩장 전하기")
                }.padding(.horizontal, 24).padding(.vertical, 20)
                if let edit {
                    VStack(alignment: .trailing, spacing: 10) {
                    InvitationEditBadge(selected: selected)
                    Button(action: edit) { Label(content.photos.isEmpty ? "표지 사진 올리기" : "표지 사진 바꾸기", systemImage: "camera").font(.custom("KakaoSmallSans-Bold", size: 12)).padding(10).background(cream, in: Capsule()).foregroundStyle(p.forest) } }.frame(maxWidth: .infinity, alignment: .trailing).padding(.horizontal, 30).padding(.top, 10)
                }
                Spacer()
            }
        }.frame(width: width, height: height)
    }
    private func half(left: Bool, width: CGFloat) -> some View {
        Image(uiImage: UIImage(named: "invitation_door.png") ?? UIImage()).resizable().scaledToFill().frame(width: width, height: height).clipped()
            .frame(width: width / 2, height: height, alignment: left ? .leading : .trailing).clipped()
    }
    private func gateCopy(width: CGFloat) -> some View {
        let size = min(104, max(66, width * 0.18))
        return ZStack {
            LinearGradient(stops: [.init(color: Color(hex: 0x112B25).opacity(0.3), location: 0), .init(color: .clear, location: 0.3), .init(color: Color(hex: 0x112B25).opacity(0.3), location: 0.52), .init(color: Color(hex: 0x112B25).opacity(0.85), location: 1)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 16) {
                Text("YOU ARE INVITED").font(.custom("KakaoSmallSans-Regular", size: 9)).tracking(3)
                Text("OUR SECRET GARDEN").font(.custom("KakaoSmallSans-Regular", size: 8)).tracking(2.8).padding(.horizontal, 16).padding(.vertical, 8).overlay(alignment: .top) { p.bright.opacity(0.35).frame(height: 1) }.overlay(alignment: .bottom) { p.bright.opacity(0.35).frame(height: 1) }
                Spacer()
            }.padding(.top, 116)
            VStack(spacing: 0) {
                Spacer()
                Text("a new beginning").font(.custom("NotoSerif-Italic", size: 16)).foregroundStyle(p.bright).padding(.bottom, 12)
                Text("Love").font(.custom("NotoSerif", size: size)).tracking(-4)
                Text("in bloom.").font(.custom("NotoSerif-Italic", size: size * 0.83)).tracking(-4).padding(.top, -12)
                p.bright.opacity(0.35).frame(width: 1, height: 32).padding(.top, 24)
                Text("우리의 이야기가 피어나는 곳").font(.custom("KakaoSmallSans-Regular", size: 11)).tracking(1.5).padding(.top, 16)
                Label("아래로 스크롤해 문을 열어 주세요", systemImage: "arrow.down").font(.custom("KakaoSmallSans-Regular", size: 11)).foregroundStyle(p.bright).padding(.top, 28)
            }.padding(.bottom, 84)
        }.foregroundStyle(cream).allowsHitTesting(false)
    }
    private var corners: some View {
        Canvas { context, size in
            var path = Path()
            for (x,y,dx,dy) in [(0.0,0.0,1.0,1.0),(size.width,0.0,-1.0,1.0),(0.0,size.height,1.0,-1.0),(size.width,size.height,-1.0,-1.0)] {
                path.move(to: CGPoint(x: x + dx * 24,y: y)); path.addLine(to: CGPoint(x: x,y: y)); path.addLine(to: CGPoint(x: x,y: y + dy * 24))
            }
            context.stroke(path, with: .color(p.bright.opacity(0.35)), lineWidth: 1)
        }.allowsHitTesting(false)
    }
    private func sparkle(time: Double, burst: Bool) -> some View {
        Canvas { context, size in
            for i in 0..<(burst ? 38 : 24) {
                let phase = Double(i) * 2.1, radius = i % 5 == 0 ? 2.2 : 1.0
                let rawY = Double((i * 137 + 31) % 991) / 991 * size.height - time * (burst ? 0.025 : 0.008)
                let y = (rawY.truncatingRemainder(dividingBy: size.height) + size.height).truncatingRemainder(dividingBy: size.height)
                let x = Double((i * 173 + 23) % 997) / 997 * size.width + sin(time / 2400 + phase) * 10
                let color = Color(hex: 0xF5DFA0).opacity(0.15 + (sin(time / 600 + phase) + 1) * 0.32)
                context.fill(Path(ellipseIn: CGRect(x: x-radius,y: y-radius,width: radius*2,height: radius*2)), with: .color(color))
                if radius > 2 {
                    context.fill(Path(CGRect(x: x-5,y: y-0.4,width: 10,height: 0.8)), with: .color(color))
                    context.fill(Path(CGRect(x: x-0.4,y: y-5,width: 0.8,height: 10)), with: .color(color))
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
