import SwiftUI

struct TerminalHeaderView: View {
    private enum Constants {
        static let hStackSpacing: CGFloat = 8
        static let statusEmojiSize: CGFloat = 14
        static let titleFontSize: CGFloat = 14
        static let descriptionFontSize: CGFloat = 12
        static let titleMaxWidth: CGFloat = 150
        static let descriptionMaxWidth: CGFloat = 200
        static let badgeFontSize: CGFloat = 10
        static let badgeHPadding: CGFloat = 6
        static let badgeVPadding: CGFloat = 2
        static let badgeBgOpacity: Double = 0.2
        static let closeButtonSize: CGFloat = 10
        static let horizontalPadding: CGFloat = 10
        static let verticalPadding: CGFloat = 6
        static let promptButtonFontSize: CGFloat = 11
        static let promptButtonHPadding: CGFloat = 10
        static let promptButtonVPadding: CGFloat = 4
        static let promptBarHeight: CGFloat = 30
        static let chevronSize: CGFloat = 10
        static let addButtonSize: CGFloat = 14
        static let subtitleFontSize: CGFloat = 11
        static let notificationOverlayOpacity: Double = 0.15
    }

    @Bindable var viewModel: TerminalSessionViewModel
    var terminalNumber: Int?
    var hasUnseenNotification: Bool = false
    var onClose: () -> Void
    var onAddPromptButton: ((PromptButton) -> Void)?
    var onUpdatePromptButton: ((PromptButton) -> Void)?
    var onDeletePromptButton: ((UUID) -> Void)?

    @State private var isEditingTitle = false
    @State private var isEditingDescription = false
    @State private var showingAddPrompt = false
    @State private var newPromptTitle = ""
    @State private var newPromptColor = "blue"
    @State private var newPromptText = ""
    @State private var editingButton: PromptButton?
    @State private var showingEditPrompt = false
    @FocusState private var titleFocused: Bool
    @FocusState private var descriptionFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: icon, title, status, close
            HStack(spacing: Constants.hStackSpacing) {
                statusEmoji
                titleView

                Spacer()

                shortcutBadge
                statusCapsule
                closeButton
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.top, Constants.verticalPadding)
            .padding(.bottom, Constants.verticalPadding + 4)

            // Row 2: description, aligned with buttons
            descriptionView
                .padding(.horizontal, Constants.horizontalPadding)
                .padding(.bottom, 4)

