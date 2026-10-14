import SwiftUI

/// Android InvitationStudio.kt: StatusColumn, LandingItems and SlotGrid.
struct InvitationLandingDetails: View {
    let empty: Bool
    var planDate: String?
    var planVenue: String?
    let onEdit: (String) -> Void
    let onPass: () -> Void
    let onExample: () -> Void
    private let ink = Color(hex: 0x344C3C)
    private let accent = Color(hex: 0x315B41)
    private let muted = Color(hex: 0x66715E)
    private let line = Color(hex: 0xDBE2D1)
    private func font(_ size: CGFloat, bold: Bool = false) -> Font { .custom(bold ? "KakaoSmallSans-Bold" : "KakaoSmallSans-Regular", size: size) }
    private var filled: Int { 1 + (planDate == nil ? 0 : 1) + (planVenue == nil ? 0 : 1) }
    private var slots: [(String, String, String, Bool, String)] { [
        ("couple", "두 사람 이름", "신부 · 신랑", false, "cover"),
        ("date", "결혼식 날짜", planDate?.replacingOccurrences(of: "-", with: ".") ?? "날짜 고르기", planDate != nil, "calendar"),
        ("album", "사진", "0 / 20", false, "gallery"),
        ("info", "예식 장소", planVenue ?? "예식장 이름", planVenue != nil, "location"),
        ("letter", "초대의 말", "예시로 채워 둠", true, "message"),
        ("garden", "템플릿", "가든 · 아이보리 · 로즈", false, "mood")
    ] }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 7) {
                InvitationSprout().stroke(lineWidth: 1.3 * 15 / 16).frame(width: 15, height: 15).accessibilityHidden(true)
                Text(empty ? "준비 패스 이용 중" : "준비 패스에 포함된 모바일 청첩장").font(font(12))
            }.foregroundStyle(muted)
            Text(empty ? "OUR GARDEN IS READY" : "OUR OWN LITTLE GARDEN")
                .font(.system(size: 10, design: .serif)).tracking(2.4).foregroundStyle(Color(hex: 0x7A6A3F)).accessibilityHidden(true)
            if empty {
                (Text("정원은 준비됐어요.\n").foregroundColor(ink) + Text("하객 자리가 비어 있어요.").font(font(23, bold: true)).foregroundColor(accent))
                    .tracking(-0.9).wpTypography(23, face: .kakao, lineHeight: 32.2)
            } else {
                (Text("링크 하나로,\n").foregroundColor(ink) + Text("하객이 정원에").font(font(23, bold: true)).foregroundColor(accent) + Text(" 걸어와요.").foregroundColor(ink))
                    .tracking(-0.9).wpTypography(23, face: .kakao, lineHeight: 32.2)
            }
            Text(empty ? "청첩장을 만들어 링크를 보내면, 축하를 남긴 사람이 하나씩 이 자리를 채워요." : "사진과 예식 정보를 담은 모바일 청첩장. 받은 사람이 축하를 남기면 그 사람이 픽셀 하객이 되어 두 사람 곁에 서요.")
                .wpTypography(13, face: .kakao, lineHeight: 23.4).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 0) {
                line.frame(height: 1)
                Text(empty ? "청첩장에 넣을 것 · \(filled) / 6" : "청첩장에 담기는 것")
                    .font(font(11)).tracking(1).foregroundStyle(muted).padding(.top, 14).padding(.bottom, 8)
                if empty { slotGrid } else { landingItems }
            }.padding(.top, 6)
            VStack(spacing: 8) {
                Button { empty ? onEdit("layout") : onPass() } label: {
                    HStack(spacing: 12) {
                        Text(empty ? "청첩장 만들기" : "준비 패스로 시작하기").font(font(13, bold: true))
                        if empty, planDate != nil || planVenue != nil {
                            Text([planDate == nil ? nil : "날짜", planVenue == nil ? nil : "장소"].compactMap { $0 }.joined(separator: "·") + "는 채워 뒀어요").font(font(11))
                        }
                    }
                }.buttonStyle(InvitationLandingButton(primary: true)).accessibilityIdentifier("invitation.primary")
                Button("예시 청첩장 구경하기", action: onExample).buttonStyle(InvitationLandingButton(primary: false))
            }
            Text(empty ? "만든 청첩장은 패스가 끝나도 그대로예요." : "준비 패스로 우리 청첩장 한 장 · 패스가 끝나도 그대로")
                .font(font(11)).foregroundStyle(muted).frame(maxWidth: .infinity).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(ink)
    }
    private var landingItems: some View {
        VStack(spacing: 6) {
            ForEach([("album", "사진 앨범", "최대 20장"), ("info", "예식 안내", "날짜 · 시간 · 장소"), ("garden", "축하의 정원", "하객 방명록"), ("qr", "링크 · QR", "바로 전하기")], id: \.0) { icon, name, note in
                HStack(spacing: 0) {
                    InvitationPixelIcon(name: icon).frame(width: 20, height: 20)
                    Text(name).font(font(13)).padding(.leading, 13)
                    Spacer(minLength: 10)
                    Text(note).font(font(11.5)).foregroundStyle(muted).multilineTextAlignment(.trailing)
                }.padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Color(hex: 0xF1F3E9), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(line, lineWidth: 1))
                    .accessibilityElement(children: .combine).accessibilityIdentifier("invitation.feature.\(icon)")
            }
        }
    }
    private var slotGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(slots, id: \.4) { icon, title, note, filled, focus in
                Button { onEdit(focus) } label: {
                    VStack(spacing: 6) {
                        if filled { InvitationPixelIcon(name: icon).frame(width: 24, height: 24) }
                        else { Image(systemName: "plus").font(.system(size: 17, weight: .light)).frame(height: 24).foregroundStyle(Color(hex: 0x9AA58E)) }
                        Text(title).font(font(12)).foregroundStyle(filled ? ink : muted)
                        Text(note).font(font(10.5)).foregroundStyle(filled ? accent : muted).multilineTextAlignment(.center)
                    }.padding(.horizontal, 6).padding(.vertical, 10).frame(maxWidth: .infinity, minHeight: 96)
                        .background(filled ? Color(hex: 0xE8EEDF) : .clear, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(filled ? line : Color(hex: 0xB9C4AD), style: StrokeStyle(lineWidth: 1, dash: filled ? [] : [3, 3])))
                }.buttonStyle(.plain).accessibilityIdentifier("invitation.slot.\(focus)")
            }
        }
    }
}
struct InvitationLandingButton: ButtonStyle {
    let primary: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.custom("KakaoSmallSans-Regular", size: 13)).frame(maxWidth: .infinity, minHeight: 46)
            .foregroundStyle(primary ? Color(hex: 0xFFFDF9) : Color(hex: 0x315B41))
            .background(primary ? Color(hex: 0x315B41) : Color(hex: 0xFFFDF9), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(primary ? Color(hex: 0x315B41) : Color(hex: 0xDBE2D1), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

private struct InvitationSprout: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 8, y: 14)); p.addLine(to: CGPoint(x: 8, y: 7))
        p.move(to: CGPoint(x: 8, y: 9))
        p.addCurve(to: CGPoint(x: 3.5, y: 4.5), control1: CGPoint(x: 5, y: 9), control2: CGPoint(x: 3.5, y: 7))
        p.addCurve(to: CGPoint(x: 8, y: 9), control1: CGPoint(x: 6, y: 4.5), control2: CGPoint(x: 8, y: 6)); p.closeSubpath()
        p.move(to: CGPoint(x: 8, y: 8))
        p.addCurve(to: CGPoint(x: 12.5, y: 3.5), control1: CGPoint(x: 8, y: 5), control2: CGPoint(x: 10, y: 3.5))
        p.addCurve(to: CGPoint(x: 8, y: 8), control1: CGPoint(x: 12.5, y: 6), control2: CGPoint(x: 11, y: 8)); p.closeSubpath()
        return p.applying(CGAffineTransform(scaleX: rect.width / 16, y: rect.height / 16))
    }
}
