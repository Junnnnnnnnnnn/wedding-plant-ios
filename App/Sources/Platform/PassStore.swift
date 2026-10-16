import Foundation
import StoreKit
import SwiftUI
import WPDomain
import WPModels
import WPNetworking

/// 준비 패스 결제(StoreKit 2) — 안드로이드 `core/billing/PassBilling.kt` 의 자리.
///
/// ── 누가 패스를 켜는가 ────────────────────────────────────────
/// **앱이 아니라 서버다.** 결제창이 성공을 돌려줘도 그것만으로는 아무 일도 일어나지 않는다. 거래의 서명(JWS)을
/// `POST /plan/pass/apple/verify` 로 보내면 서버가 Apple 서명을 확인하고, 맞을 때만 패스가 켜진다.
///
/// ── 거래는 서버가 받은 뒤에만 끝낸다(`finish`) ─────────────────
/// 결제 직후 앱이 죽거나 네트워크가 끊기면 돈만 나가고 패스는 안 켜진다. 끝내지 않은 거래는 `Transaction.unfinished`
/// 에 남아 앱을 켤 때·앞으로 올 때 다시 보낸다([recover]). 서버의 확인은 같은 거래에 같은 답을 주므로(멱등) 다시 보내도
/// 기간이 늘지 않는다.
///
/// ── 방은 화면이 정하지 않는다 ───────────────────────────────
/// 결제창에 실어 보낸 방(`appAccountToken`), 없으면 내 방이다. 화면마다 자기 방으로 복구하면 참여 중인 남의 방을 보다가
/// 내 돈으로 산 패스가 그 방에 켜질 수 있다(안드로이드 `recoverUnverified`).
@MainActor
final class PassStore {
    /// 결제창이 떠 있거나 서버 확인 중 — 그 사이 복구가 방금 결제한 거래를 같이 보내지 않게
    private var purchaseInFlight = false
    /// 지금 서버에 보내고 있는 거래(결제 · 복구 · `Transaction.updates` 가 같은 거래를 겹쳐 보내지 않게)
    private var handling: Set<UInt64> = []
    private var updatesTask: Task<Void, Never>?
    private var recovering = false

    static let productIds = PassProduct.allCases.map(\.id)

