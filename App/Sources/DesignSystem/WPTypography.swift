import SwiftUI
import UIKit

/// Compose의 기본 line-height: 1.5와 양끝의 반 줄 여백까지 함께 적용한다.
/// lineSpacing만 주면 첫 줄 위/마지막 줄 아래 여백이 빠져 카드마다 높이가 달라진다.
enum WPTypeface {
    case hak, kakao, tmoney, pixel
    func uiFont(_ size: CGFloat, _ weight: Font.Weight) -> UIFont {
        let heavy = [Font.Weight.semibold, .bold, .heavy, .black].contains(weight)
        let name: String
        switch self {
        case .hak: name = heavy ? "HakgyoansimDunggeunmisoTTF-B" : "HakgyoansimDunggeunmisoTTF-R"
        case .kakao: name = heavy ? "KakaoSmallSans-Bold" : "KakaoSmallSans-Regular"
        case .tmoney: name = "TmoneyRoundWind-Regular"
        case .pixel: name = "WP-Pixel-11-Regular"
        }
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size)
    }
}
private struct WPTextStyle: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let face: WPTypeface
    let height: CGFloat
    @Environment(\.displayScale) private var displayScale
    func body(content: Content) -> some View {
        let font = face.uiFont(size, weight)
        let scale = max(1, displayScale)
        let line = ceil(height * scale) / scale
        let glyph = ceil(font.lineHeight * scale) / scale
        let extra = max(0, line - glyph)
        let top = floor(extra * scale / 2) / scale
        content.font(Font(font)).lineSpacing(extra).padding(.top, top).padding(.bottom, extra - top)
    }
}
extension View {
    func wpTypography(_ size: CGFloat, _ weight: Font.Weight = .regular, face: WPTypeface = .hak, lineHeight: CGFloat? = nil) -> some View {
        modifier(WPTextStyle(size: size, weight: weight, face: face, height: lineHeight ?? size * 1.5))
    }
}
extension String {
    /// Android keepAll과 같은 어절 단위 줄바꿈. 접근성에는 원문을 별도로 사용한다.
    var wpKeepAll: String {
        let scalars = Array(unicodeScalars)
        func hangul(_ scalar: Unicode.Scalar) -> Bool { (0xAC00...0xD7A3).contains(scalar.value) || (0x3130...0x318F).contains(scalar.value) }
        var result = ""
        for (index, scalar) in scalars.enumerated() {
            result.unicodeScalars.append(scalar)
            if index + 1 < scalars.count {
                let next = scalars[index + 1]
                if CharacterSet.alphanumerics.contains(scalar) && CharacterSet.alphanumerics.contains(next) && (hangul(scalar) || hangul(next)) { result += "\u{2060}" }
            }
        }
        return result
    }
}

/// Android가 Regular 파일에 합성한 굵기. ExtraBold 파일로 치환하면 모양/폭이 달라진다.
struct WPTmoneyText: UIViewRepresentable {
    let text: String
    var size: CGFloat
    var bold = false
    var color = UIColor.label
    var lineHeight: CGFloat? = nil
    var tracking: CGFloat = 0
    func makeUIView(context: Context) -> UILabel { let label = UILabel(); label.setContentCompressionResistancePriority(.required, for: .horizontal); return label }
    func updateUIView(_ label: UILabel, context: Context) {
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: WPTypeface.tmoney.uiFont(size, .regular), .foregroundColor: color,
            .strokeColor: color, .strokeWidth: bold ? -2.5 : 0, .kern: tracking
        ])
        label.accessibilityLabel = text
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let size = uiView.intrinsicContentSize
        return CGSize(width: size.width, height: lineHeight ?? self.size * 1.5)
    }
}

/// 편집 가능한 Tmoney 글자에도 Android Regular + 합성 볼드와 같은 획을 쓴다.
struct WPTmoneyInput: UIViewRepresentable {
    @Binding var text: String
    var placeholder = ""
    var size: CGFloat = 16
    var bold = false
    var color = UIColor(WPColor.fgNeutral)
    var placeholderColor = UIColor(WPColor.gray400)
    var tracking: CGFloat = 0
    var alignment: NSTextAlignment = .left
    var keyboard: UIKeyboardType = .default
    var identifier = ""
    /// 키보드의 리턴 키 모양(예: 검색 칸은 `.search`)
    var returnKey: UIReturnKeyType = .done
    /// 리턴을 눌렀을 때 — 키보드를 내린 뒤 부른다(검색 칸의 엔터 = 검색)
    var onSubmit: (() -> Void)? = nil
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed), for: .editingChanged)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.returnKeyType = returnKey
        return field
    }
    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        let attributes: [NSAttributedString.Key: Any] = [.font: WPTypeface.tmoney.uiFont(size, .regular), .foregroundColor: color, .strokeColor: color, .strokeWidth: bold ? -2.5 : 0, .kern: tracking]
        // 조합 중인 한글은 UIKit의 marked text를 유지한다.
        if field.markedTextRange == nil {
            field.defaultTextAttributes = attributes
            if field.text != text { field.text = text }
        }
        var placeholderAttributes = attributes
        placeholderAttributes[.foregroundColor] = placeholderColor
        placeholderAttributes[.strokeColor] = placeholderColor
        field.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: placeholderAttributes)
        field.textAlignment = alignment
        field.keyboardType = keyboard
        field.tintColor = color
        field.accessibilityIdentifier = identifier
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 200, height: WPTypeface.tmoney.uiFont(size, .regular).lineHeight)
    }
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: WPTmoneyInput
        init(_ parent: WPTmoneyInput) { self.parent = parent }
        @objc func changed(_ field: UITextField) { parent.text = field.text ?? "" }
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            // 한글 조합 중에 누르면 조합이 끝난 글자를 먼저 넘긴다 — 안 그러면 마지막 글자가 빠진 채 검색된다
            parent.text = textField.text ?? ""
            textField.resignFirstResponder()
            if let submit = parent.onSubmit { DispatchQueue.main.async { submit() } }
            return true
        }
    }
}

/// 안내문은 어절 경계를 유지하면서 왼쪽부터 채운다. UIKit의 한글 문구 재배치를 끈다.
struct WPParagraph: UIViewRepresentable {
    let text: String
    var size: CGFloat
    var lineHeight: CGFloat
    var color: UIColor
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel(); label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }
    func updateUIView(_ label: UILabel, context: Context) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = lineHeight; paragraph.maximumLineHeight = lineHeight
        paragraph.lineBreakMode = .byWordWrapping; paragraph.lineBreakStrategy = []
        label.attributedText = NSAttributedString(string: text.wpKeepAll, attributes: [.font: WPTypeface.hak.uiFont(size, .regular), .paragraphStyle: paragraph, .foregroundColor: color])
        label.accessibilityLabel = text
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let width = proposal.width ?? 300
        let natural = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(natural.height / lineHeight) * lineHeight)
    }
}
