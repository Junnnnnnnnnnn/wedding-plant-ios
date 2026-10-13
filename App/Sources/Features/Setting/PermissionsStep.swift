import SwiftUI
import UserNotifications

struct PermissionsStep: View {
    var onNext: () -> Void
    @EnvironmentObject private var push: PushService
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var tilt = CardTilt()
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var asking = false
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                LandingHero(title: "이렇게 챙겨 드릴게요", subtitle: "필요한 것만 쓰고, 언제든 폰 설정에서 바꿀 수 있어요", titleSize: 28, subtitleSize: 14, useUserFont: false)
                VStack(spacing: 10) {
                    Image("heart_sprout").resizable().frame(width: 56,height: 56).clipShape(RoundedRectangle(cornerRadius: 16)).offset(x: tilt.y*0.35,y: -tilt.x*0.35)
                    Text("플랜이 등록되었어요").font(WPFont.hak(19, .bold)).foregroundStyle(Color(hex: 0x284C39))
                    Text("우리의 준비가 한 장씩 쌓여요").font(WPFont.hak(11)).foregroundStyle(Color(hex: 0x598463))
                }.padding(.vertical, 22).frame(maxWidth: 248).background(LinearGradient(colors: Array(BloomAction.create.colors.prefix(3)), startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 13)).padding(6).background(LinearGradient(colors: [0xFAF4CE,0x96C6AE,0xE9BED8,0xC5E2E1,0xF3E5CB].map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18)).rotation3DEffect(.degrees(max(-14,min(14,-tilt.x*0.7))), axis: (x: 1,y: 0,z: 0)).rotation3DEffect(.degrees(max(-14,min(14,-tilt.y*0.7))), axis: (x: 0,y: 1,z: 0))
                Text("폰을 살짝 기울여 보세요").font(WPFont.hak(12)).foregroundStyle(WPColor.gray400)
                VStack(spacing: 10) {
                    row("bell", "알림", "신랑·신부가 보낸 말과 잔금·중도금 날짜를 알려 드려요.", status == .authorized ? "켜져 있어요" : status == .notDetermined ? "허용이 필요해요" : "꺼져 있어요")
                    row("photo", "사진", "고를 때마다 고른 사진만 앱에 전해져요. 앨범 전체를 열어 두지 않아요.", "고른 사진만 사용해요")
                    row("iphone", "움직임", "폰을 기울이면 플랜 완료 카드가 따라 움직여요.", "기기를 기울여 보세요")
                }.frame(maxWidth: 340)
                Button { Task { await next(ask: status == .notDetermined) } } label: { Text(status == .notDetermined ? "알림 허용하고 계속하기" : "다음").font(WPFont.hak(16, .bold)).frame(maxWidth: .infinity).frame(height: 52) }.buttonStyle(.borderedProminent).disabled(asking).accessibilityIdentifier("setting.permissions.next")
                if status == .notDetermined { Button("나중에 할게요") { Task { await next(ask: false) } }.font(WPFont.hak(13)).foregroundStyle(WPColor.gray400).disabled(asking).accessibilityIdentifier("setting.permissions.later") }
            }.padding(.horizontal, 24).padding(.top, 80).padding(.bottom, 28)
        }.task { status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus; tilt.start() }
            .onDisappear { tilt.stop() }.onChange(of: scenePhase) { _, phase in if phase == .active { tilt.start() } else { tilt.stop() } }
    }
    private func row(_ icon: String,_ title: String,_ body: String,_ status: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).frame(width: 32,height: 32).foregroundStyle(WPColor.primary)
            VStack(alignment: .leading, spacing: 6) { Text(title).font(WPFont.hak(14, .bold)); Text(body).font(WPFont.hak(12)).foregroundStyle(WPColor.gray500); Text(status).font(WPFont.hak(10)).foregroundStyle(WPColor.primary) }
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(WPColor.gray200))
    }
    private func next(ask: Bool) async {
        guard !asking else { return }; asking = true
        UserDefaults.standard.set(true, forKey: "notification.permissionExplained")
        if ask && !env.isDemo { await push.requestAuthorizationIfNeeded(); await push.registerCurrentToken() }
        asking = false; onNext()
    }
}
