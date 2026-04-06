//
//  StudyAppearanceSettings.swift
//  FlashCards
//

import Observation
import SwiftUI

/// Four gentle surface pastels (screen, hints band, card) and four readable text colours, persisted for dyslexia-friendly control.
@Observable
final class StudyAppearanceSettings {
    static let shared = StudyAppearanceSettings()

    private enum Keys {
        static let background = "studyAppearance.backgroundIndex"
        static let surround = "studyAppearance.surroundIndex"
        static let card = "studyAppearance.cardIndex"
        static let text = "studyAppearance.textIndex"
        static let font = "studyAppearance.fontIndex"
    }

    /// PostScript names after registration (see bundled files in `Resources/Fonts`).
    private static let lexendPostScriptName = "Lexend-Regular"
    private static let openDyslexicPostScriptName = "OpenDyslexic-Regular"

    private let defaults = UserDefaults.standard

    /// Screen behind the study area.
    var backgroundIndex: Int {
        didSet { defaults.set(backgroundIndex, forKey: Keys.background) }
    }

    /// Hints, captions, progress row, and card outline.
    var surroundIndex: Int {
        didSet { defaults.set(surroundIndex, forKey: Keys.surround) }
    }

    /// Card face fill.
    var cardIndex: Int {
        didSet { defaults.set(cardIndex, forKey: Keys.card) }
    }

    /// Main letters and words on the card.
    var textIndex: Int {
        didSet { defaults.set(textIndex, forKey: Keys.text) }
    }

    /// 0 rounded system, 1 serif (Times-style system reading font), 2 Lexend (OFL), 3 OpenDyslexic (OFL).
    var fontIndex: Int {
        didSet { defaults.set(fontIndex, forKey: Keys.font) }
    }

    var backgroundColor: Color { Self.surfaceColors[clamped(backgroundIndex)] }
    var surroundColor: Color { Self.surfaceColors[clamped(surroundIndex)] }
    var cardFillColor: Color { Self.surfaceColors[clamped(cardIndex)] }
    var primaryTextColor: Color { Self.textColors[clamped(textIndex)] }

    private init() {
        BundledFontRegistration.registerIfNeeded()

        let d = UserDefaults.standard
        backgroundIndex = Self.clamp(d.object(forKey: Keys.background) as? Int ?? 0)
        surroundIndex = Self.clamp(d.object(forKey: Keys.surround) as? Int ?? 1)
        cardIndex = Self.clamp(d.object(forKey: Keys.card) as? Int ?? 2)
        textIndex = Self.clamp(d.object(forKey: Keys.text) as? Int ?? 0)
        fontIndex = Self.clamp(d.object(forKey: Keys.font) as? Int ?? 0)
    }

    private static func clamp(_ i: Int) -> Int {
        min(max(i, 0), 3)
    }

    private func clamped(_ i: Int) -> Int { Self.clamp(i) }

    /// Pastel surfaces (RGB in sRGB, soft saturation).
    static let surfaceColors: [Color] = [
        Color(red: 0.90, green: 0.94, blue: 0.99),
        Color(red: 0.93, green: 0.89, blue: 0.97),
        Color(red: 0.86, green: 0.95, blue: 0.90),
        Color(red: 0.99, green: 0.93, blue: 0.88),
    ]

    static let surfaceNames = ["Sky", "Lilac", "Mint", "Shell"]

    /// Muted, readable on pastels (not harsh black).
    static let textColors: [Color] = [
        Color(red: 0.22, green: 0.23, blue: 0.28),
        Color(red: 0.18, green: 0.32, blue: 0.36),
        Color(red: 0.32, green: 0.26, blue: 0.38),
        Color(red: 0.34, green: 0.27, blue: 0.22),
    ]

    static let textNames = ["Slate", "Teal", "Plum", "Cocoa"]

    static let fontTitles = ["Rounded", "Serif", "Lexend", "OpenDyslexic"]

    static let fontFootnotes = [
        "Soft, rounded system letters (Apple)",
        "Times-style reading serif — system font (Apple)",
        "Royalty-free (SIL Open Font License)",
        "Dyslexia-friendly, royalty-free (SIL Open Font License)",
    ]

    static let fontPreviewSample = "The quick brown fox — phonics: ship, chat, glow."

    /// Sample line for the settings sheet; registers bundled fonts on first use.
    static func previewFont(forOptionIndex index: Int, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        BundledFontRegistration.registerIfNeeded()
        return fontForOption(clamp(index), size: size, weight: weight)
    }

    func titleFont(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        Self.fontForOption(clamped(fontIndex), size: size, weight: weight)
    }

    func bodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Self.fontForOption(clamped(fontIndex), size: size, weight: weight)
    }

    private static func fontForOption(_ option: Int, size: CGFloat, weight: Font.Weight) -> Font {
        switch option {
        case 0:
            return .system(size: size, weight: weight, design: .rounded)
        case 1:
            return .system(size: size, weight: weight, design: .serif)
        case 2:
            // Variable font: weight is supported.
            return Font.custom(lexendPostScriptName, size: size).weight(weight)
        case 3:
            // OpenDyslexic Regular has a single face; asking SwiftUI for `.weight(.medium)` etc. often substitutes SF Pro.
            let base = Font.custom(openDyslexicPostScriptName, size: size)
            if weight == .bold || weight == .heavy || weight == .black {
                return base.bold()
            }
            return base
        default:
            return .system(size: size, weight: weight, design: .rounded)
        }
    }
}
