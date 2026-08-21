import Foundation
import OSLog

@MainActor
final class OpenAITranscriptionProvider: TranscriptionProvider {
    static let maximumAudioFileBytes: Int64 = 24_500_000
    static let minimumAudioFileBytes: Int64 = 1_024

    private let apiKey: String
    private let model: String
    private let endpoint: URL
    private let session: URLSession
    private let uploadPreparer: AudioUploadPreparing
    private let fileManager: FileManager

    init(
        apiKey: String,
        model: String = "gpt-4o-mini-transcribe",
        endpoint: URL = URL(string: "https://api.openai.com/v1/audio/transcriptions")!,
        session: URLSession? = nil,
        uploadPreparer: AudioUploadPreparing? = nil,
        fileManager: FileManager = .default
    ) {
        self.apiKey = apiKey
        self.model = model
        self.endpoint = endpoint
        self.fileManager = fileManager
        self.uploadPreparer = uploadPreparer ?? AudioUploadPreparer(fileManager: fileManager)
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 120
            configuration.timeoutIntervalForResource = 300
            self.session = URLSession(configuration: configuration)
        }
    }

    func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionResult {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranscriptionProviderError.missingAPIKey
        }

        let prepared = try await uploadPreparer.prepare(request.audioURL)
        defer { prepared.cleanup(fileManager: fileManager) }

        let values = try prepared.fileURL.resourceValues(forKeys: [.fileSizeKey])
        let audioByteCount = Int64(values.fileSize ?? 0)
        guard audioByteCount >= Self.minimumAudioFileBytes else {
            throw TranscriptionProviderError.audioFileContainsNoSamples
        }
        guard audioByteCount <= Self.maximumAudioFileBytes else {
            throw TranscriptionProviderError.audioFileTooLarge(
                actualBytes: audioByteCount,
                maximumBytes: Self.maximumAudioFileBytes
            )
        }

        let boundary = "FlowDictate-\(UUID().uuidString)"
        let multipart = try MultipartUploadFileBuilder(
            boundary: boundary,
            fileManager: fileManager
        ).build(
            fields: [("model", model), ("language", request.language)],
            fileFieldName: "file",
            filename: prepared.filename,
            mimeType: prepared.mimeType,
            sourceURL: prepared.fileURL
        )
        defer { multipart.cleanup(fileManager: fileManager) }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 120
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        urlRequest.setValue(String(multipart.byteCount), forHTTPHeaderField: "Content-Length")

        FlowLogger.transcription.info(
            "Sending \(audioByteCount, privacy: .public) audio bytes for transcription"
        )
        let (data, response) = try await session.upload(for: urlRequest, fromFile: multipart.url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionProviderError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(OpenAIErrorEnvelope.self, from: data)
            throw TranscriptionProviderError.server(
                statusCode: httpResponse.statusCode,
                message: apiError?.error.message
                    ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
        }

        let payload = try JSONDecoder().decode(OpenAITranscriptionPayload.self, from: data)
        let text = payload.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranscriptionProviderError.emptyTranscript }

        FlowLogger.transcription.info("Transcription completed")
        return TranscriptionResult(text: text, provider: "OpenAI", model: model)
    }
}

nonisolated struct OpenAITranscriptionPayload: Decodable {
    let text: String
}

private struct OpenAIErrorEnvelope: Decodable {
    struct APIError: Decodable {
        let message: String
    }

    let error: APIError
}
