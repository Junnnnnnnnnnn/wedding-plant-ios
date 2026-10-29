import Combine
import Foundation
import PhotosUI
import SwiftUI
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 웹 `app/add-plen/page.tsx` 의 폼 상태.
///
/// 웹은 입력에 따라 섹션이 순차로 나타난다:
/// 제목 입력 → 카테고리 → 결제 유형 → (금액·일자·위치·메모)
/// 수정 모드에서는 처음부터 전부 보인다.
@MainActor
final class AddPlanViewModel: ObservableObject {

    // MARK: 입력

    /// 제목을 고치면 추천 칩이 다시 돈다(Android `setTitle` · 웹 handleTitleChange).
    @Published var title = "" { didSet { if title != oldValue { categorySelectedByUser = false } } }
    @Published var category: PlanCategory?
    /// 사용자가 칩·선택기로 카테고리를 **직접** 골랐다 — 추천 칩 줄을 접는다
    /// (Android `categorySelectedByUser`). 피드에서 채워 온 값·수정 화면의 원래 값은 고른 것이 아니라 칩이 남는다.
    @Published var categorySelectedByUser = false
    @Published var payType: PlanPayType?
    @Published var amount = ""
    @Published var date: KstDate = KstDate.today()
    @Published var dateUndecided = false
    /// 시각 `"HH:mm"`. **선택이다** — 날짜만 잡아 두는 일정이 훨씬 많아
    /// 비어 있는 게 기본이고, `날짜 미정` 이면 입력 자체를 감춘다.
    @Published var startTime: String?
    /// 돈이 나갔는지. **완료와 다른 축이다** — 계약금을 미리 낸 일정은
    /// 예정이어도 이미 쓴 돈이다. 입력은 금액 바로 아래 체크다.
    @Published var isPaid = false
    @Published var completed = false
    @Published var location = ""
    @Published var locationLat: Double = 0
    @Published var locationLng: Double = 0
    @Published var memo = ""

    // MARK: 목록·상태

    @Published var categories: [PlanCategory] = WeddingCategories.merge([])
    /// 이번 세션에서 사용자가 새로 만든 카테고리 (저장 시 `addCategoryNameList` 로 전송)
    @Published var addedCategories: [String] = []
    /// 선택기에서 최근 확정한 이름(화면 메모리뿐, Android `recentCategoryNames`)
    @Published var recentCategoryNames: [String] = []
    @Published var loadingDetail = false
    @Published var saving = false
    @Published var saved = false
    /// 등록은 끝났고 완료 처리만 남았다 — 다시 누르면 **같은 id 만** 완료한다(생성 POST 를 두 번 보내지 않는다)
    @Published private(set) var completionPending = false
    /// 지난 날짜로 만든 플랜의 id · 저장한 방(완료 처리만 실패했을 때 다시 쓸 것)
    private var createdPastPlan: (id: Int?, roomId: Int?)?
    /// 완료 처리와 함께 시작한 서류 올리기 — 다시 시도할 때 또 올리지 않고 이것을 기다린다
    private var pendingUpload: Task<Void, Never>?

    /// 지난 날짜의 새 플랜 — 결제 칸을 켠 채 잠그고 저장하면 완료로 등록한다(Android `UiState.autoCompletePast`)
    var autoCompletePast: Bool {
        PlanRules.completeNewPastPlan(date: dateUndecided ? nil : date, isEdit: isEditMode, today: KstDate.today())
    }
    /// 저장 중 · 저장 뒤 · 완료 처리만 남은 동안은 폼을 고치지 않는다(고친 값이 서버에 가지 않는다)
    var formLocked: Bool { saving || saved || completionPending }
    @Published var remainingBudget: Double?
    private var resolvedRoomId: Int?
    /// `/plan/user` 가 **성공**했고 방이 없었다 — "모른다" 와 가른다
    private var roomKnownAbsent = false
    /// 영수증 자물쇠에서 여는 준비 패스의 방 — 저장할 방과 같다.
    var receiptRoomId: Int? { resolvedRoomId }
    /// 게스트가 플랜 3개를 이미 채웠음 → 로그인 안내 (웹 `GuestPlanLimitModal`)
    @Published var guestLimitReached = false
    @Published var errorMessage: String?

