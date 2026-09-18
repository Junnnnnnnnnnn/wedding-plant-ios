import SwiftUI
import WPUtils

/// 웹 `app/user/page.tsx` + `app/components/SettingsPage.tsx` 이식.
///
/// ```
/// [그라데이션 프로필 카드]  "OOO님"  + D-Day 알약
/// 이름 / 결혼식 날짜 / 예산 입력
/// [프로필 수정]  — 저장 중엔 "저장 중...", 성공하면 2초간 초록 "저장되었어요"
/// [로그아웃]  — 누르면 확인 문구가 펼쳐짐
/// ```
struct UserView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var push: PushService
    @EnvironmentObject private var guest: GuestStore
    @StateObject private var model = UserViewModel()

    @State private var showDatePicker = false
    @State private var confirmSignOut = false
    @State private var confirmWithdraw = false

    var body: some View {
        ZStack {
            WPScreenBackground()

            ScrollView {
                if model.loading {
                    ProgressView()
                        .tint(WPColor.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                } else {
                    content
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .task { await model.load(env: env, guest: guest) }
        .task(id: model.saved) {
            guard model.saved else { return }
            await model.startSavedResetTimer()
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProfileHeader(name: model.name, dDayLabel: model.dDayLabel)

            Spacer().frame(height: 28)

            SettingsSectionHeader(symbol: "person.fill", label: "기본 정보")
            Spacer().frame(height: 16)

            LabeledField(label: "이름") {
                BareInput(
                    text: Binding(get: { model.name }, set: { model.setName($0) }),
                    placeholder: "이름을 적어 주세요"
                )
                .accessibilityIdentifier("user.name")
            }

            Spacer().frame(height: 16)

            // 칸 자체가 눌린다 — 옆에 있던 보라색 캘린더 버튼은 하는 일이 같았고
            // **이 앱에 없는 색**이었다.
            LabeledField(label: "결혼식 날짜") {
                Text(model.date.weddingDateText)
                    .font(WPFont.hak(16, .medium))
                    .foregroundStyle(WPColor.fgNeutral)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { showDatePicker.toggle() }
                    .accessibilityIdentifier("user.date")
            }

            if showDatePicker {
                Spacer().frame(height: 12)
                // 이미 지난 결혼식 날짜도 그대로 보여줘야 하므로 하한을 두지 않는다.
                DateWheelPicker(value: $model.date)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Spacer().frame(height: 28)

            SettingsSectionHeader(symbol: "wallet.pass.fill", label: "예산 설정")
            Spacer().frame(height: 16)

            LabeledField(label: "예산", unit: "만 원") {
                BareInput(
                    text: Binding(get: { model.budget }, set: { model.setBudget($0) }),
                    // **값이 0 이라는 사실은 칸을 비우고 placeholder 가 말한다.**
                    placeholder: "0",
                    numeric: true
                )
                .accessibilityIdentifier("user.budget")
            }

            Spacer().frame(height: 24)

            if let message = model.errorMessage {
                InfoBanner(message: message, actionLabel: "닫기") {
                    model.errorMessage = nil
                }
                Spacer().frame(height: 12)
            }

            SaveButton(saved: model.saved, saving: model.saving) {
                Task { await model.save(env: env, guest: guest) }
            }

            Spacer().frame(height: 32)

            // 개인정보처리방침은 **로그인 여부와 상관없이 항상** 보여야 한다. 앱 안에
            // 접근 경로가 있는지를 심사에서 본다 (안드로이드도 같은 자리에 둔다).
            HStack(spacing: 14) {
                Spacer(minLength: 0)
                Link("개인정보처리방침", destination: AppLinks.privacyPolicy)
                    .accessibilityIdentifier("user.privacy")
                Text("·")
                // 사용자가 막혔을 때 나갈 길. 심사자도 지원 경로를 여기서 본다.
                Link("문의하기", destination: AppLinks.support)
                    .accessibilityIdentifier("user.support")
                Spacer(minLength: 0)
            }
            .font(WPFont.hak(12, .regular))
            .underline()
            .foregroundStyle(WPColor.gray400)
            .padding(4)

            Spacer().frame(height: 16)

            if model.loggedIn {
                // 한 번에 하나만 묻는다. 로그아웃을 확인하는 중에는 탈퇴 줄이,
                // 탈퇴를 확인하는 중에는 로그아웃 버튼이 사라진다 (웹·안드로이드와 동일).
                if confirmWithdraw {
                    WithdrawConfirm(
                        withdrawing: model.withdrawing,
                        error: model.withdrawError
                    ) {
                        confirmWithdraw = false
                        model.withdrawError = nil
                    } onConfirm: {
                        Task {
                            let ok = await model.withdraw(env: env, push: push, guest: guest)
                            // 성공하면 로그인 화면으로 돌아가 이 화면이 사라진다.
                            // 실패했을 때만 확인 상태를 유지해 다시 시도하게 둔다.
                            if ok { confirmWithdraw = false }
                        }
                    }
                } else if confirmSignOut {
                    SignOutConfirm {
                        confirmSignOut = false
                    } onConfirm: {
                        confirmSignOut = false
                        Task {
                            // 기기 토큰 해제는 **JWT 를 지우기 전에**.
                            // DELETE /plan/user/device-token 은 Authorization 이 필요하다.
                            // 안 하면 로그아웃해도 그 기기로 알림이 계속 간다.
                            await push.unregisterBeforeSignOut(env: env)
                            await env.signOut()
                            guest.clear()
                        }
                    }
                } else {
                    SoftActionButton(label: "로그아웃", symbol: "rectangle.portrait.and.arrow.right") {
                        confirmSignOut = true
                    }
                    .accessibilityIdentifier("user.signOut")

                    Spacer().frame(height: 8)

                    // 위험한 동작일수록 눈에 덜 띄어야 실수로 눌리지 않는다.
                    // 로그아웃 버튼 아래 조용한 줄로 둔다 (웹·안드로이드와 동일).
                    Button("회원 탈퇴") { confirmWithdraw = true }
                        .font(WPFont.hak(12, .regular))
                        .underline()
                        .foregroundStyle(WPColor.gray400)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(8)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("user.withdraw")
                }
            } else {
                SoftActionButton(label: "카카오로 로그인", symbol: "person.fill") {
                    env.isAuthenticated = false
                }
            }

            Spacer().frame(height: 40)
        }
    }
}

// MARK: - 프로필 헤더

/// 웹: `bg-gradient-to-r from-[#ee2b8c] to-[#ff5c95]` 카드 + 반투명 D-Day 알약
private struct ProfileHeader: View {
    var name: String
    var dDayLabel: String

    var body: some View {
        HStack(spacing: 12) {
            Text(name.isEmpty ? "이름을 입력해 주세요" : "\(name)님")
                .font(WPFont.tmoney(24, .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(dDayLabel)
                .font(WPFont.hak(20, .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Color.white.opacity(0.2),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .background(
            LinearGradient(
                colors: [WPColor.budgetGradientStart, WPColor.budgetGradientEnd],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
    }
}

// MARK: - 조각들

/// 웹: `text-[11px] font-black text-gray-400 uppercase tracking-[0.2em]` + 12px 아이콘
/// `/user` 안의 아이콘 + 라벨 줄.
///
/// DesignSystem 의 공용 ``SectionHeader``(C안 묶음 머리글)와는 **다른 것**이라
/// 이름을 나눈다. 파일 private 이어도 Swift 는 모듈 범위에서 재선언으로 잡는다.
private struct SettingsSectionHeader: View {
    var symbol: String
    var label: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(WPColor.gray400)
            Text(label)
                .font(WPFont.hak(11, .black))
                .tracking(2.2) // tracking-[0.2em]
                .foregroundStyle(WPColor.gray400)
        }
        .padding(.horizontal, 8)
    }
}

/// 웹 입력창: `h-16 pl-14 pr-6 bg-white border border-[#ee2b8c0a] rounded-3xl shadow-sm`.
///
/// 아이콘은 라벨이 아니라 **입력창 안쪽 왼쪽 20pt** 에 놓인다.
/// 라벨을 **항상 띄우는** 입력 상자.
///
/// 예전에는 placeholder 뿐이라 값을 넣는 순간 무슨 칸인지 사라졌다 — 화면에
/// `4200`, `2026-11-14` 만 남고 그게 예산인지 날짜인지 알 길이 없었다.
/// **placeholder 만 있는 칸을 다시 만들지 말 것.**
///
/// 폰(시안 C안 09)은 라벨을 상자 **밖 위**로 올리고 상자에는 값만 둔다.
/// **아이콘도 넣지 않는다** — 라벨이 이미 밖에 있어 같은 말을 두 번 하는 셈이다.
/// (넓은 화면은 라벨을 상자 안에 넣고 아이콘을 내지만, 그 레이아웃은 앱에 옮기지
/// 않는다.)
private struct LabeledField<Content: View>: View {
    var label: String
    /// 값 옆에 붙는 단위 ("만 원"). 상자 안 오른쪽 끝이다.
    var unit: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(WPFont.hak(13, .bold))
                .foregroundStyle(WPColor.fgMuted)

            HStack(spacing: 8) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let unit {
                    Text(unit)
                        .font(WPFont.hak(14))
                        .foregroundStyle(WPColor.fgMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            // SEED 채움 필드 — 테두리 대신 회색 바탕으로 입력 칸임을 알린다.
            .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

/// 배경·테두리 없이 글자만 그리는 입력 — 바깥 `IconField` 가 껍데기를 맡는다.
private struct BareInput: View {
    @Binding var text: String
    var placeholder: String
    var numeric: Bool = false

    var body: some View {
        TextField("", text: $text, prompt: promptText)
            .font(WPFont.hak(16, .medium))
            .foregroundStyle(WPColor.fgNeutral)
            .keyboardType(numeric ? .numberPad : .default)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .tint(WPColor.primary)
    }

    private var promptText: Text {
        Text(placeholder)
            .font(WPFont.hak(16))
            .foregroundColor(Color(hex: 0xB0B4BB))
    }
}

/// 저장 성공 시 2초간 초록 + 체크 (웹과 동일)
private struct SaveButton: View {
    var saved: Bool
    var saving: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if saved {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text(label)
                    .font(WPFont.hak(18, .black))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(saved || saving)
        .accessibilityIdentifier("user.save")
    }

    private var label: String {
        if saved { return "저장되었어요" }
        if saving { return "저장 중..." }
        // **`저장` 이다.** 예전에는 검정 배경에 `프로필 수정` 이라, 이미 프로필
        // 수정 화면인데 무엇이 일어날지 애매했다.
        return "저장"
    }

    private var background: Color {
        if saved { return Color(hex: 0x22C55E) }
        // **앱 primary 다.** 예전에는 검정 배경이었는데 이 앱의 주 버튼 색이
        // 아니었다 — 무엇이 주 동작인지 화면에서 읽히지 않았다.
        if saving { return WPColor.primary.opacity(0.7) }
        return WPColor.primary
    }
}

/// 웹: `bg-[#ee2b8c08] border border-[#ee2b8c11]` 연한 알약 버튼
private struct SoftActionButton: View {
    var label: String
    var symbol: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 14))
                Text(label)
                    .font(WPFont.hak(14, .bold))
            }
            .foregroundStyle(WPColor.primary.opacity(0.73))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                WPColor.primary.opacity(0.03),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(WPColor.primary.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// 회원 탈퇴 확인.
///
/// 탈퇴는 되돌릴 수 없다. "정말요?" 만 묻는 확인은 사용자가 답을 모르는 질문이라,
/// 무엇이 사라지고 무엇이 남는지 먼저 적는다. 후기가 남는 것도 여기서 밝힌다 —
/// 나중에 알게 되면 속았다고 느낀다. (웹·안드로이드와 같은 문구)
private struct WithdrawConfirm: View {
    var withdrawing: Bool
    var error: String?
    var onCancel: () -> Void
    var onConfirm: () -> Void

    private let lines = [
        "일정과 예산이 사라지고 되돌릴 수 없습니다.",
        "함께 준비하던 사람의 방에서 나가집니다.",
        "올린 견적 후기는 작성자 없이 남습니다.",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("정말 탈퇴하시겠어요?")
                .font(WPFont.hak(14, .bold))
                .foregroundStyle(WPColor.textPrimary)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(WPFont.hak(12.5, .regular))
                        .lineSpacing(6)
                        .foregroundStyle(WPColor.gray500)
                }
            }

            if let error {
                Text(error)
                    .font(WPFont.hak(12.5, .regular))
                    .foregroundStyle(WPColor.danger)
            }

            HStack(spacing: 8) {
                Button(action: onCancel) {
                    Text("취소")
                        .font(WPFont.hak(14, .bold))
                        .foregroundStyle(WPColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(WPColor.stone200, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(withdrawing)

                Button(action: onConfirm) {
                    Text(withdrawing ? "탈퇴 중..." : "탈퇴하기")
                        .font(WPFont.hak(14, .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(WPColor.danger, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(withdrawing)
                .accessibilityIdentifier("user.withdrawConfirm")
            }
            .opacity(withdrawing ? 0.6 : 1)
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(WPColor.stone200, lineWidth: 1)
        )
    }
}

/// 로그아웃 확인.
private struct SignOutConfirm: View {
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // 웹은 "이 기기에 저장된 플랜 정보가 지워집니다" 라고 안내하지만, 이 버튼은
            // **로그인한 사용자에게만** 보인다. 그 사람의 플랜은 서버에 있어 지워지지 않는데도
            // 삭제되는 것처럼 읽혀 오해를 부른다. 실제로 지워지는 건 이 기기의 로그인 정보뿐이라
            // 안드로이드와 같은 문구를 쓴다.
            Text("로그아웃해도 플랜은 그대로 남아 있어요.\n다시 로그인하면 이어서 볼 수 있습니다.")
                .font(WPFont.hak(14, .bold))
                .lineSpacing(6)
                .foregroundStyle(WPColor.textPrimary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Button(action: onCancel) {
                    Text("취소")
                        .font(WPFont.hak(14, .bold))
                        .foregroundStyle(WPColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(WPColor.gray200, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button(action: onConfirm) {
                    Text("로그아웃")
                        .font(WPFont.hak(14, .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("user.signOutConfirm")
            }
        }
        .padding(16)
        .background(
            WPColor.primary.opacity(0.03),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(WPColor.primary.opacity(0.13), lineWidth: 1)
        )
    }
}
