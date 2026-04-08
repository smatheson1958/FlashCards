//
//  SegmentationSoundPlayer.swift
//  FlashCards
//
//  Plays bundled `<grapheme>.wav` files (e.g. c.wav, sh.wav) under `Sounds/Segmentation` in order,
//  with a gap after each clip finishes (default 1s). Regenerate via Scripts/generate_segmentation_sounds.sh (Kate, 22050 Hz).
//

import AVFoundation
import Foundation

@MainActor
@Observable
final class SegmentationSoundPlayer {
    private var player: AVAudioPlayer?
    private var chainToken: UUID?

    /// `true` if a segment file was missing or decode failed.
    private(set) var lastPlaybackFailed = false

    static let wavSubdirectory = "Sounds/Segmentation"
    static let defaultPauseAfterClip: TimeInterval = 1.0

    func stop() {
        chainToken = nil
        player?.stop()
        player = nil
    }

    func clearPlaybackWarning() {
        lastPlaybackFailed = false
    }

    /// Plays each grapheme’s WAV in order: play clip → wait until it ends → pause → next.
    func playSegments(_ segments: [String], pauseAfterEachClip: TimeInterval = defaultPauseAfterClip) {
        stop()
        lastPlaybackFailed = false
        let normalized = segments.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !normalized.isEmpty else {
            lastPlaybackFailed = true
            return
        }

        activateSessionIfNeeded()

        let token = UUID()
        chainToken = token
        playSegment(at: 0, segments: normalized, pauseAfterEachClip: pauseAfterEachClip, token: token)
    }

    private func playSegment(at index: Int, segments: [String], pauseAfterEachClip: TimeInterval, token: UUID) {
        guard chainToken == token else { return }
        guard index < segments.count else { return }

        let grapheme = segments[index]
        guard let url = Self.bundleURL(forGrapheme: grapheme) else {
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
            return
        }

        let duration = max(player?.duration ?? 0, 0.05)
        let wait = duration + pauseAfterEachClip

        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
            Task { @MainActor in
                guard let self, self.chainToken == token else { return }
                self.player?.stop()
                self.player = nil
                self.playSegment(at: index + 1, segments: segments, pauseAfterEachClip: pauseAfterEachClip, token: token)
            }
        }
    }

    private func activateSessionIfNeeded() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            lastPlaybackFailed = true
        }
    }

    /// `grapheme` e.g. `"c"` → `c.wav`; later `"sh"` → `sh.wav`.
    static func bundleURL(forGrapheme grapheme: String) -> URL? {
        let name = grapheme.lowercased()
        return Bundle.main.url(
            forResource: name,
            withExtension: "wav",
            subdirectory: wavSubdirectory
        )
        ?? Bundle.main.url(forResource: name, withExtension: "wav")
    }
}
