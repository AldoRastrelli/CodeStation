import SwiftUI

struct BoardView: View {
    private enum Constants {
        static let titleFontSize: CGFloat = 15
        static let counterFontSize: CGFloat = 12
        static let addButtonFontSize: CGFloat = 14
        static let horizontalPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 8
        static let emptyStateSpacing: CGFloat = 12
        static let emptyIconSize: CGFloat = 40
        static let emptyTextSize: CGFloat = 15
    }

    @Bindable var viewModel: BoardViewModel
    let environmentName: String
    var onRename: (String) -> Void

    @State private var isEditingName = false
    @State private var editedName = ""
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                if isEditingName {
                    TextField(Strings.Terminals.namePlaceholder, text: $editedName)
                        .textFieldStyle(.plain)
                        .font(.system(size: Constants.titleFontSize, weight: .semibold))
                        .focused($isNameFieldFocused)
                        .onSubmit { commitRename() }
                        .onChange(of: isNameFieldFocused) { _, focused in
                            if !focused { commitRename() }
                        }
                        .fixedSize()
                } else {
                    Text(environmentName)
                        .font(.system(size: Constants.titleFontSize, weight: .semibold))
                        .onTapGesture(count: 2) { beginRename() }
                }

                Text(Strings.Terminals.sessionCount(viewModel.sessions.count, max: BoardViewModel.maxSessions))
                    .font(.system(size: Constants.counterFontSize))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    _ = viewModel.addSession()
                } label: {
                    Image(systemName: Strings.Icons.plus)
                        .font(.system(size: Constants.addButtonFontSize))
                }
                .disabled(!viewModel.canAddSession)
                .help(Strings.Terminals.addTerminal)
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.vertical, Constants.verticalPadding)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Terminal grid
            if viewModel.sessions.isEmpty {
                emptyState
            } else {
                TerminalGridView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            viewModel.restorePendingSessions()
            if viewModel.sessions.isEmpty {
                _ = viewModel.addSession()
            }
        }
    }

    private func beginRename() {
        editedName = environmentName
        isEditingName = true
        DispatchQueue.main.async {
            isNameFieldFocused = true
        }
    }

    private func commitRename() {
        guard isEditingName else { return }
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            onRename(trimmed)
        }
        isEditingName = false
    }

    private var emptyState: some View {
        VStack(spacing: Constants.emptyStateSpacing) {
            Image(systemName: Strings.Icons.terminal)
                .font(.system(size: Constants.emptyIconSize))
                .foregroundStyle(.secondary)
            Text(Strings.Terminals.noTerminals)
                .font(.system(size: Constants.emptyTextSize))
                .foregroundStyle(.secondary)
            Button(Strings.Terminals.openTerminal) {
                _ = viewModel.addSession()
            }
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
