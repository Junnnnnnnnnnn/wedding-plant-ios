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

    private func attachDoneIfNeeded(to field: UITextField) {
        guard Self.padTypes.contains(field.keyboardType), field.inputAccessoryView == nil else { return }
        let bar = UIToolbar(frame: CGRect(x: 0, y: 0, width: field.window?.bounds.width ?? 390, height: 44))
        let done = UIBarButtonItem(title: "완료", style: .done, target: field, action: #selector(UIResponder.resignFirstResponder))
        done.accessibilityIdentifier = "keyboard.done"
        bar.items = [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), done]
        bar.sizeToFit()
        field.inputAccessoryView = bar
        field.reloadInputViews()
    }
}
