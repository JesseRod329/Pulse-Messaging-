//
//  AvatarManager.swift
//  Pulse
//
//  Avatar management: storage, retrieval, and hashing for peer discovery.
//

import Foundation
import UIKit
import CryptoKit

@MainActor
final class AvatarManager {
    static let shared = AvatarManager()
    private init() {}

    // MARK: - Constants

    private static let avatarFileName = "profile_avatar.jpg"
    private static let avatarMaxSize: CGFloat = 100 // 100x100 display size
    private static let compressionQuality: CGFloat = 0.75

    // MARK: - File Management

    private var avatarDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var avatarPath: URL {
        avatarDirectory.appendingPathComponent(Self.avatarFileName)
    }

    // MARK: - Load Avatar

    /// Load profile avatar from disk
    func loadAvatar() -> UIImage? {
        guard FileManager.default.fileExists(atPath: avatarPath.path),
              let imageData = try? Data(contentsOf: avatarPath),
              let image = UIImage(data: imageData) else {
            return nil
        }
        return image
    }

    // MARK: - Save Avatar

    /// Save profile avatar to disk
    func saveAvatar(_ image: UIImage) -> Bool {
        // Compress to thumbnail size for consistency
        let thumbnail = resizeImage(image, to: Self.avatarMaxSize)

        guard let jpegData = thumbnail.jpegData(compressionQuality: Self.compressionQuality) else {
            return false
        }

        do {
            try jpegData.write(to: avatarPath)
            print("✅ Avatar saved: \(avatarPath.lastPathComponent)")
            return true
        } catch {
            print("❌ Failed to save avatar: \(error)")
            return false
        }
    }

    // MARK: - Remove Avatar

    /// Delete profile avatar
    func removeAvatar() -> Bool {
        guard FileManager.default.fileExists(atPath: avatarPath.path) else {
            return true
        }

        do {
            try FileManager.default.removeItem(at: avatarPath)
            print("🗑️ Avatar removed")
            return true
        } catch {
            print("❌ Failed to remove avatar: \(error)")
            return false
        }
    }

    // MARK: - Avatar Hash

    /// Generate SHA256 hash of avatar for peer discovery
    func getAvatarHash() -> String? {
        guard let imageData = try? Data(contentsOf: avatarPath) else {
            return nil
        }

        let digest = SHA256.hash(data: imageData)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Utilities

    /// Resize image while maintaining aspect ratio
    private func resizeImage(_ image: UIImage, to size: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { _ in
            let aspectRatio = image.size.width / image.size.height
            var drawRect = CGRect(origin: .zero, size: CGSize(width: size, height: size))

            if aspectRatio > 1 {
                // Wide image
                drawRect.size.height = size / aspectRatio
                drawRect.origin.y = (size - drawRect.height) / 2
            } else {
                // Tall image
                drawRect.size.width = size * aspectRatio
                drawRect.origin.x = (size - drawRect.width) / 2
            }

            image.draw(in: drawRect)
        }
    }
}
