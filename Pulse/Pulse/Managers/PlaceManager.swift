//
//  PlaceManager.swift
//  Pulse
//
//  Created by Jesse on 2026
//

import SwiftUI
import Combine

@MainActor
class PlaceManager: ObservableObject {
    static let shared = PlaceManager()
    
    @Published var currentPlace: Place? {
        didSet {
            savePlace()
            notifyMeshManager()
        }
    }
    @Published var showSelector = false
    @Published var showClearedToast = false
    
    private let storageKey = "userPlace"
    private let timestampKey = "userPlaceTimestamp"
    private let expirationInterval: TimeInterval = 6 * 60 * 60 // 6 hours
    
    private init() {
        restorePlace()
    }
    
    // MARK: - Actions
    
    func selectPlace(_ place: Place) {
        currentPlace = place
        showSelector = false
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    func clearPlace() {
        currentPlace = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: timestampKey)
    }
    
    // MARK: - Persistence & Expiration
    
    private func savePlace() {
        guard let place = currentPlace else { return }
        UserDefaults.standard.set(place.rawValue, forKey: storageKey)
        UserDefaults.standard.set(Date(), forKey: timestampKey)
    }
    
    private func restorePlace() {
        guard let rawValue = UserDefaults.standard.string(forKey: storageKey),
              let place = Place(rawValue: rawValue),
              let timestamp = UserDefaults.standard.object(forKey: timestampKey) as? Date else {
            return
        }
        
        if Date().timeIntervalSince(timestamp) > expirationInterval {
            print("🕒 Place context expired")
            clearPlace()
            showClearedToast = true
            
            // Auto-hide after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.showClearedToast = false
            }
        } else {
            currentPlace = place
        }
    }
    
    // MARK: - Broadcast
    
    private func notifyMeshManager() {
        // We need to tell MeshManager to update the advertisement
        // Since MeshManager is likely initialized already, we can use NotificationCenter
        // or access it via singleton if we refactor MeshManager to be a singleton or shared.
        // For now, let's assume MeshManager observes this or we post a notification.
        NotificationCenter.default.post(name: .didUpdatePlace, object: currentPlace)
    }
}

extension Notification.Name {
    static let didUpdatePlace = Notification.Name("didUpdatePlace")
}
