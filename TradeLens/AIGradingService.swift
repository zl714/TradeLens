import Foundation

// MARK: - AI Grading Service

final class AIGradingService {
    private let apiKey: String
    private let session: URLSession
    
    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }
    
    // MARK: - Grade Trade
    
    func gradeTrade(
        symbol: String,
        side: String,
        quantity: Double,
        entryPrice: Double,
        currentPrice: Double,
        stopLoss: Double?,
        takeProfit: Double?,
        notes: String,
        priceHistory: [(date: Date, price: Double)]
    ) async throws -> TradeGrade {
        
        // Build the prompt for Claude
        let prompt = buildGradingPrompt(
            symbol: symbol,
            side: side,
            quantity: quantity,
            entryPrice: entryPrice,
            currentPrice: currentPrice,
            stopLoss: stopLoss,
            takeProfit: takeProfit,
            notes: notes,
            priceHistory: priceHistory
        )
        
        // Call Claude API
        let response = try await callClaudeAPI(prompt: prompt)
        
        // Parse the response
        let grade = parseGradeResponse(response)
        
        return grade
    }
    
    // MARK: - Build Prompt
    
    private func buildGradingPrompt(
        symbol: String,
        side: String,
        quantity: Double,
        entryPrice: Double,
        currentPrice: Double,
        stopLoss: Double?,
        takeProfit: Double?,
        notes: String,
        priceHistory: [(date: Date, price: Double)]
    ) -> String {
        
        // Calculate key metrics
        let accountSize = 25000.0 // Starting account size
        let positionSize = quantity * entryPrice
        let positionSizePercent = (positionSize / accountSize) * 100
        
        let riskAmount: Double
        if let sl = stopLoss {
            riskAmount = abs(entryPrice - sl) * quantity
        } else {
            riskAmount = positionSize // Full position at risk
        }
        let riskPercent = (riskAmount / accountSize) * 100
        
        let rewardAmount: Double
        if let tp = takeProfit {
            rewardAmount = abs(tp - entryPrice) * quantity
        } else {
            rewardAmount = 0
        }
        
        let riskRewardRatio: Double
        if riskAmount > 0 && rewardAmount > 0 {
            riskRewardRatio = rewardAmount / riskAmount
        } else {
            riskRewardRatio = 0
        }
        
        // Format price history
        let recentPrices = priceHistory.suffix(30) // Last 30 days
        let priceHistoryText = recentPrices.map { point in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM dd"
            return "\(dateFormatter.string(from: point.date)): $\(String(format: "%.2f", point.price))"
        }.joined(separator: "\n")
        
        // Calculate price levels
        let highPrice = recentPrices.map { $0.price }.max() ?? entryPrice
        let lowPrice = recentPrices.map { $0.price }.min() ?? entryPrice
        let avgPrice = recentPrices.map { $0.price }.reduce(0, +) / Double(recentPrices.count)
        
        return """
        You are an expert day trading coach evaluating a paper trade. Grade this trade on a scale of 0-10 and provide specific, actionable feedback.
        
        TRADE DETAILS:
        Symbol: \(symbol)
        Side: \(side)
        Quantity: \(Int(quantity)) shares
        Entry Price: $\(String(format: "%.2f", entryPrice))
        Current Market Price: $\(String(format: "%.2f", currentPrice))
        Stop Loss: \(stopLoss.map { "$\(String(format: "%.2f", $0))" } ?? "Not set")
        Take Profit: \(takeProfit.map { "$\(String(format: "%.2f", $0))" } ?? "Not set")
        
        POSITION SIZING:
        Account Size: $\(String(format: "%.2f", accountSize))
        Position Size: $\(String(format: "%.2f", positionSize)) (\(String(format: "%.1f%%", positionSizePercent)) of account)
        Risk Amount: $\(String(format: "%.2f", riskAmount)) (\(String(format: "%.1f%%", riskPercent)) of account)
        Risk/Reward Ratio: \(riskRewardRatio > 0 ? String(format: "%.2f", riskRewardRatio) : "N/A")
        
        RECENT PRICE HISTORY (Last 30 days):
        \(priceHistoryText)
        
        KEY LEVELS:
        30-day High: $\(String(format: "%.2f", highPrice))
        30-day Low: $\(String(format: "%.2f", lowPrice))
        30-day Average: $\(String(format: "%.2f", avgPrice))
        
        TRADER'S NOTES:
        \(notes.isEmpty ? "No notes provided" : notes)
        
        GRADING CRITERIA:
        1. RISK MANAGEMENT (0-10): Evaluate stop loss placement, position sizing (should be 1-2% risk), and risk/reward ratio (should be at least 2:1)
        2. TIMING & PRICE (0-10): Evaluate entry price relative to recent support/resistance, trends, and key levels
        3. THESIS QUALITY (0-10): Evaluate the clarity and quality of the trader's reasoning in their notes
        
        Respond in the following JSON format ONLY (no markdown, no backticks, just pure JSON):
        {
            "overallScore": 7.5,
            "riskScore": 8.0,
            "timingScore": 7.0,
            "thesisScore": 7.5,
            "comments": "Detailed feedback here. Be specific about what was done well and what needs improvement. Include concrete suggestions."
        }
        
        Important:
        - Be honest and constructive
        - Point out specific issues (e.g., "Entry at $185.30 is near the 30-day high of $186.50, suggesting limited upside")
        - Praise good practices (e.g., "Excellent 2:1 risk/reward ratio")
        - Give actionable advice (e.g., "Consider waiting for a pullback to the $180 support level")
        - Keep comments concise but thorough (3-5 sentences)
        """
    }
    
    // MARK: - Call Claude API
    
    private func callClaudeAPI(prompt: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw AIGradingError.networkError
        }
        
        if http.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Claude API Error (\(http.statusCode)): \(errorBody)")
            throw AIGradingError.apiError(statusCode: http.statusCode, message: errorBody)
        }
        
        // Parse Claude's response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw AIGradingError.parsingError
        }
        
        return text
    }
    
    // MARK: - Parse Response
    
    private func parseGradeResponse(_ response: String) -> TradeGrade {
        // Remove any markdown formatting if present
        let cleanedResponse = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanedResponse.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("⚠️ Failed to parse AI response, using fallback")
            return TradeGrade.fallback
        }
        
        let overallScore = json["overallScore"] as? Double ?? 7.0
        let riskScore = json["riskScore"] as? Double ?? 7.0
        let timingScore = json["timingScore"] as? Double ?? 7.0
        let thesisScore = json["thesisScore"] as? Double ?? 7.0
        let comments = json["comments"] as? String ?? "Trade graded successfully."
        
        return TradeGrade(
            overallScore: overallScore,
            riskScore: riskScore,
            timingScore: timingScore,
            thesisScore: thesisScore,
            comments: comments
        )
    }
}

// MARK: - Errors

enum AIGradingError: LocalizedError {
    case networkError
    case apiError(statusCode: Int, message: String)
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network error occurred while grading trade"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .parsingError:
            return "Failed to parse AI response"
        }
    }
}

// MARK: - TradeGrade Extension

extension TradeGrade {
    static let fallback = TradeGrade(
        overallScore: 7.0,
        riskScore: 7.0,
        timingScore: 7.0,
        thesisScore: 7.0,
        comments: "Trade recorded successfully. AI grading temporarily unavailable."
    )
}
