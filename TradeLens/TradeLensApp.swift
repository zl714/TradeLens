// TradeLensApp.swift

import SwiftUI

@main
struct TradeLensApp: App {
    @StateObject private var session = UserSession()
    @StateObject private var marketStore = MarketDataStore(
        service: FinnhubMarketService(apiKey: Secrets.finnhubAPIKey),
        chartService: AlphaVantageService(apiKey: Secrets.alphaVantageAPIKey)
    )
    @StateObject private var tradingEngine = TradingEngine() // ADD THIS LINE

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(marketStore)
                .environmentObject(tradingEngine) // ADD THIS LINE
                .tint(.blue)
        }
    }
}

// Simple user session to switch between login and main app

final class UserSession: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var email: String? = nil

    func signIn(email: String) {
        self.email = email
        self.isAuthenticated = true
    }

    func signOut() {
        self.email = nil
        self.isAuthenticated = false
    }
}

struct RootView: View {
    @EnvironmentObject var session: UserSession

    var body: some View {
        Group {
            if session.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}
