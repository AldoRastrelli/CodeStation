import SwiftUI

struct SidebarView: View {
    private enum Constants {
        static let buttonPadding: CGFloat = 8
        static let logoSize: CGFloat = 32
        static let nameHeight: CGFloat = 16
        static let headerSpacing: CGFloat = 8
        static let headerPadding: CGFloat = 12
    }

    @Bindable var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // App branding header
            HStack(spacing: Constants.headerSpacing) {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: Constants.logoSize)

                Image("AppName")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: Constants.nameHeight)

                Spacer()
            }
            .padding(.horizontal, Constants.headerPadding)
            .padding(.vertical, Constants.headerPadding)

            Divider()

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
        }
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
