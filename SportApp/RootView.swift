import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        Group {
            if appViewModel.isBootstrapping {
                StartupLoadingView()
            } else if appViewModel.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
    }
}

private struct StartupLoadingView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.95), Color.indigo.opacity(0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "figure.soccer")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.white)

                Text("SportApp")
                    .font(.title.bold())
                    .foregroundStyle(.white)

                ProgressView()
                    .tint(.white)
            }
            .padding()
        }
    }
}
