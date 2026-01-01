import SwiftUI
import Charts

struct TradeEntryView: View {
    @EnvironmentObject var tradingEngine: TradingEngine
    @EnvironmentObject var marketStore: MarketDataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var ticker: String = ""
    @State private var side: String = "Buy"
    @State private var quantity: String = ""
    @State private var entryPrice: String = ""
    @State private var stopLoss: String = ""
    @State private var takeProfit: String = ""
    @State private var notes: String = ""

    @State private var showingGrade: Bool = false
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isExecuting: Bool = false
    @State private var isLoadingSymbol: Bool = false
    @State private var grade: TradeGrade = .example
    
    private let aiGradingService = AIGradingService(apiKey: Secrets.claudeAPIKey)
    private let sides = ["Buy", "Sell"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                
                // SYMBOL LOOKUP CARD
                TLCard {
                    VStack(alignment: .leading, spacing: 12) {
                        TLSectionHeader(title: "Stock symbol")

                        HStack(spacing: 12) {
                            TextField("AAPL", text: $ticker)
                                .textFieldStyle(.plain)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled(true)
                                .font(.title3.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                                )
                            
                            Button {
                                loadSymbolData()
                            } label: {
                                if isLoadingSymbol {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .frame(width: 50, height: 44)
                                } else {
                                    Text("Load")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(width: 70)
                                        .padding(.vertical, 10)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                            .disabled(cleanedTicker.isEmpty || isLoadingSymbol)
                            .opacity(cleanedTicker.isEmpty ? 0.5 : 1)
                        }
                    }
                }
                
                // LIVE PRICE & CHART (only show if symbol is loaded)
                if let currentPrice = currentMarketPrice, !marketStore.series(for: cleanedTicker).isEmpty {
                    TLCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(cleanedTicker)
                                        .font(.title2.weight(.bold))
                                    
                                    Text(currentPrice.formatted(.currency(code: "USD")))
                                        .font(.title3.weight(.semibold))
                                        .monospacedDigit()
                                        .foregroundColor(.blue)
                                }
                                
                                Spacer()
                                
                                // Auto-fill button
                                Button {
                                    entryPrice = String(format: "%.2f", currentPrice)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.down.circle.fill")
                                        Text("Use price")
                                    }
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundColor(.blue)
                                    .clipShape(Capsule())
                                }
                            }
                            
                            // Mini chart
                            let priceData = marketStore.series(for: cleanedTicker)
                            if !priceData.isEmpty {
                                Chart(priceData) { point in
                                    LineMark(
                                        x: .value("Time", point.time),
                                        y: .value("Price", point.price)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(.blue)
                                }
                                .chartYAxis(.hidden)
                                .chartXAxis(.hidden)
                                .frame(height: 100)
                                .padding(.top, 4)
                            }
                            
                            // Price levels
                            if !priceData.isEmpty {
                                let prices = priceData.map { $0.price }
                                let high = prices.max() ?? currentPrice
                                let low = prices.min() ?? currentPrice
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("High")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(high.formatted(.currency(code: "USD")))
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(.green)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("Low")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(low.formatted(.currency(code: "USD")))
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }

                // TRADE SETUP
                TLCard {
                    VStack(alignment: .leading, spacing: 12) {
                        TLSectionHeader(title: "Trade setup")
                        
                        // Side picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Side")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Picker("Side", selection: $side) {
                                ForEach(sides, id: \.self) { value in
                                    Text(value).tag(value)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        HStack(spacing: 12) {
                            TLField(title: "Quantity", placeholder: "10", text: $quantity)
                                .keyboardType(.numberPad)

                            TLField(title: "Entry price", placeholder: "185.30", text: $entryPrice)
                                .keyboardType(.decimalPad)
                        }
                    }
                }

                // RISK MANAGEMENT
                TLCard {
                    VStack(alignment: .leading, spacing: 12) {
                        TLSectionHeader(
                            title: "Risk management",
                            subtitle: "Recommended: 1-2% account risk"
                        )

                        HStack(spacing: 12) {
                            TLField(title: "Stop loss", placeholder: "180.00", text: $stopLoss)
                                .keyboardType(.decimalPad)

                            TLField(title: "Take profit", placeholder: "200.00", text: $takeProfit)
                                .keyboardType(.decimalPad)
                        }
                        
                        // Risk calculator
                        if let qty = qtyValue, let entry = entryValue, qty > 0, entry > 0 {
                            VStack(spacing: 8) {
                                Divider().opacity(0.6)
                                
                                if let sl = Double(stopLoss.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                    let riskPerShare = abs(entry - sl)
                                    let totalRisk = riskPerShare * qty
                                    let riskPercent = (totalRisk / tradingEngine.cash) * 100
                                    
                                    HStack {
                                        Text("Risk:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(totalRisk.formatted(.currency(code: "USD"))) (\(String(format: "%.2f%%", riskPercent)))")
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(riskPercent <= 2 ? .green : .orange)
                                    }
                                }
                                
                                if let sl = Double(stopLoss.trimmingCharacters(in: .whitespacesAndNewlines)),
                                   let tp = Double(takeProfit.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                    let risk = abs(entry - sl)
                                    let reward = abs(tp - entry)
                                    let rrRatio = risk > 0 ? reward / risk : 0
                                    
                                    HStack {
                                        Text("Risk/Reward:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("1:\(String(format: "%.2f", rrRatio))")
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(rrRatio >= 2 ? .green : .orange)
                                    }
                                }
                            }
                        }
                    }
                }

                // TRADE NOTES
                TLCard {
                    VStack(alignment: .leading, spacing: 10) {
                        TLSectionHeader(
                            title: "Trade thesis",
                            subtitle: "Why are you entering this trade?"
                        )

                        TextEditor(text: $notes)
                            .frame(minHeight: 110)
                            .padding(10)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                            )
                    }
                }

                // TRADE SUMMARY
                TLCard {
                    VStack(alignment: .leading, spacing: 10) {
                        TLSectionHeader(title: "Trade summary")

                        VStack(spacing: 8) {
                            HStack {
                                Text("Position cost")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(estimatedPositionText)
                                    .font(.subheadline.weight(.semibold))
                            }
                            
                            HStack {
                                Text("Available cash")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(tradingEngine.cash.formatted(.currency(code: "USD")))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(hasEnoughCash ? .primary : .red)
                            }
                            
                            if let qty = qtyValue, let entry = entryValue, qty > 0, entry > 0 {
                                let positionSize = qty * entry
                                let positionPercent = (positionSize / tradingEngine.cash) * 100
                                
                                HStack {
                                    Text("Position size")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(String(format: "%.1f%%", positionPercent)) of account")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(positionPercent <= 10 ? .green : .orange)
                                }
                            }
                        }
                    }
                }

                // EXECUTE BUTTON
                VStack(spacing: 8) {
                    Button {
                        submitTrade()
                    } label: {
                        if isExecuting {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                Text("Analyzing trade...")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        } else {
                            Text("Execute trade")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.primary)
                                .foregroundColor(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 16)
                    .disabled(!canSubmit || isExecuting)
                    .opacity(canSubmit && !isExecuting ? 1 : 0.5)

                    if !canSubmit {
                        Text("Load a symbol and fill quantity + entry price")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if !hasEnoughCash {
                        Text("⚠️ Insufficient funds for this trade")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.top, 2)

                Spacer(minLength: 10)
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .navigationTitle("New trade")
        .sheet(isPresented: $showingGrade) {
            NavigationStack {
                TradeConfirmationView(grade: grade)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showingGrade = false
                                dismiss()
                            }
                        }
                    }
            }
        }
        .alert("Trade Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Data Loading
    
    private func loadSymbolData() {
        let symbol = cleanedTicker
        guard !symbol.isEmpty else { return }
        
        isLoadingSymbol = true
        
        Task {
            await marketStore.loadDetail(symbol: symbol)
            
            // Auto-fill entry price with current price
            if let price = marketStore.lastPrice(for: symbol) {
                entryPrice = String(format: "%.2f", price)
            }
            
            isLoadingSymbol = false
        }
    }

    // MARK: - Validation and preview
    
    private var currentMarketPrice: Double? {
        let symbol = cleanedTicker
        return symbol.isEmpty ? nil : marketStore.lastPrice(for: symbol)
    }

    private var canSubmit: Bool {
        !cleanedTicker.isEmpty &&
        !(quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) &&
        !(entryPrice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) &&
        currentMarketPrice != nil // Must have loaded the symbol
    }
    
    private var hasEnoughCash: Bool {
        guard let qty = qtyValue, let entry = entryValue else { return true }
        let totalCost = qty * entry
        return totalCost <= tradingEngine.cash
    }

    private var cleanedTicker: String {
        ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var qtyValue: Double? {
        Double(quantity.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var entryValue: Double? {
        Double(entryPrice.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var estimatedPositionText: String {
        guard let q = qtyValue, let e = entryValue else { return "—" }
        return (q * e).formatted(.currency(code: "USD"))
    }

    // MARK: - Execute Trade

    private func submitTrade() {
        guard let qty = qtyValue, let entry = entryValue else { return }
        
        isExecuting = true
        
        Task {
            do {
                // Execute the trade
                let tradeSide: TradeSide = side == "Buy" ? .long : .short
                let stopLossValue = Double(stopLoss.trimmingCharacters(in: .whitespacesAndNewlines))
                let takeProfitValue = Double(takeProfit.trimmingCharacters(in: .whitespacesAndNewlines))
                
                try tradingEngine.executeTrade(
                    symbol: cleanedTicker,
                    side: tradeSide,
                    quantity: qty,
                    price: entry,
                    stopLoss: stopLossValue,
                    takeProfit: takeProfitValue,
                    notes: notes
                )
                
                // Get current price and price history for AI grading
                let currentPrice = marketStore.lastPrice(for: cleanedTicker) ?? entry
                let priceHistory = marketStore.series(for: cleanedTicker).map {
                    (date: $0.time, price: $0.price)
                }
                
                // Generate AI grade using Claude
                print("🤖 Requesting AI grade from Claude...")
                grade = try await aiGradingService.gradeTrade(
                    symbol: cleanedTicker,
                    side: side,
                    quantity: qty,
                    entryPrice: entry,
                    currentPrice: currentPrice,
                    stopLoss: stopLossValue,
                    takeProfit: takeProfitValue,
                    notes: notes,
                    priceHistory: priceHistory
                )
                print("✅ AI grade received: \(grade.overallScore)/10")
                
                // Update portfolio snapshot
                tradingEngine.updatePortfolioSnapshot(prices: marketStore.lastPriceBySymbol)
                
                isExecuting = false
                showingGrade = true
                
            } catch {
                isExecuting = false
                errorMessage = error.localizedDescription
                showingError = true
                print("❌ Trade execution error: \(error)")
            }
        }
    }
}

// MARK: - Trade Confirmation View

private struct TradeConfirmationView: View {
    let grade: TradeGrade
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                
                TLCard {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Trade Executed!")
                            .font(.title2.weight(.bold))
                        
                        Text("Your paper trade has been recorded")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }

                TLCard {
                    VStack(alignment: .leading, spacing: 10) {
                        TLSectionHeader(title: "AI Grade", subtitle: "Powered by Claude")

                        HStack(alignment: .firstTextBaseline) {
                            Text(String(format: "%.1f", grade.overallScore))
                                .font(.system(size: 48, weight: .bold, design: .rounded))

                            Spacer()

                            ScorePill(score: grade.overallScore)
                        }
                    }
                }

                TLCard {
                    VStack(alignment: .leading, spacing: 10) {
                        TLSectionHeader(title: "Breakdown")

                        BreakdownRow(label: "Risk management", score: grade.riskScore)
                        Divider().opacity(0.6)
                        BreakdownRow(label: "Timing and price", score: grade.timingScore)
                        Divider().opacity(0.6)
                        BreakdownRow(label: "Thesis quality", score: grade.thesisScore)
                    }
                }

                TLCard {
                    VStack(alignment: .leading, spacing: 10) {
                        TLSectionHeader(title: "AI Feedback")
                        Text(grade.comments)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer(minLength: 10)
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Trade Confirmation")
        .navigationBarTitleDisplayMode(.inline)
    }
}

//
// MARK: - Local UI helpers
//

private struct TLCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

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

private struct TLField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                )
        }
    }
}

private struct BreakdownRow: View {
    let label: String
    let score: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)

                Spacer()

                Text(String(format: "%.1f", score))
                    .font(.subheadline.weight(.semibold))
            }

            ScoreBar(score: score)
        }
    }
}

private struct ScoreBar: View {
    let score: Double

    var body: some View {
        GeometryReader { geo in
            let ratio = max(0, min(1, score / 10.0))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.18))
                    .frame(height: 6)

                Capsule()
                    .fill(Color.primary.opacity(0.55))
                    .frame(width: geo.size.width * ratio, height: 6)
            }
        }
        .frame(height: 10)
    }
}

private struct ScorePill: View {
    let score: Double

    private var label: String {
        switch score {
        case 9...10: return "Elite"
        case 7.5..<9: return "Strong"
        case 6..<7.5: return "Average"
        default: return "Needs work"
        }
    }

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.10))
            .clipShape(Capsule())
    }
}
