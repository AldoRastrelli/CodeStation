import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case notifications
    case customPrompts
    case keyboardShortcuts
    case help

    var id: String { rawValue }

    var label: String {
        switch self {
        case .notifications: return Strings.Notifications.sectionTitle
        case .customPrompts: return Strings.CustomPrompts.sectionTitle
        case .keyboardShortcuts: return Strings.Settings.keyboardShortcuts
        case .help: return Strings.Settings.help
        }
    }

    var icon: String {
        switch self {
        case .notifications: return "bell.badge"
        case .customPrompts: return "text.bubble"
        case .keyboardShortcuts: return "keyboard"
        case .help: return "questionmark.circle"
        }
    }
}

struct SettingsWindowView: View {
    private enum Constants {
        static let sidebarWidth: CGFloat = 180
        static let contentMinWidth: CGFloat = 400
        static let windowHeight: CGFloat = 400
        static let contentPadding: CGFloat = 24
        static let colorDotSize: CGFloat = 12
    }

    @Bindable var viewModel: AppViewModel
    @State private var selectedTab: SettingsTab = .notifications
    @State private var selectedButtonIDs: Set<UUID> = []
    @State private var isAddingNew = false
    @State private var editTitle = ""
    @State private var editColor = "blue"
    @State private var editPrompt = ""
    @State private var detailButtonID: UUID?
    @State private var hookStatusMessage: String?

