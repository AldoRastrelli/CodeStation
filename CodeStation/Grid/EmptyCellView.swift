import SwiftUI

struct EmptyCellView: View {
    private enum Constants {
        static let spacing: CGFloat = 8
        static let iconSize: CGFloat = 28
        static let textSize: CGFloat = 11
        static let bgOpacity: Double = 0.3
        static let cornerRadius: CGFloat = 8
        static let strokeWidth: CGFloat = 1
        static let targetedStrokeWidth: CGFloat = 2
        static let dashLength: CGFloat = 6
    }

    var onAdd: () -> Void
    var onSessionDropped: ((UUID) -> Bool)?

    @State private var isDropTargeted = false

    var body: some View {
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
        .overlay(border)
        .contentShape(Rectangle())
        .onTapGesture(perform: onAdd)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Strings.Terminals.newTerminal)
        .onDrop(of: TerminalDragPayload.contentTypes, isTargeted: $isDropTargeted) { providers in
            TerminalDragPayload.loadSessionID(from: providers) { sessionID in
                DispatchQueue.main.async {
                    guard let sessionID else { return }
                    _ = acceptDrop(sessionID: sessionID)
                }
            }
        }
    }

    @ViewBuilder
    private var border: some View {
        let shape = RoundedRectangle(cornerRadius: Constants.cornerRadius)
        if isDropTargeted {
            shape
                .strokeBorder(Color.accentColor, lineWidth: Constants.targetedStrokeWidth)
        } else {
            shape
                .strokeBorder(style: StrokeStyle(lineWidth: Constants.strokeWidth, dash: [Constants.dashLength]))
                .foregroundStyle(.quaternary)
        }
    }

    func acceptDrop(sessionID: UUID) -> Bool {
        onSessionDropped?(sessionID) ?? false
    }
}
