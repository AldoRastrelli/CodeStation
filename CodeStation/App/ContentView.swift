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
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: Constants.sidebarMinWidth, ideal: Constants.sidebarIdealWidth, max: Constants.sidebarMaxWidth)
        } detail: {
            if let env = viewModel.selectedEnvironment {
                let boardVM = viewModel.boardViewModel(for: env)
                BoardView(viewModel: boardVM, environmentName: env.name, onRename: { newName in
                    viewModel.renameEnvironment(env, to: newName)
                })
                .id(env.id)
            } else {
                VStack(spacing: Constants.emptyStateSpacing) {
                    if viewModel.environments.isEmpty {
                        Image(systemName: Strings.Icons.grid)
                            .font(.system(size: Constants.emptyIconSize))
                            .foregroundStyle(.secondary)
                        Text(Strings.Environments.noEnvironments)
                            .font(.system(size: Constants.emptyTextSize))
                            .foregroundStyle(.secondary)
                        Button(Strings.Environments.createEnvironment) {
                            viewModel.addEnvironment()
                        }
                    } else {
                        Text(Strings.Environments.selectEnvironment)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: Strings.Icons.gear)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsWindowView(viewModel: viewModel)
                .frame(minWidth: 580, minHeight: 400)
        }
        .frame(minWidth: Constants.minWindowWidth, minHeight: Constants.minWindowHeight)
        .onAppear {
            try? HookManager.install()
        }
    }
}
