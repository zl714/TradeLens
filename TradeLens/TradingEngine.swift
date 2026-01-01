import Foundation
import SwiftUI

// MARK: - Models

struct Position: Identifiable, Codable {
    let id: UUID
    let symbol: String
    let quantity: Double
    let averagePrice: Double
    let side: TradeSide // "long" or "short"
    let openedAt: Date
    
    var currentValue: Double {
        return quantity * averagePrice
    }
    
    func unrealizedPL(currentPrice: Double) -> Double {
        switch side {
        case .long:
            return (currentPrice - averagePrice) * quantity
        case .short:
            return (averagePrice - currentPrice) * quantity
        }
    }
    
    func unrealizedPLPercent(currentPrice: Double) -> Double {
        let costBasis = averagePrice * quantity
        guard costBasis > 0 else { return 0 }
        return (unrealizedPL(currentPrice: currentPrice) / costBasis) * 100
    }
}

enum TradeSide: String, Codable {
    case long = "Buy"
    case short = "Sell"
}

struct Trade: Identifiable, Codable {
    let id: UUID
    let symbol: String
    let side: TradeSide
    let quantity: Double
    let price: Double
    let executedAt: Date
    let stopLoss: Double?
    let takeProfit: Double?
    let notes: String
    
    var totalValue: Double {
        return quantity * price
    }
}

struct PortfolioSnapshot: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let totalValue: Double
    let cash: Double
    let positionsValue: Double
}

// MARK: - Trading Engine

@MainActor
class TradingEngine: ObservableObject {
    @Published var cash: Double
    @Published var positions: [Position] = []
    @Published var tradeHistory: [Trade] = []
    @Published var portfolioHistory: [PortfolioSnapshot] = []
    
    private let initialCash: Double = 25000.0
    private let userDefaultsKey = "TradingEngineState"
    
    init() {
        self.cash = initialCash
        loadState()
        
        // Create initial snapshot if needed
        if portfolioHistory.isEmpty {
            addPortfolioSnapshot(totalValue: initialCash, cash: initialCash, positionsValue: 0)
        }
    }
    
    // MARK: - Execute Trade
    
    func executeTrade(
        symbol: String,
        side: TradeSide,
        quantity: Double,
        price: Double,
        stopLoss: Double? = nil,
        takeProfit: Double? = nil,
        notes: String = ""
    ) throws {
        let totalCost = quantity * price
        
        // Check if we have enough cash
        guard totalCost <= cash else {
            throw TradingError.insufficientFunds
        }
        
        // Deduct cash
        cash -= totalCost
        
        // Create trade record
        let trade = Trade(
            id: UUID(),
            symbol: symbol.uppercased(),
            side: side,
            quantity: quantity,
            price: price,
            executedAt: Date(),
            stopLoss: stopLoss,
            takeProfit: takeProfit,
            notes: notes
        )
        tradeHistory.insert(trade, at: 0)
        
        // Update or create position
        if let index = positions.firstIndex(where: { $0.symbol == symbol.uppercased() && $0.side == side }) {
            // Add to existing position (average down/up)
            let existingPosition = positions[index]
            let totalQuantity = existingPosition.quantity + quantity
            let totalCost = (existingPosition.averagePrice * existingPosition.quantity) + (price * quantity)
            let newAveragePrice = totalCost / totalQuantity
            
            positions[index] = Position(
                id: existingPosition.id,
                symbol: symbol.uppercased(),
                quantity: totalQuantity,
                averagePrice: newAveragePrice,
                side: side,
                openedAt: existingPosition.openedAt
            )
        } else {
            // Create new position
            let position = Position(
                id: UUID(),
                symbol: symbol.uppercased(),
                quantity: quantity,
                averagePrice: price,
                side: side,
                openedAt: Date()
            )
            positions.append(position)
        }
        
        saveState()
    }
    
    // MARK: - Close Position
    
