//
//  Place.swift
//  Pulse
//
//  Created by Jesse on 2026
//

import SwiftUI

enum Place: String, CaseIterable, Identifiable, Codable, Sendable {
    case conference
    case campus
    case cafe
    case hackathon

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .conference: return "person.3.fill"
        case .campus: return "building.columns.fill"
        case .cafe: return "cup.and.saucer.fill"
        case .hackathon: return "bolt.fill"
        }
    }
    
    var description: String {
        switch self {
        case .conference: return "Networking & talks"
        case .campus: return "Learning & research"
        case .cafe: return "Heads down coding"
        case .hackathon: return "Building rapidly"
        }
    }
    
    // Visual modulation properties
    var pulseSpeed: Double {
        switch self {
        case .conference: return 0.8 // Faster
        case .campus: return 2.0     // Stable/Slow
        case .cafe: return 3.0       // Very slow
        case .hackathon: return 0.5  // Rapid
        }
    }
    
    var ringTextureOpacity: Double {
        switch self {
        case .conference: return 0.3
        case .campus: return 0.15
        case .cafe: return 0.1
        case .hackathon: return 0.4
        }
    }
}
