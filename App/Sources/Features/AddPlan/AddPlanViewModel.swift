import Combine
import Foundation
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

    @Published var title = ""
    @Published var category: PlanCategory?
    @Published var payType: PlanPayType?
    @Published var amount = ""
    @Published var date: KstDate = KstDate.today()
    @Published var dateUndecided = false
    @Published var location = ""
    @Published var locationLat: Double = 0
    @Published var locationLng: Double = 0
    @Published var memo = ""

    // MARK: 목록·상태

    @Published var categories: [PlanCategory] = []
    /// 이번 세션에서 사용자가 새로 만든 카테고리 (저장 시 `addCategoryNameList` 로 전송)
    @Published var addedCategories: [String] = []
    @Published var loadingDetail = false
    @Published var saving = false
    @Published var saved = false
    /// 게스트가 플랜 3개를 이미 채웠음 → 로그인 안내 (웹 `GuestPlanLimitModal`)
    @Published var guestLimitReached = false
    @Published var errorMessage: String?

    // MARK: 장소 검색

    @Published var searching = false
    @Published var searchResults: [PlaceSearchResult] = []
    @Published var hasSearched = false
    /// 백엔드에 `/plan/place/search` 가 아직 없으면 true
    @Published var searchUnavailable = false

    let isEditMode: Bool
    private let editId: Int?
    /// 신규 생성 시 이 플랜을 넣을 방. 메인이 넘겨준다 (웹의 `?roomId=` 와 동일).
    private let roomId: Int?

    /// 지도에 찍혀 있는 좌표가 **어떤 장소명으로** 선택된 것인지.
    ///
    /// 장소를 고른 뒤 입력창의 이름만 바꾸면 좌표는 그대로 남아, 엉뚱한 위치가 저장됐다.
    private var selectedPlaceName = ""

    /// 검색 요청 순번. 늦게 도착한 이전 응답이 최신 결과를 덮어쓰지 않도록 쓴다.
    private var searchSequence = 0

    init(editId: Int? = nil, roomId: Int? = nil, initialDate: String? = nil) {
        self.editId = editId
        self.roomId = roomId
        self.isEditMode = editId != nil
        if let initialDate, let parsed = KstDate(dateString: initialDate) {
            self.date = parsed
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
        PlanRules.suggestCategories(
            title: title,
            categories: categories.map(\.name) + addedCategories
        )
    }

    var saveButtonText: String {
        if saving { return isEditMode ? "수정 중..." : "저장 중..." }
        return isEditMode ? "수정하기" : "플랜 저장하기"
    }

    // MARK: - 로딩

    func load(env: AppEnvironment, guest: GuestStore) async {
        await loadCategories(env: env)
        if let editId {
            await loadDetail(id: editId, env: env, guest: guest)
        }
    }

    private func loadCategories(env: AppEnvironment) async {
        let token = await env.tokenStore.currentToken()
        let loggedIn = !(token ?? "").isEmpty
        // 비로그인은 인증 없는 경로를 쓴다. 안 그러면 카테고리가 하나도 안 보이고,
        // 카테고리가 필수라 게스트는 플랜을 아예 만들 수 없다.
        let request = Endpoint.categories(roomId: roomId, loggedIn: loggedIn)

        guard let page = try? await env.api.send(request, decoding: PlanCategoryPage.self) else { return }
        categories = page.list.sorted { $0.name < $1.name }
        syncSelectedCategory()
    }

    /// 수정 모드에서 상세를 먼저 받아온 경우, 카테고리 목록이 늦게 와도 선택을 맞춰준다.
    private func syncSelectedCategory() {
        guard let current = category, current.id == 0 else { return }
        guard let matched = categories.first(where: { $0.name == current.name }) else { return }
        category = matched
    }

    private func loadDetail(id: Int, env: AppEnvironment, guest: GuestStore) async {
        // 게스트 플랜은 id 가 음수이고 서버에 없다. 로컬에서 찾는다.
        if id < 0 {
            guard let item = guest.findSchedule(id: id) else { return }
            apply(
                title: item.title,
                categoryName: item.categoryName,
                payType: item.payType?.rawValue,
                amount: item.amount,
                startDate: item.startDate,
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
            apply(
                title: detail.title,
                categoryName: detail.categoryName,
                payType: detail.payType,
                amount: detail.amount,
                startDate: detail.startDate,
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
        amount: Int?,
        startDate: String?,
        location: String?,
        lat: Double?,
        lng: Double?,
        memo: String?
    ) {
        self.title = title
        self.category = PlanCategory(name: categoryName)
        self.payType = PlanPayType.from(api: payType) ?? .other
        self.amount = amount.map(String.init) ?? ""
        self.date = startDate.flatMap { KstDate(dateString: $0) } ?? KstDate.today()
        self.dateUndecided = (startDate ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        self.location = location ?? ""
        self.locationLat = lat ?? 0
        self.locationLng = lng ?? 0
        self.memo = memo ?? ""
        // 불러온 좌표는 불러온 이름의 것이다. 안 그러면 첫 setLocation 에서 좌표가 지워진다.
        self.selectedPlaceName = (location ?? "").trimmingCharacters(in: .whitespaces)
    }

    // MARK: - 입력 변경

    func setAmount(_ value: String) {
        // 웹은 콤마를 넣어 보여주고 전송 시 제거한다. 여기서는 숫자만 보관한다.
        amount = String(value.filter(\.isNumber).prefix(9))
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
        category = categories.first { $0.name == name } ?? PlanCategory(name: name, type: "USER")
    }

    /// 모달에서 새 카테고리를 만든 경우 — 서버에 미리 만들지 않고 저장 시 함께 보낸다(웹과 동일).
    func addCategory(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let exists = categories.contains { $0.name == trimmed } || addedCategories.contains(trimmed)
        guard !exists else {
            errorMessage = "이미 있는 카테고리예요."
            return
        }
        addedCategories.append(trimmed)
        category = PlanCategory(name: trimmed, type: "USER")
    }

    func setLocation(_ value: String) {
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
        guard !query.isEmpty, !searching else { return }

        // 이전 결과를 남겨두면 새 결과가 오기 전에 옛 항목을 눌러
        // 엉뚱한 좌표가 저장될 수 있다.
        searching = true
        searchUnavailable = false
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
            hasSearched = true
            // 404 = 백엔드에 프록시가 아직 없음. 그 외는 일반 에러로 표시.
            if case .http(let status, _) = error as? APIError, status == 404 {
                searchUnavailable = true
            } else {
                errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
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

        let request = ScheduleWriteRequest(
            categoryName: category.name,
            title: title.trimmingCharacters(in: .whitespaces),
            payType: payType.rawValue,
            amount: Int(amount) ?? 0,
            // 미정이면 nil → 명시적 null 로 직렬화된다.
            // 수정에서 이미 잡혀 있던 날짜를 미정으로 되돌릴 수 있어야 하기 때문이다.
            startDate: dateUndecided ? nil : date.dateString,
            location: location.trimmingCharacters(in: .whitespaces),
            locationLat: locationLat,
            locationLng: locationLng,
            memo: memo.trimmingCharacters(in: .whitespaces),
            // 생성에는 roomId 필수. 빼면 200 인데 목록에 영영 안 나온다.
            // 수정에는 붙이지 않는다.
            roomId: isEditMode ? nil : roomId,
            addCategoryNameList: addedCategories.isEmpty ? nil : addedCategories
        )

        do {
            if let editId {
                try await env.api.sendIgnoringData(Endpoint.updateSchedule(id: editId, request))
            } else {
                try await env.api.sendIgnoringData(Endpoint.createSchedule(request))
            }
            saved = true
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
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
            amount: Int(amount) ?? 0,
            startDate: dateUndecided ? nil : date.dateString,
            status: ScheduleStatus(rawValue: "NORMAL"),
            location: location.trimmingCharacters(in: .whitespaces),
            locationLat: locationLat,
            locationLng: locationLng,
            memo: memo.trimmingCharacters(in: .whitespaces),
            payType: PayType(rawValue: payType.rawValue),
            addCategoryNameList: addedCategories
        )
        guest.addSchedule(item)
        saved = true
        errorMessage = nil
    }
}
