import SwiftUI

// チップ形状の Toggle スタイル（"しずか" / アウトライン仕様）
struct ChipToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Trois.body(13.5, weight: .medium))
            .foregroundStyle(configuration.isOn ? Trois.accentDeep : Trois.inkSoft)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(minHeight: 44)
            .background(
                configuration.isOn ? Trois.accentTint : Trois.surface,
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    configuration.isOn ? Trois.accent : Trois.line,
                    lineWidth: 1.5
                )
            )
            .scaleEffect(configuration.isOn ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isOn)
            .contentShape(Capsule())
            .onTapGesture { configuration.isOn.toggle() }
    }
}

// 折り返しレイアウト
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                height += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
