import SwiftUI
import WPDomain
import WPModels
import WPNetworking

/// 청첩장 주인이 받은 축하 글을 모두 보고 고치고 지우는 시트(2026-11-09 사용자 승인 시안 `weddingplant-guestbook` ②).
/// 공개 방명록(`/plan/invitation/{slug}/guestbook`)이 아니라 주인용 목록을 쓴다 — 거기에만 `editable` 과 쪽 나눔이 있다.
@MainActor final class GuestbookOwnerModel: ObservableObject {
    @Published var wishes: [InvitationWish] = []
    @Published var total = 0
    @Published var loading = false
    @Published var error: String?
    @Published var notice: String?
    static let pageSize = 50
    var hasMore: Bool { wishes.count < total }

    func load(_ env: AppEnvironment) async {
        loading = true; error = nil; defer { loading = false }
        do { apply(try await env.api.send(Endpoint.myGuestbook(offset: 0, limit: Self.pageSize)), append: false) }
        catch { if !error.isCancellation { self.error = error.localizedDescription } }
    }
    func more(_ env: AppEnvironment) async {
        guard !loading, hasMore else { return }
        loading = true; defer { loading = false }
        do { apply(try await env.api.send(Endpoint.myGuestbook(offset: wishes.count, limit: Self.pageSize)), append: true) }
        catch { if !error.isCancellation { notice = error.localizedDescription } }
    }
    /// 성공하면 true. 서버가 돌려준 첫 쪽으로 목록을 갈아 끼운다(그 사이 들어온 새 글도 함께 보인다).
    func edit(_ wish: InvitationWish, name: String, message: String, env: AppEnvironment) async -> String? {
        if let invalid = InvitationRules.validateWish(name: name, message: message) { return invalid }
        do {
            let request = try Endpoint.editMyGuestbook(wishId: wish.id, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                                       message: message.trimmingCharacters(in: .whitespacesAndNewlines))
            apply(try await env.api.send(request), append: false)
            notice = "고쳤어요."
            return nil
        } catch { return error.localizedDescription }
    }
    func delete(_ wish: InvitationWish, env: AppEnvironment) async {
        do {
            apply(try await env.api.send(Endpoint.deleteMyGuestbook(wishId: wish.id)), append: false)
            notice = "지웠어요."
        } catch {
            if let api = error as? APIError, case let .http(status, _) = api, status == 404 {
                // 다른 기기(상대)가 먼저 지웠다 — 목록에서도 빼고 서버 문장을 그대로 보인다
                wishes.removeAll { $0.id == wish.id }; total = max(0, total - 1)
                notice = error.localizedDescription.isEmpty ? InvitationRules.guestbookAlreadyDeleted : error.localizedDescription
            } else { notice = error.localizedDescription }
        }
    }
    private func apply(_ page: InvitationGuestbook, append: Bool) {
        let merged = append ? wishes + page.wishes.filter { new in !wishes.contains { $0.id == new.id } } : page.wishes
        wishes = InvitationRules.newestFirst(merged)
        total = page.total ?? merged.count
    }
}

struct InvitationGuestbookSheet: View {
    /// 고치기·지우기가 끝나면 부른다 — 칸의 정원 · 수를 조용히 다시 받는다
    var onChanged: () -> Void
    /// `정원에서 만나기` — 시트를 내리고 그 하객을 정원에 불러낸다
    var onMeet: (InvitationWish) -> Void
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = GuestbookOwnerModel()
    @State private var query = ""
    @State private var editing: InvitationWish?
    @State private var deleting: InvitationWish?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(WPColor.gray400)
                    TextField(InvitationRules.guestbookSearchPlaceholder, text: $query)
                        .font(.custom("KakaoSmallSans-Regular", size: 14)).submitLabel(.search)
                        .accessibilityIdentifier("guestbook.search")
                }.padding(.horizontal, 12).frame(height: 44)
                    .background(WPColor.gray50, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(WPColor.gray200))
                    .padding(.horizontal, 16).padding(.bottom, 8)
                if let notice = model.notice {
                    Text(notice).font(.custom("KakaoSmallSans-Regular", size: 12)).foregroundStyle(WPColor.stone600)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.bottom, 6)
                        .accessibilityIdentifier("guestbook.notice")
                }
                list
            }
            .navigationTitle(InvitationRules.guestbookRowTitle(total: model.loading && model.wishes.isEmpty ? nil : model.total))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
        }
        .task { await model.load(env) }
        .sheet(item: $editing) { wish in
            GuestbookEditForm(wish: wish) { name, message in
                let failure = await model.edit(wish, name: name, message: message, env: env)
                if failure == nil { onChanged() }
                return failure
            }.presentationDetents([.medium, .large])
        }
        .alert(InvitationRules.guestbookDeleteConfirm, isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { wish in
            Button("지우기", role: .destructive) { Task { await model.delete(wish, env: env); onChanged() } }
            Button("그대로 두기", role: .cancel) {}
        }
    }

    @ViewBuilder private var list: some View {
        let shown = InvitationRules.filterWishes(model.wishes, query: query)
        if model.wishes.isEmpty && model.loading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = model.error, model.wishes.isEmpty {
            VStack(spacing: 12) {
                Text(error).font(.custom("KakaoSmallSans-Regular", size: 14))
                Button("다시 시도") { Task { await model.load(env) } }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.wishes.isEmpty {
            Text(InvitationRules.guestbookEmpty).font(.custom("KakaoSmallSans-Regular", size: 14)).foregroundStyle(WPColor.stone500)
                .frame(maxWidth: .infinity, maxHeight: .infinity).accessibilityIdentifier("guestbook.empty")
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(shown, id: \.id) { wish in
                        GuestbookOwnerRow(wish: wish, onMeet: { dismiss(); onMeet(wish) },
                                          onEdit: { editing = wish }, onDelete: { deleting = wish })
                        Divider().padding(.leading, 60)
                    }
                    if shown.isEmpty {
                        Text("찾는 축하 글이 없어요").font(.custom("KakaoSmallSans-Regular", size: 13)).foregroundStyle(WPColor.stone500).padding(.vertical, 32)
                    }
                    // 검색은 받은 글 안에서만 한다 — 더 보기는 검색과 상관없이 다음 쪽을 받는다
                    if model.hasMore {
                        Button { Task { await model.more(env) } } label: {
                            Text(model.loading ? "불러오는 중..." : "더 보기").font(.custom("KakaoSmallSans-Regular", size: 13))
                                .foregroundStyle(WPColor.stone600).frame(maxWidth: .infinity).frame(minHeight: 48)
                        }.buttonStyle(.plain).accessibilityIdentifier("guestbook.more")
                    }
                }.padding(.horizontal, 16).padding(.bottom, 24)
            }.scrollDismissesKeyboard(.interactively)
        }
    }
}

