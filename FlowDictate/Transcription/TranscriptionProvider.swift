import Foundation

struct TranscriptionRequest: Sendable {
    let audioURL: URL
    let language: String?
}

struct TranscriptionResult: Equatable, Sendable {
    let text: String
    let provider: String
    let model: String
}

protocol TranscriptionProvider: Sendable {
    func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionResult
}

enum TranscriptionProviderError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case emptyTranscript
    case server(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "OPENAI_API_KEY is missing from the Xcode scheme environment."
        case .invalidResponse:
            "The transcription service returned an invalid response."
        case .emptyTranscript:
            "The transcription service returned no text."
        case let .server(statusCode, message):
            "Transcription failed (HTTP \(statusCode)): \(message)"
        }
    }
}
