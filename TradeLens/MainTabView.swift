import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeDashboardView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            NavigationStack {
                HeavyHittersView()
            }
            .tabItem {
                Label("Heavy Hitters", systemImage: "bolt.fill")
            }

            NavigationStack {
                TradeGradingView()
            }
            .tabItem {
                Label("My Trades", systemImage: "list.bullet")
            }
        }
    }
}
