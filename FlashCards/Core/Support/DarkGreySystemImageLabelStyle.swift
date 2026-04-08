//
//  DarkGreySystemImageLabelStyle.swift
//  FlashCards
//

import SwiftUI

/// Renders the SF Symbol in dark grey (adaptive) and keeps the title at primary emphasis.
struct DarkGreySystemImageLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.primary.opacity(0.45))
            configuration.title
        }
    }
}

extension Label {
    /// Muted dark-grey SF Symbol; title stays primary. Prefer this over `extension View` so `Label<Text, Image>` always resolves (Swift 6 / strict visibility).
    func darkGreySystemImageLabel() -> some View {
        labelStyle(DarkGreySystemImageLabelStyle())
    }
}
