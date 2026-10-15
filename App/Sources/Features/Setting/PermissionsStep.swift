import SwiftUI
import UserNotifications

/// 온보딩의 권한 단계(약관 다음, 초대 앞) — 안드로이드 `ui/setting/PermissionsStep.kt` 이식.
///
/// 앱이 폰에서 쓰는 것 셋을 **무엇에 쓰는지와 함께** 보여 주고, 그중 허락이 필요한 **알림만** 묻는다.
/// 시스템 대화상자가 맥락 없이 뜨면 거절하기 쉽고, 한 번 거절하면 앱이 다시 묻지 못한다.
///
/// - **사진** — 묻지 않는다. 사진 고르기(PHPicker)는 고른 사진만 앱에 건네 권한이 없다.
/// - **움직임** — 묻지 않는다. 기울기(Core Motion 의 자세)는 허락이 필요 없다.
///   대신 위 카드를 **지금 기울여 볼 수 있게** 둔다 — 플랜을 등록했을 때 뜨는 완료 카드와 같은 효과다.
///
/// 문구는 안드로이드와 한 글자도 다르지 않게 둔다(안드로이드 화면이 정답).
/// 허용하든 미루든 다음으로 간다 — 막으면 온보딩에서 이탈한다.
struct PermissionsStep: View {
    var onNext: () -> Void
    @EnvironmentObject private var push: PushService
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var tilt = CardTilt()
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var asking = false

    private var granted: Bool { status == .authorized || status == .provisional || status == .ephemeral }
    private var askNow: Bool { status == .notDetermined }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 80)
                LandingHero(
                    title: "이렇게 챙겨 드릴게요",
                    subtitle: "필요한 것만 쓰고, 언제든 폰 설정에서 바꿀 수 있어요",
                    titleSize: 28,
                    subtitleSize: 14,
                    useUserFont: false,
                    alignStart: true
                )

                Spacer().frame(height: 24)
                TiltPreviewCard(tilt: tilt)
                Spacer().frame(height: 8)
                Text("폰을 살짝 기울여 보세요")
                    .wpTypography(12)
                    .foregroundStyle(WPColor.fgSubtle)

                Spacer().frame(height: 20)
                VStack(spacing: 10) {
                    PermissionRow(
                        icon: PermissionIcon.bell,
                        title: "알림",
                        detail: "신랑·신부가 보낸 말과 잔금·중도금 날짜를 알려 드려요.",
                        status: granted ? "켜져 있어요" : askNow ? "허용이 필요해요" : "꺼져 있어요",
                        done: granted
                    )
                    PermissionRow(
                        icon: PermissionIcon.image,
                        title: "사진",
                        detail: "고를 때마다 고른 사진만 앱에 전해져요. 앨범 전체를 열어 두지 않아요.",
                        status: "허락 없이 돼요",
                        done: true
                    )
                    PermissionRow(
                        icon: PermissionIcon.smartphone,
                        title: "움직임",
                        detail: "폰을 기울이면 플랜 완료 카드가 따라 움직여요. 움직임 센서는 따로 허락받지 않아요.",
                        status: "허락 없이 돼요",
                        done: true
                    )
                }
                .frame(maxWidth: 340)

                Spacer().frame(height: 28)

                WPNextButton(
                    text: askNow ? "알림 허용하고 계속하기" : "다음",
                    identifier: "setting.permissions.next"
                ) {
                    Task { await next(ask: askNow) }
                }

                Spacer().frame(height: 12)
                if askNow {
                    // **반드시 빠져나갈 길을 함께 둔다.** 미루면 홈에서 다시 묻지 않는다.
                    Button {
                        Task { await next(ask: false) }
                    } label: {
                        Text("나중에 할게요")
                            .wpTypography(13)
                            .foregroundStyle(WPColor.gray400)
                            .underline()
                            .padding(.horizontal, 12)
                            .frame(minHeight: 48)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(asking)
                    .accessibilityIdentifier("setting.permissions.later")
                }
                Spacer().frame(height: 28)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .task {
            status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            tilt.start()
        }
        .onDisappear { tilt.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                tilt.start()
                // 설정 앱에서 켜고 돌아왔을 때도 맞게
                Task { status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus }
            } else {
                tilt.stop()
            }
        }
    }

    private func next(ask: Bool) async {
        // 시스템 대화상자가 떠 있는 동안의 두 번째 누름은 막는다
        guard !asking else { return }
        asking = true
        // 여기서 물었으면 홈에 닿아 또 묻지 않는다
        UserDefaults.standard.set(true, forKey: "notification.permissionExplained")
        if ask && !env.isDemo {
            await push.requestAuthorizationIfNeeded()
            await push.registerCurrentToken()
        }
        asking = false
        onNext()
    }
}

