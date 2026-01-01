// HeavyHitterTrade.swift

import Foundation

struct HeavyHitterTrade: Identifiable {
    let id = UUID()
    let name: String          // Investor or entity
    let role: String          // Congress, Insider, Fund
    let symbol: String
    let direction: String     // Buy or Sell
    let sizeText: String      // "$2.5M", "$50k", etc.
    let dateText: String
    let convictionText: String
}