    /// App Store 의 상품. 못 받으면 빈 목록 — 화면은 적어 둔 금액을 그리고 결제 버튼을 잠근다.
    func loadProducts() async -> [String: Product] {
        guard let list = try? await Product.products(for: Self.productIds) else { return [:] }
        return Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// 앱이 떠 있는 동안 밖에서 온 거래(승인 대기가 풀림 · 다른 기기에서 산 것)를 받는다. 앱을 켤 때 한 번 부른다.
    func start(env: AppEnvironment) {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self, weak env] in
            for await result in StoreKit.Transaction.updates {
                guard let self, let env else { return }
                _ = await self.deliver(result, env: env)
            }
        }
    }

    /// 서버에 안 들어간 거래를 다시 보낸다. **앱을 켤 때·앞으로 올 때마다** 부른다. 살릴 게 없으면 서버에 아무것도 안 보낸다.
    func recover(env: AppEnvironment) async {
        guard env.isAuthenticated, !purchaseInFlight, !recovering else { return }
        recovering = true
        defer { recovering = false }
        for await result in StoreKit.Transaction.unfinished {
            // 그 사이 결제가 시작됐으면 방금 결제한 거래를 같이 보내지 않는다
            if purchaseInFlight { return }
            _ = await deliver(result, env: env)
        }
    }

    /// 결제창을 띄우고, 끝나면 서버 확인까지 마친 결과를 돌려준다.
    ///
    /// - Parameter roomId: 패스를 붙일 방. 화면이 먼저 `POST /plan/room/mine` 으로 받은 값이다.
    /// - Parameter onVerifying: 결제창이 닫히고 서버 확인을 시작할 때 — 버튼 글자를 "결제를 확인하는 중..." 으로 바꾼다.
    func purchase(
        _ product: Product,
        roomId: Int,
        env: AppEnvironment,
        action: PurchaseAction,
        onVerifying: () -> Void
    ) async -> PassPurchaseOutcome {
        purchaseInFlight = true
        defer { purchaseInFlight = false }

        /*
          **결제창을 열기 전에 서버에 지금 상태를 묻는다.** 평생 패스가 이미 있는 방에서 또 사면 서버가 받지 않고
          (`PASS_ALREADY_LIFETIME`), App Store 는 저절로 환불하지 않는다. 화면이 들고 있는 값은 배우자가 방금 산 경우 낡았다.
        */
        let current: PassState
        do { current = try await env.api.send(Endpoint.pass(roomId: roomId)) } catch { return .failed(PassPurchaseRules.stateCheckFailed) }
        if PassPurchaseRules.isLifetime(current) { return .settled(current, PassPurchaseRules.alreadyLifetime) }

        guard let token = PassPurchaseRules.appAccountToken(roomId: roomId) else { return .failed(PassPurchaseRules.ensureFailed) }
        let result: Product.PurchaseResult
        do {
            // **이 구매를 붙일 방.** 서버 확인이 실패해 나중에 복구할 때 이 값으로 보낸다
            result = try await action(product, options: [.appAccountToken(token)])
        } catch {
            if case StoreKitError.userCancelled = error { return .canceled }
            return .failed(PassPurchaseRules.notCompleted)
        }
        switch result {
        case let .success(verification):
            onVerifying()
            return await deliver(verification, env: env, roomId: roomId, charged: true)
        case .userCancelled:
            return .canceled
        case .pending:
            // 자녀 구매 요청 · 결제 수단 확인. 승인되면 `Transaction.updates` 로 와서 켜진다
            return .pending(PassPurchaseRules.pending)
        @unknown default:
            return .failed(PassPurchaseRules.notCompleted)
        }
    }

    /// **구매 복원**(App Store 심사 지침 3.1.1 — 비소모성 평생 패스). App Store 와 동기화한 뒤, 가진 평생 패스를 서버로
    /// 다시 보낸다. 패스는 방에 붙어 서버에 남으므로 월간·년간은 로그인만으로 돌아온다 — 기기에만 남는 것은 평생 구매 기록이다.
    func restore(env: AppEnvironment) async -> PassPurchaseOutcome {
        guard !purchaseInFlight else { return .canceled }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            try await AppStore.sync()
        } catch {
            if case StoreKitError.userCancelled = error { return .canceled }
            return .failed(PassPurchaseRules.restoreFailed)
        }
        var restored: PassState?
        var failure: PassPurchaseOutcome?
        var found = false
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  transaction.productID == PassProduct.lifetime.id,
                  transaction.revocationDate == nil else { continue }
            found = true
            switch await deliver(result, env: env) {
            case let .success(state): restored = state
            case let .settled(state, text): restored = state ?? restored; failure = .settled(state, text)
            case .canceled: break
            case let other: failure = other
            }
        }
        if let restored, failure == nil { return .settled(restored, PassPurchaseRules.restored) }
        if let failure { return failure }
        return found ? .failed(PassPurchaseRules.restoreFailed) : .settled(nil, PassPurchaseRules.nothingToRestore)
    }

    /// 거래 하나를 서버에 보내고, 받았으면 끝낸다.
    ///
    /// - Parameter roomId: 결제 직후에는 그 방. 복구·복원이면 nil — 거래의 `appAccountToken`, 없으면 내 방.
    /// - Parameter charged: 방금 결제창에서 돈이 나간 직후인가(실패 문장이 달라진다)
    private func deliver(
        _ verification: VerificationResult<StoreKit.Transaction>,
        env: AppEnvironment,
        roomId: Int? = nil,
        charged: Bool = false
    ) async -> PassPurchaseOutcome {
        // 서명을 확인하지 못한 거래로는 패스를 켜지 않는다(탈옥 기기·변조). 끝내지 않는다 — 다음 확인에 맡긴다
        guard case let .verified(transaction) = verification else { return .failed(PassPurchaseRules.unverified) }
        guard PassProduct(rawValue: transaction.productID) != nil else { return .canceled }
        // 환불·취소된 거래는 보내지 않는다(서버는 App Store 알림으로 따로 안다). 남겨 두면 매번 다시 훑는다
        if transaction.revocationDate != nil {
            await transaction.finish()
            return .canceled
        }
        guard !handling.contains(transaction.id) else { return .canceled }
        handling.insert(transaction.id)
        defer { handling.remove(transaction.id) }

        var room = roomId ?? PassPurchaseRules.roomId(fromAppAccountToken: transaction.appAccountToken)
        if room == nil { room = await env.ownRoomIdForPurchases() }
        // 내 방을 모르면 보내지 않는다 — 끝내지 않았으니 다음 복구 때 다시 시도한다
        guard let room else { return charged ? .pending(PassPurchaseRules.chargedButNotApplied) : .failed(PassPurchaseRules.restoreFailed) }

        do {
            let state: PassState = try await env.api.send(
                Endpoint.verifyApplePurchase(roomId: room, signedTransaction: verification.jwsRepresentation)
            )
            await transaction.finish()
            env.notePassChanged()
            return .success(state)
        } catch {
            let api = error as? APIError
            if api?.serverReason == PassPurchaseRules.lifetimeReason {
                /*
                  평생 패스가 있는 방이라 서버가 이 결제를 받지 않았다. 다시 보내도 같은 답이라 거래를 끝내고(남겨 두면 켤 때마다
                  거절을 다시 받는다), 방의 지금 패스(평생)를 받아 요금제 시트가 "평생 이용 중" 으로 바뀌게 한다.
                */
                await transaction.finish()
                let state: PassState? = try? await env.api.send(Endpoint.pass(roomId: room))
                env.notePassChanged()
                return .settled(state, PassPurchaseRules.lifetimeRefused)
            }
            return PassPurchaseRules.verifyFailure(
                reason: api?.serverReason,
                serverMessage: (error as? LocalizedError)?.errorDescription,
                charged: charged
            )
        }
    }
}
