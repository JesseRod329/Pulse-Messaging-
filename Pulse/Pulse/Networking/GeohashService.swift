//
//  GeohashService.swift
//  Pulse
//
//  Geohash-based location channels inspired by BitChat.
//  Enables location-based chat rooms at various precision levels.
//

import Foundation
import CoreLocation
import MapKit

/// Geohash precision levels for different ranges
enum GeohashPrecision: Int, CaseIterable, Identifiable {
    case region = 2       // ~1250km - Country/region level
    case province = 3     // ~156km - State/province level
    case city = 4         // ~39km - City level
    case neighborhood = 5 // ~5km - Neighborhood level
    case block = 6        // ~1.2km - Block level
    case street = 7       // ~150m - Street level
    case venue = 8        // ~38m - Venue level

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .region: return "Region"
        case .province: return "Province"
        case .city: return "City"
        case .neighborhood: return "Neighborhood"
        case .block: return "Block"
        case .street: return "Street"
        case .venue: return "Venue"
        }
    }

    var range: String {
        switch self {
        case .region: return "~1250km"
        case .province: return "~156km"
        case .city: return "~39km"
        case .neighborhood: return "~5km"
        case .block: return "~1.2km"
        case .street: return "~150m"
        case .venue: return "~38m"
        }
    }

    var emoji: String {
        switch self {
        case .region: return "🌍"
        case .province: return "🏞️"
        case .city: return "🏙️"
        case .neighborhood: return "🏘️"
        case .block: return "🏢"
        case .street: return "🛣️"
        case .venue: return "📍"
        }
    }
}

/// Geohash encoding/decoding utility
struct Geohash {
    private static let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")

    /// Encode a location to geohash
    static func encode(latitude: Double, longitude: Double, precision: Int = 6) -> String {
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var geohash = ""
        var bits = 0
        var currentChar = 0
        var isEven = true

        while geohash.count < precision {
            if isEven {
                let mid = (lonRange.0 + lonRange.1) / 2
                if longitude >= mid {
                    currentChar |= (1 << (4 - bits))
                    lonRange.0 = mid
                } else {
                    lonRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if latitude >= mid {
                    currentChar |= (1 << (4 - bits))
                    latRange.0 = mid
                } else {
                    latRange.1 = mid
                }
            }

            isEven.toggle()
            bits += 1

            if bits == 5 {
                geohash.append(base32[currentChar])
                bits = 0
                currentChar = 0
            }
        }

        return geohash
    }

    /// Decode a geohash to approximate location
    static func decode(_ geohash: String) -> (latitude: Double, longitude: Double)? {
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var isEven = true

        for char in geohash.lowercased() {
            guard let index = base32.firstIndex(of: char) else { return nil }
            let bits = Int(base32.distance(from: base32.startIndex, to: index))

            for i in (0..<5).reversed() {
                let bit = (bits >> i) & 1
                if isEven {
                    let mid = (lonRange.0 + lonRange.1) / 2
                    if bit == 1 {
                        lonRange.0 = mid
                    } else {
                        lonRange.1 = mid
                    }
                } else {
                    let mid = (latRange.0 + latRange.1) / 2
                    if bit == 1 {
                        latRange.0 = mid
                    } else {
                        latRange.1 = mid
                    }
                }
                isEven.toggle()
            }
        }

        return (
            latitude: (latRange.0 + latRange.1) / 2,
            longitude: (lonRange.0 + lonRange.1) / 2
        )
    }

    /// Get all geohashes at different precision levels
    static func allPrecisions(latitude: Double, longitude: Double) -> [GeohashPrecision: String] {
        var result: [GeohashPrecision: String] = [:]
        for precision in GeohashPrecision.allCases {
            result[precision] = encode(latitude: latitude, longitude: longitude, precision: precision.rawValue)
        }
        return result
    }

    /// Get neighboring geohashes (for expanded coverage)
    static func neighbors(_ geohash: String) -> [String] {
        guard let center = decode(geohash) else { return [] }

        // Approximate size based on precision
        let precision = geohash.count
        let latDelta = 180.0 / pow(2.0, Double(precision * 5 / 2))
        let lonDelta = 360.0 / pow(2.0, Double((precision * 5 + 1) / 2))

        var neighbors: [String] = []
        for dLat in [-1, 0, 1] {
            for dLon in [-1, 0, 1] {
                if dLat == 0 && dLon == 0 { continue }
                let newLat = center.latitude + Double(dLat) * latDelta
                let newLon = center.longitude + Double(dLon) * lonDelta
                neighbors.append(encode(latitude: newLat, longitude: newLon, precision: precision))
            }
        }
        return neighbors
    }
}

/// Location channel for geohash-based chat
struct LocationChannel: Identifiable, Codable {
    let id: String  // geohash or geohash#topic
    let precision: Int
    var participantCount: Int
    var lastActivity: Date
    var displayName: String?

