//
//  ProfileView.swift
//  Pulse
//
//  User profile customization view.
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var themeManager = ThemeManager.shared

    // Profile state
    @AppStorage("handle") private var handle = ""
    @AppStorage("statusMessage") private var statusMessage = ""
    @AppStorage("userStatus") private var userStatus = 0
    @AppStorage("lightningAddress") private var lightningAddress = ""

    @State private var editingHandle = ""
    @State private var editingStatusMessage = ""
    @State private var editingLightningAddress = ""
    @State private var selectedTechStack: Set<String> = []
    @State private var showContent = false
    @State private var avatarScale: CGFloat = 0.8
    @State private var didCopyIdentity = false

    // Photo picker state
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var showPhotoOptions = false

    private let availableTech = ["Swift", "Python", "JavaScript", "Rust", "Go", "TypeScript", "Java", "Kotlin", "C++", "Ruby", "PHP", "Scala"]

    private let statusOptions = [
        (0, "Active", "Open to chat", "circle.fill", Color.green),
        (1, "Flow State", "Deep work mode", "bolt.fill", Color.orange),
        (2, "Idle", "Away", "moon.fill", Color.gray)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar section
                    avatarSection
                        .scaleEffect(avatarScale)
                        .opacity(showContent ? 1 : 0)

                    // Handle section
                    handleSection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)

                    // Status section
                    statusSection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)

                    // Tech stack section
                    techStackSection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)

                    // Lightning section
                    lightningSection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)

                    // Identity section
                    identitySection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                }
                .padding()
            }
            .background(themeManager.colors.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        dismiss()
                    }
                    .foregroundStyle(themeManager.colors.textSecondary)
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Discards changes and closes profile")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .foregroundStyle(themeManager.colors.accent)
                    .fontWeight(.semibold)
                    .accessibilityLabel("Save")
                    .accessibilityHint("Saves your profile changes")
                }
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .onAppear {
            editingHandle = handle
            editingStatusMessage = statusMessage
            editingLightningAddress = lightningAddress
            loadTechStack()
            loadProfileImage()

            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                avatarScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                showContent = true
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        withAnimation(.spring(response: 0.3)) {
                            profileImage = image
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
        }
        .confirmationDialog("Profile Photo", isPresented: $showPhotoOptions, titleVisibility: .visible) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Text("Choose from Library")
            }

            if profileImage != nil {
                Button("Remove Photo", role: .destructive) {
                    withAnimation {
                        profileImage = nil
                        removeProfileImage()
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }

            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        VStack(spacing: 16) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showPhotoOptions = true
            } label: {
                ZStack {
                    // Glow
                    Circle()
                        .fill(themeManager.colors.accentGlow)
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)

                    // Avatar - show image if available, otherwise gradient with initials
                    if let image = profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [themeManager.colors.accent, themeManager.colors.secondary],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 3
                                    )
                            )
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [themeManager.colors.accent, themeManager.colors.secondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)

                        // Initials
                        Text(avatarInitials)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    // Edit badge
                    Circle()
                        .fill(themeManager.colors.background)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .fill(themeManager.colors.accent)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: profileImage == nil ? "camera.fill" : "pencil")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                )
                        )
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                        .offset(x: 35, y: 35)
                }
            }
            .buttonStyle(.plain)

            Text("@\(editingHandle.isEmpty ? "handle" : editingHandle)")
                .font(.pulseHandle)
                .foregroundStyle(themeManager.colors.text)

            Text("Tap to change photo")
                .font(.pulseCaption)
                .foregroundStyle(themeManager.colors.textSecondary.opacity(0.7))
        }
        .padding(.vertical)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Profile photo for \(editingHandle.isEmpty ? "your handle" : editingHandle)")
        .accessibilityHint("Double tap to change your profile photo")
        .accessibilityAddTraits(.isButton)
    }

    private var avatarInitials: String {
        let cleaned = editingHandle.replacingOccurrences(of: "@", with: "")
        if cleaned.isEmpty { return "?" }
        return String(cleaned.prefix(2)).uppercased()
    }

    // MARK: - Handle Section

    private var handleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Handle", icon: "at")

            TextField("your_handle", text: $editingHandle)
                .font(.pulseHandle)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding()
                .background(themeManager.colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(themeManager.colors.accent.opacity(0.3), lineWidth: 1)
                )
                .accessibilityLabel("Handle")
                .accessibilityHint("Enter your username, 2 to 20 characters")

            TextField("Status message (optional)", text: $editingStatusMessage)
                .font(.pulseBodySecondary)
                .padding()
                .background(themeManager.colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Status message")
                .accessibilityHint("Optional message shown to other developers")
        }
        .padding()
        .background(themeManager.colors.cardBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Status", icon: "circle.fill")

            VStack(spacing: 8) {
                ForEach(statusOptions, id: \.0) { status in
                    statusRow(
                        value: status.0,
                        title: status.1,
                        subtitle: status.2,
                        icon: status.3,
                        color: status.4
                    )
                }
            }
        }
        .padding()
        .background(themeManager.colors.cardBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statusRow(value: Int, title: String, subtitle: String, icon: String, color: Color) -> some View {
        let isSelected = userStatus == value

        return Button {
            // Haptic feedback
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()

            withAnimation(.spring(response: 0.3)) {
                userStatus = value
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(themeManager.colors.text)
                    Text(subtitle)
                        .font(.pulseCaption)
                        .foregroundStyle(themeManager.colors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(themeManager.colors.accent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding()
            .background(isSelected ? themeManager.colors.accent.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(isSelected ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) status")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(subtitle)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Tech Stack Section

    private var techStackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Tech Stack", icon: "chevron.left.forwardslash.chevron.right")

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(availableTech, id: \.self) { tech in
                    techChip(tech)
                }
            }
        }
        .padding()
        .background(themeManager.colors.cardBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func techChip(_ tech: String) -> some View {
        let isSelected = selectedTechStack.contains(tech)

        return Button {
            // Haptic feedback
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()

            withAnimation(.spring(response: 0.2)) {
                if isSelected {
                    selectedTechStack.remove(tech)
                } else {
                    selectedTechStack.insert(tech)
                }
            }
        } label: {
            Text(tech)
                .font(.pulseCaption)
                .foregroundStyle(isSelected ? themeManager.colors.background : themeManager.colors.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? themeManager.colors.accent : themeManager.colors.cardBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? Color.clear : themeManager.colors.textSecondary.opacity(0.3),
                            lineWidth: 1
                        )
                )
                .scaleEffect(isSelected ? 1.05 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tech)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to \(isSelected ? "remove" : "add") \(tech) to your tech stack")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Lightning Section

    private var lightningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Lightning", icon: "bolt.fill")

            TextField("you@getalby.com", text: $editingLightningAddress)
                .font(.pulseBodySecondary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .padding()
                .background(themeManager.colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(themeManager.colors.accent.opacity(0.3), lineWidth: 1)
                )
                .accessibilityLabel("Lightning Address")
                .accessibilityHint("Enter your Lightning Address to receive zaps")
                .privacySensitiveIfAvailable()

            Text("Your Lightning Address allows others to send you sats via zaps. Supports NIP-57.")
                .font(.pulseCaption)
                .foregroundStyle(themeManager.colors.textSecondary)

            // Nostr identity info
            if let nostrIdentity = NostrIdentityManager.shared.nostrIdentity {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Nostr npub")
                            .font(.caption)
                            .foregroundStyle(themeManager.colors.textSecondary)
                        Spacer()
                        Text(String(nostrIdentity.npub.prefix(20)) + "...")
                            .font(.caption.monospaced())
                            .foregroundStyle(themeManager.colors.text)
                            .privacySensitiveIfAvailable()

                        Button {
                            // SECURITY: Use ClipboardManager with auto-clear for Nostr public key
                            ClipboardManager.shared.copy(nostrIdentity.npub, sensitive: true)
                            HapticManager.shared.notify(.success)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(themeManager.colors.accent)
                        }
                    }
                }
                .padding()
                .background(themeManager.colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(themeManager.colors.cardBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Identity Section

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Cryptographic Identity", icon: "key.fill")

            VStack(alignment: .leading, spacing: 8) {
                if let identity = IdentityManager.shared.currentIdentity {
                    HStack {
                        Text("DID")
                            .font(.caption)
                            .foregroundStyle(themeManager.colors.textSecondary)
                        Spacer()
                        Text(String(identity.did.prefix(24)) + "...")
                            .font(.caption.monospaced())
                            .foregroundStyle(themeManager.colors.text)
                            .privacySensitiveIfAvailable()

                        Button {
                            // SECURITY: Use ClipboardManager with auto-clear for DID
                            ClipboardManager.shared.copy(identity.did, sensitive: true)
                            HapticManager.shared.notify(.success)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(themeManager.colors.accent)
                        }
                        .accessibilityLabel("Copy DID")
                        .accessibilityHint("Copies your decentralized identifier to clipboard")
                    }

                    Divider().background(themeManager.colors.textSecondary.opacity(0.2))

                    HStack {
                        Text("Created")
                            .font(.caption)
                            .foregroundStyle(themeManager.colors.textSecondary)
                        Spacer()
                        Text(identity.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(themeManager.colors.text)
                    }
                } else {
                    Text("No identity generated")
                        .font(.pulseCaption)
                        .foregroundStyle(themeManager.colors.textSecondary)
                }
            }
            .padding()
            .background(themeManager.colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("Your cryptographic identity is used for E2E encryption. It's stored securely in your device's Keychain.")
                .font(.pulseCaption)
                .foregroundStyle(themeManager.colors.textSecondary)
        }
        .padding()
        .background(themeManager.colors.cardBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(themeManager.colors.accent)
            Text(title)
                .font(.pulseSectionHeader)
                .foregroundStyle(themeManager.colors.text)
        }
    }

    private func loadTechStack() {
        if let saved = UserDefaults.standard.stringArray(forKey: "techStack") {
            selectedTechStack = Set(saved)
        }
    }

    private func loadProfileImage() {
        profileImage = AvatarManager.shared.loadAvatar()
    }

    private func saveProfileImage() {
        if let image = profileImage {
            _ = AvatarManager.shared.saveAvatar(image)
        }
    }

    private func removeProfileImage() {
        _ = AvatarManager.shared.removeAvatar()
    }

    private func saveProfile() {
        // Success haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        handle = editingHandle
        statusMessage = editingStatusMessage
        lightningAddress = editingLightningAddress
        UserDefaults.standard.set(Array(selectedTechStack), forKey: "techStack")

        // Save profile image
        if profileImage != nil {
            saveProfileImage()
        }

        // Publish Nostr metadata if Lightning address is set
        if !editingLightningAddress.isEmpty {
            Task {
                try? await NostrTransport.shared.publishMetadata(
                    name: editingHandle,
                    lightningAddress: editingLightningAddress
                )
            }
        }

        dismiss()
    }
}

// MARK: - Profile Image Helper

struct ProfileImageView: View {
    let size: CGFloat
    let handle: String

    @State private var profileImage: UIImage?
    @State private var themeManager = ThemeManager.shared

    var body: some View {
        SwiftUI.Group {
            if let image = profileImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [themeManager.colors.accent, themeManager.colors.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Text(initials)
                            .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    )
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private var initials: String {
        let cleaned = handle.replacingOccurrences(of: "@", with: "")
        if cleaned.isEmpty { return "?" }
        return String(cleaned.prefix(2)).uppercased()
    }

    private func loadImage() {
        profileImage = AvatarManager.shared.loadAvatar()
    }
}

#Preview {
    ProfileView()
}
