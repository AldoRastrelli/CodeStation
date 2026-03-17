import SwiftUI

struct TerminalGridView: View {
    private enum Constants {
        static let dividerThickness: CGFloat = 6
        static let padding: CGFloat = 6
        static let minColumnProportion: CGFloat = 0.08
        static let minRowProportion: CGFloat = 0.15
        static let minDragDistance: CGFloat = 1
        static let edgeButtonBgOpacity: Double = 0.3
        static let edgeButtonIconSize: CGFloat = 22
        static let edgeButtonWidth: CGFloat = 36
        static let edgeStripWidth: CGFloat = 6
        static let hoverAnimationDuration: Double = 0.15
        static let dividerHoverOpacity: Double = 0.5
        static let dividerNormalOpacity: Double = 0.2
    }

    @Bindable var viewModel: BoardViewModel

    @State private var showEdgeButton = false

    var body: some View {
        ZStack(alignment: .trailing) {
            GeometryReader { geo in
                if viewModel.useGridLayout {
                    gridLayout(in: geo.size)
                } else {
                    singleRowLayout(in: geo.size)
                }
            }
            .padding(Constants.padding)

            if viewModel.canAddSession && !viewModel.useGridLayout {
                edgeAddButton
            }
        }
    }

    // MARK: - Single Row Layout (1-4 terminals)