private struct GuestbookOwnerRow: View {
    let wish: InvitationWish
    let onMeet: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            GuestbookAvatar(avatar: wish.avatar, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(wish.name.isEmpty ? "하객" : wish.name).font(.custom("KakaoSmallSans-Bold", size: 14)).foregroundStyle(WPColor.textPrimary)
                    Spacer()
                    Text(InvitationRules.wishDateLabel(wish.createdAt)).font(.custom("KakaoSmallSans-Regular", size: 12)).foregroundStyle(WPColor.stone500)
                }
                Text(wish.message).font(.custom("KakaoSmallSans-Regular", size: 14)).foregroundStyle(WPColor.stone800)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Button("정원에서 만나기 →", action: onMeet).foregroundStyle(WPColor.primary)
                    Spacer()
                    // 서버가 허락한 글에만 낸다(옛 서버 · 다른 권한이면 editable 이 없다)
                    if wish.editable {
                        Button("고치기", action: onEdit).foregroundStyle(WPColor.stone600).accessibilityIdentifier("guestbook.edit.\(wish.id)")
                        Button("지우기", action: onDelete).foregroundStyle(WPColor.danger).accessibilityIdentifier("guestbook.delete.\(wish.id)")
                    }
                }.font(.custom("KakaoSmallSans-Regular", size: 12)).buttonStyle(.plain).padding(.top, 2)
            }
        }.padding(.vertical, 12).accessibilityElement(children: .contain).accessibilityIdentifier("guestbook.item.\(wish.id)")
    }
}

/// 정원의 하객 그림 그대로(같은 아틀라스의 서 있는 자세) — 목록과 정원의 사람이 같아 보여야 `정원에서 만나기` 가 읽힌다.
struct GuestbookAvatar: View {
    let avatar: Int
    var size: CGFloat = 40
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22).fill(Color(hex: 0xE9F3E4))
            if let image = GardenCanvas.standingSprite(avatar: avatar) {
                Image(uiImage: image).interpolation(.none).resizable().scaledToFit().padding(.top, size * 0.08)
            }
        }.frame(width: size, height: size).clipped().accessibilityHidden(true)
    }
}

private struct GuestbookEditForm: View {
    let wish: InvitationWish
    /// 실패하면 그 문장, 성공하면 nil
    let save: (String, String) async -> String?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var message: String
    @State private var failure: String?
    @State private var saving = false
    init(wish: InvitationWish, save: @escaping (String, String) async -> String?) {
        self.wish = wish; self.save = save
        _name = State(initialValue: wish.name); _message = State(initialValue: wish.message)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("이름", text: $name).accessibilityIdentifier("guestbook.editName")
                } header: { Text("이름") } footer: { Text("\(name.trimmingCharacters(in: .whitespacesAndNewlines).count)/\(InvitationRules.guestbookNameLimit)") }
                Section {
                    TextField("축하 글", text: $message, axis: .vertical).lineLimit(3...6).accessibilityIdentifier("guestbook.editMessage")
                } header: { Text("축하 글") } footer: { Text("\(message.trimmingCharacters(in: .whitespacesAndNewlines).count)/\(InvitationRules.guestbookMessageLimit)") }
                if let failure {
                    Text(failure).foregroundStyle(WPColor.danger).font(.custom("KakaoSmallSans-Regular", size: 13)).accessibilityIdentifier("guestbook.editError")
                }
            }
            .navigationTitle("축하 글 고치기").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "저장 중..." : "저장") {
                        saving = true
                        Task {
                            failure = await save(name, message); saving = false
                            if failure == nil { dismiss() }
                        }
                    }.disabled(saving).accessibilityIdentifier("guestbook.editSave")
                }
            }
        }.interactiveDismissDisabled(saving)
    }
}
