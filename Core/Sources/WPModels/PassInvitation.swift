import Foundation

// Wire models shared with Android data/model/Invitation.kt and Models.kt.
public struct MyInvitation: Codable, Sendable, Equatable {
    public var roomId: Int?
    public var hasPass: Bool
    public var canEdit: Bool
    public var invitation: InvitationContent?
    public init(roomId: Int? = nil, hasPass: Bool = false, canEdit: Bool = false, invitation: InvitationContent? = nil) {
        self.roomId = roomId
        self.hasPass = hasPass
        self.canEdit = canEdit
        self.invitation = invitation
    }
    private enum CodingKeys: String, CodingKey { case roomId, hasPass, canEdit, invitation }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        roomId = try c.decodeIfPresent(Int.self, forKey: .roomId)
        hasPass = try c.decodeIfPresent(Bool.self, forKey: .hasPass) ?? false
        canEdit = try c.decodeIfPresent(Bool.self, forKey: .canEdit) ?? false
        invitation = try c.decodeIfPresent(InvitationContent.self, forKey: .invitation)
    }
}

public struct InvitationContent: Codable, Sendable, Equatable {
    public var slug: String
    public var template: String
    public var title: String
    public var bride: String
    public var groom: String
    public var weddingDate: String?
    public var weddingTime: String?
    public var venue: String
    public var message: String
    public var photos: [InvitationPhotoDto]
    public var design: InvitationDesignBody?
    public var published: Bool
    public var updatedAt: String
    public init(slug: String = "", template: String = "garden", title: String = "", bride: String = "", groom: String = "", weddingDate: String? = nil, weddingTime: String? = nil, venue: String = "", message: String = "", photos: [InvitationPhotoDto] = [], design: InvitationDesignBody? = nil, published: Bool = false, updatedAt: String = "") {
        self.slug = slug
        self.template = template
        self.title = title
        self.bride = bride
        self.groom = groom
        self.weddingDate = weddingDate
        self.weddingTime = weddingTime
        self.venue = venue
        self.message = message
        self.photos = photos
        self.design = design
        self.published = published
        self.updatedAt = updatedAt
    }
    private enum CodingKeys: String, CodingKey { case slug, template, title, bride, groom, weddingDate, weddingTime, venue, message, photos, design, published, updatedAt }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slug = try c.decodeIfPresent(String.self, forKey: .slug) ?? ""
        template = try c.decodeIfPresent(String.self, forKey: .template) ?? "garden"
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        bride = try c.decodeIfPresent(String.self, forKey: .bride) ?? ""
        groom = try c.decodeIfPresent(String.self, forKey: .groom) ?? ""
        weddingDate = try c.decodeIfPresent(String.self, forKey: .weddingDate)
        weddingTime = try c.decodeIfPresent(String.self, forKey: .weddingTime)
        venue = try c.decodeIfPresent(String.self, forKey: .venue) ?? ""
        message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
        photos = try c.decodeIfPresent([InvitationPhotoDto].self, forKey: .photos) ?? []
        design = try? c.decodeIfPresent(InvitationDesignBody.self, forKey: .design)
        published = try c.decodeIfPresent(Bool.self, forKey: .published) ?? false
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }
}

public struct InvitationPhotoDto: Codable, Sendable, Equatable {
    public var key: String
    public var url: String?
    public init(key: String = "", url: String? = nil) {
        self.key = key
        self.url = url
    }
    private enum CodingKeys: String, CodingKey { case key, url }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decodeIfPresent(String.self, forKey: .key) ?? ""
        url = try c.decodeIfPresent(String.self, forKey: .url)
    }
}

