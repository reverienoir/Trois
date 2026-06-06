import SwiftUI

struct LoadingView: View {
    @State private var phase = 0
    private let messages = [
        "近くのお店を探しています…",
        "候補を集めています…",
        "3軒に絞っています…",
        "推薦理由を考えています…",
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text(messages[phase])
                .font(.headline)
                .foregroundStyle(.secondary)
                .animation(.easeInOut, value: phase)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .onAppear { cycleMessages() }
    }

    private func cycleMessages() {
        Timer.scheduledTimer(withTimeInterval: 1.8, repeats: true) { timer in
            withAnimation {
                phase = (phase + 1) % messages.count
            }
        }
    }
}
