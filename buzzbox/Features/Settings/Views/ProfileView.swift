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
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    profilePictureSection

                    Divider()
                        .padding(.vertical)

                    displayNameSection

                    Spacer()

                    saveButton

                    logoutButton
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Profile Updated", isPresented: $viewModel.showSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your profile has been updated successfully.")
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Failed to update profile.")
            }
            .task {
                // Load profile on appear
                viewModel.loadCurrentProfile()
            }
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
                        await viewModel.uploadProfileImage(uiImage)
                    }
                }
            }
        }
    }

    // MARK: - Display Name Section

    private var displayNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Username")
                .font(.caption)
                .foregroundColor(.gray)

            TextField("Username", text: $viewModel.displayName)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Username")
                .onChange(of: viewModel.displayName) { _, newValue in
                    Task {
                        await viewModel.checkDisplayNameAvailability(newValue)
                    }
                }

            // Availability indicator
            if viewModel.isCheckingAvailability {
                HStack {
                    ProgressView()
                        .frame(width: 20, height: 20)
                    Text("Checking availability...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } else if !viewModel.displayNameError.isEmpty {
                Text(viewModel.displayNameError)
                    .font(.caption)
                    .foregroundColor(.red)
            } else if viewModel.displayNameAvailable && !viewModel.displayName.isEmpty {
                Label("Available", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: {
            Task {
                await viewModel.updateProfile(modelContext: modelContext)
            }
        }) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(width: 20, height: 20)
                    Text("Saving...")
                } else {
                    Text("Save Changes")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.canSave ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(!viewModel.canSave || viewModel.isLoading)
        .padding(.horizontal)
        .accessibilityIdentifier("saveButton")
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
