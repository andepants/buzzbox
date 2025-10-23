/// ForgotPasswordView.swift
/// Password reset screen with email input
/// [Source: Epic 1, Story 1.4]
///
/// Provides password reset functionality via Firebase Auth's email reset flow.
/// Features real-time email validation, haptic feedback, and accessibility support.

import SwiftUI

struct ForgotPasswordView: View {
    // MARK: - Properties

    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEmailFocused: Bool

    let prefillEmail: String?

    // MARK: - Initialization

    init(prefillEmail: String? = nil) {
        self.prefillEmail = prefillEmail
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Icon
                    Image(systemName: "envelope.badge")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                        .padding(.top, 40)

                    // Title
                    Text("Reset Password")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    // Description
                    Text("Enter your email address and we'll send you a link to reset your password.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Email TextField
                    emailField

                    // Email validation error
                    if !viewModel.email.isEmpty && !isEmailValid {
                        Text("Please enter a valid email address")
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }

                    // Send Reset Email Button
                    sendResetButton

                    // Back to Login Button
                    Button("Back to Login") {
                        dismiss()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 20)
                }
                .padding()
            }
            .navigationBarHidden(true)
            .alert("Password Reset Email Sent", isPresented: $viewModel.resetEmailSent) {
                Button("OK") {
                    // Dismiss to login screen
                    dismiss()
                }
            } message: {
                Text("We've sent a password reset link to \(viewModel.email). Check your inbox and follow the instructions.")
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Failed to send reset email. Please try again.")
            }
            .onAppear {
                if let prefillEmail = prefillEmail {
                    viewModel.email = prefillEmail
                }
                isEmailFocused = true
            }
        }
    }

    // MARK: - Email Field

    private var emailField: some View {
        HStack {
            Image(systemName: isEmailValid ? "checkmark.circle.fill" : "envelope")
                .foregroundColor(isEmailValid ? .green : .gray)

            TextField("Email", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .focused($isEmailFocused)
                .submitLabel(.send)
                .accessibilityLabel("Email address")
                .accessibilityIdentifier("emailTextField")
                .onSubmit {
                    Task { await sendResetEmail() }
                }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isEmailValid ? Color.green : Color.clear, lineWidth: 2)
        )
        .padding(.horizontal)
    }

    // MARK: - Send Reset Button

    private var sendResetButton: some View {
        Button(action: {
            Task { await sendResetEmail() }
        }) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(width: 20, height: 20)
                    Text("Sending...")
                } else {
                    Text("Send Reset Email")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isEmailValid ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(!isEmailValid || viewModel.isLoading)
        .padding(.horizontal)
        .accessibilityIdentifier("sendResetEmailButton")
    }

    // MARK: - Computed Properties

    /// Validates email format using regex
    private var isEmailValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: viewModel.email)
    }

    // MARK: - Actions

    /// Sends password reset email
    private func sendResetEmail() async {
        guard isEmailValid else { return }

        do {
            try await viewModel.sendPasswordReset(email: viewModel.email)
            // Success haptic feedback
            HapticFeedback.notification(.success)
            // VoiceOver announcement
            UIAccessibility.post(notification: .announcement, argument: "Password reset email sent to \(viewModel.email)")
        } catch {
            // Error haptic feedback
            HapticFeedback.notification(.error)
        }
    }
}

// MARK: - Preview

#Preview {
    ForgotPasswordView()
}

#Preview("With Prefilled Email") {
    ForgotPasswordView(prefillEmail: "user@example.com")
}
