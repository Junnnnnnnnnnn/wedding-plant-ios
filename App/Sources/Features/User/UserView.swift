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
    @State private var coupleOpen = false

    /// 신랑·신부로 귀속됐다 — 날짜·예식장·예산은 방장 플랜을 따르고 여기서는 이름만 고친다(안드로이드와 같음)
    private var bound: Bool { env.boundRoomId != nil }
    private var boundOwnerName: String? { bound ? (env.boundRoomPlan?.ownerName.trimmingCharacters(in: .whitespaces) ?? "") : nil }
    private var shownDate: KstDate { bound ? (env.boundRoomPlan.flatMap { KstDate(dateString: $0.weddingDate) } ?? model.date) : model.date }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: 0) {
                ProfileHeader(name: model.name, date: shownDate, loading: model.loading)
                if model.loading {
                    // 받는 동안 폼 모양 그대로 뼈대를 낸다
                    VStack(alignment: .leading, spacing: 0) {
                        SkeletonBox(width: 80, height: 22)
                        ForEach(0..<4, id: \.self) { _ in
                            SkeletonBox(width: 64, height: 14).padding(.top, 20)
                            SkeletonBox(height: 48, corner: 12).padding(.top, 8)
                        }
                    }
                    .padding(16)
                } else {
                    content.padding(16)
                }
            }
            .padding(.bottom, 24)
        }
        // 아래로 끌면 키보드가 따라 내려간다(플랜 추가와 같음)
        .scrollDismissesKeyboard(.interactively)
        // 탈퇴 · 로그아웃 확인 상자가 열리면 끝까지 굴려 단추가 탭바 뒤에 숨지 않게(Android 8ab1b3d — 열려도 화면이 따라
        // 내려가지 않아 단추가 탭바에 가렸다. 2026-10-28 iOS QA PROF-05 에서도 상자 아래가 탭바 밑에 걸렸다)
        .onChange(of: confirmWithdraw || confirmSignOut) { _, open in
            guard open else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(60))
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("user.bottom", anchor: .bottom) }
            }
        }
        }
        .background(WPColor.background)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.load(env: env, guest: guest) }
        .task(id: model.saved) {
            guard model.saved else { return }
            await model.startSavedResetTimer()
        }
        .sheet(isPresented: $coupleOpen, onDismiss: { Task { await model.load(env: env, guest: guest) } }) { SpouseInviteSheet() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 준비 패스 카드는 **폼 위** — 로그인한 사람에게만(게스트는 붙일 방이 없다)
            if model.loggedIn {
                UserPassCard(loggedIn: model.loggedIn)
                Spacer().frame(height: 20)
            }

            Text("정보 수정").tracking(-0.36).wpTypography(18, .bold).foregroundStyle(WPColor.fgNeutral)
            Spacer().frame(height: 16)

            if let owner = boundOwnerName {
                let who = owner.isEmpty ? "초대한 사람" : owner
                (Text(who).font(Font(WPTypeface.hak.uiFont(12.5, .bold)))
                    + Text(" 님과 함께 준비하고 있어요. 결혼식 날짜 · 예식장 · 예산은 ")
                    + Text(who).font(Font(WPTypeface.hak.uiFont(12.5, .bold)))
                    + Text(" 님의 플랜을 따라가고, 여기서는 바꿀 수 없어요."))
                    .wpTypography(12.5, lineHeight: 20)
                    .foregroundStyle(Color(hex: 0x96296A))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color(hex: 0xFFF5FA), in: RoundedRectangle(cornerRadius: 16))
                Spacer().frame(height: 16)
            }

            LabeledField(label: "이름") {
                BareInput(text: Binding(get: { model.name }, set: { model.setName($0) }), placeholder: "이름을 입력해 주세요")
                    .accessibilityIdentifier("user.name")
            }

            Spacer().frame(height: 16)

            // 날짜는 칸 자체가 눌린다. 고칠 수 없는 값(귀속)은 같은 자리·크기로 두되 색을 한 단계 낮춘다.
            LabeledField(label: "결혼식 날짜") {
                Text(shownDate.weddingDateText)
                    .tracking(-0.16).wpTypography(16)
                    .foregroundStyle(bound ? WPColor.fgMuted : WPColor.fgNeutral)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { if !bound { showDatePicker.toggle() } }
                    .accessibilityIdentifier("user.date")
            }
            if showDatePicker && !bound {
                Spacer().frame(height: 12)
                // 이미 지난 결혼식 날짜도 그대로 보여줘야 하므로 하한을 두지 않는다.
                DateWheelPicker(value: $model.date).frame(maxWidth: .infinity, alignment: .center)
            }

            // 예식장 — 비워 둘 수 있다. 게스트는 저장할 곳이 없어 입력을 내지 않는다.
            if model.loggedIn {
                Spacer().frame(height: 16)
                LabeledField(label: "예식장", labelHint: bound ? nil : "(선택)") {
                    if bound {
                        ReadOnlyValue(text: model.weddingVenue.isEmpty ? "아직 안 정했어요" : model.weddingVenue)
                    } else {
                        BareInput(text: $model.weddingVenue, placeholder: "아직 안 정했어요")
                    }
                }
            }

            Spacer().frame(height: 16)

            LabeledField(label: "예산", unit: "만 원") {
                if bound {
                    ReadOnlyValue(text: wpThousands(env.boundRoomPlan?.budget ?? (Double(model.budget) ?? 0)), tmoney: true)
                } else {
                    BareInput(
                        text: Binding(get: { model.budget }, set: { model.setBudget($0) }),
                        // **값이 0 이라는 사실은 칸을 비우고 placeholder 가 말한다.**
                        placeholder: "0",
                        numeric: true,
                        tmoney: true
                    )
                    .accessibilityIdentifier("user.budget")
                }
            }

            if let message = model.errorMessage {
                Spacer().frame(height: 16)
                Text(message).wpTypography(13, .bold).foregroundStyle(Self.withdrawRed)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Self.withdrawRed.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                    .onTapGesture { model.errorMessage = nil }
            }

            Spacer().frame(height: 20)

            SaveButton(saved: model.saved, saving: model.saving) {
                Task { await model.save(env: env, guest: guest) }
            }

            Spacer().frame(height: 16)
            SupportLinks(onOpenCouple: model.loggedIn ? { coupleOpen = true } : nil)

            Spacer().frame(height: 16)
            Rectangle().fill(WPColor.strokeSubtle).frame(height: 1)
            Spacer().frame(height: 20)

            if model.loggedIn {
                // 한 번에 하나만 묻는다. 로그아웃을 확인하는 중에는 탈퇴 줄이,
                // 탈퇴를 확인하는 중에는 로그아웃 버튼이 사라진다 (웹·안드로이드와 동일).
                if confirmWithdraw {
                    WithdrawConfirm(withdrawing: model.withdrawing, error: model.withdrawError) {
                        confirmWithdraw = false
                        model.withdrawError = nil
                    } onConfirm: {
                        Task {
                            let ok = await model.withdraw(env: env, push: push, guest: guest)
                            // 성공하면 로그인 화면으로 돌아가 이 화면이 사라진다.
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
                            await push.unregisterBeforeSignOut(env: env)
                            await env.signOut()
                            guest.clear()
                        }
                    }
                } else {
                    OutlineDangerButton(label: "로그아웃", paths: WPIconPaths.logout) { confirmSignOut = true }
                        .accessibilityIdentifier("user.signOut")
                    Spacer().frame(height: 12)
                    Rectangle().fill(Color(hex: 0xF4EFF2)).frame(height: 1)
                    Spacer().frame(height: 8)
                    // 위험한 동작일수록 눈에 덜 띄어야 실수로 눌리지 않는다.
                    Button { confirmWithdraw = true } label: {
                        Text("회원 탈퇴").wpTypography(12).underline().foregroundStyle(WPColor.gray400).padding(8)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("user.withdraw")
                }
            } else {
                OutlineDangerButton(label: "카카오로 로그인", paths: WPIconPaths.personFilled, tint: WPColor.primary) {
                    env.isAuthenticated = false
                }
            }

            Spacer().frame(height: 40).id("user.bottom")
        }
    }

    /// 웹 `#c0203c` — 삭제 위험을 뜻하는 붉은색. 브랜드 핑크와 섞이면 안 된다.
    static let withdrawRed = Color(hex: 0xC0203C)
}

