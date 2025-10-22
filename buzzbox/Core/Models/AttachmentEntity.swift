/// AttachmentEntity.swift
///
/// SwiftData model for message attachments (images, videos, files).
/// Tracks upload status and stores local/remote URLs.
///
/// Created: 2025-10-20

import Foundation
import SwiftData

@Model
final class AttachmentEntity {
    // MARK: - Core Properties

    /// Unique attachment identifier
    @Attribute(.unique) var id: String

    /// Attachment type (image, video, audio, document)
    var type: AttachmentType

    /// Remote URL (Firebase Storage)
    var url: String?

    /// Local file URL (for offline access)
    var localURL: String?

    /// Thumbnail URL (for images/videos)
    var thumbnailURL: String?

    /// File size in bytes
    var fileSize: Int64

    /// MIME type
    var mimeType: String

    /// Original file name
    var fileName: String

    /// Upload status
    var uploadStatus: UploadStatus

    /// Upload progress (0.0 - 1.0)
    var uploadProgress: Double

    /// Upload error message (if failed)
    var uploadError: String?

    /// Creation timestamp
    var createdAt: Date

    // MARK: - Relationships

    /// Parent message (inverse relationship)
    @Relationship(deleteRule: .nullify, inverse: \MessageEntity.attachments)
    var message: MessageEntity?

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        type: AttachmentType,
        localURL: String,
        fileSize: Int64,
        mimeType: String,
        fileName: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.localURL = localURL
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.fileName = fileName
        self.uploadStatus = .pending
        self.uploadProgress = 0.0
        self.createdAt = createdAt
    }

    // MARK: - Helper Methods

    /// Update upload progress
    func updateUploadProgress(_ progress: Double) {
        self.uploadProgress = min(max(progress, 0.0), 1.0)
    }

    /// Mark upload as completed
    func markAsUploaded(url: String, thumbnailURL: String? = nil) {
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.uploadStatus = .completed
        self.uploadProgress = 1.0
        self.uploadError = nil
    }

    /// Mark upload as failed
    func markAsFailed(error: String) {
        self.uploadStatus = .failed
        self.uploadError = error
    }

    /// Check if attachment is ready to display
    var isAvailable: Bool {
        uploadStatus == .completed && url != nil
    }
}

// MARK: - Supporting Enums

enum AttachmentType: String, Codable {
    case image
    case video
    case audio
    case document
}

enum UploadStatus: String, Codable {
    case pending
    case uploading
    case completed
    case failed
}