/// 기울기 미리보기 — 플랜 완료 카드(`PlanBloomSuccess`)를 작게 줄인 모양. 같은 무지개 테두리와 종이 면.
private struct TiltPreviewCard: View {
    @ObservedObject var tilt: CardTilt
    private let colors = BloomAction.create.colors

    var body: some View {
        VStack(spacing: 0) {
            Image(uiImage: UIImage(named: "heart_sprout.png") ?? UIImage())
                .resizable()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                // 앞에 떠 있는 것처럼 — 기울인 쪽으로 조금 더 미끄러진다
                .offset(x: tilt.y * 0.35, y: -tilt.x * 0.35)
            Spacer().frame(height: 10)
            Text("플랜이 등록되었어요")
                .wpTypography(16, .bold)
                .foregroundStyle(colors[3])
                .multilineTextAlignment(.center)
            Spacer().frame(height: 4)
            Text("✧ BLOOM TOGETHER ✧")
                .wpTypography(7)
                .tracking(1)
                .foregroundStyle(colors[4])
        }
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(colors: Array(colors.prefix(3)), startPoint: .topLeading, endPoint: .bottomTrailing)
            // 안드로이드 `tiltGlare(strength = 0.45)` — 면 바로 위, 내용 밑
            GeometryReader { geometry in
                RadialGradient(
                    colors: [.white.opacity(0.45 * (0.35 + 0.65 * min(1, (abs(tilt.x) + abs(tilt.y)) / 25))), .clear],
                    center: UnitPoint(x: 0.5 + 0.6 * max(-1, min(1, tilt.y / 25)), y: 0.25 - 0.5 * max(-1, min(1, tilt.x / 25))),
                    startRadius: 0,
                    endRadius: max(geometry.size.width, geometry.size.height) * 0.75
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .padding(6)
        .background(
            LinearGradient(colors: WPColor.bloomRainbow, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .frame(maxWidth: 260)
        // 안드로이드 `deviceTilt(follow = 0.7f, maxDegrees = 14f)` — 카드는 폰과 반대로 돈다
        .rotation3DEffect(.degrees(max(-14, min(14, -tilt.x * 0.7))), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
        .rotation3DEffect(.degrees(max(-14, min(14, -tilt.y * 0.7))), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("기울기 미리보기 카드")
    }
}

private struct PermissionRow: View {
    var icon: [String]
    var title: String
    var detail: String
    var status: String
    var done: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.white)
                .frame(width: 34, height: 34)
                .overlay { WPLucideIcon(paths: icon, size: 18, color: WPColor.primary) }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 0) {
                    Text(title)
                        .wpTypography(14, .bold)
                        .foregroundStyle(WPColor.stone900)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(status)
                        .wpTypography(11, .bold)
                        .foregroundStyle(done ? WPColor.primary : WPColor.fgSubtle)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .frame(minHeight: 22)
                        .overlay(Capsule().strokeBorder(done ? WPColor.primary.opacity(0.35) : WPColor.stone200, lineWidth: 1))
                }
                // 우리가 쓴 문장이라 어절로 꺾는다(안드로이드 `keepAll`)
                WPParagraph(text: detail, size: 12, lineHeight: 18, color: UIColor(WPColor.fgSubtle))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// 안드로이드 `LucideIcons.Bell / Image / Smartphone` 원본 경로(같은 문자열)
private enum PermissionIcon {
    static let bell = [
        "M10.268 21a2 2 0 0 0 3.464 0",
        "M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326",
    ]
    static let image = [
        "M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-14a2 2 0 0 1 2 -2z",
        "M7 9a2 2 0 1 0 4 0a2 2 0 1 0 -4 0",
        "m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21",
    ]
    static let smartphone = [
        "M7 2h10a2 2 0 0 1 2 2v16a2 2 0 0 1 -2 2h-10a2 2 0 0 1 -2 -2v-16a2 2 0 0 1 2 -2z",
        "M12 18h.01",
    ]
}
