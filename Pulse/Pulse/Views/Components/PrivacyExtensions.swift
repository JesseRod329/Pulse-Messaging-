//
//  PrivacyExtensions.swift
//  Pulse
//
//  Helpers for privacy-sensitive UI redaction.
//

import SwiftUI

extension View {
    @ViewBuilder
    func privacySensitiveIfAvailable() -> some View {
        if #available(iOS 15.0, *) {
            self.privacySensitive()
        } else {
            self
        }
    }
}