    var body: some View {
        HStack(spacing: 0) {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label(tab.label, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .frame(width: Constants.sidebarWidth)

            Divider()

            Group {
                switch selectedTab {
                case .notifications:
                    notificationsPane
                case .customPrompts:
                    if let buttonID = detailButtonID,
                       let index = viewModel.promptButtons.firstIndex(where: { $0.id == buttonID }) {
                        promptDetailView(index: index)
                    } else {
                        customPromptsPane
                    }
                case .keyboardShortcuts:
                    keyboardShortcutsPane
                case .help:
                    helpPane
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: Constants.sidebarWidth + Constants.contentMinWidth, minHeight: Constants.windowHeight)
        .onChange(of: viewModel.notificationSettings) {
            viewModel.scheduleSave()
        }
    }

    // MARK: - Notifications

    private var notificationsPane: some View {
        Form {
            Section {
                Toggle(Strings.Notifications.enableToggle, isOn: $viewModel.notificationSettings.enabled)
                    .toggleStyle(.switch)
            }

            Section {
                Toggle(Strings.Notifications.whenDoneToggle, isOn: $viewModel.notificationSettings.notifyWhenDone)
                    .disabled(!viewModel.notificationSettings.enabled)

                Toggle(Strings.Notifications.whenWaitingToggle, isOn: $viewModel.notificationSettings.notifyWhenWaiting)
                    .disabled(!viewModel.notificationSettings.enabled)
            } header: {
                Text(Strings.Settings.notifyWhen)
            }

            Section {
                Toggle(Strings.Notifications.makeSoundToggle, isOn: $viewModel.notificationSettings.soundEnabled)
                    .toggleStyle(.switch)

                Picker(Strings.Notifications.soundPicker, selection: $viewModel.notificationSettings.soundName) {
                    ForEach(NotificationSettings.availableSounds, id: \.self) { sound in
                        Text(sound).tag(sound)
                    }
                }
                .disabled(!viewModel.notificationSettings.soundEnabled)
                .onChange(of: viewModel.notificationSettings.soundName) { _, newValue in
                    NotificationService.playSound(named: newValue)
                }
            } header: {
                Text(Strings.Settings.soundSection)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Strings.Notifications.sectionTitle)
        .padding(Constants.contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Custom Prompts List

    private var customPromptsPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.promptButtons.isEmpty && !isAddingNew {
                VStack(spacing: 12) {
                    Text(Strings.CustomPrompts.noPrompts)
                        .foregroundStyle(.secondary)
                    Button(Strings.CustomPrompts.addPrompt) {
                        beginAddNew()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.promptButtons) { button in
                        promptButtonRow(button)
                    }

                    if isAddingNew {
                        newButtonRow
                    }
                }

                if !selectedButtonIDs.isEmpty {
                    HStack {
                        Text("\(selectedButtonIDs.count) selected")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if selectedButtonIDs.count == 1 {
                            Button(Strings.CustomPrompts.duplicatePrompt) {
                                duplicateSelected()
                            }
                        }
                        Button(Strings.CustomPrompts.deletePrompt) {
                            deleteSelected()
                        }
                        .foregroundStyle(.red)
                        Button(Strings.Terminals.cancel) {
                            selectedButtonIDs.removeAll()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }

                HStack {
                    Spacer()
                    Button(Strings.CustomPrompts.addPrompt) {
                        beginAddNew()
                    }
                    .padding()
                }
            }
        }
        .padding(.top, Constants.contentPadding)
        .padding(.horizontal, Constants.contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Prompt Row

    private func promptButtonRow(_ button: PromptButton) -> some View {
        let isSelected = selectedButtonIDs.contains(button.id)

        return HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .onTapGesture { toggleSelection(button.id) }

            Circle()
                .fill(colorForName(button.color))
                .frame(width: Constants.colorDotSize, height: Constants.colorDotSize)

            Text(button.title)
                .font(.headline)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            detailButtonID = button.id
        }
    }

    // MARK: - Prompt Detail View

    private func promptDetailView(index: Int) -> some View {
        let button = viewModel.promptButtons[index]

        return VStack(alignment: .leading, spacing: 0) {
            // Navigation bar
            HStack {
                Button(action: {
                    viewModel.scheduleSave()
                    detailButtonID = nil
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .medium))
                        Text(Strings.CustomPrompts.sectionTitle)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

                Spacer()
            }
            .padding(.horizontal, Constants.contentPadding)
            .padding(.vertical, 12)

            Divider()

            // Detail form
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Strings.CustomPrompts.titlePlaceholder)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField(Strings.CustomPrompts.titlePlaceholder, text: $viewModel.promptButtons[index].title)
                            .textFieldStyle(.roundedBorder)
                    }

                    if isDuplicateTitle(button.title, excluding: button.id) {
                        Text(Strings.CustomPrompts.duplicateName)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    // Color
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Strings.CustomPrompts.colorLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            ForEach(PromptButton.availableColors, id: \.self) { color in
                                Button(action: {
                                    viewModel.promptButtons[index].color = color
                                    viewModel.scheduleSave()
                                }) {
                                    Circle()
                                        .fill(colorForName(color))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(Color.primary, lineWidth: button.color == color ? 2 : 0)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Prompt
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Strings.CustomPrompts.promptLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $viewModel.promptButtons[index].prompt)
                            .font(.body)
                            .frame(minHeight: 100)
                            .padding(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(Constants.contentPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: viewModel.promptButtons) {
            viewModel.scheduleSave()
        }
    }

    // MARK: - New Button Row

    private var newButtonRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.bottom, 4)

            TextField(Strings.CustomPrompts.titlePlaceholder, text: $editTitle)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text(Strings.CustomPrompts.colorLabel)
                    .font(.subheadline)
                ForEach(PromptButton.availableColors, id: \.self) { color in
                    Button(action: { editColor = color }) {
                        Circle()
                            .fill(colorForName(color))
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.primary, lineWidth: editColor == color ? 2 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField(Strings.CustomPrompts.promptPlaceholder, text: $editPrompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            HStack {
                Spacer()
                Button(Strings.Terminals.cancel) {
                    isAddingNew = false
                    resetEditForm()
                }
                Button(Strings.CustomPrompts.addPrompt) {
                    let button = PromptButton(title: editTitle, color: editColor, prompt: editPrompt)
                    viewModel.promptButtons.append(button)
                    viewModel.scheduleSave()
                    isAddingNew = false
                    resetEditForm()
                }
                .disabled(editTitle.isEmpty || editPrompt.isEmpty || isDuplicateTitle(editTitle, excluding: nil))
                .buttonStyle(.borderedProminent)
            }

            if isDuplicateTitle(editTitle, excluding: nil) {
                Text(Strings.CustomPrompts.duplicateName)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Selection Helpers

    private func toggleSelection(_ id: UUID) {
        if selectedButtonIDs.contains(id) {
            selectedButtonIDs.remove(id)
        } else {
            selectedButtonIDs.insert(id)
        }
    }

    private func deleteSelected() {
        viewModel.promptButtons.removeAll { selectedButtonIDs.contains($0.id) }
        viewModel.scheduleSave()
        selectedButtonIDs.removeAll()
    }

    private func duplicateSelected() {
        guard let id = selectedButtonIDs.first,
              let source = viewModel.promptButtons.first(where: { $0.id == id }) else { return }
        let newButton = PromptButton(
            title: source.title + " (copy)",
            color: source.color,
            prompt: source.prompt
        )
        viewModel.promptButtons.append(newButton)
        viewModel.scheduleSave()
        selectedButtonIDs.removeAll()
        detailButtonID = newButton.id
    }

    // MARK: - Add Helpers

    private func beginAddNew() {
        resetEditForm()
        isAddingNew = true
    }

    private func resetEditForm() {
        editTitle = ""
        editColor = "blue"
        editPrompt = ""
    }

    private func isDuplicateTitle(_ title: String, excluding id: UUID?) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return viewModel.promptButtons.contains { button in
            button.id != id && button.title.trimmingCharacters(in: .whitespaces).lowercased() == trimmed.lowercased()
        }
    }

    // MARK: - Keyboard Shortcuts

    private var keyboardShortcutsPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                shortcutSection("Terminals", shortcuts: [
                    ("⌘ N", "New terminal (or new environment if environment is full)"),
                    ("⌘ W", "Close focused terminal"),
                    ("⌘ 1–8", "Focus terminal by number"),
                    ("⇧⌘ ←", "Focus previous terminal"),
                    ("⇧⌘ →", "Focus next terminal"),
                ])

                shortcutSection("Environments", shortcuts: [
                    ("⇧⌘ ↑", "Previous environment"),
                    ("⇧⌘ ↓", "Next environment"),
                ])

                shortcutSection("View", shortcuts: [
                    ("⌘ +", "Zoom in"),
                    ("⌘ −", "Zoom out"),
                    ("⌘ 0", "Reset zoom"),
                ])

                shortcutSection("General", shortcuts: [
                    ("⌘ T", "New terminal (same as ⌘ N)"),
                ])
            }
            .padding(Constants.contentPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func shortcutSection(_ title: String, shortcuts: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            ForEach(shortcuts, id: \.0) { shortcut in
                HStack {
                    Text(shortcut.0)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .frame(width: 80, alignment: .trailing)
                        .foregroundStyle(.primary)

                    Text(shortcut.1)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Help

    private var helpPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Strings.Settings.help)
                .font(.headline)

            Text(Strings.Settings.helpMessage)
                .foregroundStyle(.secondary)

            Button(Strings.Settings.reinstallHook) {
                do {
                    try HookManager.install()
                    hookStatusMessage = Strings.Settings.hookReinstalled
                } catch {
                    hookStatusMessage = Strings.Settings.hookReinstallFailed
                }
            }
            .buttonStyle(.borderedProminent)

            if let hookStatusMessage {
                Text(hookStatusMessage)
                    .font(.subheadline)
                    .foregroundStyle(hookStatusMessage == Strings.Settings.hookReinstalled ? .green : .red)
            }
        }
        .padding(Constants.contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func colorForName(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "red": return .red
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        default: return .blue
        }
    }
}
