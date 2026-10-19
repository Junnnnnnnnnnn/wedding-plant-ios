import UIKit

/// 키보드를 편하게 내리는 앱 전체 규칙(Android `clearFocusOnTap` · 2026-10-19 사용자 "유저가 편하게 키패드를 내릴 방법").
///
/// - **입력 칸 바깥을 누르면 내린다.** 창마다 탭 인식기를 하나 붙인다. `cancelsTouchesInView = false` 라
///   단추·칸의 누름은 그대로 지나가고(단추를 누르면 내리면서 그 단추도 눌린다 — Android 와 같다),
///   입력 칸(UITextField · UITextView) 위를 누른 것은 받지 않는다.
/// - **숫자 · 전화 키패드에는 `완료` 를 붙인다.** 이 키패드들은 리턴 키가 없어(금액 · 계좌번호 · 인증 코드)
///   내릴 방법이 없었다. SwiftUI 의 `TextField` 도 안은 UITextField 라 편집 시작 알림으로 붙일 수 있다.
///
/// 스크롤로 내리기(`.scrollDismissesKeyboard(.interactively)`)는 화면의 ScrollView 마다 붙인다.
@MainActor
final class KeyboardDismiss: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismiss()
    private var windows = NSHashTable<UIWindow>.weakObjects()
    private var observer: NSObjectProtocol?

    /// 앱 시작 때 한 번. 새로 생기는 창(시트 등은 같은 창이지만 알림 창 등)도 키 창이 될 때 붙인다.
    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: UITextField.textDidBeginEditingNotification, object: nil, queue: .main) { note in
            MainActor.assumeIsolated {
                guard let field = note.object as? UITextField else { return }
                KeyboardDismiss.shared.attachDoneIfNeeded(to: field)
                if let window = field.window { KeyboardDismiss.shared.install(on: window) }
            }
        }
        NotificationCenter.default.addObserver(forName: UIWindow.didBecomeKeyNotification, object: nil, queue: .main) { note in
            MainActor.assumeIsolated {
                if let window = note.object as? UIWindow { KeyboardDismiss.shared.install(on: window) }
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        for scene in UIApplication.shared.connectedScenes {
            (scene as? UIWindowScene)?.windows.forEach { install(on: $0) }
        }
    }

    private func install(on window: UIWindow) {
        guard !windows.contains(window) else { return }
        windows.add(window)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        window.addGestureRecognizer(tap)
    }

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        recognizer.view?.endEditing(true)
    }

    // 입력 칸 위의 누름은 받지 않는다 — 칸을 눌러 커서를 옮기는 중에 키보드가 내려가면 안 된다
    nonisolated func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        MainActor.assumeIsolated {
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView { return false }
                view = current.superview
            }
            return true
        }
    }

    nonisolated func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                       shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    private static let padTypes: Set<UIKeyboardType> = [.numberPad, .decimalPad, .phonePad, .asciiCapableNumberPad, .numbersAndPunctuation]

    private static let doneBarTag = 0x57505F44 // "WP_D"

    /// 키보드가 올라오는 순간 한 번 더 — SwiftUI 칸은 편집 시작 뒤에 자기 보조 막대를 끼워 앞의 것을 덮는다
    @objc private func keyboardWillShow() {
        if let field = UIResponder.wpCurrentFirstResponder as? UITextField { attachDoneIfNeeded(to: field) }
    }

    private func attachDoneIfNeeded(to field: UITextField) {
        guard Self.padTypes.contains(field.keyboardType), field.inputAccessoryView?.tag != Self.doneBarTag else { return }
        /*
          SwiftUI `TextField` 에는 SwiftUI 의 보조 막대 생성기(`InputAccessoryGenerator…`)가 들어 있는데, 앱은
          `.toolbar(placement: .keyboard)` 를 쓰지 않아 늘 비어 있다 — 그것은 바꿔 끼운다. 직접 단 다른 막대는 둔다.
          iOS 기본 막대(UIToolbar)는 iOS 26 에서 파란 알약 하나로 그려져 앱과 어울리지 않아(2026-10-19 사용자) 직접 그린다.
        */
        if let existing = field.inputAccessoryView, !String(describing: type(of: existing)).contains("InputAccessory") { return }
        let bar = DoneBar(width: field.window?.bounds.width ?? UIScreen.main.bounds.width) { [weak field] in
            field?.resignFirstResponder()
        }
        bar.tag = Self.doneBarTag
        field.inputAccessoryView = bar
        field.reloadInputViews()
    }
}

/// 숫자 키패드 위 `완료` 막대 — 폭 전체 흰 면 · 위 구분선 · 오른쪽 분홍 굵은 `완료`(앱의 글자 단추와 같은 글꼴·색)
private final class DoneBar: UIView {
    private let action: () -> Void

    init(width: CGFloat, action: @escaping () -> Void) {
        self.action = action
        super.init(frame: CGRect(x: 0, y: 0, width: width, height: 48))
        autoresizingMask = .flexibleWidth
        backgroundColor = .white

        let line = UIView()
        line.backgroundColor = UIColor(red: 0xEC / 255, green: 0xE7 / 255, blue: 0xEA / 255, alpha: 1)
        line.translatesAutoresizingMaskIntoConstraints = false
        addSubview(line)

        let button = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.attributedTitle = AttributedString("완료", attributes: AttributeContainer([
            .font: WPTypeface.hak.uiFont(16, .bold),
            .foregroundColor: UIColor(red: 0xEE / 255, green: 0x2B / 255, blue: 0x8C / 255, alpha: 1),
        ]))
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        button.configuration = config
        button.accessibilityIdentifier = "keyboard.done"
        button.addAction(UIAction { [weak self] _ in self?.action() }, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)

        NSLayoutConstraint.activate([
            line.topAnchor.constraint(equalTo: topAnchor),
            line.leadingAnchor.constraint(equalTo: leadingAnchor),
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: 48) }
}

extension UIResponder {
    private nonisolated(unsafe) static weak var found: UIResponder?
    /// 지금 초점이 있는 응답자(키보드를 띄운 칸)
    static var wpCurrentFirstResponder: UIResponder? {
        found = nil
        UIApplication.shared.sendAction(#selector(wpCaptureFirstResponder), to: nil, from: nil, for: nil)
        return found
    }
    @objc private func wpCaptureFirstResponder() { UIResponder.found = self }
}

import SwiftUI

extension View {
    /// SwiftUI 숫자·전화 키패드 칸이 있는 화면에 `완료` 를 단다(리턴 키가 없어 내릴 길이 없다). 화면의 바깥 틀에
    /// **한 번만** 붙인다 — 칸마다 붙이면 SwiftUI 가 툴바 단추를 칸 수만큼 겹쳐 그린다.
    /// - Parameter shown: 숫자 칸에 초점이 있을 때만 참으로 — 글자 키보드에도 붙이면 막대 높이만큼 다음 칸을 가린다.
    func wpKeyboardDone(_ shown: Bool = true) -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if shown {
                Spacer()
                Button("완료") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
                .accessibilityIdentifier("keyboard.done")
                }
            }
        }
    }
}
