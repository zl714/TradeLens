import SwiftUI

struct LoginView: View {
    @EnvironmentObject var session: UserSession

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSecure: Bool = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {

                Spacer(minLength: 28)

                // Logo + name
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.06))
                            .frame(width: 76, height: 76)

                        Circle()
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                            .frame(width: 76, height: 76)

                        Image(systemName: "eye")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.primary)
                    }

                    Text("TradeLens")
                        .font(.title2.weight(.semibold))

                    Text("Learn to trade with clarity")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 6)

                // Credentials
                TLCard {
                    VStack(alignment: .leading, spacing: 12) {
                        TLSectionHeader(title: "Sign in")

                        TLTextField(title: "Email", placeholder: "you@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)

                        TLPasswordField(title: "Password", placeholder: "Password", text: $password, isSecure: $isSecure)

                        Button {
                            session.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "user@tradelens.app" : email)
                        } label: {
                            Text("Sign in")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.primary)
                                .foregroundColor(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .padding(.top, 2)
                    }
                }

                // Divider
                HStack(spacing: 12) {
                    Divider().opacity(0.6)
                    Text("Or continue with")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Divider().opacity(0.6)
                }
                .padding(.horizontal, 20)
                .padding(.top, 2)

                // Third party + biometrics
                TLCard {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ProviderButton(icon: "g.circle", label: "Google") {
                                session.signIn(email: "google@tradelens.app")
                            }
                            ProviderButton(icon: "apple.logo", label: "Apple") {
                                session.signIn(email: "apple@tradelens.app")
                            }
                        }

                        HStack(spacing: 12) {
                            ProviderButton(icon: "faceid", label: "Face ID") {
                                session.signIn(email: "faceid@tradelens.app")
                            }
                            ProviderButton(icon: "touchid", label: "Touch ID") {
                                session.signIn(email: "touchid@tradelens.app")
                            }
                        }
                    }
                }

                Text("For demo only. No real accounts or trades.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)

                Spacer(minLength: 28)
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
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

private struct TLTextField: View {
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

private struct TLPasswordField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @Binding var isSecure: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .textFieldStyle(.plain)

                Button {
                    isSecure.toggle()
                } label: {
                    Image(systemName: isSecure ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
            }
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

private struct ProviderButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
