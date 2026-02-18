import SwiftUI

@main
struct SportAppApp: App {
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appViewModel)
                .task {
                    await NotificationService.shared.requestAuthorization()
                    await appViewModel.bootstrap()
                }
        }
    }
}
