/// StorageService.swift
/// Handles Firebase Storage operations for profile pictures and media
/// [Source: Epic 1, Story 1.5]
///
/// Manages image uploads to Firebase Storage with automatic compression,
/// progress tracking, and HTTPS download URL retrieval for use with Kingfisher.

import Foundation
import FirebaseStorage
import UIKit

/// Manages Firebase Storage operations for images and media uploads
final class StorageService {
    // MARK: - Properties

    private let storage = Storage.storage()

    // MARK: - Public Methods

    /// Upload image to Firebase Storage and return publicly accessible download URL
    /// - Parameters:
    ///   - image: UIImage to upload
    ///   - path: Storage path (e.g., "profile_pictures/{userId}/profile.jpg")
    /// - Returns: HTTPS download URL (not gs:// reference URL)
    /// - Throws: StorageError if upload fails
    func uploadImage(_ image: UIImage, path: String) async throws -> URL {
        // 1. Compress image to target quality and size
        guard let compressedImage = compressImage(image) else {
            throw StorageError.imageCompressionFailed
        }

        // 2. Validate file size (5MB max enforced by Storage Rules)
        let maxSize = 5 * 1024 * 1024 // 5MB
        guard compressedImage.count <= maxSize else {
            throw StorageError.fileTooLarge
        }

        // 3. Create storage reference
        nonisolated(unsafe) let storageRef = storage.reference().child(path)

        // 4. Upload with metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.cacheControl = "public, max-age=31536000" // Cache for 1 year

        _ = try await storageRef.putData(compressedImage, metadata: metadata)

        // 5. CRITICAL: Get download URL (HTTPS, not gs://)
        // This URL is what we store in Firestore and use with Kingfisher
        let downloadURL = try await storageRef.downloadURL()

        // 6. Verify URL is HTTPS (required for Kingfisher & AsyncImage)
        guard downloadURL.scheme == "https" else {
            throw StorageError.invalidDownloadURL
        }

        return downloadURL
    }

    /// Upload group photo to Firebase Storage
    /// - Parameters:
    ///   - image: UIImage to upload
    ///   - groupID: Group conversation ID
    /// - Returns: HTTPS download URL
    /// - Throws: StorageError if upload fails
    func uploadGroupPhoto(_ image: UIImage, groupID: String) async throws -> String {
        let path = "group_photos/\(groupID)/photo.jpg"
        let downloadURL = try await uploadImage(image, path: path)
        return downloadURL.absoluteString
    }

    /// Delete image from Firebase Storage
    /// - Parameter path: Storage path (e.g., "profile_pictures/{userId}/profile.jpg")
    /// - Throws: Firebase Storage errors
    func deleteImage(at path: String) async throws {
        nonisolated(unsafe) let storageRef = storage.reference().child(path)
        try await storageRef.delete()
    }

    // MARK: - Private Methods

    /// Compress image to target size and quality
    /// - Parameter image: UIImage to compress
    /// - Returns: Compressed JPEG data
    private func compressImage(_ image: UIImage) -> Data? {
        // Target: 2048x2048 max dimension, 85% JPEG quality, < 500KB
        let maxDimension: CGFloat = 2048
        let targetSize: Int = 500 * 1024 // 500KB

        // Resize if needed
        let resizedImage = image.resized(toMaxDimension: maxDimension)

        // Start with 85% quality
        var quality: CGFloat = 0.85
        var imageData = resizedImage.jpegData(compressionQuality: quality)

        // Reduce quality if still too large
        while let data = imageData, data.count > targetSize && quality > 0.1 {
            quality -= 0.1
            imageData = resizedImage.jpegData(compressionQuality: quality)
        }

        return imageData
    }
}

// MARK: - Storage Error

/// Errors that can occur during Firebase Storage operations
enum StorageError: Error, LocalizedError {
    case imageCompressionFailed
    case fileTooLarge
    case invalidDownloadURL

    var errorDescription: String? {
        switch self {
        case .imageCompressionFailed:
            return "Failed to compress image. Please try a different image."
        case .fileTooLarge:
            return "Image is too large. Maximum size is 5MB."
        case .invalidDownloadURL:
            return "Failed to get valid download URL from Firebase Storage."
        }
    }
}

// MARK: - UIImage Extension

extension UIImage {
    /// Resize image to maximum dimension while maintaining aspect ratio
    /// - Parameter maxDimension: Maximum width or height in pixels
    /// - Returns: Resized UIImage
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let scale = max(size.width, size.height) / maxDimension
        if scale <= 1 { return self }

        let newSize = CGSize(width: size.width / scale, height: size.height / scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()

        return resizedImage
    }
}
