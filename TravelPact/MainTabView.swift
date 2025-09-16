import SwiftUI

// Tab selection manager
class TabSelectionManager: ObservableObject {
    static let shared = TabSelectionManager()
    @Published var selectedTab = 0
}

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var tabSelection = TabSelectionManager.shared

    var body: some View {
        // Globe View is now the only view, no tab bar needed
        GlobeView()
            .environmentObject(authManager)
            .preferredColorScheme(.dark)
    }
}
