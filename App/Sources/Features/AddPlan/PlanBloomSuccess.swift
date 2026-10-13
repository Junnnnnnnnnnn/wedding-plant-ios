import SwiftUI
import WPUtils

enum BloomAction {
    case create, update, delete
    var verb: String { self == .create ? "등록" : self == .update ? "수정" : "삭제" }
    var colors: [Color] {
        let values: [UInt32]
        switch self {
        case .create: values = [0xF3F0DD,0xE9EFDC,0xDCEBDA,0x284C39,0x598463,0x284C39,0xFCFDF1,0xC9D8BB,0xD8E2CA,0x365F49]
        case .update: values = [0xF2F6FA,0xE3EAF2,0xD6E1EE,0x27456B,0x4F6680,0x2E4F7A,0xF6F9FD,0xC3D2E3,0xD3DEEA,0x355A85]
        case .delete: values = [0xF9F1EC,0xF1E6E3,0xEBD9D6,0x6B2F34,0x7A5A58,0x8A3D40,0xFDF8F6,0xE2CBC6,0xEAD8D4,0x7D3A3F]
        }
        return values.map { Color(hex: $0) }
    }
}
struct PlanBloomSuccess: View {
    let title: String
    let amount: Double
    let remaining: Double?
    var action: BloomAction = .create
    let onClose: () -> Void
    @StateObject private var tilt = CardTilt()
    @Environment(\.scenePhase) private var scenePhase
    @State private var started = Date()
    private var colors: [Color] { action.colors }
    private var over: Bool { (remaining ?? 0) < 0 }
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture(perform: onClose)
            ScrollView {
                VStack(spacing: 0) {
                    card
                        .rotation3DEffect(.degrees(min(12, max(-12, -tilt.x * 0.55))), axis: (x: 1,y: 0,z: 0), perspective: 0.4)
                        .rotation3DEffect(.degrees(min(12, max(-12, -tilt.y * 0.55))), axis: (x: 0,y: 1,z: 0), perspective: 0.4)
                }.frame(maxWidth: 390).padding(.horizontal, 22).padding(.vertical, 28).frame(maxWidth: .infinity)
            }.defaultScrollAnchor(.center)
        }.presentationBackground(.clear).onAppear { tilt.start() }.onDisappear { tilt.stop() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { tilt.start() } else { tilt.stop() } }
    }
    private var card: some View {
        VStack(spacing: 0) {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: scenePhase != .active)) { context in
                ZStack {
                    Ellipse().stroke(colors[4].opacity(0.2), lineWidth: 1).frame(width: 170, height: 145).offset(x: tilt.y * 0.15, y: -tilt.x * 0.15)
                    BloomFlower().frame(width: 150, height: 135).rotationEffect(.degrees(sin(context.date.timeIntervalSince(started) / 6 * 2 * .pi) * 3)).offset(x: tilt.y * 0.45, y: -tilt.x * 0.45)
                }.frame(width: 150, height: 135)
            }
            Text("플랜이 \(action.verb)되었어요").font(WPFont.hak(28, .bold)).tracking(-0.9).foregroundStyle(colors[3]).padding(.top, 14)
            reward.padding(.top, 20)
            Button(action: onClose) {
                Text(over ? "확인했어요  →" : action == .create ? "좋아, 다음 플랜으로  →" : "확인  →").font(WPFont.hak(13, .bold)).foregroundStyle(Color(hex: 0xFFFDF3)).frame(maxWidth: .infinity).padding(.vertical, 15).background(colors[9], in: RoundedRectangle(cornerRadius: 11))
            }.padding(.top, 16).accessibilityIdentifier("bloom.close")
            if over { Text("다음 플랜을 정할 때 예산을 조정해 보세요.").font(WPFont.hak(10)).foregroundStyle(colors[4]).padding(.top, 15) }
        }.padding(.horizontal, 19).padding(.top, 50).padding(.bottom, 30)
            .frame(maxWidth: .infinity)
            .background {
                LinearGradient(colors: Array(colors.prefix(3)), startPoint: .topLeading, endPoint: .bottomTrailing)
                GeometryReader { geometry in
                    RadialGradient(colors: [.white.opacity(0.35 * (0.35 + 0.65 * min(1, (abs(tilt.x) + abs(tilt.y)) / 25))), .clear], center: UnitPoint(x: 0.5 + 0.6 * tilt.y / 25, y: 0.25 - 0.5 * tilt.x / 25), startRadius: 0, endRadius: max(geometry.size.width, geometry.size.height) * 0.75)
                }
            }.clipShape(RoundedRectangle(cornerRadius: 16)).padding(8)
            .background(LinearGradient(colors: [0xFAF4CE,0x96C6AE,0xE9BED8,0xC5E2E1,0xF3E5CB].map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 23))
            .overlay(alignment: .topLeading) { Image("heart_sprout").resizable().frame(width: 28,height: 28).clipShape(RoundedRectangle(cornerRadius: 9)).padding(18) }
            .overlay(alignment: .topTrailing) { Button(action: onClose) { Image(systemName: "xmark").font(.system(size: 20)).foregroundStyle(colors[3]).frame(width: 48, height: 48) }.accessibilityLabel("\(action.verb) 완료 닫기") }
            .overlay(alignment: .bottom) { Text("✧ BLOOM TOGETHER ✧").font(WPFont.hak(7)).tracking(1).foregroundStyle(colors[4]).padding(.bottom, 5) }
    }
    private var reward: some View {
        VStack(spacing: 0) {
            if amount > 0 {
                Text(remaining == nil ? action == .create ? "이번 플랜에 담은 금액" : action == .update ? "수정한 플랜의 금액" : "지운 플랜의 금액" : over ? "총예산을 초과했어요" : "앞으로 총 사용할 수 있는 금액").font(WPFont.hak(11)).foregroundStyle(colors[4])
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(wpThousands(abs(remaining ?? amount))).font(.custom("KakaoSmallSans-Bold", size: 37))
                    Text(over ? "만 원 초과" : "만 원").font(WPFont.hak(14, .bold))
                }.foregroundStyle(over ? .red : colors[5]).padding(.top, 5)
                colors[8].frame(height: 1).padding(.top, 12)
                HStack { Text(title).lineLimit(1); Spacer(); Text("\(wpThousands(amount))만 원").bold().strikethrough(action == .delete) }.font(WPFont.hak(11)).foregroundStyle(colors[4]).padding(.top, 10)
            } else {
                Text(action == .create ? "플랜 +1" : action == .update ? "플랜 수정" : "플랜 -1").font(WPFont.hak(27, .bold))
                Text(title).font(WPFont.hak(13)).padding(.vertical, 7)
                Text(action == .create ? "잊지 않도록, 우리 플랜에 담아뒀어요." : action == .update ? "바뀐 내용으로 다시 담아뒀어요." : "우리 플랜에서 덜어냈어요.").font(WPFont.hak(11)).foregroundStyle(colors[4])
            }
        }.frame(maxWidth: .infinity).padding(.horizontal, 16).padding(.vertical, 17).background(colors[6].opacity(0.91), in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(colors[7]))
    }
}

