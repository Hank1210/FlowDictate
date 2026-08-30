import Foundation

nonisolated struct TranscriptionRequest: Sendable {
    let audioURL: URL
    let language: String?
    let prompt: String?

    init(audioURL: URL, language: String?, prompt: String? = nil) {
        self.audioURL = audioURL
        self.language = language
        self.prompt = prompt
    }
}

nonisolated struct TranscriptionResult: Equatable, Sendable {
    let text: String
    let provider: String
    let model: String
}

nonisolated protocol TranscriptionProvider: Sendable {
    func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionResult
}

nonisolated enum TranscriptionProviderError: LocalizedError {
    case missingAPIKey
    case audioFileContainsNoSamples
    case audioFileTooLarge(actualBytes: Int64, maximumBytes: Int64)
    case invalidResponse
    case emptyTranscript
    case server(statusCode: Int, message: String)
    case providerUnavailable(reason: String)
    case localModelMissing(modelID: String)
    case localModelCorrupt(modelID: String)
    case unsupportedLanguage(language: String)
    case localInitializationFailed(message: String)
    case networkBlocked(purpose: NetworkPurpose)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "No OpenAI API key is configured. Add one in FlowDictate Settings → Transcription."
        case .audioFileContainsNoSamples:
            "The microphone produced no audio samples. The recording was kept; check the selected input device and try again."
        case let .audioFileTooLarge(actualBytes, maximumBytes):
            "The recording is too large to upload (\(Self.megabytes(actualBytes)) MB). The limit is \(Self.megabytes(maximumBytes)) MB. The original recording was kept."
        case .invalidResponse:
            "The transcription service returned an invalid response."
        case .emptyTranscript:
            "The transcription service returned no text."
        case let .server(statusCode, message):
            "Transcription failed (HTTP \(statusCode)): \(message)"
        case let .providerUnavailable(reason):
            reason
        case let .localModelMissing(modelID):
            "The local transcription model \(modelID) is not installed. Download it in Settings → Transcription."
        case let .localModelCorrupt(modelID):
            "The local transcription model \(modelID) could not be verified. Remove and download it again."
        case let .unsupportedLanguage(language):
            "The selected local transcription model does not support \(language)."
        case let .localInitializationFailed(message):
            "Local transcription could not start: \(message)"
        case let .networkBlocked(purpose):
            "The current privacy mode blocks the \(purpose.rawValue) network request. Change the privacy mode to continue."
        }
    }

    private static func megabytes(_ bytes: Int64) -> String {
        String(format: "%.1f", Double(bytes) / 1_000_000)
    }
}