            // Row 3: chevron + "Buttons" label (always visible)
            HStack(spacing: 4) {
                Button(action: { viewModel.promptButtonsCollapsed.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: Constants.chevronSize, weight: .medium))
                        Text(Strings.CustomPrompts.buttonsLabel)
                            .font(.system(size: Constants.subtitleFontSize, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(isCollapsed ? "Show prompt buttons" : "Hide prompt buttons")

                Spacer()
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.vertical, 3)

            // Row 3: buttons bar (when expanded)
            if !isCollapsed {
                promptButtonsBar
                    .padding(.horizontal, Constants.horizontalPadding)
                    .padding(.bottom, 4)
            }
        }
        .background {
            Color(nsColor: .controlBackgroundColor)
            if hasUnseenNotification {
                notificationOverlayColor
                    .opacity(Constants.notificationOverlayOpacity)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: hasUnseenNotification)
        .popover(isPresented: $showingAddPrompt) {
            addPromptPopover
        }
        .popover(isPresented: $showingEditPrompt) {
            editPromptPopover
        }
    }

    // MARK: - Header subviews

    private var statusEmoji: some View {
        Text(viewModel.session.status.emoji)
            .font(.system(size: Constants.statusEmojiSize))
    }

    @ViewBuilder
    private var titleView: some View {
        if isEditingTitle {
            TextField(Strings.Terminals.titlePlaceholder, text: $viewModel.session.title)
                .textFieldStyle(.plain)
                .font(.system(size: Constants.titleFontSize, weight: .semibold))
                .focused($titleFocused)
                .onSubmit {
                    isEditingTitle = false
                    let trimmed = viewModel.session.title.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty {
                        viewModel.resetTitleToDefault()
                    } else {
                        viewModel.session.isUserEditedTitle = true
                    }
                }
                .onAppear { titleFocused = true }
                .frame(maxWidth: Constants.titleMaxWidth)
        } else {
            Text(viewModel.session.title)
                .font(.system(size: Constants.titleFontSize, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: Constants.titleMaxWidth, alignment: .leading)
                .onTapGesture(count: 2) { isEditingTitle = true }
        }
    }

    @ViewBuilder
    private var descriptionView: some View {
        if isEditingDescription {
            TextField(Strings.Terminals.descriptionPlaceholder, text: $viewModel.session.sessionDescription)
                .textFieldStyle(.plain)
                .font(.system(size: Constants.descriptionFontSize))
                .foregroundStyle(.secondary)
                .focused($descriptionFocused)
                .onSubmit { isEditingDescription = false }
                .onAppear { descriptionFocused = true }
        } else {
            Text(viewModel.session.sessionDescription.isEmpty ? Strings.Terminals.descriptionPlaceholder : viewModel.session.sessionDescription)
                .font(.system(size: Constants.descriptionFontSize))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture(count: 2) { isEditingDescription = true }
        }
    }

    @ViewBuilder
    private var shortcutBadge: some View {
        if let number = terminalNumber {
            Text("⌘\(number)")
                .font(.system(size: Constants.badgeFontSize, weight: .bold))
                .foregroundStyle(.tertiary)
        }
    }

    private var statusCapsule: some View {
        Text(viewModel.session.status.label)
            .font(.system(size: Constants.badgeFontSize, weight: .medium))
            .padding(.horizontal, Constants.badgeHPadding)
            .padding(.vertical, Constants.badgeVPadding)
            .background(statusColor.opacity(Constants.badgeBgOpacity))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: Strings.Icons.xmark)
                .font(.system(size: Constants.closeButtonSize, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(Strings.Terminals.closeTerminal)
    }

    private var isCollapsed: Bool {
        viewModel.promptButtonsCollapsed
    }

    private var promptButtons: [PromptButton] {
        viewModel.getPromptButtons?() ?? []
    }

    private var promptButtonsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(promptButtons) { button in
                    Button(action: { viewModel.sendPrompt(button.prompt) }) {
                        Text(button.title)
                            .font(.system(size: Constants.promptButtonFontSize, weight: .medium))
                            .padding(.horizontal, Constants.promptButtonHPadding)
                            .padding(.vertical, Constants.promptButtonVPadding)
                            .background(colorForName(button.color).opacity(0.2))
                            .foregroundStyle(colorForName(button.color))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(button.prompt)
                    .contextMenu {
                        Button(Strings.CustomPrompts.editPrompt) {
                            editingButton = button
                            newPromptTitle = button.title
                            newPromptColor = button.color
                            newPromptText = button.prompt
                            showingEditPrompt = true
                        }
                        Divider()
                        Button(Strings.CustomPrompts.deletePrompt, role: .destructive) {
                            onDeletePromptButton?(button.id)
                        }
                    }
                }

                // Add button
                Button(action: { showingAddPrompt = true }) {
                    Image(systemName: Strings.Icons.plusCircle)
                        .font(.system(size: Constants.addButtonSize))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(Strings.CustomPrompts.addPrompt)
            }
            .padding(.vertical, 2)
        }
    }

    private var addPromptPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Strings.CustomPrompts.addPrompt)
                .font(.headline)

            TextField(Strings.CustomPrompts.titlePlaceholder, text: $newPromptTitle)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text(Strings.CustomPrompts.colorLabel)
                    .font(.subheadline)
                Spacer()
                ForEach(PromptButton.availableColors, id: \.self) { color in
                    Button(action: { newPromptColor = color }) {
                        Circle()
                            .fill(colorForName(color))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.primary, lineWidth: newPromptColor == color ? 2 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField(Strings.CustomPrompts.promptPlaceholder, text: $newPromptText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...5)

            HStack {
                Spacer()
                Button(Strings.Terminals.cancel) {
                    resetAddForm()
                    showingAddPrompt = false
                }
                Button(Strings.CustomPrompts.addPrompt) {
                    let button = PromptButton(title: newPromptTitle, color: newPromptColor, prompt: newPromptText)
                    onAddPromptButton?(button)
                    resetAddForm()
                    showingAddPrompt = false
                }
                .disabled(newPromptTitle.isEmpty || newPromptText.isEmpty || isDuplicateTitle(newPromptTitle))
                .buttonStyle(.borderedProminent)
            }

            if isDuplicateTitle(newPromptTitle) {
                Text(Strings.CustomPrompts.duplicateName)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(width: 300)
    }

    private var editPromptPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Strings.CustomPrompts.editPrompt)
                .font(.headline)

            TextField(Strings.CustomPrompts.titlePlaceholder, text: $newPromptTitle)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text(Strings.CustomPrompts.colorLabel)
                    .font(.subheadline)
                Spacer()
                ForEach(PromptButton.availableColors, id: \.self) { color in
                    Button(action: { newPromptColor = color }) {
                        Circle()
                            .fill(colorForName(color))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.primary, lineWidth: newPromptColor == color ? 2 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField(Strings.CustomPrompts.promptPlaceholder, text: $newPromptText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...5)

            HStack {
                Spacer()
                Button(Strings.Terminals.cancel) {
                    showingEditPrompt = false
                    resetAddForm()
                }
                Button(Strings.CustomPrompts.editPrompt) {
                    if var updated = editingButton {
                        updated.title = newPromptTitle
                        updated.color = newPromptColor
                        updated.prompt = newPromptText
                        onUpdatePromptButton?(updated)
                    }
                    showingEditPrompt = false
                    resetAddForm()
                }
                .disabled(newPromptTitle.isEmpty || newPromptText.isEmpty || isDuplicateTitle(newPromptTitle, excludingID: editingButton?.id))
                .buttonStyle(.borderedProminent)
            }

            if isDuplicateTitle(newPromptTitle, excludingID: editingButton?.id) {
                Text(Strings.CustomPrompts.duplicateName)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(width: 300)
    }

    private func isDuplicateTitle(_ title: String, excludingID: UUID?) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return promptButtons.contains {
            $0.id != excludingID && $0.title.trimmingCharacters(in: .whitespaces).lowercased() == trimmed.lowercased()
        }
    }

    private func isDuplicateTitle(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return promptButtons.contains { $0.title.trimmingCharacters(in: .whitespaces).lowercased() == trimmed.lowercased() }
    }

    private func resetAddForm() {
        newPromptTitle = ""
        newPromptColor = "blue"
        newPromptText = ""
    }

    private var statusColor: Color {
        switch viewModel.session.status {
        case .cooking: return .red
        case .ready: return .green
        case .asleep: return .gray
        case .waiting: return .orange
        }
    }

    private var notificationOverlayColor: Color {
        switch viewModel.session.status {
        case .ready: return .green
        case .waiting: return .orange
        default: return .clear
        }
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
