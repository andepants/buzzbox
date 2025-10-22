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
            .alert("Login Failed", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error occurred")
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

    /// Development-only quick login buttons for testing
    private var devQuickLoginButtons: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.vertical, 8)

            Text("DEV: Quick Login")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                // Test User 1
                Button(action: {
                    viewModel.email = "alice@test.com"
                    viewModel.password = "Test123!"
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                        Text("Alice")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }

                // Test User 2
                Button(action: {
                    viewModel.email = "bob@test.com"
                    viewModel.password = "Test123!"
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                        Text("Bob")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }

                // Test User 3
                Button(action: {
                    viewModel.email = "charlie@test.com"
                    viewModel.password = "Test123!"
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                        Text("Charlie")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Computed Properties

    /// Check if login form is valid
    private var isFormValid: Bool {
        !viewModel.email.isEmpty && !viewModel.password.isEmpty
    }
}

// MARK: - Preview

#Preview {
    LoginView()
        .modelContainer(for: [UserEntity.self], inMemory: true)
}
