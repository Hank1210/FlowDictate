import Foundation

enum DictationState: Equatable {
    case idle
    case recording
    case transcribing
    case inserting
    case failed(message: String, retainedAudioURL: URL?)

    var title: String {
        switch self {
        case .idle:
            "Ready"
        case .recording:
            "Recording"
        case .transcribing:
            "Transcribing"
        case .inserting:
            "Inserting"
        case let .failed(message, _):
            "Error: \(message)"
        }
    }

    var symbolName: String {
        switch self {
        case .idle:
            "waveform"
        case .recording:
            "record.circle.fill"
        case .transcribing, .inserting:
            "ellipsis.circle"
        case .failed:
            "exclamationmark.triangle"
        }
    }

    var acceptsStart: Bool {
        switch self {
        case .idle, .failed:
            true
        case .recording, .transcribing, .inserting:
            false
        }
    }
}