// MARK: - 프로필 헤더

/// 안드로이드 `ProfileHead` — 뒤로(32) · 44 이니셜 원 + 이름 20 + "결혼식까지 N일".
private struct ProfileHeader: View {
    var name: String
    var date: KstDate
    var loading: Bool
    @Environment(\.dismiss) private var dismiss
    private var subtitle: String {
        let days = KstDate.today().days(until: date)
        return days > 0 ? "결혼식까지 \(days)일" : days == 0 ? "오늘이 결혼식이에요" : "결혼식이 \(-days)일 지났어요"
    }
    var body: some View {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        BrandHead(corner: 24, horizontal: 24, top: 20, bottom: 20) {
            HStack(spacing: 0) {
                Button { dismiss() } label: {
                    WPMaterialPathIcon(paths: WPIconPaths.arrowBack, size: 20, color: .white)
                        .frame(width: 32, height: 32).contentShape(Circle())
                }
                .buttonStyle(.plain).accessibilityLabel("뒤로가기").padding(.trailing, 8)
                Text(trimmed.isEmpty ? "?" : String(trimmed.prefix(1)).uppercased())
                    .wpTypography(18, .black).foregroundStyle(.white).frame(width: 44, height: 44)
                    .background(.white.opacity(0.2), in: Circle()).overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 2))
                VStack(alignment: .leading, spacing: 4) {
                    if loading {
                        SkeletonBox(width: 96, height: 22, onBrand: true)
                        SkeletonBox(width: 112, height: 14, onBrand: true).padding(.top, 2)
                    } else {
                        Text(trimmed.isEmpty ? "프로필" : trimmed).tracking(-0.4).wpTypography(20, .bold).lineLimit(1)
                        Text(subtitle).wpTypography(12.5).foregroundStyle(.white.opacity(0.8))
                    }
                }
                .foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 12)
            }
        }
    }
}