public struct InvitationDesignBody: Codable, Sendable, Equatable {
    public var intro: String
    public var galleryLayout: String
    public var sections: [InvitationSectionBody]
    public var couple: InvitationCoupleBody
    public var location: InvitationLocationBody
    public var notice: InvitationNoticeBody
    public var accounts: [InvitationAccountBody]
    public init(intro: String = "", galleryLayout: String = "", sections: [InvitationSectionBody] = [], couple: InvitationCoupleBody = InvitationCoupleBody(), location: InvitationLocationBody = InvitationLocationBody(), notice: InvitationNoticeBody = InvitationNoticeBody(), accounts: [InvitationAccountBody] = []) {
        self.intro = intro
        self.galleryLayout = galleryLayout
        self.sections = sections
        self.couple = couple
        self.location = location
        self.notice = notice
        self.accounts = accounts
    }
    private enum CodingKeys: String, CodingKey { case intro, galleryLayout, sections, couple, location, notice, accounts }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        intro = (try? c.decodeIfPresent(String.self, forKey: .intro)) ?? ""
        galleryLayout = (try? c.decodeIfPresent(String.self, forKey: .galleryLayout)) ?? ""
        sections = (try? c.decodeIfPresent(InvitationLossyList<InvitationSectionBody>.self, forKey: .sections))?.values ?? []
        couple = (try? c.decodeIfPresent(InvitationCoupleBody.self, forKey: .couple)) ?? InvitationCoupleBody()
        location = (try? c.decodeIfPresent(InvitationLocationBody.self, forKey: .location)) ?? InvitationLocationBody()
        notice = (try? c.decodeIfPresent(InvitationNoticeBody.self, forKey: .notice)) ?? InvitationNoticeBody()
        accounts = (try? c.decodeIfPresent(InvitationLossyList<InvitationAccountBody>.self, forKey: .accounts))?.values ?? []
    }
}

public struct InvitationSectionBody: Codable, Sendable, Equatable {
    public var type: String
    public var visible: Bool
    public init(type: String = "", visible: Bool = false) {
        self.type = type
        self.visible = visible
    }
    private enum CodingKeys: String, CodingKey { case type, visible }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? c.decodeIfPresent(String.self, forKey: .type)) ?? ""
        visible = (try? c.decodeIfPresent(Bool.self, forKey: .visible)) ?? false
    }
}

public struct InvitationCoupleBody: Codable, Sendable, Equatable {
    public var groomFather: String
    public var groomMother: String
    public var groomRelation: String
    public var brideFather: String
    public var brideMother: String
    public var brideRelation: String
    public init(groomFather: String = "", groomMother: String = "", groomRelation: String = "아들", brideFather: String = "", brideMother: String = "", brideRelation: String = "딸") {
        self.groomFather = groomFather
        self.groomMother = groomMother
        self.groomRelation = groomRelation
        self.brideFather = brideFather
        self.brideMother = brideMother
        self.brideRelation = brideRelation
    }
    private enum CodingKeys: String, CodingKey { case groomFather, groomMother, groomRelation, brideFather, brideMother, brideRelation }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        groomFather = (try? c.decodeIfPresent(String.self, forKey: .groomFather)) ?? ""
        groomMother = (try? c.decodeIfPresent(String.self, forKey: .groomMother)) ?? ""
        groomRelation = (try? c.decodeIfPresent(String.self, forKey: .groomRelation)) ?? "아들"
        brideFather = (try? c.decodeIfPresent(String.self, forKey: .brideFather)) ?? ""
        brideMother = (try? c.decodeIfPresent(String.self, forKey: .brideMother)) ?? ""
        brideRelation = (try? c.decodeIfPresent(String.self, forKey: .brideRelation)) ?? "딸"
    }
}

public struct InvitationLocationBody: Codable, Sendable, Equatable {
    public var address: String
    public var guide: String
    public init(address: String = "", guide: String = "") {
        self.address = address
        self.guide = guide
    }
    private enum CodingKeys: String, CodingKey { case address, guide }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        address = (try? c.decodeIfPresent(String.self, forKey: .address)) ?? ""
        guide = (try? c.decodeIfPresent(String.self, forKey: .guide)) ?? ""
    }
}

public struct InvitationNoticeBody: Codable, Sendable, Equatable {
    public var title: String
    public var body: String
    public init(title: String = "안내 말씀", body: String = "") {
        self.title = title
        self.body = body
    }
    private enum CodingKeys: String, CodingKey { case title, body }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? "안내 말씀"
        body = (try? c.decodeIfPresent(String.self, forKey: .body)) ?? ""
    }
}

public struct InvitationAccountBody: Codable, Sendable, Equatable {
    public var side: String
    public var role: String
    public var name: String
    public var bank: String
    public var number: String
    public init(side: String = "", role: String = "", name: String = "", bank: String = "", number: String = "") {
        self.side = side
        self.role = role
        self.name = name
        self.bank = bank
        self.number = number
    }
    private enum CodingKeys: String, CodingKey { case side, role, name, bank, number }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        side = (try? c.decodeIfPresent(String.self, forKey: .side)) ?? ""
        role = (try? c.decodeIfPresent(String.self, forKey: .role)) ?? ""
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        bank = (try? c.decodeIfPresent(String.self, forKey: .bank)) ?? ""
        number = (try? c.decodeIfPresent(String.self, forKey: .number)) ?? ""
    }
}

