import SwiftUI
import WPDomain
import WPModels
import WPUtils

extension WPColor {
    static let invInk = Color(hex: 0x344C3C), invMuted = Color(hex: 0x7D8874)
    static let invAccent = Color(hex: 0x315B41), invPaper = Color(hex: 0xF7F5ED)
    static let invWhite = Color(hex: 0xFFFDF9), invGarden = Color(hex: 0xF1F3E9)
    static let invLine = Color(hex: 0xDBE2D1), invForest = Color(hex: 0x173C2F)
    static let invSoft = Color(hex: 0xE8EEDF), invGold = Color(hex: 0xB7A375)
    static let invLandMuted = Color(hex: 0x66715E), invDash = Color(hex: 0xB9C4AD)
    static let invPlaceholder = Color(hex: 0x959E8C), invErrorInk = Color(hex: 0xA93D56)
}
func invitationFont(_ size: CGFloat, bold: Bool = false) -> Font { .custom(bold ? "KakaoSmallSans-Bold" : "KakaoSmallSans-Regular", size: size) }

struct InvitationFlower: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Android InvitationIcons.flower의 24×24 선 도형.
        p.addEllipse(in: CGRect(x: 10, y: 6, width: 4, height: 4))
        for (x, y, start, end, clockwise) in [(15.0, 5.0, 180.0, 90.0, false), (9, 5, 0, 90, true), (9, 11, -90, 0, true), (15, 11, -90, 180, false)] {
            var petal = Path(); petal.addArc(center: CGPoint(x: x, y: y), radius: 3, startAngle: .degrees(start), endAngle: .degrees(end), clockwise: clockwise); p.addPath(petal)
        }
        p.move(to: CGPoint(x: 12, y: 10)); p.addLine(to: CGPoint(x: 12, y: 22))
        p.move(to: CGPoint(x: 12, y: 22)); p.addCurve(to: CGPoint(x: 19, y: 17), control1: CGPoint(x: 16.2, y: 22), control2: CGPoint(x: 19, y: 20.333)); p.addCurve(to: CGPoint(x: 12, y: 22), control1: CGPoint(x: 14.8, y: 17), control2: CGPoint(x: 12, y: 18.667))
        p.move(to: CGPoint(x: 12, y: 22)); p.addCurve(to: CGPoint(x: 5, y: 17), control1: CGPoint(x: 7.8, y: 22), control2: CGPoint(x: 5, y: 20.333)); p.addCurve(to: CGPoint(x: 12, y: 22), control1: CGPoint(x: 9.2, y: 17), control2: CGPoint(x: 12, y: 18.667))
        return p.applying(.init(scaleX: rect.width / 24, y: rect.height / 24))
    }
}

/// 편집기가 지금 고치는 칸을 아는 통로 — 패널 안에서 그 칸을 키보드 위로 굴리고, 미리보기를 그 칸에 맞춥니다.
/// 칸마다 클로저를 넘기지 않으려고 환경으로 둡니다(계좌 여섯 줄 × 세 칸).
private struct InvitationFieldFocusKey: EnvironmentKey { static let defaultValue: ((String, Bool) -> Void)? = nil }
extension EnvironmentValues {
    var invitationFieldFocus: ((String, Bool) -> Void)? {
        get { self[InvitationFieldFocusKey.self] }
        set { self[InvitationFieldFocusKey.self] = newValue }
    }
}

