//
//  CreateChannelSheet.swift
//  Pulse
//
//  Created by Jesse on 2026
//

import SwiftUI

struct CreateChannelSheet: View {
    let precision: GeohashPrecision
    @Environment(\.dismiss) private var dismiss
    @State private var topic = ""
    @State private var themeManager = ThemeManager.shared
    @State private var geohashService = GeohashService.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Create Channel")
                            .font(.title2.bold())
                            .foregroundStyle(themeManager.colors.text)
                        
                        if let geohash = geohashService.currentGeohashes[precision] {
                            Text("at \(precision.displayName) level (\(geohash.uppercased()))")
                                .font(.subheadline)
                                .foregroundStyle(themeManager.colors.textSecondary)
                        }
                    }
                    .padding(.top, 24)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CHANNEL TOPIC (OPTIONAL)")
                            .font(.caption.bold())
                            .foregroundStyle(themeManager.colors.textSecondary)
                            .padding(.leading, 4)
                        
                        TextField("e.g. Swift Meetup, Coffee Chat", text: $topic)
                            .padding()
                            .background(themeManager.colors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(themeManager.colors.accent.opacity(0.3), lineWidth: 1)
                            )
                            .foregroundStyle(themeManager.colors.text)
                    }
                    .padding(.horizontal)
                    
                    Button {
                        createChannel()
                    } label: {
                        if geohashService.currentGeohashes[precision] == nil {
                            HStack {
                                ProgressView()
                                    .tint(.white)
                                Text("Getting Location...")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            Text(topic.isEmpty ? "Join Location Channel" : "Create Topic Channel")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(themeManager.colors.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .disabled(geohashService.currentGeohashes[precision] == nil)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(themeManager.colors.textSecondary)
                }
            }
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }
    
    private func createChannel() {
        if topic.isEmpty {
            geohashService.joinCurrentChannel()
        } else {
            geohashService.createChannel(topic: topic, precision: precision)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}
