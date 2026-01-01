import Foundation

final class AlphaVantageService {
    private let apiKey: String
    private let session: URLSession
    
    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }
    
    /// Fetch intraday candles (1min, 5min, 15min, 30min, 60min)
    /// Returns (timestamps, closePrices)
    func fetchIntradayCandles(symbol: String, interval: String = "5min") async throws -> ([Int], [Double]) {
        var components = URLComponents(string: "https://www.alphavantage.co/query")!
        components.queryItems = [
            URLQueryItem(name: "function", value: "TIME_SERIES_INTRADAY"),
            URLQueryItem(name: "symbol", value: symbol.uppercased()),
            URLQueryItem(name: "interval", value: interval),
            URLQueryItem(name: "outputsize", value: "compact"), // last 100 data points
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        
        let url = components.url!
        print("🌐 Alpha Vantage URL: \(url.absoluteString)")
        
        let (data, response) = try await session.data(from: url)
        
        // Debug: print raw response
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📥 Alpha Vantage Response (first 500 chars): \(String(jsonString.prefix(500)))")
        }
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "AlphaVantageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch data"])
        }
        
        // Parse as generic JSON first to handle different response formats
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "AlphaVantageError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
        }
        
        // Check for error messages
        if let note = json["Note"] as? String {
            print("⚠️ Alpha Vantage Note: \(note)")
            throw NSError(domain: "AlphaVantageError", code: -2, userInfo: [NSLocalizedDescriptionKey: "API limit: \(note)"])
        }
        
        if let errorMessage = json["Error Message"] as? String {
            print("❌ Alpha Vantage Error: \(errorMessage)")
            throw NSError(domain: "AlphaVantageError", code: -4, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        // Find the time series key (it varies by interval)
        let timeSeriesKey = "Time Series (\(interval))"
        guard let timeSeries = json[timeSeriesKey] as? [String: [String: String]] else {
            print("❌ Could not find time series data with key: \(timeSeriesKey)")
            print("Available keys: \(json.keys.joined(separator: ", "))")
            return ([], [])
        }
        
        var timestamps: [Int] = []
        var closes: [Double] = []
        
        // Sort by time ascending
        let sorted = timeSeries.sorted { $0.key < $1.key }
        
        for (timeStr, candle) in sorted {
            if let timestamp = parseTimestamp(timeStr),
               let closeStr = candle["4. close"],
               let close = Double(closeStr) {
                timestamps.append(timestamp)
                closes.append(close)
            }
        }
        
        print("✅ Parsed \(timestamps.count) candles from Alpha Vantage")
        
        return (timestamps, closes)
    }
    
    /// Fetch daily candles for longer time ranges
    func fetchDailyCandles(symbol: String) async throws -> ([Int], [Double]) {
        var components = URLComponents(string: "https://www.alphavantage.co/query")!
        components.queryItems = [
            URLQueryItem(name: "function", value: "TIME_SERIES_DAILY"),
            URLQueryItem(name: "symbol", value: symbol.uppercased()),
            URLQueryItem(name: "outputsize", value: "compact"), // last 100 days
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        
        let url = components.url!
        let (data, response) = try await session.data(from: url)
        
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "AlphaVantageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch data"])
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "AlphaVantageError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
        }
        
        if let note = json["Note"] as? String {
            throw NSError(domain: "AlphaVantageError", code: -2, userInfo: [NSLocalizedDescriptionKey: "API limit: \(note)"])
        }
        
        guard let timeSeries = json["Time Series (Daily)"] as? [String: [String: String]] else {
            return ([], [])
        }
        
        var timestamps: [Int] = []
        var closes: [Double] = []
        
        let sorted = timeSeries.sorted { $0.key < $1.key }
        
        for (dateStr, candle) in sorted {
            if let timestamp = parseDateTimestamp(dateStr),
               let closeStr = candle["4. close"],
               let close = Double(closeStr) {
                timestamps.append(timestamp)
                closes.append(close)
            }
        }
        
        return (timestamps, closes)
    }
    
    // MARK: - Helpers
    
    private func parseTimestamp(_ timeStr: String) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "America/New_York") // Market time
        
        guard let date = formatter.date(from: timeStr) else { return nil }
        return Int(date.timeIntervalSince1970)
    }
    
    private func parseDateTimestamp(_ dateStr: String) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        
        guard let date = formatter.date(from: dateStr) else { return nil }
        return Int(date.timeIntervalSince1970)
    }
}