struct InvitationField: View {
    let label: String
    @Binding var text: String
    var identifier: String = ""
    var multiline = false
    /// 안드로이드 `GardenField` 의 placeholder · 길이 제한 · 위 여백(웹 문구 그대로)
    var placeholder: String = ""
    var max: Int = 500
    var top: CGFloat = 14
    var filter: ((String) -> String)? = nil
    /// 패널 안 스크롤 자리 · 초점 알림의 이름. 같은 라벨이 둘인 칸(부모님 성함·계좌)은 따로 줍니다
    var focusID: String? = nil
    @FocusState private var focused: Bool
    @Environment(\.invitationFieldFocus) private var onFocus
    private var limited: Binding<String> {
        Binding(get: { text }, set: { value in
            let filtered = filter?(value) ?? value
            text = String(filtered.prefix(max))
        })
    }
    private var prompt: Text? { placeholder.isEmpty ? nil : Text(placeholder).foregroundColor(WPColor.invPlaceholder) }
    private var key: String { focusID ?? (identifier.isEmpty ? "field." + label : identifier) }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 여러 줄 칸은 글자 수를 라벨 옆에 씁니다(안드로이드 counter)
            if !label.isEmpty || multiline {
                HStack(spacing: 0) {
                    Text(label).font(invitationFont(12, bold: true)).foregroundStyle(WPColor.invInk)
                    Spacer(minLength: 0)
                    if multiline { Text("\(text.count)/\(max)").font(invitationFont(12)).foregroundStyle(WPColor.invMuted) }
                }
            }
            // 한 줄 칸은 `axis` 없는 TextField — `axis:` 를 주면 안이 UITextView 라 앱 전체의 숫자 키패드 `완료`
            // (`KeyboardDismiss`, UITextField 편집 알림으로 붙임)가 계좌번호 칸에 붙지 않았습니다
            Group {
                if multiline { TextField("", text: limited, prompt: prompt, axis: .vertical) }
                else { TextField("", text: limited, prompt: prompt) }
            }
                .lineLimit(multiline ? 4...8 : 1...1).font(invitationFont(16)).foregroundStyle(WPColor.invInk)
                .lineSpacing(multiline ? 8 : 0)
                .padding(.horizontal, 12).padding(.vertical, 10).frame(minHeight: multiline ? 112 : 46, alignment: multiline ? .topLeading : .leading)
                .background(focused ? WPColor.invWhite : WPColor.invPaper, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused ? WPColor.invAccent : WPColor.invLine, lineWidth: focused ? 2 : 1))
                .focused($focused).accessibilityLabel(label).accessibilityIdentifier(identifier)
        }.padding(.top, top).id(key)
            .onChange(of: focused) { _, value in onFocus?(key, value) }
    }
}
/// 안드로이드 `OutlineButton` — 초록 1px 테두리 · 흰 바탕 · 높이 40 · r10 · 글자 12 bold accent.
struct InvitationOutlineLabel: View {
    let title: String
    var icon: [String]? = nil
    var enabled = true
    var body: some View {
        HStack(spacing: 6) {
            if let icon { InvIconView(icon, size: 16, color: WPColor.invAccent) }
            Text(title).font(invitationFont(12, bold: true)).foregroundStyle(WPColor.invAccent).lineLimit(1).fixedSize()
        }.padding(.horizontal, 14).frame(minHeight: 40)
            .background(WPColor.invWhite, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(WPColor.invAccent, lineWidth: 1))
            .opacity(enabled ? 1 : 0.45)
    }
}
struct InvitationSwitch: View {
    @Binding var isOn: Bool
    var label: String
    var body: some View {
        Button { withAnimation(.easeOut(duration: 0.15)) { isOn.toggle() } } label: {
            Capsule().fill(isOn ? WPColor.invAccent : WPColor.invLine).frame(width: 40, height: 24)
                .overlay(alignment: isOn ? .trailing : .leading) { Circle().fill(.white).frame(width: 18, height: 18).padding(3) }
                .frame(width: 52, height: 44)
        }.buttonStyle(.plain).accessibilityLabel(label).accessibilityValue(isOn ? "켜짐" : "꺼짐")
    }
}