public struct InvitationPhotoSlot: Codable, Sendable, Equatable {
    public var key: String
    public var uploadUrl: String
    public init(key: String = "", uploadUrl: String = "") {
        self.key = key
        self.uploadUrl = uploadUrl
    }
    private enum CodingKeys: String, CodingKey { case key, uploadUrl }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decodeIfPresent(String.self, forKey: .key) ?? ""
        uploadUrl = try c.decodeIfPresent(String.self, forKey: .uploadUrl) ?? ""
    }
}

public struct InvitationGuestbook: Codable, Sendable, Equatable {
    public var wishes: [InvitationWish]
    public var total: Int?
    public init(wishes: [InvitationWish] = [], total: Int? = nil) {
        self.wishes = wishes
        self.total = total
    }
    private enum CodingKeys: String, CodingKey { case wishes, total }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        wishes = try c.decodeIfPresent([InvitationWish].self, forKey: .wishes) ?? []
        total = try c.decodeIfPresent(Int.self, forKey: .total)
    }
}

public struct InvitationWish: Codable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var message: String
    public var avatar: Int
    public var createdAt: String
    public init(id: String = "", name: String = "", message: String = "", avatar: Int = 0, createdAt: String = "") {
        self.id = id
        self.name = name
        self.message = message
        self.avatar = avatar
        self.createdAt = createdAt
    }
    private enum CodingKeys: String, CodingKey { case id, name, message, avatar, createdAt }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
        avatar = try c.decodeIfPresent(Int.self, forKey: .avatar) ?? 0
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }
}

public struct PassState: Codable, Sendable, Equatable {
    public var hasPass: Bool
    public var plan: String?
    public var expiresAt: String?
    public var buyerName: String?
    public var purchasedAt: String?
    public var expired: Bool
    public var filesDeleteAt: String?
    public init(hasPass: Bool = false, plan: String? = nil, expiresAt: String? = nil, buyerName: String? = nil, purchasedAt: String? = nil, expired: Bool = false, filesDeleteAt: String? = nil) {
        self.hasPass = hasPass
        self.plan = plan
        self.expiresAt = expiresAt
        self.buyerName = buyerName
        self.purchasedAt = purchasedAt
        self.expired = expired
        self.filesDeleteAt = filesDeleteAt
    }
    private enum CodingKeys: String, CodingKey { case hasPass, plan, expiresAt, buyerName, purchasedAt, expired, filesDeleteAt }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hasPass = try c.decodeIfPresent(Bool.self, forKey: .hasPass) ?? false
        plan = try c.decodeIfPresent(String.self, forKey: .plan)
        expiresAt = try c.decodeIfPresent(String.self, forKey: .expiresAt)
        buyerName = try c.decodeIfPresent(String.self, forKey: .buyerName)
        purchasedAt = try c.decodeIfPresent(String.self, forKey: .purchasedAt)
        expired = try c.decodeIfPresent(Bool.self, forKey: .expired) ?? false
        filesDeleteAt = try c.decodeIfPresent(String.self, forKey: .filesDeleteAt)
    }
}

public struct ReminderSetting: Codable, Sendable, Equatable {
    public var leadDays: [Int]
    public var hour: Int
    public var email: Bool
    public var emailAddress: String?
    public var devices: ReminderDevices
    public init(leadDays: [Int] = [7, 1, 0], hour: Int = 9, email: Bool = false, emailAddress: String? = nil, devices: ReminderDevices = ReminderDevices()) {
        self.leadDays = leadDays
        self.hour = hour
        self.email = email
        self.emailAddress = emailAddress
        self.devices = devices
    }
    private enum CodingKeys: String, CodingKey { case leadDays, hour, email, emailAddress, devices }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        leadDays = try c.decodeIfPresent([Int].self, forKey: .leadDays) ?? [7, 1, 0]
        hour = try c.decodeIfPresent(Int.self, forKey: .hour) ?? 9
        email = try c.decodeIfPresent(Bool.self, forKey: .email) ?? false
        emailAddress = try c.decodeIfPresent(String.self, forKey: .emailAddress)
        devices = try c.decodeIfPresent(ReminderDevices.self, forKey: .devices) ?? ReminderDevices()
    }
}

