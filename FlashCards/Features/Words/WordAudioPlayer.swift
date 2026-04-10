//
//  WordAudioPlayer.swift
//  FlashCards
//

import AudioToolbox
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
            print("WordAudioPlayer: empty stem; cannot resolve \(Self.wavSubdirectory)/*.wav")
            Self.playSystemBeep()
            return
        }

        guard let url = Self.bundleURL(forWavStem: normalized) else {
            lastPlaybackFailed = true
            print(
                "WordAudioPlayer: no WAV for stem \"\(normalized)\" — add \(Self.wavSubdirectory)/\(normalized).wav to the app bundle (or \(normalized).wav at bundle root)."
            )
            activatePlaybackSessionIgnoringErrors()
            Self.playSystemBeep()
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            lastPlaybackFailed = true
            print("WordAudioPlayer: AVAudioSession error — \(error.localizedDescription)")
            Self.playSystemBeep()
            return
        }

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay()
            player = p
            player?.play()
        } catch {
            lastPlaybackFailed = true
            print("WordAudioPlayer: failed to play \(url.lastPathComponent) — \(error.localizedDescription)")
            Self.playSystemBeep()
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

    private func activatePlaybackSessionIgnoringErrors() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private static func playSystemBeep() {
        AudioServicesPlaySystemSound(1057)
    }
}