struct InvitationEditBadge: View {
    let selected: Bool
    var onDark = false
    var body: some View {
        HStack(spacing: 4) {
            InvIconView(InvIcon.pencil, size: 12, color: selected ? WPColor.invWhite : WPColor.invAccent)
            Text(selected ? "고치는 중" : "고치기").font(invitationFont(11, bold: true)).frame(minHeight: 14)
        }
            .foregroundStyle(selected ? WPColor.invWhite : WPColor.invAccent).padding(.horizontal, 9).padding(.vertical, 5)
            .background(selected ? WPColor.invAccent : WPColor.invWhite.opacity(0.94), in: Capsule())
            .overlay { if !selected && !onDark { Capsule().stroke(WPColor.invLine, lineWidth: 1) } }
    }
}
struct InvitationEditSelection: ViewModifier {
    let enabled: Bool
    let selected: Bool
    var showsBadge = true
    func body(content: Content) -> some View {
        content.overlay {
            if enabled && selected { RoundedRectangle(cornerRadius: 8).inset(by: 4).stroke(WPColor.invAccent, style: StrokeStyle(lineWidth: 2, dash: [3.3, 2.3])).allowsHitTesting(false) }
        }.overlay(alignment: .topTrailing) {
            if enabled && showsBadge { InvitationEditBadge(selected: selected).padding(10).allowsHitTesting(false) }
        }
    }
}
struct InvitationDateFields: View {
    @Binding var date: String?
    @Binding var time: String?
    @State private var picker: String?
    @State private var value = Date()
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            field("예식 날짜", value: dayLabel, key: "date")
            field("예식 시간", value: timeLabel, key: "time")
        }.sheet(isPresented: Binding(get: { picker != nil }, set: { if !$0 { picker = nil } })) {
            VStack(spacing: 16) {
                Text(picker == "date" ? "예식 날짜" : "예식 시간").font(invitationFont(18, bold: true))
                DatePicker("", selection: $value, displayedComponents: picker == "date" ? .date : .hourAndMinute)
                    .datePickerStyle(.wheel).labelsHidden().environment(\.locale, Locale(identifier: "ko_KR")).environment(\.timeZone, KST.timeZone)
                HStack {
                    Button("지우기") { if picker == "date" { date = nil } else { time = nil }; picker = nil }
                    Spacer()
                    Button("확인") {
                        let formatter = DateFormatter(); formatter.timeZone = KST.timeZone; formatter.dateFormat = picker == "date" ? "yyyy-MM-dd" : "HH:mm"
                        if picker == "date" { date = formatter.string(from: value) } else { time = formatter.string(from: value) }; picker = nil
                    }
                }.padding(.horizontal, 24)
            }.padding(20).presentationDetents([.height(350)]).tint(WPColor.invAccent)
        }
    }
    private var dayLabel: String {
        guard let date, let parsed = KstDate(dateString: date) else { return "날짜 고르기" }
        let weekday = ["일", "월", "화", "수", "목", "금", "토"][KST.calendar.component(.weekday, from: parsed.startOfDay) - 1]
        return "\(parsed.year)년 \(parsed.month)월 \(parsed.day)일 \(weekday)요일"
    }
    private var timeLabel: String {
        let parts = (time ?? "").split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return "시간 고르기" }
        return "\(parts[0] < 12 ? "오전" : "오후") \(parts[0] % 12 == 0 ? 12 : parts[0] % 12)시" + (parts[1] == 0 ? "" : " \(parts[1])분")
    }
    private func field(_ title: String, value: String, key: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(invitationFont(12, bold: true)).foregroundStyle(WPColor.invInk)
            Button { picker = key; let formatter = DateFormatter(); formatter.timeZone = KST.timeZone; formatter.dateFormat = key == "date" ? "yyyy-MM-dd" : "HH:mm"; self.value = formatter.date(from: (key == "date" ? date : time) ?? "") ?? Date() } label: {
                Text(value).wpTypography(15, face: .kakao, lineHeight: 22).foregroundStyle(value.hasSuffix("고르기") ? WPColor.invPlaceholder : WPColor.invInk).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 10)
                    .background(WPColor.invPaper, in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(WPColor.invLine))
            }.buttonStyle(.plain)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InvitationLayoutPanel: View {
    @Binding var draft: InvitationContent
    let onOpen: (String) -> Void
    @State private var dragOffset: CGFloat = 0
    @State private var dragConsumed: CGFloat = 0
    @State private var dragging: String?
    private var sections: [InvitationSectionBody] { draft.design?.sections ?? [] }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("구성").font(invitationFont(16, bold: true)).tracking(-0.3).foregroundStyle(WPColor.invForest)
                Text("\(sections.filter(\.visible).count)칸 보임 · 끌어서 순서를 바꾸고, 쓰지 않을 칸은 꺼 두세요")
                    .wpTypography(12, face: .kakao, lineHeight: 18).foregroundStyle(WPColor.invMuted).padding(.top, -4).padding(.bottom, 4)
                row("cover", title: "표지", summary: InvitationRules.coverSummary(draft), index: nil)
                ForEach(Array(sections.enumerated()), id: \.element.type) { index, section in
                    row(section.type, title: InvitationRules.sectionTypes.firstIndex(of: section.type).map { InvitationRules.sectionLabels[$0] } ?? section.type,
                        summary: section.visible ? InvitationRules.sectionSummary(section.type, content: draft) : "꺼 둠 · 청첩장에 보이지 않아요", index: index)
                        .offset(y: dragging == section.type ? dragOffset : 0).zIndex(dragging == section.type ? 1 : 0)
                }
                HStack(spacing: 6) {
                    InvIconView(InvIcon.pin, size: 13, color: WPColor.invGold)
                    Text("맨 아래에는 늘 맺음 인사와 ‘청첩장 전하기’가 붙어요.".wpKeepAll).font(invitationFont(12)).foregroundStyle(WPColor.invMuted)
                }.padding(.top, 6)
            }.padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 24)
        }.background(WPColor.invPaper)
    }
    private func row(_ key: String, title: String, summary: String, index: Int?) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Group {
                    if index == nil { InvIconView(InvIcon.pin, size: 15, color: WPColor.invGold) }
                    else { InvIconView(InvIcon.gripVertical, size: 18, color: WPColor.invMuted) }
                }
                    .frame(width: 36, height: 48).contentShape(Rectangle())
                    .gesture(DragGesture().onChanged { value in
                        guard let index = sections.firstIndex(where: { $0.type == key }) else { return }
                        if dragging != key { dragging = key; dragConsumed = 0 }
                        dragOffset = value.translation.height - dragConsumed
                        let direction = dragOffset > 0 ? 1 : -1
                        let next = index + direction
                        if abs(dragOffset) > 56, sections.indices.contains(next) { move(index, next); dragConsumed += CGFloat(direction) * 112; dragOffset = value.translation.height - dragConsumed }
                    }.onEnded { _ in dragging = nil; dragOffset = 0; dragConsumed = 0 })
                Button { onOpen(key) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(invitationFont(14, bold: true)).tracking(-0.2).foregroundStyle(index.map { sections[$0].visible } == false ? WPColor.invMuted : WPColor.invInk)
                        Text(summary).font(invitationFont(12)).foregroundStyle(WPColor.invMuted).lineLimit(1)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).padding(.vertical, 6)
                }.buttonStyle(.plain).accessibilityIdentifier(key == "cover" ? "invitation.editCover" : "invitation.layout." + key)
                if let index {
                    InvitationSwitch(isOn: Binding(get: { sections[index].visible }, set: { draft.design?.sections[index].visible = $0 }), label: title + " 보이기")
                } else {
                    Text("맨 위").font(invitationFont(11)).foregroundStyle(WPColor.invAccent).padding(.horizontal, 8).padding(.vertical, 4).background(WPColor.invSoft, in: Capsule())
                }
            }.padding(.leading, 2).padding(.trailing, 10).padding(.vertical, 4).frame(minHeight: 64)
            if let index {
                HStack(spacing: 0) {
                    Text("\(index + 1) / \(sections.count)번째").font(invitationFont(12)).foregroundStyle(WPColor.invMuted)
                    Spacer(minLength: 0)
                    moveButton("위로", icon: "arrow.up", enabled: index > 0) { move(index, index - 1) }
                    moveButton("아래로", icon: "arrow.down", enabled: index < sections.count - 1) { move(index, index + 1) }
                }.padding(.leading, 38).padding(.trailing, 4).padding(.bottom, 4)
            }
        }.background(WPColor.invWhite, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(WPColor.invLine, lineWidth: 1))
    }
    private func moveButton(_ title: String, icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) { InvIconView(icon == "arrow.up" ? InvIcon.arrowUp : InvIcon.arrowDown, size: 14, color: WPColor.invAccent); Text(title).font(invitationFont(12)) }
                .padding(.horizontal, 10).frame(minHeight: 36)
        }
            .buttonStyle(.plain).foregroundStyle(WPColor.invAccent).opacity(enabled ? 1 : 0.45).disabled(!enabled)
    }
    private func move(_ from: Int, _ to: Int) { guard sections.indices.contains(from), sections.indices.contains(to) else { return }; draft.design?.sections.swapAt(from, to) }
}
