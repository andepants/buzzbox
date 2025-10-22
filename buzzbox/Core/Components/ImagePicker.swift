/// ImagePicker.swift
///
/// UIViewControllerRepresentable wrapper for UIImagePickerController.
/// Provides native iOS photo picker for selecting images from the photo library.
///
/// Usage:
/// ```swift
/// @State private var selectedImage: UIImage?
/// @State private var showPicker = false
///
/// Button("Select Photo") { showPicker = true }
/// .sheet(isPresented: $showPicker) {
///     ImagePicker(image: $selectedImage)
/// }
/// ```
///
/// Created: 2025-10-22

import SwiftUI
import UIKit
import PhotosUI

/// SwiftUI wrapper for UIImagePickerController
struct ImagePicker: UIViewControllerRepresentable {
    // MARK: - Properties

    /// Binding to selected image
    @Binding var image: UIImage?

    /// Environment dismiss action
    @Environment(\.dismiss) private var dismiss

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        /// Handle image selection
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // Try to get edited image first, fallback to original
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }

            parent.dismiss()
        }

        /// Handle picker cancellation
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedImage: UIImage?
        @State private var showPicker = false

        var body: some View {
            VStack(spacing: 20) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 200)
                        .overlay {
                            Text("No Image")
                                .foregroundColor(.secondary)
                        }
                }

                Button("Select Photo") {
                    showPicker = true
                }
                .buttonStyle(.borderedProminent)
            }
            .sheet(isPresented: $showPicker) {
                ImagePicker(image: $selectedImage)
            }
        }
    }

    return PreviewWrapper()
}
