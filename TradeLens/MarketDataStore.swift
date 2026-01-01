import Foundation
import SwiftUI

struct PortfolioSummary {
    let balanceText: String
    let todayText: String
    let totalReturnText: String
    let isTodayPositive: Bool
}

struct MarketSummaryViewModel {
    let indexName: String
    let valueText: String
    let changeText: String
    let isPositive: Bool

    init(from overview: MarketOverview) {
        indexName = overview.indexName
        valueText = String(format: "%.2f", overview.value)
        changeText = String(format: "%+.2f%%", overview.changePercent)
        isPositive = overview.changePercent >= 0
    }
}

struct StockMoveViewModel: Identifiable, Hashable {
    var id: String { symbol } // stable
    let symbol: String
    let changeText: String
    let isPositive: Bool
    let changePercent: Double

    init(from move: SymbolMove) {
        symbol = move.symbol.uppercased()
        changePercent = move.changePercent
        changeText = String(format: "%+.2f%%", move.changePercent)
        isPositive = move.changePercent >= 0
    }
}

@MainActor
final class MarketDataStore: ObservableObject {
    @Published var marketSummary: MarketSummaryViewModel?
    @Published var topGainers: [StockMoveViewModel] = []
    @Published var topLosers: [StockMoveViewModel] = []
    @Published var portfolio: PortfolioSummary?
    
    // Price cache
    @Published private(set) var lastPriceBySymbol: [String: Double] = [:]
    
    // Price action series (candles -> points)
    struct PricePoint: Identifiable, Equatable {
        let id = UUID()
        let time: Date
        let price: Double
    }
    @Published private(set) var seriesBySymbol: [String: [PricePoint]] = [:]
    
    private let service: MarketDataService
    private let chartService: AlphaVantageService
    private var hasLoadedOnce = false
    
    init(service: MarketDataService, chartService: AlphaVantageService) {
        self.service = service
        self.chartService = chartService
    }
    
    func refreshIfNeeded() async {
        if hasLoadedOnce { return }
        await refresh()
    }
    
    func refresh() async {
        do {
            async let overviewTask = service.fetchMarketOverview()
            async let gainersTask = service.fetchTopGainers()
            async let losersTask = service.fetchTopLosers()
            
            let overview = try await overviewTask
            let gainers = try await gainersTask
            let losers = try await losersTask
            
            marketSummary = MarketSummaryViewModel(from: overview)
            topGainers = gainers.map { StockMoveViewModel(from: $0) }
            topLosers = losers.map { StockMoveViewModel(from: $0) }
            
            // Pre-cache prices for symbols we are showing
            let symbols = Set((gainers + losers).map { $0.symbol.uppercased() })
            for sym in symbols {
                let price = try await service.fetchQuotePrice(symbol: sym)
                lastPriceBySymbol[sym] = price
            }
            
            if portfolio == nil {
                portfolio = PortfolioSummary(
                    balanceText: "$25,000.00",
                    todayText: "+$0.00 (0.00%)",
                    totalReturnText: "+$0.00 (0.00%)",
                    isTodayPositive: true
                )
            }
            
            hasLoadedOnce = true
        } catch {
            print("Error refreshing market data: \(error)")
        }
    }
    
    func combinedMovers(limitEach: Int) -> [StockMoveViewModel] {
        Array(topGainers.prefix(limitEach)) + Array(topLosers.prefix(limitEach))
    }
    
    func lastPrice(for symbol: String) -> Double? {
        lastPriceBySymbol[symbol.uppercased()]
    }
    
    
    func series(for symbol: String) -> [PricePoint] {
        seriesBySymbol[symbol.uppercased()] ?? []
    }
    
    /// Loads price + candles for the selected stock's detail page - NOW USING ALPHA VANTAGE DAILY DATA
    func loadDetail(symbol: String) async {
        let key = symbol.uppercased()
        do {
            // Latest price from Finnhub
            let price = try await service.fetchQuotePrice(symbol: key)
            lastPriceBySymbol[key] = price
            
            print("📊 Fetching chart data for \(key) from Alpha Vantage (daily)...")
            
            // Price action candles from Alpha Vantage (DAILY - free tier)
            let (t, c) = try await chartService.fetchDailyCandles(symbol: key)
            
            print("📊 Received \(t.count) data points for \(key)")
            
            if t.isEmpty {
                print("⚠️ No chart data received for \(key)")
                seriesBySymbol[key] = []
                return
            }
            
            let points: [PricePoint] = zip(t, c).map { (tt, close) in
                PricePoint(time: Date(timeIntervalSince1970: TimeInterval(tt)), price: close)
            }
            seriesBySymbol[key] = points
            print("✅ Chart data loaded successfully for \(key) - showing last \(points.count) days")
        } catch {
            print("❌ Error loading detail for \(key): \(error.localizedDescription)")
            seriesBySymbol[key] = []
        }
    }
}