public struct ReminderDevices: Codable, Sendable, Equatable {
    public var android: Int
    public var ios: Int
    public init(android: Int = 0, ios: Int = 0) {
        self.android = android
        self.ios = ios
    }
    private enum CodingKeys: String, CodingKey { case android, ios }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        android = try c.decodeIfPresent(Int.self, forKey: .android) ?? 0
        ios = try c.decodeIfPresent(Int.self, forKey: .ios) ?? 0
    }
}

public struct PassFileItem: Codable, Sendable, Equatable {
    public var id: Int
    public var fileName: String
    public var contentType: String
    public var sizeBytes: Int
    public var createdAt: String?
    public init(id: Int = 0, fileName: String = "", contentType: String = "", sizeBytes: Int = 0, createdAt: String? = nil) {
        self.id = id
        self.fileName = fileName
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.createdAt = createdAt
    }
    private enum CodingKeys: String, CodingKey { case id, fileName, contentType, sizeBytes, createdAt }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        fileName = try c.decodeIfPresent(String.self, forKey: .fileName) ?? ""
        contentType = try c.decodeIfPresent(String.self, forKey: .contentType) ?? ""
        sizeBytes = try c.decodeIfPresent(Int.self, forKey: .sizeBytes) ?? 0
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

public struct PassFilePage: Codable, Sendable, Equatable {
    public var canOpen: Bool
    public var quotaBytes: Int
    public var usedBytes: Int
    public var list: [PassFileItem]
    public var roomId: Int?
    public init(canOpen: Bool = false, quotaBytes: Int = 0, usedBytes: Int = 0, list: [PassFileItem] = [], roomId: Int? = nil) {
        self.canOpen = canOpen
        self.quotaBytes = quotaBytes
        self.usedBytes = usedBytes
        self.list = list
        self.roomId = roomId
    }
    private enum CodingKeys: String, CodingKey { case canOpen, quotaBytes, usedBytes, list, roomId }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        canOpen = try c.decodeIfPresent(Bool.self, forKey: .canOpen) ?? false
        quotaBytes = try c.decodeIfPresent(Int.self, forKey: .quotaBytes) ?? 0
        usedBytes = try c.decodeIfPresent(Int.self, forKey: .usedBytes) ?? 0
        list = try c.decodeIfPresent([PassFileItem].self, forKey: .list) ?? []
        roomId = try c.decodeIfPresent(Int.self, forKey: .roomId)
    }
}

public struct PassDownloadAll: Codable, Sendable, Equatable {
    public var list: [PassDownloadItem]
    public init(list: [PassDownloadItem] = []) {
        self.list = list
    }
    private enum CodingKeys: String, CodingKey { case list }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        list = try c.decodeIfPresent([PassDownloadItem].self, forKey: .list) ?? []
    }
}

public struct PassDownloadItem: Codable, Sendable, Equatable {
    public var fileName: String
    public var url: String
    public init(fileName: String = "", url: String = "") {
        self.fileName = fileName
        self.url = url
    }
    private enum CodingKeys: String, CodingKey { case fileName, url }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fileName = try c.decodeIfPresent(String.self, forKey: .fileName) ?? ""
        url = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
    }
}

public struct PassFileUpload: Codable, Sendable, Equatable {
    public var fileId: Int
    public var uploadUrl: String
    public init(fileId: Int = 0, uploadUrl: String = "") {
        self.fileId = fileId
        self.uploadUrl = uploadUrl
    }
    private enum CodingKeys: String, CodingKey { case fileId, uploadUrl }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fileId = try c.decodeIfPresent(Int.self, forKey: .fileId) ?? 0
        uploadUrl = try c.decodeIfPresent(String.self, forKey: .uploadUrl) ?? ""
    }
}

public struct PassFileUrl: Codable, Sendable, Equatable {
    public var url: String
    public init(url: String = "") {
        self.url = url
    }
    private enum CodingKeys: String, CodingKey { case url }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        url = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
    }
}


private struct InvitationLossyList<Element: Decodable>: Decodable {
    let values: [Element]
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var result: [Element] = []
        while !container.isAtEnd {
            let child = try container.superDecoder()
            if let item = try? Element(from: child) { result.append(item) }
        }
        values = result
    }
}
