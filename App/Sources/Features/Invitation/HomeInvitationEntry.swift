import SwiftUI
import WPDomain

struct HomeInvitationEntry: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject var model: InvitationStore
    var rowOnly = false
    var body: some View {
        Group {
            switch model.state {
            case .loading, .error: EmptyView()
            case .landing:
                if rowOnly {
                NavigationLink { InvitationStudioView() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope").font(.system(size: 20)).foregroundStyle(WPColor.primary).frame(width: 38, height: 38).background(WPColor.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("모바일 청첩장").font(WPFont.hak(14, .bold))
                            Text("준비 패스를 구매하고 모바일 청첩장을 무료로 받아 보세요").font(WPFont.hak(12)).foregroundStyle(.secondary)
                        }; Spacer(); Text("구경하기").font(WPFont.hak(12, .bold))
                    }.padding(.horizontal, 20).padding(.vertical, 14).background(.white).overlay(alignment: .top) { WPColor.gray100.frame(height: 1).padding(.horizontal, 20) }
                }.buttonStyle(.plain)
                }
            case .empty, .mine:
                if !rowOnly {
                NavigationLink { InvitationStudioView() } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        SeasideGardenView(wishes: model.wishes, empty: model.state == .empty, peek: true,
                            groom: model.result?.invitation?.groom ?? "", bride: model.result?.invitation?.bride ?? "")
                            .aspectRatio(2, contentMode: .fit).allowsHitTesting(false).clipped()
                            .id(model.state == .empty ? "empty" : "mine")
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(model.state == .empty ? "하객 자리가 비어 있어요" : model.result?.invitation?.published == true ? "청첩장 공개 중" : "청첩장이 아직 비공개예요").font(WPFont.hak(15, .bold))
                                Text(model.state == .empty ? "사진 · 날짜 · 장소를 담아 하객을 맞아요" : "링크 · QR로 하객을 맞아요").font(WPFont.hak(12)).foregroundStyle(.secondary)
                            }; Spacer(); Text(model.state == .empty ? "만들기" : "보기").font(WPFont.hak(13, .bold))
                        }.padding(16)
                    }.background(WPColor.fill).clipShape(RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain)
            }
                }
        }
    }
}
