import SwiftUI

// 「収束」演出: 多数の候補ドットが中央に集まり、3つの円に収束する
struct LoadingView: View {
    @State private var phase = 0
    @State private var dotsConverged = false
    @State private var circlesVisible = false
    @State private var floaty = false

    // 各メッセージの表示秒数（実際の処理タイミングとは独立して演出として設定）
    private let messages: [(text: String, duration: Double)] = [
        (String(localized: "近くのお店を探しています…"),  2.2),
        (String(localized: "候補を集めています…"),        2.8),
        (String(localized: "3軒に絞っています…"),         2.5),
        (String(localized: "推薦理由を考えています…"),    99),
    ]

    private let roles: [Role] = [.honmei, .anaba, .bunan]

    // 候補ドットの初期オフセット（円形に散らす・ランダム感のため半径を変える）
    private let dotOffsets: [CGSize] = (0..<20).map { i in
        let angle = Double(i) / 20 * 2 * .pi + Double(i % 3) * 0.18
        let radius: CGFloat = 80 + CGFloat(i % 4) * 16
        return CGSize(width: cos(angle) * radius, height: sin(angle) * radius)
    }

    var body: some View {
        ZStack {
            Trois.cream.ignoresSafeArea()

            VStack(spacing: 44) {
                Spacer()

                ZStack {
                    // 候補ドット
                    ForEach(0..<dotOffsets.count, id: \.self) { i in
                        Circle()
                            .fill(Trois.inkFaint.opacity(0.6))
                            .frame(width: 6, height: 6)
                            .offset(dotsConverged ? .zero : dotOffsets[i])
                            .opacity(dotsConverged ? 0 : 0.8)
                            .animation(
                                .easeInOut(duration: 0.75).delay(Double(i) * 0.025),
                                value: dotsConverged
                            )
                    }

                    // 3つの円（収束後に出現）
                    HStack(spacing: 18) {
                        ForEach(Array(roles.enumerated()), id: \.offset) { index, role in
                            Circle()
                                .fill(role.color)
                                .frame(width: 46, height: 46)
                                .scaleEffect(circlesVisible ? 1 : 0.3)
                                .opacity(circlesVisible ? 1 : 0)
                                .offset(y: floaty ? -5 : 5)
                                .animation(
                                    .spring(response: 0.6, dampingFraction: 0.5)
                                        .delay(Double(index) * 0.13),
                                    value: circlesVisible
                                )
                                .animation(
                                    .easeInOut(duration: 2.8 + Double(index) * 0.3)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.25),
                                    value: floaty
                                )
                        }
                    }
                }
                .frame(height: 200)

                VStack(spacing: 20) {
                    Text(messages[phase].text)
                        .font(Trois.display(18, weight: .medium))
                        .foregroundStyle(Trois.ink)
                        .multilineTextAlignment(.center)
                        .id(phase)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal:   .opacity.combined(with: .move(edge: .top))
                            )
                        )
                        .animation(.easeInOut(duration: 0.45), value: phase)

                    // 進捗トラック
                    HStack(spacing: 8) {
                        ForEach(0..<messages.count, id: \.self) { i in
                            Capsule()
                                .fill(i < phase ? Trois.accent.opacity(0.4)
                                      : i == phase ? Trois.accent
                                      : Trois.line)
                                .frame(width: i == phase ? 26 : 7, height: 7)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: phase)
                        }
                    }
                }

                Spacer()
                Spacer()
            }
        }
        .onAppear { runSequence() }
    }

    private func runSequence() {
        // ドット収束
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation { dotsConverged = true }
        }
        // 3円出現
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            circlesVisible = true
            floaty = true
        }
        // メッセージを各自のdurationに従ってめくる
        scheduleNextPhase(after: 1.5, phaseIndex: 0)
    }

    private func scheduleNextPhase(after delay: Double, phaseIndex: Int) {
        let duration = messages[phaseIndex].duration
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let next = phaseIndex + 1
            guard next < messages.count else { return }
            withAnimation(.easeInOut(duration: 0.45)) { phase = next }
            scheduleNextPhase(after: duration, phaseIndex: next)
        }
    }
}
