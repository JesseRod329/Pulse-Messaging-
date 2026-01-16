//
//  PlaceComponents.swift
//  Pulse
//
//  Created by Jesse on 2026
//

import SwiftUI

struct PlacePillView: View {
    @ObservedObject var placeManager = PlaceManager.shared
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                placeManager.showSelector = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: placeManager.currentPlace?.icon ?? "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .semibold))
                
                Text(placeManager.currentPlace?.title ?? "Set place")
                    .font(.pulseLabel)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                    
                    if placeManager.currentPlace != nil {
                        Capsule()
                            .fill(Color.blue.opacity(0.15))
                    }
                    
                    Capsule()
                        .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                }
            )
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            .overlay(
                SwiftUI.Group {
                    if placeManager.showClearedToast {
                        Text("Place cleared")
                            .font(.pulseCaption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.gray.opacity(0.8)))
                            .transition(.opacity.combined(with: .scale))
                            .offset(y: 40)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

struct PlaceSelectorView: View {
    @ObservedObject var placeManager = PlaceManager.shared
    @State private var feedbackText: String? = nil
    
    var body: some View {
        VStack(spacing: 24) {
            // Indicator handle
            RoundedRectangle(cornerRadius: 2)
                .fill(.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
            
            VStack(spacing: 8) {
                Text("Where are you?")
                    .font(.pulseSectionHeader)
                    .foregroundStyle(.white)
                
                Text("Your place adds context to your presence")
                    .font(.pulseCaption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 8)
            
            // Grid of places
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(Place.allCases) {
                    place in
                    PlaceCard(
                        place: place,
                        isSelected: placeManager.currentPlace == place,
                        action: {
                            selectPlace(place)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            
            if placeManager.currentPlace != nil {
                Button(action: {
                    withAnimation {
                        placeManager.clearPlace()
                    }
                }) {
                    Text("Clear place")
                        .font(.pulseLabel)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .padding(.bottom, 40)
        .background(
            ZStack {
                Color.black.opacity(0.8)
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
            .ignoresSafeArea()
        )
        .overlay(
            SwiftUI.Group {
                if let text = feedbackText {
                    Text(text)
                        .font(.pulseLabel)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.blue))
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .offset(y: -100)
                }
            }
        )
    }
    
    private func selectPlace(_ place: Place) {
        placeManager.selectPlace(place)
        
        feedbackText = "You are visible as \"\(place.title)\""
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                feedbackText = nil
            }
        }
    }
}

struct PlaceCard: View {
    let place: Place
    let isSelected: Bool
    let action: () -> Void
    
    @State private var animate = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue.opacity(0.2) : Color.white.opacity(0.05))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: place.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? .blue : .white)
                        .scaleEffect(animate ? 1.1 : 1.0)
                }
                
                VStack(spacing: 4) {
                    Text(place.title)
                        .font(.pulseLabel)
                        .foregroundStyle(.white)
                    
                    Text(place.description)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(isSelected ? Color.blue.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            if isSelected {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
        }
    }
}

#Preview {
    PlaceSelectorView()
}
