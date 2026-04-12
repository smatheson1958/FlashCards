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

    /// Whole-word clips grouped by construction-index sound id (`WordsAudio/sound_<id>/<stem>.wav`), when present.
    static func soundSubdirectory(soundOrderIndex: Int) -> String {
        "\(wavSubdirectory)/sound_\(soundOrderIndex)"
    }

    /// - Parameter soundOrderIndex: When set (Sound Card / construction-index order), prefers `WordsAudio/sound_<id>/<stem>.wav`, then flat `WordsAudio/<stem>.wav`.
    func play(stem: String, soundOrderIndex: Int? = nil) {
        lastPlaybackFailed = false
        let normalized = stem.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            lastPlaybackFailed = true
            print("WordAudioPlayer: empty stem; cannot resolve \(Self.wavSubdirectory)/*.wav")
            Self.playSystemBeep()
            return
        }

        guard let url = Self.bundleURL(forWavStem: normalized, soundOrderIndex: soundOrderIndex) else {
            lastPlaybackFailed = true
            let hint = if let n = soundOrderIndex {
                "\(Self.soundSubdirectory(soundOrderIndex: n))/\(normalized).wav or \(Self.wavSubdirectory)/\(normalized).wav"
            } else {
                "\(Self.wavSubdirectory)/\(normalized).wav (or \(normalized).wav at bundle root)"
            }
            print(
                "WordAudioPlayer: no WAV for stem \"\(normalized)\" — add \(hint)."
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

    static func bundleURL(forWavStem stem: String, soundOrderIndex: Int? = nil) -> URL? {
        if let n = soundOrderIndex, n > 0 {
            if let nested = Bundle.main.url(
                forResource: stem,
                withExtension: "wav",
                subdirectory: soundSubdirectory(soundOrderIndex: n)
            ) {
                return nested
            }
        }
        return Bundle.main.url(
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
