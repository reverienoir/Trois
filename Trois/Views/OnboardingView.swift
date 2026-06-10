import SwiftUI
import CoreLocation

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var step = 0

    var body: some View {
        ZStack {
            Trois.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                if step == 0 {
                    welcomeStep
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                } else {
                    locationStep
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity
                        ))
                }

                Spacer()

                // ステップインジケーター
                HStack(spacing: 6) {
                    ForEach(0..<2) { i in
                        Capsule()
                            .fill(i == step ? Trois.accent : Trois.line)
                            .frame(width: i == step ? 20 : 6, height: 6)
                            .animation(.easeInOut(duration: 0.25), value: step)
                    }
                }
                .padding(.bottom, 24)

                // CTAボタン
                Button {
                    if step == 0 {
                        withAnimation(.easeInOut(duration: 0.3)) { step = 1 }
                    } else {
                        requestLocationAndFinish()
                    }
                } label: {
                    Text(step == 0 ? "はじめる" : "現在地を許可して使いはじめる")
                        .font(Trois.display(16.5, weight: .medium))
                        .tracking(0.3)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Trois.accent, in: Capsule())
                        .shadow(color: Trois.accent.opacity(0.4), radius: 14, y: 8)
                }
                .padding(.horizontal, Trois.screenPadding)

                // 地名入力で使う場合のスキップ
                if step == 1 {
                    Button {
                        finish()
                    } label: {
                        Text("地名で指定するので許可しない")
                            .font(Trois.body(13, weight: .medium))
                            .foregroundStyle(Trois.inkSoft)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 14)
                }

                Color.clear.frame(height: step == 1 ? 28 : 44)
            }
            .padding(.horizontal, Trois.screenPadding)
        }
    }

    // MARK: - Step 0: ようこそ

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            // ロゴドット（大きめ）
            HStack(spacing: 14) {
                Circle().fill(Trois.terracotta).frame(width: 22, height: 22)
                Circle().fill(Trois.sage).frame(width: 22, height: 22)
                Circle().fill(Trois.ochre).frame(width: 22, height: 22)
            }
            .padding(.bottom, 32)

            Text("Trois")
                .font(Trois.display(36, weight: .bold))
                .foregroundStyle(Trois.ink)
                .padding(.bottom, 10)

            Text("トロワ")
                .font(Trois.body(14))
                .foregroundStyle(Trois.inkFaint)
                .tracking(2)
                .padding(.bottom, 40)

            VStack(alignment: .leading, spacing: 24) {
                featureRow(
                    icon: "sparkles",
                    color: Trois.terracotta,
                    title: "AIが3軒だけ決めてくれる",
                    body: "候補を並べるのではなく、今のあなたに合う3軒をAIが厳選して提案します。"
                )
                featureRow(
                    icon: "text.bubble",
                    color: Trois.sage,
                    title: "理由つきで提案",
                    body: "「なぜこの店か」を一言添えるから、はじめてのお店でも安心して行けます。"
                )
                featureRow(
                    icon: "hand.tap",
                    color: Trois.ochre,
                    title: "選ぶのは気分だけ",
                    body: "細かい検索は不要。気分・予算をざっくり選べばOK。あとはおまかせ。"
                )
            }
            .padding(.horizontal, 4)
        }
    }

    private func featureRow(icon: String, color: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Trois.display(15, weight: .semibold))
                    .foregroundStyle(Trois.ink)
                Text(body)
                    .font(Trois.body(13.5))
                    .foregroundStyle(Trois.inkSoft)
                    .lineSpacing(5)
            }
        }
    }

    // MARK: - Step 1: 位置情報

    private var locationStep: some View {
        VStack(spacing: 0) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Trois.accent)
                .padding(.bottom, 32)

            Text("現在地を使わせてください")
                .font(Trois.display(26, weight: .medium))
                .foregroundStyle(Trois.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.bottom, 20)

            Text("近くのお店を探すために、\n現在地の情報を使います。")
                .font(Trois.body(15))
                .foregroundStyle(Trois.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(7)
                .padding(.bottom, 40)

            VStack(spacing: 0) {
                privacyRow(icon: "lock.shield", text: "位置情報はお店の検索にのみ使用します")
                Divider().padding(.leading, 44)
                privacyRow(icon: "xmark.icloud", text: "サーバーへの保存・第三者への提供はありません")
                Divider().padding(.leading, 44)
                privacyRow(icon: "gear", text: "許可はiOSの設定からいつでも変更できます")
            }
            .background(Trois.surface, in: RoundedRectangle(cornerRadius: Trois.rField))
            .overlay(RoundedRectangle(cornerRadius: Trois.rField).strokeBorder(Trois.line, lineWidth: 1))
        }
    }

    private func privacyRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Trois.accentDeep)
                .frame(width: 20)
            Text(text)
                .font(Trois.body(13.5))
                .foregroundStyle(Trois.ink)
                .lineSpacing(4)
            Spacer()
        }
        .padding(14)
    }

    // MARK: - Actions

    private func requestLocationAndFinish() {
        CLLocationManager().requestWhenInUseAuthorization()
        // 通知許可もセットで（自然なタイミング）
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        finish()
    }

    private func finish() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = false
        }
    }
}