// MARK: - 조각들

/// 라벨을 **항상 띄우는** 입력 상자 — 라벨은 상자 **밖 위**, 상자에는 값만(회색 채움). 안드로이드 `Field`.
/// placeholder 만 있는 칸을 다시 만들지 말 것(값을 넣는 순간 무슨 칸인지 사라진다).
private struct LabeledField<Content: View>: View {
    var label: String
    var labelHint: String?
    /// 값 옆에 붙는 단위 ("만 원"). 상자 안 오른쪽 끝이다.
    var unit: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 4) {
                Text(label).wpTypography(13, .bold).foregroundStyle(WPColor.fgMuted)
                if let labelHint { Text(labelHint).wpTypography(13, .bold).foregroundStyle(WPColor.gray300) }
            }
            HStack(spacing: 8) {
                content.frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                if let unit { Text(unit).wpTypography(14).foregroundStyle(WPColor.fgMuted) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// 배경·테두리 없이 글자만 그리는 입력 — 바깥 `LabeledField` 가 껍데기를 맡는다.
private struct BareInput: View {
    @Binding var text: String
    var placeholder: String
    var numeric: Bool = false
    /// 사용자 값(예산)은 Tmoney — 안드로이드 `fontFamily = Tmoney`
    var tmoney: Bool = false

    var body: some View {
        let face: WPTypeface = tmoney ? .tmoney : .hak
        TextField("", text: $text, prompt: Text(placeholder).font(Font(face.uiFont(16, .regular))).foregroundColor(Color(hex: 0xB0B4BB)))
            .font(Font(face.uiFont(16, .regular)))
            .tracking(-0.16)
            .foregroundStyle(WPColor.fgNeutral)
            .keyboardType(numeric ? .numberPad : .default)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .tint(WPColor.primary)
    }
}

/// 고칠 수 없는 값(귀속된 사람) — 같은 자리·크기, 색만 한 단계 낮춘다.
private struct ReadOnlyValue: View {
    var text: String
    var tmoney = false
    var body: some View {
        Text(text).tracking(-0.16).wpTypography(16, face: tmoney ? .tmoney : .hak).foregroundStyle(WPColor.fgMuted)
    }
}

/// 웹 `h-14 rounded-2xl bg-[#ee2b8c] text-[15px] font-bold` — 저장 성공 시 2초간 초록 + 체크
private struct SaveButton: View {
    var saved: Bool
    var saving: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if saved { WPMaterialPathIcon(paths: WPIconPaths.check, size: 20, color: .white) }
                Text(saved ? "저장되었어요" : saving ? "저장 중..." : "저장").wpTypography(15, .bold).foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(saved ? Color(hex: 0x22C55E) : saving ? WPColor.primary.opacity(0.7) : WPColor.primary,
                        in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(saved || saving)
        .accessibilityIdentifier("user.save")
    }
}

/// 웹 `h-11 rounded-xl border border-[#e5484d33] bg-white text-[13px] font-bold text-[#c0203c]`
private struct OutlineDangerButton: View {
    var label: String
    var paths: [String]
    var tint: Color = UserView.withdrawRed
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                WPMaterialPathIcon(paths: paths, size: 16, color: tint)
                Text(label).wpTypography(13, .bold).foregroundStyle(tint)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// 회원 탈퇴 확인 — 무엇이 사라지고 무엇이 남는지 먼저 적는다 (웹·안드로이드와 같은 문구).
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
        VStack(alignment: .leading, spacing: 0) {
            Text("정말 탈퇴하시겠어요?").wpTypography(14, .bold).foregroundStyle(WPColor.textPrimary)
            Spacer().frame(height: 10)
            ForEach(lines, id: \.self) { line in
                Text(line).wpTypography(12.5, lineHeight: 19).foregroundStyle(WPColor.gray500).padding(.bottom, 5)
            }
            if let error {
                Text(error).wpTypography(12.5, lineHeight: 19).foregroundStyle(WPColor.danger).padding(.top, 4)
            }
            HStack(spacing: 8) {
                Button(action: onCancel) {
                    Text("취소").wpTypography(13, .bold).foregroundStyle(WPColor.textPrimary)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(WPColor.stone200, lineWidth: 1))
                        .opacity(withdrawing ? 0.5 : 1)
                }
                .buttonStyle(.plain).allowsHitTesting(!withdrawing)
                Button(action: onConfirm) {
                    Text(withdrawing ? "탈퇴 중..." : "탈퇴하기").wpTypography(13, .bold).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(UserView.withdrawRed, in: RoundedRectangle(cornerRadius: 12))
                        .opacity(withdrawing ? 0.6 : 1)
                }
                .buttonStyle(.plain).allowsHitTesting(!withdrawing)
                .accessibilityIdentifier("user.withdrawConfirm")
            }
            .padding(.top, 14)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(WPColor.stone200, lineWidth: 1))
    }
}

/// 로그아웃 확인. 이 버튼은 로그인한 사람에게만 보여 "기기의 플랜이 지워진다" 고 쓰지 않는다(안드로이드와 같은 문구).
private struct SignOutConfirm: View {
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("로그아웃해도 플랜은 그대로 남아 있어요.\n다시 로그인하면 이어서 볼 수 있습니다.".wpKeepAll)
                .wpTypography(14, .bold, lineHeight: 20)
                .foregroundStyle(WPColor.textPrimary)
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                Button(action: onCancel) {
                    Text("취소").wpTypography(14, .bold).foregroundStyle(WPColor.textPrimary)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(WPColor.gray200, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Button(action: onConfirm) {
                    Text("로그아웃").wpTypography(14, .bold).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("user.signOutConfirm")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(WPColor.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(WPColor.primary.opacity(0.13), lineWidth: 1))
    }
}
