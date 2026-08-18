import Foundation

enum DictationRecordStatus: String, Codable, CaseIterable, Sendable {
    case recorded
    case transcribing
    case transcriptionFailed
    case transcribed
    case inserting
    case insertionFailed
    case insertionUnknown
    case completed
    case cancelled
    case recovered
    case audioMissing
    case audioCorrupt

    nonisolated var title: String {
        switch self {
        case .recorded: "Recorded"
        case .transcribing: "Transcribing"
        case .transcriptionFailed: "Transcription failed"
        case .transcribed: "Transcribed"
        case .inserting: "Inserting"
        case .insertionFailed: "Insertion failed"
        case .insertionUnknown: "Insertion needs review"
        case .completed: "Completed"
        case .cancelled: "Cancelled"
        case .recovered: "Recovered"
        case .audioMissing: "Audio missing"
        case .audioCorrupt: "Audio damaged"
        }
    }

    nonisolated var symbolName: String {
        switch self {
        case .completed: "checkmark.circle.fill"
        case .transcribing, .inserting: "ellipsis.circle"
        case .recorded, .transcribed: "clock.circle"
        case .cancelled: "xmark.circle"
        case .recovered: "lifepreserver"
        case .transcriptionFailed, .insertionFailed, .insertionUnknown, .audioMissing, .audioCorrupt:
            "exclamationmark.triangle.fill"
        }
    }
}

enum DictationErrorCategory: String, Codable, Sendable {
    case configuration
    case credentialMissing
    case authentication
    case permission
    case storageUnavailable
    case storageFull
    case audioDevice
    case audioCorrupt
    case network
    case timeout
    case rateLimit
    case providerTemporary
    case providerPermanent
    case insertion
    case clipboardConflict
    case interrupted
    case unknown
}

struct DictationRecord: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var createdAt: Date
    var recordingStartedAt: Date
    var recordingEndedAt: Date
    var duration: TimeInterval
    var status: DictationRecordStatus
    var audioRelativePath: String
    var audioFileSize: Int64
    var originalTranscript: String?
    var finalText: String?
    var providerID: String
    var modelID: String
    var language: String?
    var targetBundleIdentifier: String?
    var targetApplicationName: String?
    var attemptCount: Int
    var lastAttemptAt: Date?
    var errorCategory: DictationErrorCategory?
    var errorCode: String?
    var errorMessage: String?
    var cancelled: Bool
    var updatedAt: Date
    var schemaVersion: Int

    nonisolated var previewText: String {
        let text = finalText ?? originalTranscript
        return text?.isEmpty == false ? text! : status.title
    }

    nonisolated var canRetry: Bool {
        [.recorded, .transcriptionFailed, .recovered].contains(status)
    }

    nonisolated var canInsert: Bool {
        guard let finalText else { return false }
        return !finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
