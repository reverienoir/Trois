import Foundation
import StoreKit
import UserNotifications

// MARK: - TopUp

struct TopUpPlan {
    let productID: String
    let uses: Int
    let price: Int           // 円
    var perUse: Double { Double(price) / Double(uses) }
}

// MARK: - UsageManager

@MainActor
final class UsageManager: ObservableObject {

    // MARK: Published

    @Published private(set) var usageCount: Int = 0
    @Published private(set) var extraUses: Int = 0    // 追加購入分（期間リセット時に消える）
    @Published private(set) var isSubscribed: Bool = false
    @Published private(set) var freeResetUsed: Bool = false
    @Published private(set) var periodStart: Date = Date()

    // MARK: Constants

    static let subscriptionProductID = "com.eruru.Trois.monthly"

    static let topUpPlans: [TopUpPlan] = [
        TopUpPlan(productID: "com.eruru.Trois.topup10",  uses: 10, price: 100),
        TopUpPlan(productID: "com.eruru.Trois.topup80",  uses: 80, price: 400),
    ]

    let freeLimit   = 30
    let paidLimit   = 150
    let freeReset   = 5
    let notifyAt    = [10, 5]

    // MARK: Computed

    var currentLimit: Int { isSubscribed ? paidLimit : freeLimit }
    var remaining: Int { max(0, currentLimit + extraUses - usageCount) }
    var isLimitReached: Bool { remaining == 0 }

    // MARK: Keys

    private enum Key {
        static let usageCount    = "usage_count"
        static let extraUses     = "extra_uses"
        static let periodStart   = "usage_period_start"
        static let freeResetUsed = "free_reset_used"
    }

    // MARK: Init

    init() {
        loadFromDefaults()
        rolloverPeriodIfNeeded()
        Task { await refreshSubscriptionStatus() }
    }

    // MARK: - Public API

    /// 1回消費する。上限超えの場合は false を返す。
    func consume() -> Bool {
        #if DEBUG
        // デバッグビルドでは制限をスキップ
        return true
        #else
        guard !isLimitReached else { return false }
        usageCount += 1
        saveToDefaults()
        scheduleNotificationIfNeeded()
        return true
        #endif
    }

    /// 無料復活（月1回・5回分）
    func applyFreeReset() {
        guard !freeResetUsed else { return }
        usageCount = max(0, usageCount - freeReset)
        freeResetUsed = true
        saveToDefaults()
    }

    var canApplyFreeReset: Bool {
        !freeResetUsed && isLimitReached
    }

    /// サブスク購入
    func purchaseSubscription() async throws {
        let products = try await Product.products(for: [Self.subscriptionProductID])
        guard let product = products.first else { throw UsageError.productNotFound }
        let result = try await product.purchase()
        if case .success(let v) = result, case .verified = v {
            await refreshSubscriptionStatus()
        }
    }

    /// 追加購入（消費型）
    func purchaseTopUp(_ plan: TopUpPlan) async throws {
        let products = try await Product.products(for: [plan.productID])
        guard let product = products.first else { throw UsageError.productNotFound }
        let result = try await product.purchase()
        if case .success(let v) = result, case .verified(let tx) = v {
            extraUses += plan.uses
            saveToDefaults()
            await tx.finish()
        }
    }

    /// サブスク状態を StoreKit から再確認
    func refreshSubscriptionStatus() async {
        var subscribed = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == Self.subscriptionProductID,
               tx.revocationDate == nil {
                subscribed = true
                break
            }
        }
        isSubscribed = subscribed
    }

    // MARK: - Private

    private func loadFromDefaults() {
        let d = UserDefaults.standard
        usageCount    = d.integer(forKey: Key.usageCount)
        extraUses     = d.integer(forKey: Key.extraUses)
        freeResetUsed = d.bool(forKey: Key.freeResetUsed)
        if let date = d.object(forKey: Key.periodStart) as? Date {
            periodStart = date
        } else {
            periodStart = Date()
            d.set(periodStart, forKey: Key.periodStart)
        }
    }

    private func saveToDefaults() {
        let d = UserDefaults.standard
        d.set(usageCount,    forKey: Key.usageCount)
        d.set(extraUses,     forKey: Key.extraUses)
        d.set(freeResetUsed, forKey: Key.freeResetUsed)
        d.set(periodStart,   forKey: Key.periodStart)
    }

    /// 課金日から30日経過していたらリセット
    private func rolloverPeriodIfNeeded() {
        let now = Date()
        let days = Calendar.current.dateComponents([.day], from: periodStart, to: now).day ?? 0
        if days >= 30 {
            usageCount    = 0
            extraUses     = 0
            freeResetUsed = false
            periodStart   = now
            saveToDefaults()
        }
    }

    // MARK: - Notifications

    private func scheduleNotificationIfNeeded() {
        guard notifyAt.contains(remaining) else { return }
        let content = UNMutableNotificationContent()
        content.sound = .default
        if remaining == 10 {
            content.title = "提案があと10回使えます"
            content.body  = "今月の残りが10回になりました。"
        } else {
            content.title = "提案があと5回"
            content.body  = "今月の残りが5回になりました。追加購入またはサブスクをどうぞ。"
        }
        let req = UNNotificationRequest(
            identifier: "usage_warning_\(remaining)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(req)
    }
}

// MARK: - Errors

enum UsageError: LocalizedError {
    case productNotFound
    var errorDescription: String? { "商品情報が見つかりませんでした" }
}
