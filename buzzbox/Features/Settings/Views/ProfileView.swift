/// ProfileView.swift
/// User profile management screen
/// [Source: Epic 1, Story 1.5]
///
/// Provides UI for editing display name and profile picture with
/// real-time validation, image upload, and Kingfisher caching.

import SwiftUI
import Kingfisher
import PhotosUI
import SwiftData

/// Profile editing view
struct ProfileView: View {
    // MARK: - Properties

    @State private var viewModel: ProfileViewModel?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel

    // MARK: - Body

    var body: some View {
        Group {
            if let viewModel = viewModel {
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
                        VStack(spacing: 24) {
                            profilePictureSection(viewModel: viewModel)

                            accountInfoSection(viewModel: viewModel)

                            // AI Settings link (Story 6.9)
                            if authViewModel.currentUser?.isCreator == true {
                                aiSettingsLink
                            }

                            Spacer()

                            logoutButton
                        }
                        .padding()
                    }
                }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .alert("Error", isPresented: Binding(
                    get: { viewModel.showError },
                    set: { self.viewModel?.showError = $0 }
                )) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(viewModel.errorMessage ?? "Failed to upload profile picture.")
                }
                // Reload profile when currentUser changes (e.g., after login or profile update)
                // Skip reload during active photo upload to prevent overwriting cache-busted URL
                .onChange(of: authViewModel.currentUser) { _, newUser in
                    if newUser != nil, viewModel.isUploadingPhoto == false {
                        viewModel.loadCurrentProfile()
                    }
                }
            } else {
                ProgressView()
            }
        }
        .task {
            // Initialize viewModel with shared authService
            if viewModel == nil {
                viewModel = ProfileViewModel(authService: authViewModel.authService)
            }
        }
        .onAppear {
            // Reload profile data when view appears to ensure displayName is current
            viewModel?.loadCurrentProfile()
        }
    }

    // MARK: - Profile Picture Section

    private func profilePictureSection(viewModel: ProfileViewModel) -> some View {
        VStack(spacing: 16) {
            ZStack {
                // Glass background circle
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 136, height: 136)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.4),
                                        Color.blue.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .shadow(color: Color.blue.opacity(0.15), radius: 12, x: 0, y: 6)

                if let photoURL = viewModel.photoURL {
                    // Use Kingfisher for cached image loading
                    KFImage(photoURL)
                        .placeholder {
                            ProgressView()
                                .frame(width: 120, height: 120)
                        }
                        .retry(maxCount: 3, interval: .seconds(2))
                        .cacheOriginalImage()
                        .fade(duration: 0.25)
                        .cancelOnDisappear(true)
                        .onSuccess { result in
                            // Force cache refresh to ensure new images display immediately
                        }
                        .onFailure { error in
                        }
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .id(photoURL) // Force SwiftUI view refresh when URL changes (cache-busting)
                } else {
                    // Default placeholder
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 120, height: 120)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.gray, Color.gray.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                // Upload progress overlay
                if viewModel.isUploading {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle()
                                .fill(Color.black.opacity(0.3))
                        )

                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            .accessibilityLabel("Profile picture")
            .accessibilityHint("Double tap to change")

            // Change Photo Button - Glass pill style
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.fill")
                        .font(.caption)
                    Text("Change Photo")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.thinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                )
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await viewModel.uploadProfileImage(uiImage, modelContext: modelContext)
                    }
                }
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Account Info Section

    private func accountInfoSection(viewModel: ProfileViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Information")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 16) {
                // Username display
                HStack {
                    Label {
                        Text("Username")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text(authViewModel.currentUser?.displayName ?? "")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)

                        // ✅ Creator badge
                        // [Source: Story 5.2 - User Type Auto-Assignment]
                        if authViewModel.currentUser?.isCreator == true {
                            CreatorBadgeView(size: .small)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Username: \(authViewModel.currentUser?.displayName ?? "")")

                Divider()
                    .background(Color.white.opacity(0.2))

                // Email display
                HStack {
                    Label {
                        Text("Email")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                    }

                    Spacer()

                    Text(authViewModel.currentUser?.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Email: \(authViewModel.currentUser?.email ?? "")")
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
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
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal)
    }

    // MARK: - AI Settings Link (Story 6.9)

    private var aiSettingsLink: some View {
        NavigationLink {
            AISettingsView()
        } label: {
            HStack {
                Label {
                    Text("AI Settings")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                } icon: {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
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
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Logout Button

    private var logoutButton: some View {
        Button(role: .destructive, action: {
            Task {
                await authViewModel.logout(modelContext: modelContext)
            }
        }) {
            ZStack {
                // Glass background
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)

                // Red gradient overlay
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.red.opacity(0.15),
                                Color.red.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Button content
                Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.red.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
        .accessibilityIdentifier("logoutButton")
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .modelContainer(for: [UserEntity.self], inMemory: true)
        .environmentObject(AuthViewModel())
}
