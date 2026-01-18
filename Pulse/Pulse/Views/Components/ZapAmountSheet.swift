//
//  ZapAmountSheet.swift
//  Pulse
//
//  Bottom sheet for selecting zap amount before sending.
//

import SwiftUI

struct ZapAmountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var themeManager = ThemeManager.shared

    let recipientHandle: String
    let lightningAddress: String
    let onZap: (Int, String?) -> Void

    @State private var selectedAmount: Int = 1000
    @State private var customAmount: String = ""
    @State private var comment: String = ""
    @State private var showCustomInput = false

    private let presetAmounts = ZapAmount.allCases

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                zapHeader

                // Amount grid
                amountGrid

                // Custom amount input
                if showCustomInput {
                    customAmountInput
                }

                // Comment input
                commentInput

                // Zap button
                zapButton

                Spacer()
            }
            .padding()
            .background(themeManager.colors.background)
            .navigationTitle("Zap \(recipientHandle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Components

    private var zapHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            Text(lightningAddress)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var amountGrid: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(presetAmounts, id: \.rawValue) { amount in
                    AmountButton(
                        amount: amount.rawValue,
                        displayName: amount.displayName,
                        isSelected: selectedAmount == amount.rawValue && !showCustomInput,
                        onTap: {
                            selectedAmount = amount.rawValue
                            showCustomInput = false
                            HapticManager.shared.selection()
                        }
                    )
                }
            }

            // Custom amount toggle
            Button(action: {
                showCustomInput.toggle()
                if showCustomInput {
                    customAmount = ""
                }
            }) {
                HStack {
                    Image(systemName: showCustomInput ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(showCustomInput ? .blue : .secondary)
                    Text("Custom amount")
                        .font(.subheadline)
                }
                .foregroundStyle(.primary)
            }
            .padding(.top, 8)
        }
    }

    private var customAmountInput: some View {
        HStack {
            TextField("Amount in sats", text: $customAmount)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .onChange(of: customAmount) { _, newValue in
                    if let amount = Int(newValue), amount > 0 {
                        selectedAmount = amount
                    }
                }

            Text("sats")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var commentInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Comment (optional)")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Add a message...", text: $comment)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var zapButton: some View {
        Button(action: {
            onZap(selectedAmount, comment.isEmpty ? nil : comment)
            dismiss()
        }) {
            HStack {
                Image(systemName: "bolt.fill")
                Text("Zap \(selectedAmount.formattedSats) sats")
            }
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.yellow)
            .cornerRadius(12)
        }
    }
}

// MARK: - Amount Button

struct AmountButton: View {
    let amount: Int
    let displayName: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(displayName)
                    .font(.headline)
                Text("sats")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(isSelected ? Color.yellow.opacity(0.3) : Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .foregroundStyle(.primary)
    }
}

#Preview {
    ZapAmountSheet(
        recipientHandle: "alice",
        lightningAddress: "alice@getalby.com"
    ) { amount, comment in
        print("Zapping \(amount) sats with comment: \(comment ?? "none")")
    }
}
