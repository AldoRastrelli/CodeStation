import SwiftUI

struct TerminalContainerView: View {
    private enum Constants {
        static let cornerRadius: CGFloat = 8
        static let hoverBorderOpacity: Double = 0.5
        static let normalBorderOpacity: Double = 0.3
        static let borderWidth: CGFloat = 1
    }

    let viewModel: TerminalSessionViewModel
    var terminalNumber: Int?
    var hasUnseenNotification: Bool = false
    var onClose: () -> Void
    var onAddPromptButton: ((PromptButton) -> Void)?
    var onUpdatePromptButton: ((PromptButton) -> Void)?
    var onDeletePromptButton: ((UUID) -> Void)?
    var onFocus: (() -> Void)?
    var dragID: String?
    var skipCloseConfirmation: Bool = false
    var onSkipCloseConfirmationChanged: ((Bool) -> Void)?

    @State private var isHovered = false
    @State private var showCloseConfirmation = false
    @State private var dontShowAgain = false

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            TerminalSessionView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear { viewModel.onFocused = onFocus }
        }
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .stroke(isHovered ? Color.accentColor.opacity(Constants.hoverBorderOpacity) : Color.gray.opacity(Constants.normalBorderOpacity), lineWidth: Constants.borderWidth)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onFocus?()
        }
        .sheet(isPresented: $showCloseConfirmation) {
            VStack(spacing: 16) {
                Text(Strings.Terminals.closeTerminalTitle)
                    .font(.headline)

                Text(Strings.Terminals.closeConfirmation(viewModel.session.title))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Toggle(Strings.Terminals.dontShowAgain, isOn: $dontShowAgain)
                    .toggleStyle(.checkbox)

                HStack {
                    Button(Strings.Terminals.cancel) {
                        showCloseConfirmation = false
                    }
                    .keyboardShortcut(.cancelAction)

                    Button(Strings.Terminals.close) {
                        if dontShowAgain {
                            onSkipCloseConfirmationChanged?(true)
                        }
                        showCloseConfirmation = false
                        onClose()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding(24)
            .frame(width: 340)
        }
    }

    @ViewBuilder
    private var headerView: some View {
        let header = TerminalHeaderView(
            viewModel: viewModel,
            terminalNumber: terminalNumber,
            hasUnseenNotification: hasUnseenNotification,
            onClose: {
                if skipCloseConfirmation {
                    onClose()
                } else {
                    showCloseConfirmation = true
                }
            },
            onAddPromptButton: onAddPromptButton,
            onUpdatePromptButton: onUpdatePromptButton,
            onDeletePromptButton: onDeletePromptButton
        )

        if let dragID {
            header.draggable(dragID)
        } else {
            header
        }
    }
}
