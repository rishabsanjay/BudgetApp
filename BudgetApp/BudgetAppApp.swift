import SwiftUI

@main
struct BudgetAppApp: App {
    @StateObject private var authManager = AuthManager()
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                HomeView()
                    .environmentObject(authManager)
            } else {
                AuthView()
                    .environmentObject(authManager)
            }
        }
    }
}