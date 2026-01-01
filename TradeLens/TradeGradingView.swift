import SwiftUI

struct TradeGrade {
    let overallScore: Double    // 0.0 to 10.0
    let riskScore: Double
    let timingScore: Double
    let thesisScore: Double
    let comments: String

    static let example = TradeGrade(
        overallScore: 8.2,
        riskScore: 7.5,
        timingScore: 8.4,
        thesisScore: 8.7,
        comments: "Example grade for a trade with balanced risk, reasonable timing, and a clear thesis."
    )
}

struct TradeGradingView: View {
    let grade: TradeGrade

    init(grade: TradeGrade = .example) {
        self.grade = grade
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {

                TLCard {
                    VStack(alignment: .leading, spacing: 10) {
                        TLSectionHeader(title: "Overall grade", subtitle: "0.0 to 10.0 scale")

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
                        TLSectionHeader(title: "Comments")
                        Text(grade.comments)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                TLCard {
                    VStack(alignment: .leading, spacing: 10) {
                        TLSectionHeader(title: "Next steps")
                        Text("TradeLens will suggest improvements for entries, exits, and risk rules based on your recent trading history.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer(minLength: 10)
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .navigationTitle("My Trades")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { ProfileView() } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }
}

//
// MARK: - Components (kept in this file)
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
