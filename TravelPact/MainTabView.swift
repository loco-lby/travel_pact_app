import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        GlobeView()
            .environmentObject(authManager)
    }
}