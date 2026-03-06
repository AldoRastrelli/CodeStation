import SwiftUI

struct ContentView: View {
    private enum Constants {
        static let sidebarMinWidth: CGFloat = 160
        static let sidebarIdealWidth: CGFloat = 200
        static let sidebarMaxWidth: CGFloat = 300
        static let minWindowWidth: CGFloat = 800
        static let minWindowHeight: CGFloat = 500
        static let emptyStateSpacing: CGFloat = 12
        static let emptyIconSize: CGFloat = 40
        static let emptyTextSize: CGFloat = 15
    }

    @Bindable var viewModel: AppViewModel
    @State private var showCloseTerminalConfirmation = false
    @State private var dontShowAgain = false

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: Constants.sidebarMinWidth, ideal: Constants.sidebarIdealWidth, max: Constants.sidebarMaxWidth)
        } detail: {
            if viewModel.environments.isEmpty {
                VStack(spacing: Constants.emptyStateSpacing) {
                    Image(systemName: Strings.Icons.grid)
                        .font(.system(size: Constants.emptyIconSize))
                        .foregroundStyle(.secondary)
                    Text(Strings.Environments.noEnvironments)
                        .font(.system(size: Constants.emptyTextSize))
                        .foregroundStyle(.secondary)
                    Button(Strings.Environments.createEnvironment) {
                        viewModel.addEnvironment()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.selectedEnvironment == nil {
                VStack(spacing: Constants.emptyStateSpacing) {
                    Text(Strings.Environments.selectEnvironment)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack {
                    ForEach(viewModel.environments) { env in
                        let boardVM = viewModel.boardViewModel(for: env)
                        BoardView(viewModel: boardVM, environmentName: env.name, onRename: { newName in
                            viewModel.renameEnvironment(env, to: newName)
                        })
                        .opacity(env.id == viewModel.selectedEnvironmentID ? 1 : 0)
                        .allowsHitTesting(env.id == viewModel.selectedEnvironmentID)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    SettingsWindowController.show(viewModel: viewModel)
                } label: {
                    Image(systemName: Strings.Icons.gear)
                }
            }
        }
        .frame(minWidth: Constants.minWindowWidth, minHeight: Constants.minWindowHeight)
        .onChange(of: showCloseTerminalConfirmation) { _, isOpen in
            viewModel.isModalOpen = isOpen
        }
        .sheet(isPresented: $showCloseTerminalConfirmation) {
            VStack(spacing: 16) {
                Text(Strings.Terminals.closeTerminalTitle)
                    .font(.headline)

                Text(Strings.Terminals.closeConfirmation(viewModel.focusedTerminalTitle ?? ""))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Toggle(Strings.Terminals.dontShowAgain, isOn: $dontShowAgain)
                    .toggleStyle(.checkbox)

                HStack {
                    Button(Strings.Terminals.cancel) {
                        showCloseTerminalConfirmation = false
                    }
                    .keyboardShortcut(.cancelAction)

                    Button(Strings.Terminals.close) {
                        if dontShowAgain {
                            viewModel.skipCloseConfirmation = true
                            viewModel.scheduleSave()
                        }
                        showCloseTerminalConfirmation = false
                        viewModel.closeFocusedTerminal()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding(24)
            .frame(width: 340)
        }
        .onChange(of: viewModel.closeTerminalRequested) { _, requested in
            if requested {
                viewModel.closeTerminalRequested = false
                if viewModel.focusedTerminalTitle != nil {
                    if viewModel.skipCloseConfirmation {
                        viewModel.closeFocusedTerminal()
                    } else {
                        showCloseTerminalConfirmation = true
                    }
                }
            }
        }
        .onAppear {
            try? HookManager.install()
        }
    }
}
