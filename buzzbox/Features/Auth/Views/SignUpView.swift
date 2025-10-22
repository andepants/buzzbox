/// SignUpView.swift
/// User sign up screen with email/password and display name
/// [Source: Epic 1, Story 1.1]
///
/// Implements Instagram-style signup with real-time validation,
/// display name uniqueness checking, and comprehensive error handling.

import SwiftUI
import SwiftData

/// Sign up view with form validation
struct SignUpView: View {
    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: AuthViewModel

    // MARK: - State

    @FocusState private var focusedField: Field?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Form
                    formSection

                    // Sign Up Button
                    signUpButton

                    // Login Link
                    loginLink
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.resetSignUpFields()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .onChange(of: viewModel.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    // Success haptic feedback
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    // Dismiss to return to root, which will show ConversationListView
                    dismiss()
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Create Account")
                .font(.title)
                .fontWeight(.bold)

            Text("Join Buzzbox to manage your messages with AI")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: 16) {
            // Email Field
            VStack(alignment: .leading, spacing: 6) {
                TextField("Email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(emailBorderColor, lineWidth: 1.5)
                    )
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .accessibilityLabel("Email address")

                if let message = viewModel.emailValidationMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                        Text(message)
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                }
            }

            // Password Field
            VStack(alignment: .leading, spacing: 6) {
                SecureField("Password", text: $viewModel.password)
                    .textContentType(.newPassword)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(passwordBorderColor, lineWidth: 1.5)
                    )
                    .focused($focusedField, equals: .password)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .confirmPassword }
                    .accessibilityLabel("Password")
                    .accessibilityHint("Minimum 8 characters")

                if let message = viewModel.passwordValidationMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                        Text(message)
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                } else if !viewModel.password.isEmpty && viewModel.isPasswordValid {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text("Strong password")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                }
            }

            // Confirm Password Field
            VStack(alignment: .leading, spacing: 6) {
                SecureField("Confirm Password", text: $viewModel.confirmPassword)
                    .textContentType(.newPassword)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(confirmPasswordBorderColor, lineWidth: 1.5)
                    )
                    .focused($focusedField, equals: .confirmPassword)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .displayName }
                    .accessibilityLabel("Confirm password")

                if let message = viewModel.passwordMatchValidationMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                        Text(message)
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                } else if !viewModel.confirmPassword.isEmpty && viewModel.passwordsMatch {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text("Passwords match")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                }
            }

            // Display Name Field
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    TextField("Display Name (Username)", text: $viewModel.displayName)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(displayNameBorderColor, lineWidth: 1.5)
                        )
                        .focused($focusedField, equals: .displayName)
                        .submitLabel(.done)
                        .onChange(of: viewModel.displayName) { _, _ in
                            viewModel.checkDisplayNameAvailability()
                        }
                        .accessibilityLabel("Display name")
                        .accessibilityHint("Instagram-style username")

                    // Availability indicator
                    availabilityIndicator
                        .padding(.trailing, 8)
                }

                if let message = viewModel.displayNameValidationMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                        Text(message)
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                } else if viewModel.displayNameAvailability == .available {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text("Username available")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                }
            }
        }
    }

    // MARK: - Border Colors

    private var emailBorderColor: Color {
        if viewModel.email.isEmpty {
            return Color.clear
        }
        return viewModel.isEmailValid ? Color.green.opacity(0.5) : Color.red.opacity(0.5)
    }

    private var passwordBorderColor: Color {
        if viewModel.password.isEmpty {
            return Color.clear
        }
        return viewModel.isPasswordValid ? Color.green.opacity(0.5) : Color.red.opacity(0.5)
    }

    private var confirmPasswordBorderColor: Color {
        if viewModel.confirmPassword.isEmpty {
            return Color.clear
        }
        return viewModel.passwordsMatch ? Color.green.opacity(0.5) : Color.red.opacity(0.5)
    }

    private var displayNameBorderColor: Color {
        if viewModel.displayName.isEmpty {
            return Color.clear
        }
        if !viewModel.isDisplayNameValid {
            return Color.red.opacity(0.5)
        }
        switch viewModel.displayNameAvailability {
        case .available:
            return Color.green.opacity(0.5)
        case .taken:
            return Color.red.opacity(0.5)
        case .unknown:
            return Color.clear
        }
    }

    // MARK: - Availability Indicator

    @ViewBuilder
    private var availabilityIndicator: some View {
        switch viewModel.displayNameAvailability {
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .accessibilityLabel("Display name available")

        case .taken:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .accessibilityLabel("Display name taken")

        case .unknown:
            EmptyView()
        }
    }

    // MARK: - Sign Up Button

    private var signUpButton: some View {
        Button {
            Task {
                try? await viewModel.signUp(modelContext: modelContext)
            }
        } label: {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            } else {
                Text("Sign Up")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
        }
        .background(viewModel.isFormValid ? Color.blue : Color.gray)
        .cornerRadius(10)
        .disabled(!viewModel.isFormValid || viewModel.isLoading)
        .accessibilityIdentifier("signUpButton")
    }

    // MARK: - Login Link

    private var loginLink: some View {
        HStack {
            Text("Already have an account?")
                .foregroundColor(.secondary)

            Button("Log In") {
                // Navigate to login screen
                // TODO: Implement navigation in Story 1.2
                dismiss()
            }
            .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}

// MARK: - Focus Field

extension SignUpView {
    enum Field {
        case email
        case password
        case confirmPassword
        case displayName
    }
}

// MARK: - Preview

#Preview {
    SignUpView()
        .modelContainer(for: [UserEntity.self], inMemory: true)
}
