/// StorageService.swift
/// Handles Firebase Storage operations for profile pictures and media
/// [Source: Epic 1, Story 1.5]
///
/// Manages image uploads to Firebase Storage with automatic compression,
/// progress tracking, and HTTPS download URL retrieval for use with Kingfisher.

import Foundation
import FirebaseStorage
import FirebaseAuth
import UIKit

/// Manages Firebase Storage operations for images and media uploads
final class StorageService {
    // MARK: - Properties

    private let storage = Storage.storage()
    private let auth = Auth.auth()

    // MARK: - Public Methods

    /// Upload image to Firebase Storage and return publicly accessible download URL
    /// - Parameters:
    ///   - image: UIImage to upload
    ///   - path: Storage path (e.g., "profile_pictures/{userId}/profile.jpg")
    /// - Returns: HTTPS download URL (not gs:// reference URL)
    /// - Throws: StorageError if upload fails
    func uploadImage(_ image: UIImage, path: String) async throws -> URL {
        // 0. Verify user is authenticated (required by Storage Rules)
        guard let currentUser = auth.currentUser else {
            print("❌ [STORAGE] Upload failed: User not authenticated")
            throw StorageError.notAuthenticated
        }

        print("✅ [STORAGE] Starting upload for user: \(currentUser.uid)")
        print("📁 [STORAGE] Upload path: \(path)")

        // 1. Compress image to target quality and size
        guard let compressedImage = compressImage(image) else {
            print("❌ [STORAGE] Image compression failed")
            throw StorageError.imageCompressionFailed
        }

        print("✅ [STORAGE] Image compressed to \(compressedImage.count) bytes")

        // 2. Validate file size (5MB max enforced by Storage Rules)
        let maxSize = 5 * 1024 * 1024 // 5MB
        guard compressedImage.count <= maxSize else {
            print("❌ [STORAGE] File too large: \(compressedImage.count) bytes (max: \(maxSize) bytes)")
            throw StorageError.fileTooLarge
        }

        // 3. Create storage reference
        nonisolated(unsafe) let storageRef = storage.reference().child(path)
        print("📦 [STORAGE] Storage reference created: \(storageRef.fullPath)")

        // 4. Upload with metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.cacheControl = "public, max-age=31536000" // Cache for 1 year

        do {
            _ = try await storageRef.putData(compressedImage, metadata: metadata)
            print("✅ [STORAGE] Upload successful")
        } catch let error as NSError {
            print("❌ [STORAGE] Upload failed with error code: \(error.code)")
            print("❌ [STORAGE] Error domain: \(error.domain)")
            print("❌ [STORAGE] Error description: \(error.localizedDescription)")

            // Map Firebase Storage errors to user-friendly messages
            throw StorageError.uploadFailed(
                code: error.code,
                description: error.localizedDescription
            )
        }

        // 5. CRITICAL: Get download URL (HTTPS, not gs://) with retry logic
        // This URL is what we store in Firestore and use with Kingfisher
        // Firebase Storage may need time to propagate the file, so we retry with backoff
        var downloadURL: URL?
        var lastError: NSError?
        let maxAttempts = 5
        let baseDelay: UInt64 = 500_000_000 // 500ms in nanoseconds

        for attempt in 1...maxAttempts {
            do {
                downloadURL = try await storageRef.downloadURL()
                print("✅ [STORAGE] Download URL retrieved on attempt \(attempt): \(downloadURL!.absoluteString)")
                break
            } catch let error as NSError {
                lastError = error

                if attempt < maxAttempts {
                    // Exponential backoff: 500ms, 1s, 2s, 4s
                    let delay = baseDelay * UInt64(1 << (attempt - 1))
                    print("⚠️ [STORAGE] Download URL attempt \(attempt) failed, retrying in \(Double(delay) / 1_000_000_000)s...")
                    try await Task.sleep(nanoseconds: delay)
                } else {
                    print("❌ [STORAGE] Failed to get download URL after \(maxAttempts) attempts: \(error.localizedDescription)")
                    throw StorageError.downloadURLFailed(description: error.localizedDescription)
                }
            }
        }

        guard let finalURL = downloadURL else {
            throw StorageError.downloadURLFailed(description: lastError?.localizedDescription ?? "Unknown error")
        }

        // 6. Verify URL is HTTPS (required for Kingfisher & AsyncImage)
        guard finalURL.scheme == "https" else {
            print("❌ [STORAGE] Invalid URL scheme: \(finalURL.scheme ?? "nil")")
            throw StorageError.invalidDownloadURL
        }

        // 7. Verify URL is accessible with a HEAD request
        var urlAccessible = false
        for attempt in 1...3 {
            do {
                var request = URLRequest(url: finalURL)
                request.httpMethod = "HEAD"
                request.timeoutInterval = 10

                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    urlAccessible = true
                    print("✅ [STORAGE] URL accessibility verified on attempt \(attempt)")
                    break
                } else {
                    print("⚠️ [STORAGE] URL returned non-200 status on attempt \(attempt)")
                }
            } catch {
                print("⚠️ [STORAGE] URL accessibility check attempt \(attempt) failed: \(error.localizedDescription)")
            }

            if attempt < 3 {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            }
        }

        if !urlAccessible {
            print("⚠️ [STORAGE] Warning: URL accessibility check failed, but proceeding anyway")
        }

        print("🎉 [STORAGE] Upload complete! URL: \(finalURL.absoluteString)")
        return finalURL
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
    case notAuthenticated
    case imageCompressionFailed
    case fileTooLarge
    case invalidDownloadURL
    case uploadFailed(code: Int, description: String)
    case downloadURLFailed(description: String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to upload images. Please sign in and try again."
        case .imageCompressionFailed:
            return "Failed to compress image. Please try a different image."
        case .fileTooLarge:
            return "Image is too large. Maximum size is 5MB."
        case .invalidDownloadURL:
            return "Failed to get valid download URL from Firebase Storage."
        case .uploadFailed(let code, let description):
            return "Upload failed (code \(code)): \(description). Please check your internet connection and try again."
        case .downloadURLFailed(let description):
            return "Failed to retrieve image URL: \(description)"
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
