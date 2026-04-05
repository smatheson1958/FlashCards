//
//  WordAudioPlayer.swift
//  FlashCards
//

import AVFoundation
import Foundation

@MainActor
@Observable
final class WordAudioPlayer {
    private var player: AVAudioPlayer?

    /// `true` after a failed lookup or decode (e.g. WAV not in bundle yet).
    private(set) var lastPlaybackFailed = false

    /// Subfolder under the app bundle resources where `.wav` files live.
    static let wavSubdirectory = "WordsAudio"

    func play(stem: String) {
        lastPlaybackFailed = false
        let normalized = stem.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            lastPlaybackFailed = true
            return
        }

        guard let url = Self.bundleURL(forWavStem: normalized) else {
            lastPlaybackFailed = true
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            lastPlaybackFailed = true
            return
        }

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay()
            player = p
            player?.play()
        } catch {
            lastPlaybackFailed = true
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }

    func clearPlaybackWarning() {
        lastPlaybackFailed = false
    }

    static func bundleURL(forWavStem stem: String) -> URL? {
        Bundle.main.url(
            forResource: stem,
            withExtension: "wav",
            subdirectory: wavSubdirectory
        )
        ?? Bundle.main.url(forResource: stem, withExtension: "wav")
    }
}
