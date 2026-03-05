import SwiftUI

struct SidebarRowView: View {
    private enum Constants {
        static let hStackSpacing: CGFloat = 8
        static let iconSize: CGFloat = 12
        static let countFontSize: CGFloat = 11
        static let countHPadding: CGFloat = 6
        static let countVPadding: CGFloat = 2
        static let countBgOpacity: Double = 0.15
    }

    let environment: Environment
    let viewModel: AppViewModel

    @FocusState private var isFieldFocused: Bool
    @State private var isEditing = false
    @State private var editedName = ""

    var body: some View {
        HStack(spacing: Constants.hStackSpacing) {
            Image(systemName: Strings.Icons.grid)
                .foregroundStyle(.secondary)
                .font(.system(size: Constants.iconSize))

            if isEditing {
                TextField(Strings.Terminals.namePlaceholder, text: $editedName)
                    .textFieldStyle(.plain)
                    .focused($isFieldFocused)
                    .onSubmit {
                        commitRename()
                    }
                    .onChange(of: isFieldFocused) { _, focused in
                        if !focused {
                            commitRename()
                        }
                    }
            } else {
                Text(environment.name)
                    .lineLimit(1)
            }

            Spacer()

            let hasNotification = viewModel.boardViewModel(for: environment).hasUnseenNotification
            Text("\(viewModel.boardViewModel(for: environment).sessions.count)")
                .font(.system(size: Constants.countFontSize))
                .foregroundStyle(hasNotification ? .white : .secondary)
                .padding(.horizontal, Constants.countHPadding)
                .padding(.vertical, Constants.countVPadding)
                .background(hasNotification ? Color.red : Color.secondary.opacity(Constants.countBgOpacity))
                .clipShape(Capsule())
                .animation(.easeInOut(duration: 0.3), value: hasNotification)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button(Strings.Environments.rename) {
                DispatchQueue.main.async {
                    beginRename()
                }
            }
            Divider()
            Button(Strings.Environments.delete, role: .destructive) {
                DispatchQueue.main.async {
                    viewModel.removeEnvironment(environment)
                }
            }
        }
    }

    private func beginRename() {
        editedName = environment.name
        isEditing = true
        DispatchQueue.main.async {
            isFieldFocused = true
        }
    }

    private func commitRename() {
        guard isEditing else { return }
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            viewModel.renameEnvironment(environment, to: trimmed)
        }
        isEditing = false
    }
}