    private func singleRowLayout(in size: CGSize) -> some View {
        let sessions = sortedSessions
        let count = sessions.count
        let totalDividers = CGFloat(max(count - 1, 0)) * Constants.dividerThickness
        let availableWidth = size.width - totalDividers

        return HStack(spacing: 0) {
            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                let colWidth = availableWidth * normalizedProportion(index: index, count: count)

                TerminalContainerView(
                    viewModel: viewModel.viewModel(for: session),
                    terminalNumber: index + 1,
                    hasUnseenNotification: viewModel.unseenNotificationSessionIDs.contains(session.id),
                    onClose: { viewModel.removeSession(session) },
                    onAddPromptButton: viewModel.onAddPromptButton,
                    onUpdatePromptButton: viewModel.onUpdatePromptButton,
                    onDeletePromptButton: viewModel.onDeletePromptButton,
                    onFocus: { viewModel.focusedSessionID = session.id },
                    skipCloseConfirmation: viewModel.getSkipCloseConfirmation?() ?? false,
                    onSkipCloseConfirmationChanged: viewModel.onSkipCloseConfirmationChanged
                )
                .frame(width: colWidth)

                if index < count - 1 {
                    VerticalDividerHandle(
                        onDragStart: { beginColumnResize() },
                        onDragChanged: { offset in
                            resizeColumns(draggingAfter: index, cumulativeOffset: offset, totalWidth: availableWidth, count: count)
                        },
                        onDragEnded: { endColumnResize() },
                        onDoubleClick: { resetColumnProportions(count: count) }
                    )
                    .frame(width: Constants.dividerThickness)
                }
            }
        }
    }

    // MARK: - Grid Layout (5-8 terminals, 2 rows x 4 cols)

    private func gridLayout(in size: CGSize) -> some View {
        let totalHDivider = Constants.dividerThickness
        let availableHeight = size.height - totalHDivider
        let topHeight = availableHeight * viewModel.rowProportion
        let bottomHeight = availableHeight * (1 - viewModel.rowProportion)

        return VStack(spacing: 0) {
            gridRow(row: 0, size: CGSize(width: size.width, height: topHeight))
                .frame(height: topHeight)

            HorizontalDividerHandle(
                onDragStart: { beginRowResize() },
                onDragChanged: { offset in
                    resizeRows(cumulativeOffset: offset, totalHeight: availableHeight)
                },
                onDragEnded: { endRowResize() },
                onDoubleClick: { resetRowProportion() }
            )
            .frame(height: Constants.dividerThickness)

            gridRow(row: 1, size: CGSize(width: size.width, height: bottomHeight))
                .frame(height: bottomHeight)
        }
    }

    private func gridRow(row: Int, size: CGSize) -> some View {
        let cols = viewModel.gridColumns
        let totalDividers = CGFloat(cols - 1) * Constants.dividerThickness
        let availableWidth = size.width - totalDividers

        return HStack(spacing: 0) {
            ForEach(0..<cols, id: \.self) { col in
                let colWidth = availableWidth * normalizedProportion(index: col, count: cols)

                cellView(row: row, col: col)
                    .frame(width: colWidth)

                if col < cols - 1 {
                    VerticalDividerHandle(
                        onDragStart: { beginColumnResize() },
                        onDragChanged: { offset in
                            resizeColumns(draggingAfter: col, cumulativeOffset: offset, totalWidth: availableWidth, count: cols)
                        },
                        onDragEnded: { endColumnResize() },
                        onDoubleClick: { resetColumnProportions(count: cols) }
                    )
                    .frame(width: Constants.dividerThickness)
                }
            }
        }
    }

    // MARK: - Cell View

    @ViewBuilder
    private func cellView(row: Int, col: Int) -> some View {
        let gridIndex = row * viewModel.gridColumns + col
        if let session = viewModel.sessionAt(row: row, col: col) {
            let sortedIndex = viewModel.sessions.sorted(by: { $0.gridIndex < $1.gridIndex }).firstIndex(where: { $0.id == session.id })
            TerminalContainerView(
                viewModel: viewModel.viewModel(for: session),
                terminalNumber: (sortedIndex ?? 0) + 1,
                hasUnseenNotification: viewModel.unseenNotificationSessionIDs.contains(session.id),
                onClose: { viewModel.removeSession(session) },
                onAddPromptButton: viewModel.onAddPromptButton,
                onUpdatePromptButton: viewModel.onUpdatePromptButton,
                onDeletePromptButton: viewModel.onDeletePromptButton,
                onFocus: { viewModel.focusedSessionID = session.id },
                dragID: session.id.uuidString,
                skipCloseConfirmation: viewModel.getSkipCloseConfirmation?() ?? false,
                onSkipCloseConfirmationChanged: viewModel.onSkipCloseConfirmationChanged
            )
            .dropDestination(for: String.self) { items, _ in
                guard let idString = items.first,
                      let sourceID = UUID(uuidString: idString) else { return false }
                return viewModel.swapSessions(sourceID: sourceID, targetGridIndex: gridIndex)
            }
        } else if viewModel.canAddSession {
            EmptyCellView {
                _ = viewModel.addSessionAt(row: row, col: col)
            }
            .dropDestination(for: String.self) { items, _ in
                guard let idString = items.first,
                      let sourceID = UUID(uuidString: idString) else { return false }
                return viewModel.moveSession(sourceID: sourceID, toGridIndex: gridIndex)
            }
        } else {
            Color.clear
        }
    }

    // MARK: - Resize Logic

    @State private var dragStartColumnProportions: [CGFloat]?
    @State private var dragStartRowProportion: CGFloat?

    private func normalizedProportion(index: Int, count: Int) -> CGFloat {
        guard index < viewModel.columnProportions.count else { return 1.0 / CGFloat(count) }
        let slice = Array(viewModel.columnProportions.prefix(count))
        let total = slice.reduce(0, +)
        guard total > 0 else { return 1.0 / CGFloat(count) }
        return slice[index] / total
    }

    private func beginColumnResize() {
        dragStartColumnProportions = viewModel.columnProportions
    }

    private func resizeColumns(draggingAfter index: Int, cumulativeOffset: CGFloat, totalWidth: CGFloat, count: Int) {
        guard let startProps = dragStartColumnProportions,
              index + 1 < count, totalWidth > 0 else { return }
        let proportionDelta = cumulativeOffset / totalWidth

        var props = startProps
        let newLeft = props[index] + proportionDelta
        let newRight = props[index + 1] - proportionDelta

        if newLeft >= Constants.minColumnProportion && newRight >= Constants.minColumnProportion {
            props[index] = newLeft
            props[index + 1] = newRight
            viewModel.columnProportions = props
        }
    }

    private func endColumnResize() {
        dragStartColumnProportions = nil
    }

    private func beginRowResize() {
        dragStartRowProportion = viewModel.rowProportion
    }

    private func resizeRows(cumulativeOffset: CGFloat, totalHeight: CGFloat) {
        guard let startProp = dragStartRowProportion, totalHeight > 0 else { return }
        let proportionDelta = cumulativeOffset / totalHeight

        let newTop = startProp + proportionDelta
        if newTop >= Constants.minRowProportion && newTop <= (1 - Constants.minRowProportion) {
            viewModel.rowProportion = newTop
        }
    }

    private func endRowResize() {
        dragStartRowProportion = nil
    }

    private func resetColumnProportions(count: Int) {
        let equal = 1.0 / CGFloat(count)
        var props = viewModel.columnProportions
        for i in 0..<count where i < props.count {
            props[i] = equal
        }
        viewModel.columnProportions = props
    }

    private func resetRowProportion() {
        viewModel.rowProportion = 0.5
    }

    // MARK: - Edge Add Button

    private var edgeAddButton: some View {
        HStack(spacing: 0) {
            if showEdgeButton {
                Button {
                    _ = viewModel.addSession()
                } label: {
                    ZStack {
                        Color.black.opacity(Constants.edgeButtonBgOpacity)
                        Image(systemName: Strings.Icons.plusCircleFill)
                            .font(.system(size: Constants.edgeButtonIconSize))
                            .foregroundStyle(.white)
                    }
                    .frame(width: Constants.edgeButtonWidth)
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .help(Strings.Terminals.addTerminal)
            }

            Color.clear
                .frame(width: Constants.edgeStripWidth)
        }
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: Constants.hoverAnimationDuration)) {
                showEdgeButton = hovering
            }
        }
    }

    private var sortedSessions: [TerminalSession] {
        viewModel.sessions.sorted { $0.gridIndex < $1.gridIndex }
    }
}

