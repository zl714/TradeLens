import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var session: UserSession

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {

                // Account card
                TLCard {
                    VStack(alignment: .leading, spacing: 10) {
                        TLSectionHeader(title: "Account")

                        HStack {
                            Text("Email")
                                .font(.subheadline)

                            Spacer()

                            Text(session.email ?? "Guest")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Preferences (placeholders for later)
                TLCard {
                    VStack(alignment: .leading, spacing: 10) {
                        TLSectionHeader(title: "Preferences")

                        ProfileRow(title: "Notifications", value: "On")
                        Divider().opacity(0.6)
                        ProfileRow(title: "Theme", value: "Dark")
                        Divider().opacity(0.6)
                        ProfileRow(title: "Data", value: "Simulated")
                    }
                }

                // Sign out
                TLCard {
                    Button(role: .destructive) {
                        session.signOut()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign out")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 10)
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Profile")
    }
}

//
// MARK: - Local components (kept in this file)
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

private struct ProfileRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .contentShape(Rectangle())
    }
}