    init(id: String, displayName: String? = nil) {
        self.id = id
        // Extract pure geohash for precision calculation
        let pureGeohash = id.components(separatedBy: "#").first ?? id
        self.precision = pureGeohash.count
        self.participantCount = 0
        self.lastActivity = Date()
        self.displayName = displayName
    }
    
    var geohash: String {
        id.components(separatedBy: "#").first ?? id
    }
    
    var topic: String? {
        let components = id.components(separatedBy: "#")
        return components.count > 1 ? components.last : nil
    }

    var precisionLevel: GeohashPrecision? {
        GeohashPrecision(rawValue: precision)
    }
}

/// Geohash service for location-based features
@MainActor
final class GeohashService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = GeohashService()

    private let locationManager = CLLocationManager()

    @Published var currentLocation: CLLocation?
    @Published var currentGeohashes: [GeohashPrecision: String] = [:]
    @Published var activeChannels: [LocationChannel] = []
    @Published var selectedPrecision: GeohashPrecision = .neighborhood

    @Published var locationPermissionStatus: CLAuthorizationStatus = .notDetermined

    private let nostrTransport = NostrTransport.shared

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Request location permission
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Start tracking location
    func startTracking() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        locationManager.startUpdatingLocation()
    }

    /// Stop tracking location
    func stopTracking() {
        locationManager.stopUpdatingLocation()
    }

    /// Join a location channel at the selected precision
    func joinCurrentChannel() {
        guard let geohash = currentGeohashes[selectedPrecision] else { return }
        joinChannel(id: geohash)
    }
    
    /// Create a new channel with an optional topic
    func createChannel(topic: String, precision: GeohashPrecision) {
        guard let geohash = currentGeohashes[precision] else { return }
        
        let id = "\(geohash)#\(topic)"
        joinChannel(id: id, displayName: topic)
    }

    /// Join a specific channel
    func joinChannel(id: String, displayName: String? = nil) {
        // Check if already joined
        if activeChannels.contains(where: { $0.id == id }) { return }

        var channel = LocationChannel(id: id, displayName: displayName)
        let geohash = channel.geohash

        // Try to get a display name from reverse geocoding if no custom name provided
        if displayName == nil, let location = currentLocation {
            Task {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = geohash 
                
                let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
                request.region = region
                
                do {
                    let search = MKLocalSearch(request: request)
                    if let response = try? await search.start(), let mapItem = response.mapItems.first {
                        channel.displayName = mapItem.name
                        
                        // Update channel if already added
                        if let index = self.activeChannels.firstIndex(where: { $0.id == id }) {
                            self.activeChannels[index].displayName = channel.displayName
                        }
                    }
                }
            }
        }

        activeChannels.append(channel)

        // Subscribe via Nostr (using the full ID allows topic separation if transport supports it)
        nostrTransport.subscribeToChannel(geohash: id)
        
        // Post notification for UI feedback
        NotificationCenter.default.post(name: .didJoinChannel, object: displayName ?? geohash)
    }

    /// Leave a channel
    func leaveChannel(id: String) {
        activeChannels.removeAll { $0.id == id }
        nostrTransport.unsubscribeFromChannel(geohash: id)
    }

    /// Update channel activity
    func updateChannelActivity(id: String, participantCount: Int? = nil) {
        guard let index = activeChannels.firstIndex(where: { $0.id == id }) else { return }
        activeChannels[index].lastActivity = Date()
        if let count = participantCount {
            activeChannels[index].participantCount = count
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            currentLocation = location
            currentGeohashes = Geohash.allPrecisions(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        Task { @MainActor in
            locationPermissionStatus = status

            if status == .authorizedWhenInUse || status == .authorizedAlways {
                startTracking()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}

extension Notification.Name {
    static let didJoinChannel = Notification.Name("didJoinChannel")
}
