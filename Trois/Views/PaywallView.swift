import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var usage: UsageManager
    @Environment(\.dismiss) private var dismiss

    @State private var purchasingID: String? = nil
    @State private var errorMessage: String?

    private let plans = UsageManager.topUpPlans

    var body: some View {
        ZStack {
            Trois.cream.ignoresSafeArea()

            VStack(spacing: 0) {

                // 閉じる
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Trois.inkSoft)
                            .padding(10)
                            .background(Trois.surfaceSink, in: Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                // ドット
                HStack(spacing: 10) {
                    Circle().fill(Trois.terracotta).frame(width: 14, height: 14)
                    Circle().fill(Trois.sage).frame(width: 14, height: 14)
                    Circle().fill(Trois.ochre).frame(width: 14, height: 14)
                }
                .padding(.bottom, 24)

                // タイトル
                VStack(spacing: 10) {
                    Text("今月の提案回数を\n使いきりました")
                        .font(Trois.display(26, weight: .medium))
                        .foregroundStyle(Trois.ink)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                }
                .padding(.bottom, 32)

                // ── 追加購入カード ──────────────────────────
                VStack(spacing: 12) {
                    topUpCard(plan: plans[0], isBetter: false)
                    topUpCard(plan: plans[1], isBetter: true)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                // ── サブスク ──────────────────────────────
                VStack(spacing: 10) {
                    Divider().padding(.horizontal, 24)

                    Text("毎月たくさん使うなら")
                        .font(Trois.body(12, weight: .medium))
                        .foregroundStyle(Trois.inkFaint)

                    Button {
                        Task { await purchaseSubscription() }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("月額サブスク")
                                    .font(Trois.display(15, weight: .medium))
                                    .foregroundStyle(Trois.ink)
                                Text("150回 / 月 ・ ¥3.3/回")
                                    .font(Trois.body(12))
                                    .foregroundStyle(Trois.inkSoft)
                            }
                            Spacer()
                            Group {
                                if purchasingID == UsageManager.subscriptionProductID {
                                    ProgressView().tint(Trois.accentDeep)
                                } else {
                                    Text("¥500 / 月")
                                        .font(Trois.display(15, weight: .semibold))
                                        .foregroundStyle(Trois.accentDeep)
                                }
                            }
                        }
                        .padding(16)
                        .background(Trois.accentTint, in: RoundedRectangle(cornerRadius: Trois.rField))
                    }
                    .buttonStyle(.plain)
                    .disabled(purchasingID != nil)
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)

                // 無料復活
                if usage.canApplyFreeReset {
                    Button {
                        usage.applyFreeReset()
                        dismiss()
                    } label: {
                        Text("5回だけ無料で復活させる（月1回限り）")
                            .font(Trois.body(13, weight: .medium))
                            .foregroundStyle(Trois.inkSoft)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 12)
                }

                Spacer()

                Text("Apple の課金規約が適用されます。\nサブスクはいつでもキャンセルできます。")
                    .font(Trois.body(11))
                    .foregroundStyle(Trois.inkFaint)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 28)
            }
        }
        .alert("エラー", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - TopUp Card

    @ViewBuilder
    private func topUpCard(plan: TopUpPlan, isBetter: Bool) -> some View {
        Button {
            Task { await purchaseTopUp(plan) }
        } label: {
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .center, spacing: 0) {
                    // 左: 回数・単価
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(plan.uses)回追加")
                            .font(Trois.display(17, weight: .semibold))
                            .foregroundStyle(Trois.ink)

                        // 単価バー比較
                        perUseBar(plan: plan)
                    }

                    Spacer()

                    // 右: 価格ボタン
                    Group {
                        if purchasingID == plan.productID {
                            ProgressView().tint(.white).frame(width: 72, height: 40)
                        } else {
                            Text("¥\(plan.price)")
                                .font(Trois.display(16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 72, height: 40)
                                .background(Trois.accent, in: Capsule())
                        }
                    }
                }
                .padding(16)
                .background(Trois.surface, in: RoundedRectangle(cornerRadius: Trois.rField))
                .overlay(
                    RoundedRectangle(cornerRadius: Trois.rField)
                        .strokeBorder(isBetter ? Trois.accent.opacity(0.5) : Trois.line, lineWidth: isBetter ? 1.5 : 1)
                )

                // お得バッジ
                if isBetter {
                    Text("1回あたり半額")
                        .font(Trois.body(10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Trois.accent, in: Capsule())
                        .offset(x: -12, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(purchasingID != nil)
    }

    /// 1回あたり単価を視覚的に示すバー
    @ViewBuilder
    private func perUseBar(plan: TopUpPlan) -> some View {
        let cheapest = plans.map(\.perUse).min() ?? 1
        let ratio = cheapest / plan.perUse   // 最安を1.0として相対比

        HStack(spacing: 6) {
            // バー
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Trois.line).frame(height: 5)
                    Capsule()
                        .fill(ratio == 1 ? Trois.accent : Trois.inkFaint.opacity(0.5))
                        .frame(width: geo.size.width * ratio, height: 5)
                }
            }
            .frame(height: 5)

            Text(String(format: String(localized: "¥%@/回"), String(format: "%.0f", plan.perUse)))
                .font(Trois.body(11.5, weight: .medium))
                .foregroundStyle(ratio == 1 ? Trois.accentDeep : Trois.inkSoft)
                .fixedSize()
        }
        .frame(maxWidth: 180)
    }

    // MARK: - Actions

    private func purchaseTopUp(_ plan: TopUpPlan) async {
        purchasingID = plan.productID
        defer { purchasingID = nil }
        do {
            try await usage.purchaseTopUp(plan)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func purchaseSubscription() async {
        purchasingID = UsageManager.subscriptionProductID
        defer { purchasingID = nil }
        do {
            try await usage.purchaseSubscription()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
