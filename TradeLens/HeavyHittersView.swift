import SwiftUI

struct HeavyHittersView: View {

    struct EliteTrade: Identifiable {
        let id = UUID()
        let name: String
        let role: String
        let symbol: String
        let direction: String
        let sizeText: String
        let dateText: String
        let convictionText: String
        let source: Source
        let sortSizeValue: Double
        let sortDateValue: Int
    }

    enum Source: String, CaseIterable, Identifiable {
        case all = "All"
        case congress = "Congress"
        case funds = "Funds"
        case insiders = "Insiders"
        var id: String { rawValue }
    }

    enum SortMode: String, CaseIterable, Identifiable {
        case mostRecent = "Most recent"
        case biggest = "Biggest size"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .mostRecent: return "clock"
            case .biggest: return "arrow.up.right.circle"
            }
        }
    }

    @State private var selectedSource: Source = .all
    @State private var sortMode: SortMode = .mostRecent

    // Repeat mock data so you always have enough to scroll
    private let trades: [EliteTrade] = {
        let base: [EliteTrade] = [
            .init(name: "Nancy Pelosi", role: "Congress", symbol: "AAPL", direction: "Buy", sizeText: "$50k - $100k", dateText: "Nov 21", convictionText: "New position disclosure", source: .congress, sortSizeValue: 0.08, sortDateValue: 20251121),
            .init(name: "Warren Buffett", role: "Fund", symbol: "AAPL", direction: "Buy", sizeText: "$150M", dateText: "Nov 15", convictionText: "High conviction add", source: .funds, sortSizeValue: 150.0, sortDateValue: 20251115),
            .init(name: "Company Insider", role: "Insider", symbol: "NVDA", direction: "Sell", sizeText: "$3.2M", dateText: "Nov 10", convictionText: "Partial profit taking", source: .insiders, sortSizeValue: 3.2, sortDateValue: 20251110),
            .init(name: "Congress Filing", role: "Congress", symbol: "MSFT", direction: "Buy", sizeText: "$15k - $50k", dateText: "Nov 08", convictionText: "Follow-on purchase", source: .congress, sortSizeValue: 0.04, sortDateValue: 20251108),
            .init(name: "Fund Manager", role: "Fund", symbol: "AMZN", direction: "Sell", sizeText: "$25M", dateText: "Nov 06", convictionText: "Trim into strength", source: .funds, sortSizeValue: 25.0, sortDateValue: 20251106),
            .init(name: "Company Insider", role: "Insider", symbol: "TSLA", direction: "Buy", sizeText: "$850k", dateText: "Nov 04", convictionText: "Open market buy", source: .insiders, sortSizeValue: 0.85, sortDateValue: 20251104),
        ]
        return (0..<6).flatMap { _ in base }
    }()

    var body: some View {
        List {
            // Intro
            TLCardRow {
                Text("Track notable trades from congressional filings, insiders, and funds. Data is simulated until you hook up a live feed.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            // Sources selector
            TLCardRow {
                VStack(alignment: .leading, spacing: 10) {
                    TLSectionHeader(title: "Sources")

                    HStack(spacing: 8) {
                        ForEach(Source.allCases) { source in
                            SegmentedChip(title: source.rawValue, isSelected: source == selectedSource) {
                                selectedSource = source
                            }
                        }
                    }
                }
            }

            // Sort
            TLCardRow {
                HStack {
                    Text("Sort")
                        .font(.headline)

                    Spacer()

                    Menu {
                        ForEach(SortMode.allCases) { mode in
                            Button {
                                sortMode = mode
                            } label: {
                                Label(mode.rawValue, systemImage: mode.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: sortMode.icon)
                            Text(sortMode.rawValue)
                                .font(.subheadline.weight(.semibold))
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                        )
                    }
                }
            }

            // Feed
            ForEach(filteredAndSortedTrades) { trade in
                TLCardRow {
                    TradeCard(trade: trade)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .navigationTitle("Heavy Hitters")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { ProfileView() } label: { Image(systemName: "gearshape") }
            }
        }
    }

    private var filteredAndSortedTrades: [EliteTrade] {
        let filtered: [EliteTrade] = {
            switch selectedSource {
            case .all: return trades
            default: return trades.filter { $0.source == selectedSource }
            }
        }()

        switch sortMode {
        case .mostRecent:
            return filtered.sorted { $0.sortDateValue > $1.sortDateValue }
        case .biggest:
            return filtered.sorted { $0.sortSizeValue > $1.sortSizeValue }
        }
    }
}

//
// MARK: - UI pieces
//

private struct TradeCard: View {
    let trade: HeavyHittersView.EliteTrade

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(trade.symbol)
                    .font(.title3.weight(.semibold))
                Spacer()
                DirectionPill(direction: trade.direction)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(trade.name)
                    .font(.subheadline.weight(.semibold))
                Text(trade.role)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(trade.sizeText)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(trade.dateText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(trade.convictionText)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}

private struct DirectionPill: View {
    let direction: String
    private var isBuy: Bool { direction.lowercased() == "buy" }

    var body: some View {
        Text(isBuy ? "Buy" : "Sell")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((isBuy ? Color.green : Color.red).opacity(0.14))
            .foregroundColor(isBuy ? .green : .red)
            .clipShape(Capsule())
    }
}

private struct SegmentedChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.primary.opacity(0.14) : Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? Color.primary.opacity(0.18) : Color.primary.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

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

private struct TLSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            if let subtitle {
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}
