//
//  SegmentationProgressEvent.swift
//  FlashCards
//
//  Append-only audit trail for segmentation journey (attendance, outcomes). Not used for global deck state.
//

import Foundation
import SwiftData

@Model
final class SegmentationProgressEvent {
    var eventID: UUID
    var occurredAt: Date
    var soundOrderIndex: Int
    /// Normalized word key; empty when not word-scoped.
    var wordKey: String
    var visitIndex: Int
    var kindRaw: String

    init(
        eventID: UUID = UUID(),
        occurredAt: Date = Date(),
        soundOrderIndex: Int,
        wordKey: String,
        visitIndex: Int,
        kind: SegmentationProgressEventKind
    ) {
        self.eventID = eventID
        self.occurredAt = occurredAt
        self.soundOrderIndex = soundOrderIndex
        self.wordKey = wordKey
        self.visitIndex = visitIndex
        self.kindRaw = kind.rawValue
    }

    var kind: SegmentationProgressEventKind {
        get { SegmentationProgressEventKind(rawValue: kindRaw) ?? .wordPresented }
        set { kindRaw = newValue.rawValue }
    }
}

enum SegmentationProgressEventKind: String, Codable, Sendable {
    /// Learner opened journey practice for this sound (once per session per sound).
    case soundAttended
    case wordPresented
    case wordSuccess
    case wordError
}