    // MARK: 장소 검색

    @Published var locationError = false
    @Published var searching = false
    @Published var searchResults: [PlaceSearchResult] = []
    @Published var hasSearched = false
    /// 백엔드에 `/plan/place/search` 가 아직 없으면 true
    @Published var searchUnavailable = false
    /// 검색이 실패했다(5xx·네트워크) — 검색칸 바로 아래에 말한다(Android `searchError`).
    /// 실패는 "결과 없음" 이 아니라 `hasSearched` 를 켜지 않는다.
    @Published var searchError: String?
    /// 영수증 줄 — `nil` 받는 중·방 모름(줄 없음) / `true` 패스 있음(안내 줄) / `false` 없음(잠금 + 소개).
    /// Android `receiptPass` 와 같은 판정(`hasPass && !expired`).
    @Published var receiptPass: Bool?
    /// 로그인했다(게스트 저장이 아님) — 새 플랜의 서류 칸은 계정에만 낸다
    @Published private(set) var loggedIn = false

    // MARK: 저장 전에 담아 둔 서류 (새 플랜만, Android 2026-10-16)

    /// 담아 둔 서류. 저장으로 일정 id 가 생기면 그 일정에 하나씩 올라간다
    @Published private(set) var pendingDocs: [PendingDoc] = []
    /// 담지 못한 까닭(형식 · 크기 · 개수) — 서류 칸 안에 띄운다
    @Published private(set) var docsMessage: String?
    /// 고른 파일을 읽는 중 — 저장은 이것을 기다린다(고르자마자 저장하면 고른 것이 빠지지 않게)
    @Published private(set) var readingDocs = false
    /// 저장 뒤 서류를 올리는 중 — (지금 올리는 순번, 전체). 저장 버튼 글자가 된다
    @Published private(set) var uploadingDocs: (index: Int, total: Int)?
    private var readers: [Task<Void, Never>] = []
    /// 담아 둔 서류를 올리기 시작했다 — 이 뒤로는 더 담지 않는다
    private var uploadsStarted = false

    let isEditMode: Bool
    let editId: Int?
    /// 신규 생성 시 이 플랜을 넣을 방. 메인이 넘겨준다 (웹의 `?roomId=` 와 동일).
    private let roomId: Int?

    /// 지도에 찍혀 있는 좌표가 **어떤 장소명으로** 선택된 것인지.
    ///
    /// 장소를 고른 뒤 입력창의 이름만 바꾸면 좌표는 그대로 남아, 엉뚱한 위치가 저장됐다.
    private var selectedPlaceName = ""

    /// 검색 요청 순번. 늦게 도착한 이전 응답이 최신 결과를 덮어쓰지 않도록 쓴다.
    private var searchSequence = 0

    /// - Parameter prefill: 피드의 `내 플랜에 담기` 가 넘기는 값.
    ///   **리텐션 축이 이것이다** — 후기를 보다가 코어(내 플랜)로 되돌아오는 길.
    init(
        editId: Int? = nil,
        roomId: Int? = nil,
        initialDate: String? = nil,
        prefill: Prefill? = nil
    ) {
        self.editId = editId
        self.roomId = roomId
        self.isEditMode = editId != nil
        if let initialDate, let parsed = KstDate(dateString: initialDate) {
            self.date = parsed
        }
        if let prefill {
            // 업체명이 제목이 된다 — 일정 제목은 개인 메모인 경우가 많아,
            // 후기에서 담을 때는 고른 장소 이름이 더 쓸모 있다.
            self.title = prefill.title
            if !prefill.categoryName.isEmpty {
                self.category = PlanCategory(name: prefill.categoryName)
            }
            // **금액이 비공개면 비워 둔다.** 0 을 넣으면 "0원짜리 일정" 이 된다.
            if let amount = prefill.amount { self.amount = MoneyInput.text(amount) }
            self.location = prefill.location ?? ""
            self.selectedPlaceName = prefill.location ?? ""
        }
    }

