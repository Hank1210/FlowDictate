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
        }
    }

    private static func megabytes(_ bytes: Int64) -> String {
        String(format: "%.1f", Double(bytes) / 1_000_000)
    }
}
