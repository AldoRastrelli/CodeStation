import SwiftUI

struct SidebarView: View {
    private enum Constants {
        static let buttonPadding: CGFloat = 8
    }

    @Bindable var viewModel: AppViewModel
    @State private var isShowingNewEnvironmentAlert = false
    @State private var newEnvironmentName = ""

    var body: some View {
        List(selection: $viewModel.selectedEnvironmentID) {
            ForEach(viewModel.sortedEnvironments) { env in
                SidebarRowView(environment: env, viewModel: viewModel)
                    .tag(env.id)
            }
            .onMove { source, destination in
                viewModel.moveEnvironment(from: source, to: destination)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    newEnvironmentName = ""
                    isShowingNewEnvironmentAlert = true
                } label: {
                    Label(Strings.Environments.newEnvironment, systemImage: Strings.Icons.plus)
                }
                .buttonStyle(.borderless)
                .padding(Constants.buttonPadding)

                Spacer()
            }
        }
        .alert(Strings.Environments.newEnvironment, isPresented: $isShowingNewEnvironmentAlert) {
            TextField(Strings.Environments.environmentNamePlaceholder, text: $newEnvironmentName)
            Button(Strings.Environments.create) {
                let name = newEnvironmentName.trimmingCharacters(in: .whitespaces)
                viewModel.addEnvironment(name: name.isEmpty ? nil : name)
            }
            Button(Strings.Terminals.cancel, role: .cancel) {}
        }
    }
}
