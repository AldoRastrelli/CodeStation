import SwiftUI

struct SidebarView: View {
    private enum Constants {
        static let buttonPadding: CGFloat = 8
    }

    @Bindable var viewModel: AppViewModel

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
                    viewModel.addEnvironment()
                } label: {
                    Label(Strings.Environments.newEnvironment, systemImage: Strings.Icons.plus)
                }
                .buttonStyle(.borderless)
                .padding(Constants.buttonPadding)

                Spacer()
            }
        }
    }
}
