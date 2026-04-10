//
//  SegmentationSoundPlayer.swift
//  FlashCards
//
//  Plays bundled `<grapheme>.wav` files (e.g. c.wav, sh.wav) under `Sounds/Segmentation` in order,
//  with a gap after each clip finishes (default 1s). Regenerate via Scripts/generate_segmentation_sounds.sh (Kate, 22050 Hz).
//

import AudioToolbox
import AVFoundation
import Foundation
import os

@MainActor
@Observable
final class SegmentationSoundPlayer {
    private var player: AVAudioPlayer?
    private var chainToken: UUID?

    /// `true` if a segment file was missing or decode failed.
    private(set) var lastPlaybackFailed = false

    static let wavSubdirectory = "Sounds/Segmentation"
    static let defaultPauseAfterClip: TimeInterval = 1.0

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "FlashCards",
        category: "SegmentationSound"
    )

    func stop() {
        chainToken = nil
        player?.stop()
        player = nil
    }

    func clearPlaybackWarning() {
        lastPlaybackFailed = false
    }

    /// Plays a single grapheme clip (e.g. tap on one segment block).
    func playGrapheme(_ grapheme: String) {
        stop()
        lastPlaybackFailed = false
        let g = grapheme.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !g.isEmpty else {
            Self.logMissingSoundFile(grapheme: grapheme, reason: "empty grapheme after trim")
            lastPlaybackFailed = true
            return
        }

        activateSessionIfNeeded()

        guard let url = Self.bundleURL(forGrapheme: g) else {
            Self.logMissingSoundFile(grapheme: g, reason: "no bundled WAV")
            lastPlaybackFailed = true
            return
        }

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay()
            player = p
            player?.play()
        } catch {
            Self.log.error("SegmentationSound: could not decode \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            lastPlaybackFailed = true
        }
    }

    /// Plays `Sounds/Segmentation/<grapheme>.wav` when present; otherwise a short system beep.
    func playGraphemeOrBeep(_ grapheme: String) {
        _ = prepareAndPlayGraphemeOrBeep(grapheme)
    }

    /// Same as `playGraphemeOrBeep`, but waits until the WAV (or beep stand‑in) has finished.
    func playGraphemeOrBeepAwaitFinish(_ grapheme: String) async {
        let seconds = prepareAndPlayGraphemeOrBeep(grapheme)
        let ns = UInt64((seconds * 1_000_000_000.0).rounded())
        if ns > 0 {
            try? await Task.sleep(nanoseconds: ns)
        }
    }

    /// Starts playback; returns approximate duration until the clip (or beep) is done.
    private func prepareAndPlayGraphemeOrBeep(_ grapheme: String) -> TimeInterval {
        stop()
        lastPlaybackFailed = false
        let g = grapheme.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !g.isEmpty else {
            Self.logMissingSoundFile(grapheme: grapheme, reason: "empty grapheme after trim")
            Self.playSystemBeep()
            lastPlaybackFailed = true
            return Self.fallbackBeepWait
        }

        activateSessionIfNeeded()

        guard let url = Self.bundleURL(forGrapheme: g) else {
            Self.logMissingSoundFile(grapheme: g, reason: "no bundled WAV")
            Self.playSystemBeep()
            lastPlaybackFailed = true
            return Self.fallbackBeepWait
        }

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay()
            player = p
            player?.play()
            return max(p.duration, 0.05)
        } catch {
            Self.log.error("SegmentationSound: could not decode \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public) — using beep")
            Self.playSystemBeep()
            lastPlaybackFailed = true
            return Self.fallbackBeepWait
        }
    }

    private static func logMissingSoundFile(grapheme: String, reason: String) {
        log.warning("SegmentationSound: \(reason, privacy: .public) for grapheme \"\(grapheme, privacy: .public)\" (expected \(wavSubdirectory, privacy: .public)/\(grapheme.lowercased(), privacy: .public).wav)")
    }

    private static let fallbackBeepWait: TimeInterval = 0.15

    private static func playSystemBeep() {
        AudioServicesPlaySystemSound(1057)
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
            Self.logMissingSoundFile(grapheme: grapheme, reason: "no bundled WAV")
            lastPlaybackFailed = true
            return
        }

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay()
            player = p
            player?.play()
        } catch {
            Self.log.error("SegmentationSound: could not decode \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
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
