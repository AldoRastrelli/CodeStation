import SwiftUI

struct SidebarView: View {
    private enum Constants {
        static let buttonPadding: CGFloat = 8
    }

    @Bindable var viewModel: AppViewModel

    var body: some View {
        List(selection: $viewModel.selectedEnvironmentID) {
            ForEach(viewModel.sortedFolders) { folder in
                SidebarFolderView(folder: folder, viewModel: viewModel)
            }
            .onMove { source, destination in
                viewModel.moveFolder(from: source, to: destination)
            }

            ForEach(viewModel.topLevelEnvironments) { env in
                SidebarRowView(environment: env, viewModel: viewModel)
                    .tag(env.id)
                    .draggable(env.id.uuidString)
                    .dropDestination(for: String.self) { items, _ in
                        viewModel.handleEnvironmentDrop(items, before: env)
                    }
            }
            .onMove { source, destination in
                viewModel.moveEnvironment(from: source, to: destination, inFolder: nil)
            }
        }
        .listStyle(.sidebar)
        // Dropping anywhere on the sidebar background moves an environment out
        // to the top level, so an environment can leave a folder even when no
        // top-level rows exist to drop onto.
        .dropDestination(for: String.self) { items, _ in
            viewModel.handleEnvironmentDrop(items, toFolder: nil)
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Menu {
                    Button(Strings.Environments.newEnvironment) {
                        viewModel.newEnvironmentName = ""
                        viewModel.showNewEnvironmentAlert = true
                    }
                    Button(Strings.Environments.newFolder) {
                        viewModel.newFolderName = ""
                        viewModel.showNewFolderAlert = true
                    }
                } label: {
                    Label(Strings.Environments.add, systemImage: Strings.Icons.plus)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .padding(Constants.buttonPadding)

                Spacer()
            }
        }
    }
}

private struct SidebarFolderView: View {
    private enum Constants {
        static let iconSize: CGFloat = 12
        static let spacing: CGFloat = 8
    }

    let folder: Folder
    let viewModel: AppViewModel

    @FocusState private var isFieldFocused: Bool
    @State private var isEditing = false
    @State private var editedName = ""

    private var isExpanded: Binding<Bool> {
        Binding(
            get: { folder.isExpanded },
            set: { viewModel.setFolderExpanded(folder, expanded: $0) }
        )
    }

    var body: some View {
        DisclosureGroup(isExpanded: isExpanded) {
            ForEach(viewModel.environments(in: folder)) { env in
                SidebarRowView(environment: env, viewModel: viewModel)
                    .tag(env.id)
                    .draggable(env.id.uuidString)
                    .dropDestination(for: String.self) { items, _ in
                        viewModel.handleEnvironmentDrop(items, before: env)
                    }
            }
            .onMove { source, destination in
                viewModel.moveEnvironment(from: source, to: destination, inFolder: folder.id)
            }
        } label: {
            label
        }
    }

    @ViewBuilder
    private var label: some View {
        HStack(spacing: Constants.spacing) {
            Image(systemName: Strings.Icons.folder)
                .foregroundStyle(.secondary)
                .font(.system(size: Constants.iconSize))

            if isEditing {
                TextField(Strings.Environments.folderNamePlaceholder, text: $editedName)
                    .textFieldStyle(.plain)
                    .focused($isFieldFocused)
                    .onSubmit { commitRename() }
                    .onChange(of: isFieldFocused) { _, focused in
                        if !focused { commitRename() }
                    }
            } else {
                Text(folder.name)
                    .lineLimit(1)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, _ in
            viewModel.handleEnvironmentDrop(items, toFolder: folder.id)
        }
        .contextMenu {
            Button(Strings.Environments.renameFolder) {
                DispatchQueue.main.async { beginRename() }
            }
            Divider()
            Button(Strings.Environments.deleteFolder, role: .destructive) {
                DispatchQueue.main.async { viewModel.removeFolder(folder) }
            }
        }
    }

    private func beginRename() {
        editedName = folder.name
        isEditing = true
        DispatchQueue.main.async { isFieldFocused = true }
    }

    private func commitRename() {
        guard isEditing else { return }
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            viewModel.renameFolder(folder, to: trimmed)
        }
        isEditing = false
    }
}
