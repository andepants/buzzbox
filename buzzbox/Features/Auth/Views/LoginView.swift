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
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.03),
                        Color.blue.opacity(0.08),
                        Color.blue.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Logo/Branding
                        brandingSection

                        // Main content card with glass effect
                        VStack(spacing: 24) {
                            // Form Fields
                            formSection

                            // Login Button
                            loginButton

                            // Sign Up Link
                            signUpLink
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 32)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)

                        // Development Quick Login (remove in production)
                        #if DEBUG
                        devQuickLoginButtons
                        #endif
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 40)
                }
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
                    HapticFeedback.notification(.success)
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
            // App icon with glass effect
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.1),
                                Color.blue.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("BuzzBox")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.primary, Color.primary.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("Welcome back to the community")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: 16) {
            // Email Field with glass effect
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                TextField("Email", text: $viewModel.email)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        focusedField == .email
                            ? Color.blue.opacity(0.5)
                            : Color.clear,
                        lineWidth: 1.5
                    )
            )

            // Password Field with glass effect
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                SecureField("Password", text: $viewModel.password)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        focusedField == .password
                            ? Color.blue.opacity(0.5)
                            : Color.clear,
                        lineWidth: 1.5
                    )
            )

            // Forgot Password Link
            HStack {
                Spacer()
                Button("Forgot Password?") {
                    showForgotPassword = true
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Login Button

    private var loginButton: some View {
        Button(action: {
            Task {
                await viewModel.login(modelContext: modelContext)
            }
        }) {
            ZStack {
                // Glass background
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)

                // Gradient overlay
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: isFormValid
                                ? [Color.blue, Color.blue.opacity(0.8)]
                                : [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Button content
                HStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                        Text("Logging in...")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    } else {
                        Text("Log In")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .shadow(
                color: isFormValid ? Color.blue.opacity(0.3) : Color.clear,
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .disabled(viewModel.isLoading || !isFormValid)
        .scaleEffect(viewModel.isLoading ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isLoading)
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

            // Creator Auto-Login Button with glass effect
            Button(action: {
                // Auto-fill creator credentials and login
                viewModel.email = "andrewsheim@gmail.com"
                viewModel.password = "test1234"
                Task {
                    await viewModel.login(modelContext: modelContext)
                }
            }) {
                ZStack {
                    // Glass background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)

                    // Gradient overlay
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.2), Color.red.opacity(0.15)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

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
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            Color.orange.opacity(0.4),
                            lineWidth: 1
                        )
                )
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
