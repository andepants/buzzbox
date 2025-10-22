/// LoginView.swift
/// Login screen with email/password authentication
/// [Source: Epic 1, Story 1.2]
///
/// Provides the UI for existing users to log in with email and password.
/// Features iOS-native autofill, accessibility support, and haptic feedback.

import SwiftUI
import SwiftData

struct LoginView: View {
    // MARK: - Properties

    @EnvironmentObject private var viewModel: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @FocusState private var focusedField: Field?
    @State private var showForgotPassword = false

    // MARK: - Focus State

    enum Field {
        case email
        case password
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo/Branding
                    brandingSection

                    // Form Fields
                    formSection

                    // Login Button
                    loginButton

                    // Sign Up Link
                    signUpLink

                    // Development Quick Login (remove in production)
                    #if DEBUG
                    devQuickLoginButtons
                    #endif
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.resetLoginFields()
            }
            .alert(errorTitle, isPresented: $viewModel.showError) {
                Button(primaryActionText) {
                    handlePrimaryAction()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: viewModel.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    // Success haptic feedback
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView(prefillEmail: viewModel.email)
            }
        }
    }

    // MARK: - Branding Section

    private var brandingSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.circle.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)

            Text("Welcome Back")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Log in to your account")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 40)
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: 16) {
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                TextField("Email", text: $viewModel.email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .accessibilityLabel("Email address")
                    .accessibilityIdentifier("emailTextField")
                    .onSubmit {
                        focusedField = .password
                    }
            }

            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .accessibilityLabel("Password")
                    .accessibilityIdentifier("passwordTextField")
                    .onSubmit {
                        Task {
                            await viewModel.login(modelContext: modelContext)
                        }
                    }
            }

            // Forgot Password Link
            HStack {
                Spacer()
                Button("Forgot Password?") {
                    showForgotPassword = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
    }

    // MARK: - Login Button

    private var loginButton: some View {
        Button(action: {
            Task {
                await viewModel.login(modelContext: modelContext)
            }
        }) {
            HStack(spacing: 8) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                    Text("Logging in...")
                        .fontWeight(.semibold)
                } else {
                    Text("Log In")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isFormValid ? Color.blue : Color.gray.opacity(0.5))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(viewModel.isLoading || !isFormValid)
        .accessibilityIdentifier("loginButton")
        .accessibilityLabel(viewModel.isLoading ? "Logging in" : "Log in")
    }

    // MARK: - Sign Up Link

    private var signUpLink: some View {
        NavigationLink {
            SignUpView()
        } label: {
            HStack(spacing: 4) {
                Text("Don't have an account?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Sign Up")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Development Quick Login

    /// Development-only dev login button for creator (Andrew)
    private var devQuickLoginButtons: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.vertical, 8)

            Text("DEV MODE")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.orange)

            // Creator Auto-Login Button
            Button(action: {
                // Auto-fill creator credentials and login
                viewModel.email = "andrewsheim@gmail.com"
                viewModel.password = "test1234"
                Task {
                    await viewModel.login(modelContext: modelContext)
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Creator Login")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("andrewsheim@gmail.com")
                            .font(.caption2)
                            .opacity(0.8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.15), Color.red.opacity(0.15)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(10)
            }
            .accessibilityIdentifier("devLoginButton")
            .accessibilityLabel("Developer login as creator")

            Text("Password: test1234")
                .font(.caption2)
                .foregroundColor(.secondary)
                .opacity(0.7)
        }
        .padding(.top, 16)
    }

    // MARK: - Computed Properties

    /// Check if login form is valid
    private var isFormValid: Bool {
        !viewModel.email.isEmpty && !viewModel.password.isEmpty
    }

    // MARK: - Error Handling Helpers

    /// Get appropriate error title based on error message
    private var errorTitle: String {
        guard let error = viewModel.errorMessage else { return "Error" }

        if error.contains("password") || error.contains("Password") {
            return "Incorrect Password"
        } else if error.contains("connection") || error.contains("network") || error.contains("Network") {
            return "Connection Issue"
        } else if error.contains("Server") || error.contains("configuration") {
            return "Server Issue"
        } else if error.contains("disabled") {
            return "Account Disabled"
        } else {
            return "Login Failed"
        }
    }

    /// Get error message text
    private var errorMessage: String {
        viewModel.errorMessage ?? "An unexpected error occurred"
    }

    /// Get primary action button text based on error type
    private var primaryActionText: String {
        guard let error = viewModel.errorMessage else { return "OK" }

        if error.contains("password") || error.contains("Password") {
            return "Reset Password"
        } else if error.contains("connection") || error.contains("network") || error.contains("Network") {
            return "Retry"
        } else {
            return "OK"
        }
    }

    /// Handle primary action based on error type
    private func handlePrimaryAction() {
        guard let error = viewModel.errorMessage else { return }

        if error.contains("password") || error.contains("Password") {
            showForgotPassword = true
        } else if error.contains("connection") || error.contains("network") || error.contains("Network") {
            Task {
                await viewModel.login(modelContext: modelContext)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LoginView()
        .modelContainer(for: [UserEntity.self], inMemory: true)
}
