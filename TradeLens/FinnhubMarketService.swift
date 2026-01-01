import Foundation

struct MarketOverview {
    let indexName: String
    let value: Double
    let changePercent: Double
}

// Stable identity: symbol as id (NOT UUID)
struct SymbolMove: Identifiable, Hashable {
    var id: String { symbol }
    let symbol: String
    let changePercent: Double
}

protocol MarketDataService {
    func fetchMarketOverview() async throws -> MarketOverview
    func fetchTopGainers() async throws -> [SymbolMove]
    func fetchTopLosers() async throws -> [SymbolMove]

    // Detail support
    func fetchQuotePrice(symbol: String) async throws -> Double
    /// Returns (timestamps, closePrices) for the given range.
    func fetchCandles(symbol: String, resolution: String, from: Int, to: Int) async throws -> ([Int], [Double])
}

final class FinnhubMarketService: MarketDataService {
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // Use SPY as a proxy for S&P 500
    func fetchMarketOverview() async throws -> MarketOverview {
        let quote = try await fetchSymbolQuote(symbol: "SPY")
        return MarketOverview(
            indexName: "S&P 500 (SPY)",
            value: quote.c,
            changePercent: quote.changePercent
        )
    }

    func fetchTopGainers() async throws -> [SymbolMove] {
        let symbols = ["AAPL", "MSFT", "NVDA", "TSLA", "META", "AMD"]
        let quotes = try await fetchQuotes(symbols: symbols)

        let sorted = quotes.sorted { $0.changePercent > $1.changePercent }
        return Array(sorted.prefix(3)).map { q in
            SymbolMove(symbol: q.symbol, changePercent: q.changePercent)
        }
    }

    func fetchTopLosers() async throws -> [SymbolMove] {
        let symbols = ["AAPL", "MSFT", "NVDA", "TSLA", "META", "AMD"]
        let quotes = try await fetchQuotes(symbols: symbols)

        let sorted = quotes.sorted { $0.changePercent < $1.changePercent }
        return Array(sorted.prefix(3)).map { q in
            SymbolMove(symbol: q.symbol, changePercent: q.changePercent)
        }
    }

    // MARK: - Detail support

    func fetchQuotePrice(symbol: String) async throws -> Double {
        let quote = try await fetchSymbolQuote(symbol: symbol.uppercased())
        return quote.c
    }

    /// resolution: "1", "5", "15", "30", "60", "D"
    func fetchCandles(symbol: String, resolution: String, from: Int, to: Int) async throws -> ([Int], [Double]) {
        let sym = symbol.uppercased()

        var components = URLComponents(string: "https://finnhub.io/api/v1/stock/candle")!
        components.queryItems = [
            URLQueryItem(name: "symbol", value: sym),
            URLQueryItem(name: "resolution", value: resolution),
            URLQueryItem(name: "from", value: String(from)),
            URLQueryItem(name: "to", value: String(to)),
            URLQueryItem(name: "token", value: apiKey)
        ]

        let url = components.url!
        let (data, response) = try await session.data(from: url)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("Finnhub candles error \(http.statusCode): \(body)")
            throw NSError(
                domain: "FinnhubError",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Finnhub status \(http.statusCode)"]
            )
        }

        let decoded = try JSONDecoder().decode(FinnhubCandlesResponse.self, from: data)

        guard decoded.s == "ok",
              let t = decoded.t,
              let c = decoded.c,
              t.count == c.count
        else {
            return ([], [])
        }

        return (t, c)
    }

    // MARK: - Private helpers

    private struct FinnhubQuoteResponse: Decodable {
        let c: Double    // current price
        let pc: Double   // previous close
    }

    private struct FinnhubCandlesResponse: Decodable {
        let c: [Double]?
        let t: [Int]?
        let s: String
    }

    private struct SymbolQuote {
        let symbol: String
        let c: Double
        let pc: Double

        var changePercent: Double {
            guard pc != 0 else { return 0 }
            return ((c - pc) / pc) * 100.0
        }
    }

    private func fetchSymbolQuote(symbol: String) async throws -> SymbolQuote {
        let sym = symbol.uppercased()

        var components = URLComponents(string: "https://finnhub.io/api/v1/quote")!
        components.queryItems = [
            URLQueryItem(name: "symbol", value: sym),
            URLQueryItem(name: "token", value: apiKey)
        ]

        let url = components.url!
        let (data, response) = try await session.data(from: url)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("Finnhub error \(http.statusCode): \(body)")
            throw NSError(
                domain: "FinnhubError",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Finnhub status \(http.statusCode)"]
            )
        }

        let decoded = try JSONDecoder().decode(FinnhubQuoteResponse.self, from: data)
        return SymbolQuote(symbol: sym, c: decoded.c, pc: decoded.pc)
    }

    private func fetchQuotes(symbols: [String]) async throws -> [SymbolQuote] {
        var results: [SymbolQuote] = []
        results.reserveCapacity(symbols.count)

        for symbol in symbols {
            let quote = try await fetchSymbolQuote(symbol: symbol)
            results.append(quote)
        }

        return results
    }
}
