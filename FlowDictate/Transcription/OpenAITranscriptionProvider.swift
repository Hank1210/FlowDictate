import Foundation
import OSLog

@MainActor
final class OpenAITranscriptionProvider: TranscriptionProvider {
    private let apiKey: String
    private let model: String
    private let endpoint: URL
    private let session: URLSession

    init(
        apiKey: String,
        model: String = "gpt-4o-mini-transcribe",
        endpoint: URL = URL(string: "https://api.openai.com/v1/audio/transcriptions")!,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.model = model
        self.endpoint = endpoint
        self.session = session
    }

    func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionResult {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranscriptionProviderError.missingAPIKey
        }

        let audioData = try Data(contentsOf: request.audioURL)
        let boundary = "FlowDictate-\(UUID().uuidString)"
        let body = MultipartFormDataBuilder(boundary: boundary)
            .addingField(name: "model", value: model)
            .addingOptionalField(name: "language", value: request.language)
            .addingFile(
                name: "file",
                filename: request.audioURL.lastPathComponent,
                mimeType: "audio/wav",
                data: audioData
            )
            .build()

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        FlowLogger.transcription.info(
            "Sending \(audioData.count, privacy: .public) audio bytes for transcription"
        )
        let (data, response) = try await session.upload(for: urlRequest, from: body)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionProviderError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(OpenAIErrorEnvelope.self, from: data)
            throw TranscriptionProviderError.server(
                statusCode: httpResponse.statusCode,
                message: apiError?.error.message ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
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

struct MultipartFormDataBuilder {
    let boundary: String
    private var data = Data()

    init(boundary: String) {
        self.boundary = boundary
    }

    func addingField(name: String, value: String) -> MultipartFormDataBuilder {
        var copy = self
        copy.data.appendUTF8("--\(boundary)\r\n")
        copy.data.appendUTF8("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        copy.data.appendUTF8("\(value)\r\n")
        return copy
    }

    func addingOptionalField(name: String, value: String?) -> MultipartFormDataBuilder {
        guard let value, !value.isEmpty else { return self }
        return addingField(name: name, value: value)
    }

    func addingFile(
        name: String,
        filename: String,
        mimeType: String,
        data fileData: Data
    ) -> MultipartFormDataBuilder {
        var copy = self
        copy.data.appendUTF8("--\(boundary)\r\n")
        copy.data.appendUTF8(
            "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n"
        )
        copy.data.appendUTF8("Content-Type: \(mimeType)\r\n\r\n")
        copy.data.append(fileData)
        copy.data.appendUTF8("\r\n")
        return copy
    }

    func build() -> Data {
        var result = data
        result.appendUTF8("--\(boundary)--\r\n")
        return result
    }
}

private extension Data {
    mutating func appendUTF8(_ string: String) {
        append(contentsOf: string.utf8)
    }
}
