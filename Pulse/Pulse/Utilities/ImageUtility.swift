//
//  ImageUtility.swift
//  Pulse
//
//  Image compression, thumbnail generation, and size calculations.
//

import Foundation
import SwiftUI
import UIKit

final class ImageUtility: Sendable {
    static let shared = ImageUtility()
    private init() {}

    // MARK: - Constants

    private static let maxImageSize: Int = 1_000_000 // 1MB max
    private static let thumbnailSize: CGFloat = 100 // 100x100 thumbnail
    private static let compressionQuality: CGFloat = 0.75

    // MARK: - Image Compression

    /// Compress image to max size and return as base64
    func compressImage(_ uiImage: UIImage, maxBytes: Int? = nil) -> (data: Data, quality: CGFloat)? {
        let limit = maxBytes ?? Self.maxImageSize
        var quality: CGFloat = Self.compressionQuality

        // Progressive compression
        while quality > 0.1 {
            if let jpegData = uiImage.jpegData(compressionQuality: quality) {
                if jpegData.count <= limit {
                    return (jpegData, quality)
                }
            }
            quality -= 0.1
        }

        return nil
    }

    /// Generate thumbnail for image (100x100)
    func generateThumbnail(_ uiImage: UIImage) -> UIImage? {
        let size = CGSize(width: Self.thumbnailSize, height: Self.thumbnailSize)

        let renderer = UIGraphicsImageRenderer(size: size)
        let thumbnail = renderer.image { _ in
            let aspectRatio = uiImage.size.width / uiImage.size.height
            var drawRect = CGRect(origin: .zero, size: size)

            if aspectRatio > 1 {
                // Wide image
                drawRect.size.height = size.width / aspectRatio
                drawRect.origin.y = (size.height - drawRect.height) / 2
            } else {
                // Tall image
                drawRect.size.width = size.height * aspectRatio
                drawRect.origin.x = (size.width - drawRect.width) / 2
            }

            uiImage.draw(in: drawRect)
        }

        return thumbnail
    }

    /// Get image dimensions
    func getDimensions(_ uiImage: UIImage) -> (width: Int, height: Int) {
        let size = uiImage.size
        return (Int(size.width), Int(size.height))
    }

    /// Convert image to base64 for transmission
    func toBase64(_ imageData: Data) -> String {
        imageData.base64EncodedString()
    }

    /// Convert base64 back to UIImage
    func fromBase64(_ base64String: String) -> UIImage? {
        guard let imageData = Data(base64Encoded: base64String) else { return nil }
        return UIImage(data: imageData)
    }

    /// Format file size for display
    static func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}