    /// 다른 화면에서 값을 채워 열 때 쓰는 묶음.
    struct Prefill: Hashable, Sendable {
        var title: String
        var categoryName: String
        /// 비공개면 `nil`. **0 으로 채우지 말 것.**
        var amount: Double?
        var location: String?

        init(title: String, categoryName: String, amount: Double? = nil, location: String? = nil) {
            self.title = title
            self.categoryName = categoryName
            self.amount = amount
            self.location = location
        }
    }

    // MARK: - 파생 상태 (웹의 showCategory / showPaymentType / showRestFields)

    var showCategory: Bool { isEditMode || !title.trimmingCharacters(in: .whitespaces).isEmpty }
    var showPayType: Bool { isEditMode || category != nil }
    var showRestFields: Bool { isEditMode || payType != nil }

    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && category != nil && payType != nil
    }

    var hasCoordinates: Bool { locationLat != 0 || locationLng != 0 }

    /// 제목으로 추천되는 카테고리 (웹 `searchResults`).
    /// 제목이 비었거나 맞는 게 없으면 빈 목록.
    var suggestedCategories: [String] {
        if categorySelectedByUser { return [] }
        return PlanRules.suggestCategories(
            title: title,
            categories: categories.map(\.name) + addedCategories
        )
    }

    var saveButtonText: String {
        // 담아 둔 서류를 새 일정에 올리는 중이면 몇 번째인지 보여 기다리는 까닭을 말한다
        if let uploadingDocs { return "서류 올리는 중 \(uploadingDocs.index + 1)/\(uploadingDocs.total)" }
        if saving { return isEditMode ? "수정 중..." : "저장 중..." }
        if completionPending { return "완료 처리 다시 시도" }
        return isEditMode ? "수정하기" : "플랜 저장하기"
    }

    // MARK: - 로딩

    func load(env: AppEnvironment, guest: GuestStore) async {
        resolvedRoomId = roomId ?? env.boundRoomId
        loggedIn = await env.tokenStore.currentToken()?.isEmpty == false
        roomKnownAbsent = false
        if resolvedRoomId == nil, loggedIn {
            if let user: PlanUser = try? await env.api.send(Endpoint.user()) {
                resolvedRoomId = user.roomId
                roomKnownAbsent = user.roomId == nil
            }
        }
        await loadCategories(env: env)
        if let editId {
            await loadDetail(id: editId, env: env, guest: guest)
        }
        await loadReceiptPass(env: env)
        let args = ProcessInfo.processInfo.arguments
        if editId == nil, pendingDocs.isEmpty, args.contains("-WPDemoMode"), args.contains("-WPPendingDocsSample") {
            pendingDocs = PendingDocReader.samples()
        }
    }

    /// 영수증 줄의 패스 판정 — 저장할 방(`resolvedRoomId`)의 패스. 방을 모르거나 못 받았으면 줄을 내지 않는다
    /// (산 사람에게 자물쇠를 보이지 않게, Android `passState.loading || roomUnknown -> null`).
    func loadReceiptPass(env: AppEnvironment) async {
        /*
          방이 **없다고 확인된** 혼자 쓰는 사람에게는 패스도 없다 — 잠긴 칸을 보인다(결제 직전에 서버가 방을 만든다,
          `room/mine`). 묻지 못해 **모를 때**만 줄 · 칸을 내지 않는다(산 사람에게 자물쇠가 번쩍이지 않게).
        */
        guard let room = resolvedRoomId else { receiptPass = roomKnownAbsent ? false : nil; return }
        if let pass: PassState = try? await env.api.send(Endpoint.pass(roomId: room)) {
            receiptPass = pass.hasPass && !pass.expired
        } else {
            receiptPass = nil
        }
    }

    private func loadCategories(env: AppEnvironment) async {
        let token = await env.tokenStore.currentToken()
        let loggedIn = !(token ?? "").isEmpty
        // 비로그인은 인증 없는 경로를 쓴다. 안 그러면 카테고리가 하나도 안 보이고,
        // 카테고리가 필수라 게스트는 플랜을 아예 만들 수 없다.
        let request = Endpoint.categories(roomId: resolvedRoomId, loggedIn: loggedIn)

        guard let page = try? await env.api.send(request, decoding: PlanCategoryPage.self) else { return }
        categories = WeddingCategories.merge(page.list)
        addedCategories.removeAll { added in categories.contains { WeddingCategories.normalize($0.name) == WeddingCategories.normalize(added) } }
        syncSelectedCategory()
    }

    /// 수정 모드에서 상세를 먼저 받아온 경우, 카테고리 목록이 늦게 와도 선택을 맞춰준다.
    private func syncSelectedCategory() {
        guard let current = category, current.id == 0 else { return }
        guard let matched = categories.first(where: { WeddingCategories.normalize($0.name) == WeddingCategories.normalize(current.name) }) else { return }
        category = matched
    }

    private func loadDetail(id: Int, env: AppEnvironment, guest: GuestStore) async {
        // 게스트 플랜은 id 가 음수이고 서버에 없다. 로컬에서 찾는다.
        if id < 0 {
            guard let item = guest.findSchedule(id: id) else { return }
            completed = item.isScheduleCompleted
            apply(
                title: item.title,
                categoryName: item.categoryName,
                payType: item.payType?.rawValue,
                amount: item.amount,
                startDate: item.startDate,
                startTime: item.startTime,
                isPaid: item.isPaid,
                location: item.location,
                lat: item.locationLat,
                lng: item.locationLng,
                memo: item.memo
            )
            return
        }

        loadingDetail = true
        defer { loadingDetail = false }

        do {
            let detail = try await env.api.send(
                Endpoint.schedule(id: id),
                decoding: ScheduleDetail.self
            )
            completed = detail.isScheduleCompleted
            apply(
                title: detail.title,
                categoryName: detail.categoryName,
                payType: detail.payType,
                amount: detail.amount,
                startDate: detail.startDate,
                startTime: detail.startTime,
                isPaid: detail.isPaid,
                location: detail.location,
                lat: detail.locationLat,
                lng: detail.locationLng,
                memo: detail.memo
            )
            syncSelectedCategory()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func apply(
        title: String,
        categoryName: String,
        payType: String?,
        amount: Double?,
        startDate: String?,
        startTime: String?,
        isPaid: Bool,
        location: String?,
        lat: Double?,
        lng: Double?,
        memo: String?
    ) {
        self.title = title
        self.category = PlanCategory(name: categoryName)
        self.payType = PlanPayType.from(api: payType) ?? .other
        self.amount = amount.map(MoneyInput.text) ?? ""
        self.date = startDate.flatMap { KstDate(dateString: $0) } ?? KstDate.today()
        self.dateUndecided = (startDate ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        self.startTime = (startTime ?? "").isEmpty ? nil : startTime
        self.isPaid = isPaid
        self.location = location ?? ""
        self.locationLat = lat ?? 0
        self.locationLng = lng ?? 0
        self.memo = memo ?? ""
        // 불러온 좌표는 불러온 이름의 것이다. 안 그러면 첫 setLocation 에서 좌표가 지워진다.
        self.selectedPlaceName = (location ?? "").trimmingCharacters(in: .whitespaces)
    }

    // MARK: - 입력 변경

    func setAmount(_ value: String) {
        // 콤마를 제거하되 소수점은 유지한다.
        amount = MoneyInput.accept(value, previous: amount)
    }

    func setMemo(_ value: String) {
        memo = String(value.prefix(500))
    }

    func setDate(_ value: KstDate) {
        date = value
        dateUndecided = false
    }

    func toggleDateUndecided() {
        dateUndecided.toggle()
    }

    /// 제목 추천 칩을 눌렀을 때 — 이름으로 실제 카테고리를 찾아 선택한다.
    func selectCategory(named name: String) {
        category = categories.first { WeddingCategories.normalize($0.name) == WeddingCategories.normalize(name) }
            ?? PlanCategory(name: name, type: "USER")
        categorySelectedByUser = true
    }

    /// 모달에서 새 카테고리를 만든 경우 — 서버에 미리 만들지 않고 저장 시 함께 보낸다(웹과 동일).
    func addCategory(_ name: String) {
        let trimmed = WeddingCategories.clean(name)
        guard !trimmed.isEmpty else { return }
        let exists = categories.contains { WeddingCategories.normalize($0.name) == WeddingCategories.normalize(trimmed) } || addedCategories.contains { WeddingCategories.normalize($0) == WeddingCategories.normalize(trimmed) }
        guard !exists else {
            errorMessage = "이미 있는 카테고리예요."
            return
        }
        addedCategories.append(trimmed)
        category = PlanCategory(name: trimmed, type: "USER")
    }

    func setLocation(_ value: String) {
        locationError = false
        searchError = nil
        if value.trimmingCharacters(in: .whitespaces).isEmpty {
            // 웹과 동일: 입력을 비우면 검색 결과와 좌표도 초기화
            selectedPlaceName = ""
            location = value
            searchResults = []
            hasSearched = false
            locationLat = 0
            locationLng = 0
            return
        }

        // 장소를 고른 뒤 이름만 고치면 좌표가 그대로 남아 엉뚱한 위치가 저장된다.
        // 이름이 달라지는 순간 좌표를 버린다.
        if hasCoordinates, value.trimmingCharacters(in: .whitespaces) != selectedPlaceName {
            selectedPlaceName = ""
            locationLat = 0
            locationLng = 0
        }
        location = value
    }

    /// 지도를 눌러 고른 좌표(Android `setCoords`). 직접 찍은 좌표는 지금 적힌 이름의 것으로 본다 —
    /// 안 그러면 다음 `setLocation` 에서 방금 찍은 좌표가 지워진다.
    func setCoords(lat: Double, lng: Double) {
        selectedPlaceName = location.trimmingCharacters(in: .whitespaces)
        locationLat = lat
        locationLng = lng
    }

    func selectPlace(_ place: PlaceSearchResult) {
        selectedPlaceName = place.placeName.trimmingCharacters(in: .whitespaces)
        location = place.placeName
        locationLat = place.lat
        locationLng = place.lng
        searchResults = []
        hasSearched = false
    }

    // MARK: - 장소 검색

    /// 웹 `handleSearchLocation()` — 키워드로 장소 검색 (최대 10개)
    func searchPlaces(env: AppEnvironment) async {
        let query = location.trimmingCharacters(in: .whitespaces)
        guard !searching else { return }
        guard !query.isEmpty else { locationError = true; return }
        locationError = false

        // 이전 결과를 남겨두면 새 결과가 오기 전에 옛 항목을 눌러
        // 엉뚱한 좌표가 저장될 수 있다.
        searching = true
        searchUnavailable = false
        searchError = nil
        searchResults = []

        searchSequence += 1
        let sequence = searchSequence

        do {
            let page = try await env.api.send(
                Endpoint.searchPlaces(query: query),
                decoding: PlaceSearchPage.self
            )
            // 더 최신 검색이 시작됐으면 이 응답은 버린다.
            guard sequence == searchSequence else { return }
            searching = false
            searchResults = page.list
            hasSearched = true
        } catch {
            guard sequence == searchSequence else { return }
            searching = false
            searchResults = []
            // 실패는 "결과 없음" 이 아니다(Android) — 켜면 "검색 결과가 없습니다." 가 진짜 오류를 가린다.
            hasSearched = false
            // 404 = 백엔드에 프록시가 아직 없음. 그 외는 검색칸 바로 아래에 오류로 표시.
            if case .http(let status, _) = error as? APIError, status == 404 {
                searchUnavailable = true
            } else {
                searchError = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    // MARK: - 저장

    func save(env: AppEnvironment, guest: GuestStore) async {
        guard !saving else { return }
        guard let category, let payType, !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "제목·카테고리·결제 유형은 필수예요."
            return
        }

        let token = await env.tokenStore.currentToken()
        guard let token, !token.isEmpty else {
            saveAsGuest(category: category, payType: payType, guest: guest)
            return
        }

        saving = true
        errorMessage = nil
        defer { saving = false }
        // 방금 고른 파일을 읽는 중이면 마저 담고 저장한다
        for reader in readers { await reader.value }

        // 이미 만들어 두고 완료 처리만 실패했다 — 그 플랜만 완료한다
        if let created = createdPastPlan {
            await completeCreatedPastPlan(env: env, id: created.id, roomId: created.roomId)
            return
        }
        let completePast = autoCompletePast

        /*
          방이 없으면 **개인 일정으로 저장한다**(Android `targetRoomAsync` · 웹 `useOwnRoomId`). 방은 초대 참여나
          패스 결제 때 생겨서, 막 가입해 혼자 쓰는 사람은 방이 없다 — 예전에는 여기서 저장을 막아 그런 사람은
          플랜을 하나도 만들 수 없었다(2026-10-19 심사용 새 계정). 홈도 방이 없으면 개인 목록을 읽는다.
          화면을 열 때 묻지 못했을 수 있으니 저장 직전에 한 번 더 묻는다.
        */
        if !isEditMode && resolvedRoomId == nil {
            resolvedRoomId = env.boundRoomId
            if resolvedRoomId == nil, let user: PlanUser = try? await env.api.send(Endpoint.user()) {
                resolvedRoomId = user.roomId
            }
        }
        let request = ScheduleWriteRequest(
            categoryName: category.name,
            title: title.trimmingCharacters(in: .whitespaces),
            payType: payType.rawValue,
            amount: Double(amount) ?? 0,
            // 미정이면 nil → 명시적 null 로 직렬화된다.
            // 수정에서 이미 잡혀 있던 날짜를 미정으로 되돌릴 수 있어야 하기 때문이다.
            startDate: dateUndecided ? nil : date.dateString,
            location: location.trimmingCharacters(in: .whitespaces),
            locationLat: locationLat,
            locationLng: locationLng,
            memo: memo.trimmingCharacters(in: .whitespaces),
            // 생성에는 roomId 필수. 빼면 200 인데 목록에 영영 안 나온다.
            // 수정에는 붙이지 않는다.
            //
            // **귀속된 방을 여기 한 곳에서 메운다.** 호출부마다 넘기게 하면 한 곳만
            // 빠뜨려도 새 일정이 **화면에 보이지도 않는 개인 플랜에** 저장된다 —
            // 실제로 피드의 `내 플랜에 담기` 가 roomId 없이 열리고 있었다.
            roomId: isEditMode ? nil : resolvedRoomId,
            addCategoryNameList: addedCategories.isEmpty ? nil : addedCategories,
            /*
              완료한 플랜은 결제 칸을 **보내지 않는다**(PATCH 에서 빠진 키는 서버가 저장된 칸을 그대로 둔다). 예전에는 불러올 때
              받은 `isPaid` 를 "원래 값" 으로 되돌려 보냈는데, 그 값은 저장된 칸이 아니라 백엔드 `isSchedulePaid()` 계산값이라
              완료면 늘 `true` 였다 — 완료한 플랜을 한 번 고치면 결제 칸이 `true` 로 굳어, 나중에 예정으로 되돌렸을 때 고른 적
              없는 `예정 · 결제함` 이 남았다(Android 7523938, 2026-10-28 QA).
            */
            isPaid: completed ? nil : (isPaid || completePast),
            // 날짜가 미정이면 시각도 뜻이 없다. 수정에서 지우려면 **빈 문자열**을
            // 보내야 한다 — 키를 빼면 PATCH 시맨틱상 "변경 없음" 이라 남는다.
            startTime: dateUndecided ? "" : (startTime ?? "")
        )

        do {
            if let editId {
                try await env.api.sendIgnoringData(Endpoint.updateSchedule(id: editId, request))
            } else {
                // POST /plan/schedule 은 `{ id }` 를 돌려준다(백엔드 PostPlanScheduleResponse) — 담아 둔 서류를 붙일 자리
                let response = try await env.api.sendRaw(Endpoint.createSchedule(request))
                try Self.checkEnvelope(response.body)
                let id = Self.createdId(response.body)
                if completePast {
                    /*
                      생성 API 는 상태를 받지 않는다 — 만든 뒤 그 id 로 완료 처리를 따로 부른다. 여기서부터는 생성을 되풀이하지
                      않는다(완료만 실패해도 다시 누르면 완료만). 서류는 바로 올리기 시작하되, 긴 올리기가 완료 처리를 막지 않게
                      기다림은 뒤로 미룬다(Android `startPendingDocs`).
                    */
                    createdPastPlan = (id, resolvedRoomId)
                    completionPending = true
                    startPendingDocs(env: env, scheduleId: id)
                    await completeCreatedPastPlan(env: env, id: id, roomId: resolvedRoomId)
                    return
                }
                await uploadPendingDocs(env: env, scheduleId: id)
            }
            if (Double(amount) ?? 0) > 0 {
                var query = Endpoint.amountDetail(roomId: resolvedRoomId.map(String.init)); query.timeout = 3
                if let amount: AmountDetail = try? await env.api.send(query) { remainingBudget = amount.initialCapital - amount.totalPlannedAndUsedAmount }
            }
            saved = true
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// 지난 날짜로 만든 플랜을 완료로 바꾸고 마무리한다. 실패하면 `completionPending` 을 남겨 다시 누를 때 이것만 한다.
    /// 저장 버튼의 Task 는 화면이 사라져도 취소되지 않아(구조화되지 않은 Task) 이미 시작한 완료 처리는 끝까지 간다.
    private func completeCreatedPastPlan(env: AppEnvironment, id: Int?, roomId: Int?) async {
        do {
            guard let id else { throw APIError.backend(message: "등록된 플랜 번호를 확인하지 못했어요.") }
            try await env.api.sendIgnoringData(Endpoint.updateScheduleStatus(id: id, status: .completed))
        } catch {
            errorMessage = "플랜은 등록됐지만 완료 처리하지 못했어요. 다시 누르면 등록한 플랜의 완료 처리만 재시도해요."
            return
        }
        await pendingUpload?.value
        uploadingDocs = nil
        if (Double(amount) ?? 0) > 0 {
            var query = Endpoint.amountDetail(roomId: roomId.map(String.init)); query.timeout = 3
            if let amount: AmountDetail = try? await env.api.send(query) { remainingBudget = amount.initialCapital - amount.totalPlannedAndUsedAmount }
        }
        completionPending = false
        saved = true
    }

    /// 서류 올리기를 시작만 한다(완료 처리와 나란히). 한 번만 — 다시 시도에서 또 올리지 않는다.
    private func startPendingDocs(env: AppEnvironment, scheduleId: Int?) {
        guard pendingUpload == nil, !pendingDocs.isEmpty else { return }
        pendingUpload = Task { [weak self] in await self?.uploadPendingDocs(env: env, scheduleId: scheduleId) }
    }

    // MARK: - 서류 담기

    /// 고른 사진을 담아 둔다(새 플랜만). 올릴 수 없는 것은 **고른 자리에서** 거절한다.
    func addPendingPhotos(_ items: [PhotosPickerItem]) {
        stage { try await withThrowingTaskGroup(of: (Int, PendingDoc).self) { group in
            for (index, item) in items.enumerated() { group.addTask { (index, try await PendingDocReader.read(item)) } }
            var out: [(Int, Result<PendingDoc, Error>)] = []
            while let next = await group.nextResult() {
                switch next { case .success(let pair): out.append((pair.0, .success(pair.1))); case .failure(let e): out.append((out.count, .failure(e))) }
            }
            return out.sorted { $0.0 < $1.0 }.map(\.1)
        } }
    }

    /// 고른 PDF 를 담아 둔다(파일 앱)
    func addPendingPdfs(_ urls: [URL]) {
        stage { urls.map { url in Result { try PendingDocReader.read(url) } } }
    }

    private func stage(_ read: @escaping () async throws -> [Result<PendingDoc, Error>]) {
        guard editId == nil, !formLocked, !uploadsStarted else { return }
        readingDocs = true
        let task = Task { [weak self] in
            let checked = (try? await read()) ?? [.failure(DocUploadError(message: "파일을 읽지 못했어요. 다시 선택해 주세요."))]
            guard let self else { return }
            guard !self.saved, !self.uploadsStarted else { PendingDocReader.discard(checked.compactMap { try? $0.get() }); return }
            let fresh = checked.compactMap { try? $0.get() }
            let (kept, dropped) = DocumentRules.stage(self.pendingDocs, picked: fresh)
            PendingDocReader.discard(fresh.filter { doc in !kept.contains { $0.file == doc.file } })
            self.pendingDocs = kept
            self.docsMessage = dropped > 0 ? DocumentRules.stageLimitMessage
                : checked.lazy.compactMap { result -> String? in
                    if case .failure(let error) = result { return (error as? LocalizedError)?.errorDescription ?? "파일을 읽지 못했어요. 다시 선택해 주세요." }
                    return nil
                }.first
        }
        readers.append(task)
        Task { [weak self] in
            await task.value
            self?.readers.removeAll { $0 == task }
            self?.readingDocs = !(self?.readers.isEmpty ?? true)
        }
    }

    /// 담아 둔 서류를 뺀다 — 아직 올리지 않았으니 되돌릴 일이 없어 묻지 않는다
    func removePendingDoc(_ doc: PendingDoc) {
        guard !formLocked else { return }
        pendingDocs.removeAll { $0 == doc }
        PendingDocReader.discard([doc])
        docsMessage = nil
    }

    /**
     담아 둔 서류를 **방금 만든 일정**에 올린다. 올리기는 화면이 아니라 `PendingDocUploader` 가 앱 수명 동안 한다 —
     올리는 동안 탭 · 뒤로가기로 화면을 떠나도 끝까지 올리고, 못 올린 것은 거기서 알린다.
     */
    private func uploadPendingDocs(env: AppEnvironment, scheduleId: Int?) async {
        let docs = pendingDocs
        guard editId == nil, !docs.isEmpty, !uploadsStarted else { return }
        uploadsStarted = true
        guard let scheduleId else {
            PendingDocReader.discard(docs)
            PendingDocUploader.shared.announce(failed: docs.count)
            return
        }
        _ = await PendingDocUploader.shared.upload(env: env, scheduleId: scheduleId, docs: docs) { [weak self] index, total in
            self?.uploadingDocs = (index, total)
        }
        // 다 올렸으면 진행 표시를 바로 걷는다(남은 예산을 받는 동안 `3/3` 이 남지 않게)
        uploadingDocs = nil
    }

    /// `{ result: false }` 봉투면 서버 문장으로 실패시킨다(`sendIgnoringData` 와 같은 판정)
    private static func checkEnvelope(_ body: Data) throws {
        guard !body.isEmpty, let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let result = object["result"] as? Bool, !result else { return }
        throw APIError.backend(message: (object["error"] as? String) ?? (object["message"] as? String))
    }

    private static func createdId(_ body: Data) -> Int? {
        guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let data = object["data"] as? [String: Any] else { return nil }
        return (data["id"] as? Int) ?? (data["id"] as? NSNumber)?.intValue ?? (data["id"] as? String).flatMap(Int.init)
    }

    /// 비로그인 저장 — 웹과 동일하게 **최대 3개**까지만 로컬에 담는다.
    ///
    /// `saving` 을 먼저 세워 중복 제출을 막는다. 웹은 이 가드가 없어서
    /// 저장 버튼을 빠르게 두 번 누르면 같은 플랜이 두 건 들어갔다.
    private func saveAsGuest(category: PlanCategory, payType: PlanPayType, guest: GuestStore) {
        guard guest.canAddSchedule else {
            guestLimitReached = true
            return
        }
        saving = true

        let item = ScheduleItem(
            id: 0, // GuestStore 가 음수 id 를 새로 발급한다
            categoryName: category.name,
            title: title.trimmingCharacters(in: .whitespaces),
            amount: Double(amount) ?? 0,
            startDate: dateUndecided ? nil : date.dateString,
            status: ScheduleStatus(rawValue: autoCompletePast ? "COMPLETED" : "NORMAL"),
            location: location.trimmingCharacters(in: .whitespaces),
            locationLat: locationLat,
            locationLng: locationLng,
            memo: memo.trimmingCharacters(in: .whitespaces),
            payType: PayType(rawValue: payType.rawValue),
            addCategoryNameList: addedCategories,
            isPaid: isPaid || autoCompletePast,
            startTime: dateUndecided ? nil : startTime
        )
        guest.addSchedule(item)
        saved = true
        errorMessage = nil
    }
}