    func closePosition(_ position: Position, currentPrice: Double) {
        // Calculate P&L
        let proceeds = position.quantity * currentPrice
        cash += proceeds
        
        // Record the closing trade
        let closingTrade = Trade(
            id: UUID(),
            symbol: position.symbol,
            side: position.side == .long ? .short : .long, // Opposite side to close
            quantity: position.quantity,
            price: currentPrice,
            executedAt: Date(),
            stopLoss: nil,
            takeProfit: nil,
            notes: "Position closed"
        )
        tradeHistory.insert(closingTrade, at: 0)
        
        // Remove position
        positions.removeAll { $0.id == position.id }
        
        saveState()
    }
    
    // MARK: - Portfolio Calculations
    
    func totalPortfolioValue(prices: [String: Double]) -> Double {
        let positionsValue = positions.reduce(0.0) { sum, position in
            let currentPrice = prices[position.symbol] ?? position.averagePrice
            return sum + (position.quantity * currentPrice)
        }
        return cash + positionsValue
    }
    
    func totalUnrealizedPL(prices: [String: Double]) -> Double {
        return positions.reduce(0.0) { sum, position in
            let currentPrice = prices[position.symbol] ?? position.averagePrice
            return sum + position.unrealizedPL(currentPrice: currentPrice)
        }
    }
    
    func totalReturn(prices: [String: Double]) -> Double {
        let currentValue = totalPortfolioValue(prices: prices)
        return currentValue - initialCash
    }
    
    func totalReturnPercent(prices: [String: Double]) -> Double {
        return (totalReturn(prices: prices) / initialCash) * 100
    }
    
    // MARK: - Portfolio History Tracking
    
    func updatePortfolioSnapshot(prices: [String: Double]) {
        let positionsValue = positions.reduce(0.0) { sum, position in
            let currentPrice = prices[position.symbol] ?? position.averagePrice
            return sum + (position.quantity * currentPrice)
        }
        let totalValue = cash + positionsValue
        
        addPortfolioSnapshot(totalValue: totalValue, cash: cash, positionsValue: positionsValue)
        saveState()
    }
    
    private func addPortfolioSnapshot(totalValue: Double, cash: Double, positionsValue: Double) {
        let snapshot = PortfolioSnapshot(
            id: UUID(),
            timestamp: Date(),
            totalValue: totalValue,
            cash: cash,
            positionsValue: positionsValue
        )
        portfolioHistory.append(snapshot)
        
        // Keep only last 365 snapshots (1 year of data)
        if portfolioHistory.count > 365 {
            portfolioHistory = Array(portfolioHistory.suffix(365))
        }
    }
    
    // MARK: - Reset Portfolio
    
    func resetPortfolio() {
        cash = initialCash
        positions = []
        tradeHistory = []
        portfolioHistory = []
        addPortfolioSnapshot(totalValue: initialCash, cash: initialCash, positionsValue: 0)
        saveState()
    }
    
    // MARK: - Persistence
    
    private func saveState() {
        let state = TradingEngineState(
            cash: cash,
            positions: positions,
            tradeHistory: tradeHistory,
            portfolioHistory: portfolioHistory
        )
        
        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    private func loadState() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let state = try? JSONDecoder().decode(TradingEngineState.self, from: data) else {
            return
        }
        
        cash = state.cash
        positions = state.positions
        tradeHistory = state.tradeHistory
        portfolioHistory = state.portfolioHistory
    }
}

// MARK: - State Model for Persistence

private struct TradingEngineState: Codable {
    let cash: Double
    let positions: [Position]
    let tradeHistory: [Trade]
    let portfolioHistory: [PortfolioSnapshot]
}

// MARK: - Errors

enum TradingError: LocalizedError {
    case insufficientFunds
    case invalidQuantity
    case positionNotFound
    
    var errorDescription: String? {
        switch self {
        case .insufficientFunds:
            return "Insufficient funds to execute this trade"
        case .invalidQuantity:
            return "Invalid quantity specified"
        case .positionNotFound:
            return "Position not found"
        }
    }
}
