import SwiftUI

struct TerminalContainerView: View {
    private enum Constants {
        static let cornerRadius: CGFloat = 8
        static let hoverBorderOpacity: Double = 0.5
        static let normalBorderOpacity: Double = 0.3
        static let borderWidth: CGFloat = 1
    }

    let viewModel: TerminalSessionViewModel
    var onClose: () -> Void
    var onAddPromptButton: ((PromptButton) -> Void)?

    @State private var isHovered = false
    @State private var showCloseConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            TerminalHeaderView(
                viewModel: viewModel,
                onClose: { showCloseConfirmation = true },
                onAddPromptButton: onAddPromptButton
            )

            Divider()

            TerminalSessionView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .stroke(isHovered ? Color.accentColor.opacity(Constants.hoverBorderOpacity) : Color.gray.opacity(Constants.normalBorderOpacity), lineWidth: Constants.borderWidth)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .alert(Strings.Terminals.closeTerminalTitle, isPresented: $showCloseConfirmation) {
            Button(Strings.Terminals.cancel, role: .cancel) {}
            Button(Strings.Terminals.close, role: .destructive, action: onClose)
                .keyboardShortcut(.defaultAction)
        } message: {
            Text(Strings.Terminals.closeConfirmation(viewModel.session.title))
        }
    }
}
