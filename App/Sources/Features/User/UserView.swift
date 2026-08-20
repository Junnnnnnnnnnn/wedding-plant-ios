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
    @EnvironmentObject private var guest: GuestStore
    @StateObject private var model = UserViewModel()

    @State private var showDatePicker = false
    @State private var confirmSignOut = false

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

            SectionHeader(symbol: "person.fill", label: "기본 정보")
            Spacer().frame(height: 16)

            IconField(symbol: "person.fill") {
                BareInput(
                    text: Binding(get: { model.name }, set: { model.setName($0) }),
                    placeholder: "이름"
                )
                .accessibilityIdentifier("user.name")
            }

            Spacer().frame(height: 16)

            // 웹: 입력창 + 오른쪽에 보라색 캘린더 버튼
            HStack(spacing: 8) {
                IconField(symbol: "calendar") {
                    Text(model.date.weddingDateText)
                        .font(WPFont.hak(18, .bold))
                        .foregroundStyle(WPColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { showDatePicker.toggle() }
                }

                Button {
                    showDatePicker.toggle()
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(hex: 0x9333EA))
                        .frame(width: 56, height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0xFAF5FF), Color(hex: 0xF3E8FF)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("날짜 선택")
            }

            if showDatePicker {
                Spacer().frame(height: 12)
                // 이미 지난 결혼식 날짜도 그대로 보여줘야 하므로 하한을 두지 않는다.
                DateWheelPicker(value: $model.date)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Spacer().frame(height: 28)

            SectionHeader(symbol: "wallet.pass.fill", label: "예산 설정")
            Spacer().frame(height: 16)

            IconField(symbol: "wallet.pass.fill") {
                BareInput(
                    text: Binding(get: { model.budget }, set: { model.setBudget($0) }),
                    placeholder: "보유 예산 (만 원)",
                    numeric: true
                )
                .accessibilityIdentifier("user.budget")
            } trailing: {
                // 웹: 입력창 안쪽 오른쪽에 붙는 "만원"
                Text("만원")
                    .font(WPFont.hak(12, .black))
                    .foregroundStyle(WPColor.gray400)
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

            if model.loggedIn {
                if confirmSignOut {
                    SignOutConfirm {
                        confirmSignOut = false
                    } onConfirm: {
                        confirmSignOut = false
                        Task {
                            await env.signOut()
                            guest.clear()
                        }
                    }
                } else {
                    SoftActionButton(label: "로그아웃", symbol: "rectangle.portrait.and.arrow.right") {
                        confirmSignOut = true
                    }
                    .accessibilityIdentifier("user.signOut")
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
private struct SectionHeader: View {
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
private struct IconField<Content: View, Trailing: View>: View {
    var symbol: String
    @ViewBuilder var content: Content
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(WPColor.gray300)
                .frame(width: 20)

            Spacer().frame(width: 16)

            content
                .frame(maxWidth: .infinity, alignment: .leading)

            trailing
                .padding(.leading, 8)
        }
        .padding(.leading, 20)
        .padding(.trailing, 24)
        .frame(height: 64)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(WPColor.cardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

extension IconField where Trailing == EmptyView {
    init(symbol: String, @ViewBuilder content: () -> Content) {
        self.symbol = symbol
        self.content = content()
        self.trailing = EmptyView()
    }
}

/// 배경·테두리 없이 글자만 그리는 입력 — 바깥 `IconField` 가 껍데기를 맡는다.
private struct BareInput: View {
    @Binding var text: String
    var placeholder: String
    var numeric: Bool = false

    var body: some View {
        TextField("", text: $text, prompt: promptText)
            .font(WPFont.hak(18, .bold))
            .foregroundStyle(WPColor.textPrimary)
            .keyboardType(numeric ? .numberPad : .default)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .tint(WPColor.primary)
    }

    private var promptText: Text {
        Text(placeholder)
            .font(WPFont.hak(18, .bold))
            .foregroundColor(WPColor.gray300)
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
        return "프로필 수정"
    }

    private var background: Color {
        if saved { return Color(hex: 0x22C55E) }
        if saving { return WPColor.textPrimary.opacity(0.7) }
        return WPColor.textPrimary
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
