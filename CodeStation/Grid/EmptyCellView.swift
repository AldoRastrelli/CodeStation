import SwiftUI

struct EmptyCellView: View {
    private enum Constants {
        static let spacing: CGFloat = 8
        static let iconSize: CGFloat = 28
        static let textSize: CGFloat = 11
        static let bgOpacity: Double = 0.3
        static let cornerRadius: CGFloat = 8
        static let strokeWidth: CGFloat = 1
        static let dashLength: CGFloat = 6
    }

    var onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            VStack(spacing: Constants.spacing) {
                Image(systemName: Strings.Icons.plusCircle)
                    .font(.system(size: Constants.iconSize, weight: .light))
                    .foregroundStyle(.secondary)
                Text(Strings.Terminals.newTerminal)
                    .font(.system(size: Constants.textSize))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor).opacity(Constants.bgOpacity))
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .strokeBorder(style: StrokeStyle(lineWidth: Constants.strokeWidth, dash: [Constants.dashLength]))
                    .foregroundStyle(.quaternary)
            )
        }
        .buttonStyle(.plain)
    }
}
