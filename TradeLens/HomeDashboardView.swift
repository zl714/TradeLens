import SwiftUI
import Charts

struct HomeDashboardView: View {
    @EnvironmentObject var marketStore: MarketDataStore
    @EnvironmentObject var tradingEngine: TradingEngine
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                // Portfolio with CHART
                TLCardRow {
                    VStack(alignment: .leading, spacing: 10) {
                        TLSectionHeader(title: "Portfolio")

                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(portfolioBalanceText)
                                    .font(.title2.weight(.semibold))

                                Text(portfolioTodayText)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(portfolioIsPositive ? .green : .red)

                                Text(portfolioTotalReturnText)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        
                        // PORTFOLIO CHART
                        if !tradingEngine.portfolioHistory.isEmpty {
                            PortfolioChart(history: tradingEngine.portfolioHistory)
                                .frame(height: 120)
                                .padding(.top, 6)
                        }
                    }
                }

                // Top movers
                let movers = marketStore.combinedMovers(limitEach: 3)
                if !movers.isEmpty {
                    TLCardRow {
                        VStack(alignment: .leading, spacing: 10) {
                            TLSectionHeader(title: "Top movers", subtitle: "Based on real-time stocks")

                            VStack(spacing: 10) {
                                ForEach(movers, id: \.symbol) { move in
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        path.append(move.symbol.uppercased())
                                    } label: {
                                        MoverRow(
                                            symbol: move.symbol,
                                            priceText: marketStore.lastPrice(for: move.symbol).map {
                                                $0.formatted(.currency(code: "USD"))
                                            } ?? "—",
                                            changeText: move.changeText,
                                            isPositive: move.isPositive,
                                            showsChevron: true
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    if move.symbol != movers.last?.symbol {
                                        Divider().opacity(0.6)
                                    }
                                }
                            }
                        }
                    }
                }

                // Market snapshot
                if let market = marketStore.marketSummary {
                    TLCardRow {
                        VStack(alignment: .leading, spacing: 10) {
                            TLSectionHeader(title: "Market snapshot")

                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(market.indexName)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    Text(market.valueText)
                                        .font(.title3.weight(.semibold))

                                    Text(market.changeText)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(market.isPositive ? .green : .red)
                                }

                                Spacer()

                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.title3)
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                        }
                    }
                }

                // CTA
                TLCardRow {
                    NavigationLink {
                        TradeEntryView()
                    } label: {
                        Text("Start new paper trade")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.primary)
                            .foregroundColor(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("TradeLens")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { ProfileView() } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .task {
                await marketStore.refreshIfNeeded()
                updatePortfolioSnapshot()
            }
            .refreshable {
                await marketStore.refresh()
                updatePortfolioSnapshot()
            }
            .navigationDestination(for: String.self) { symbol in
                StockDetailView(symbol: symbol)
                    .id(symbol)
            }
        }
    }
    
    // MARK: - Portfolio Calculations
    
    private var portfolioBalanceText: String {
        let totalValue = tradingEngine.totalPortfolioValue(prices: marketStore.lastPriceBySymbol)
        return totalValue.formatted(.currency(code: "USD"))
    }
    
    private var portfolioTodayText: String {
        // Calculate today's change (simplified - compare to yesterday's snapshot)
        if tradingEngine.portfolioHistory.count >= 2 {
            let current = tradingEngine.totalPortfolioValue(prices: marketStore.lastPriceBySymbol)
            let previous = tradingEngine.portfolioHistory[tradingEngine.portfolioHistory.count - 2].totalValue
            let change = current - previous
            let changePercent = (change / previous) * 100
            return String(format: "%+.2f (%+.2f%%)", change, changePercent)
        }
        return "+$0.00 (0.00%)"
    }
    
    private var portfolioIsPositive: Bool {
        tradingEngine.totalReturn(prices: marketStore.lastPriceBySymbol) >= 0
    }
    
    private var portfolioTotalReturnText: String {
        let totalReturn = tradingEngine.totalReturn(prices: marketStore.lastPriceBySymbol)
        let totalReturnPercent = tradingEngine.totalReturnPercent(prices: marketStore.lastPriceBySymbol)
        return String(format: "Total return %+.2f (%+.2f%%)", totalReturn, totalReturnPercent)
    }
    
    private func updatePortfolioSnapshot() {
        tradingEngine.updatePortfolioSnapshot(prices: marketStore.lastPriceBySymbol)
    }
}

// MARK: - Stock Detail View

private struct StockDetailView: View {
    @EnvironmentObject var marketStore: MarketDataStore
    let symbol: String

    private var key: String { symbol.uppercased() }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {

                TLCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(key)
                            .font(.largeTitle.weight(.semibold))

                        HStack(alignment: .firstTextBaseline) {
                            Text(priceText)
                                .font(.title2.weight(.semibold))
                                .monospacedDigit()

                            Spacer()
                        }

                        PriceActionChart(points: marketStore.series(for: key))
                            .frame(height: 260)
                            .padding(.top, 6)
                    }
                }

                TLCard {
                    VStack(alignment: .leading, spacing: 10) {
                        TLSectionHeader(title: "Quick actions")

                        NavigationLink {
                            TradeEntryView()
                        } label: {
                            HStack {
                                Text("Start a paper trade on \(key)")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 10)
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .navigationTitle(key)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await marketStore.loadDetail(symbol: key)
        }
    }

    private var priceText: String {
        if let p = marketStore.lastPrice(for: key) {
            return p.formatted(.currency(code: "USD"))
        }
        return "Loading…"
    }
}

// MARK: - Portfolio Chart Component

private struct PortfolioChart: View {
    let history: [PortfolioSnapshot]
    
    var body: some View {
        let sortedHistory = history.sorted { $0.timestamp < $1.timestamp }
        
        Chart(sortedHistory) { snapshot in
            LineMark(
                x: .value("Time", snapshot.timestamp),
                y: .value("Value", snapshot.totalValue)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(chartColor)
            
            AreaMark(
                x: .value("Time", snapshot.timestamp),
                y: .value("Value", snapshot.totalValue)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [chartColor.opacity(0.3), chartColor.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .chartYAxis(.hidden)
        .chartXAxis(.hidden)
    }
    
    private var chartColor: Color {
        guard let first = history.first, let last = history.last else {
            return .blue
        }
        return last.totalValue >= first.totalValue ? .green : .red
    }
}

// MARK: - Price Action Chart

private struct PriceActionChart: View {
    let points: [MarketDataStore.PricePoint]

    var body: some View {
        if points.isEmpty {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.05))
                .overlay(
                    Text("Loading price action…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                )
        } else {
            Chart(points) { p in
                LineMark(
                    x: .value("Time", p.time),
                    y: .value("Price", p.price)
                )
                .interpolationMethod(.catmullRom)
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        }
    }
}

//
// MARK: - UI Pieces
//

private struct TLCardRow<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(Color.clear)
    }
}

private struct TLCard<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 16)
    }
}

private struct TLSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct MoverRow: View {
    let symbol: String
    let priceText: String
    let changeText: String
    let isPositive: Bool
    var showsChevron: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(symbol.uppercased())
                    .font(.subheadline.weight(.semibold))
                Text(priceText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            Text(changeText)
                .font(.subheadline.weight(.medium))
                .foregroundColor(isPositive ? .green : .red)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .contentShape(Rectangle())
    }
}

private struct MiniChartPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.primary.opacity(0.06))
            .frame(width: 140, height: 72)
            .overlay(
                Image(systemName: "waveform.path.ecg")
                    .font(.title3)
                    .foregroundColor(.secondary.opacity(0.7))
            )
    }
}