// MARK: - Draggable Divider Handles

struct VerticalDividerHandle: View {
    var onDragStart: () -> Void
    var onDragChanged: (CGFloat) -> Void
    var onDragEnded: () -> Void
    var onDoubleClick: (() -> Void)?

    private enum Constants {
        static let hoverOpacity: Double = 0.5
        static let normalOpacity: Double = 0.2
        static let minDragDistance: CGFloat = 1
        static let resetAnimationDuration: Double = 0.25
    }

    @State private var isHovered = false
    @State private var isDragging = false

    var body: some View {
        Rectangle()
            .fill(isHovered ? Color.accentColor.opacity(Constants.hoverOpacity) : Color.gray.opacity(Constants.normalOpacity))
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut(duration: Constants.resetAnimationDuration)) {
                    onDoubleClick?()
                }
            }
            .gesture(
                DragGesture(minimumDistance: Constants.minDragDistance)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onDragStart()
                        }
                        onDragChanged(value.translation.width)
                    }
                    .onEnded { _ in
                        isDragging = false
                        onDragEnded()
                    }
            )
    }
}

struct HorizontalDividerHandle: View {
    var onDragStart: () -> Void
    var onDragChanged: (CGFloat) -> Void
    var onDragEnded: () -> Void
    var onDoubleClick: (() -> Void)?

    private enum Constants {
        static let hoverOpacity: Double = 0.5
        static let normalOpacity: Double = 0.2
        static let minDragDistance: CGFloat = 1
        static let resetAnimationDuration: Double = 0.25
    }

    @State private var isHovered = false
    @State private var isDragging = false

    var body: some View {
        Rectangle()
            .fill(isHovered ? Color.accentColor.opacity(Constants.hoverOpacity) : Color.gray.opacity(Constants.normalOpacity))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut(duration: Constants.resetAnimationDuration)) {
                    onDoubleClick?()
                }
            }
            .gesture(
                DragGesture(minimumDistance: Constants.minDragDistance)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onDragStart()
                        }
                        onDragChanged(value.translation.height)
                    }
                    .onEnded { _ in
                        isDragging = false
                        onDragEnded()
                    }
            )
    }
}
