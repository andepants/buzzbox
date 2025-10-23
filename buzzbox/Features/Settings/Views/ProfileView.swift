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

    @State private var viewModel = ProfileViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profilePictureSection

                Divider()
                    .padding(.vertical)

                accountInfoSection

                Spacer()

                logoutButton
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "Failed to upload profile picture.")
        }
        .task {
            // Load profile on appear
            viewModel.loadCurrentProfile()
        }
    }

    // MARK: - Profile Picture Section

    private var profilePictureSection: some View {
        VStack(spacing: 12) {
            ZStack {
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
                            print("✅ Profile image loaded successfully")
                        }
                        .onFailure { error in
                            print("⚠️ Profile image failed to load: \(error)")
                        }
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                } else {
                    // Default placeholder
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.gray)
                }

                // Upload progress overlay
                if viewModel.isUploading {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 120, height: 120)

                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            .accessibilityLabel("Profile picture")
            .accessibilityHint("Double tap to change")

            // Change Photo Button
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("Change Photo", systemImage: "photo")
                    .font(.caption)
                    .foregroundColor(.blue)
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
    }

    // MARK: - Account Info Section

    private var accountInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Information")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 8) {
                // Username display
                HStack {
                    Text("Username:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                    HStack(spacing: 4) {
                        Text(authViewModel.currentUser?.displayName ?? viewModel.displayName)
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
                .accessibilityLabel("Username: \(authViewModel.currentUser?.displayName ?? viewModel.displayName)")

                Divider()

                // Email display
                HStack {
                    Text("Email:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
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
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding(.horizontal)
    }

    // MARK: - Logout Button

    private var logoutButton: some View {
        Button(role: .destructive, action: {
            Task {
                await authViewModel.logout(modelContext: modelContext)
            }
        }) {
            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(10)
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
}