/// Vector equivalent of Android assets/pass/bloom.svg; preserves the supplied paths and colors.
struct BloomFlower: View {
    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 170, y: size.height / 152)
            func ellipse(_ x: Double,_ y: Double,_ rx: Double,_ ry: Double,_ color: UInt32, opacity: Double = 1) {
                context.fill(Path(ellipseIn: CGRect(x: x-rx,y: y-ry,width: rx*2,height: ry*2)), with: .color(Color(hex: color).opacity(opacity)))
            }
            ellipse(85,141,45,7,0x365733,opacity: 0.1)
            var stem = Path(); stem.move(to: CGPoint(x: 85,y: 138)); stem.addLine(to: CGPoint(x: 85,y: 60)); context.stroke(stem, with: .color(Color(hex: 0x598463)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            var left = Path(); left.move(to: CGPoint(x: 84,y: 118)); left.addQuadCurve(to: CGPoint(x: 41,y: 89), control: CGPoint(x: 43,y: 124)); left.addQuadCurve(to: CGPoint(x: 84,y: 118), control: CGPoint(x: 76,y: 88)); context.fill(left, with: .color(Color(hex: 0x8EAF71)))
            var right = Path(); right.move(to: CGPoint(x: 87,y: 102)); right.addQuadCurve(to: CGPoint(x: 133,y: 75), control: CGPoint(x: 123,y: 109)); right.addQuadCurve(to: CGPoint(x: 87,y: 102), control: CGPoint(x: 101,y: 70)); context.fill(right, with: .color(Color(hex: 0x527E59)))
            for i in 0..<6 {
                var petal = context; petal.translateBy(x: 85,y: 48); petal.rotate(by: .degrees(Double(i)*60))
                petal.fill(Path(ellipseIn: CGRect(x: -17,y: -46,width: 34,height: 50)), with: .color(Color(hex: [0xF1A5B7,0xF6BDC9,0xE993AA][i % 3])))
            }
            ellipse(85,48,17,17,0xF3D383)
            ellipse(75,52,3.5,2.2,0xE7907D,opacity: 0.22); ellipse(95,52,3.5,2.2,0xE7907D,opacity: 0.22)
            ellipse(80,47,1.8,2.1,0x685333); ellipse(90,47,1.8,2.1,0x685333)
            ellipse(79.6,46.3,0.65,0.65,0xFFF6D5); ellipse(89.6,46.3,0.65,0.65,0xFFF6D5)
            var smile = Path(); smile.move(to: CGPoint(x: 81,y: 53)); smile.addQuadCurve(to: CGPoint(x: 89,y: 53), control: CGPoint(x: 85,y: 57)); context.stroke(smile, with: .color(Color(hex: 0x685333)), style: StrokeStyle(lineWidth: 1.5,lineCap: .round))
        }.accessibilityHidden(true)
    }
}
