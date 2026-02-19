import SwiftUI
import UIKit

@main
struct SportAppApp: App {
    @StateObject private var appViewModel = AppViewModel()

    init() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(AppTheme.backgroundTop)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(AppTheme.accent)

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundColor = UIColor(AppTheme.backgroundTop.opacity(0.95))
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appViewModel)
                .tint(AppTheme.accent)
                .preferredColorScheme(.dark)
                .task {
                    await NotificationService.shared.requestAuthorization()
                    await appViewModel.bootstrap()
                }
        }
    }
}
