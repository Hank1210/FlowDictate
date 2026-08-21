import Foundation

enum LivePreviewProviderError: LocalizedError {
    case permissionDenied
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Speech Recognition permission is required for Live Preview."
        case .recognizerUnavailable:
            "Local speech recognition is unavailable for the selected language."
        }
    }
}

@MainActor
protocol LivePreviewProviding: AnyObject {
    var isAvailable: Bool { get }
    func start(
        buffers: AsyncStream<LivePreviewAudioBuffer>,
        localeIdentifier: String,
        updateHandler: @escaping @MainActor (String) -> Void
    ) throws
    func stop()
}
