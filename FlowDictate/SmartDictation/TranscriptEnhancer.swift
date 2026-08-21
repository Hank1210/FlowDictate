import Foundation

nonisolated struct TranscriptEnhancementRequest: Sendable {
    let text: String
    let styleInstruction: String
    let language: String?
    let model: String
    let protectedTerms: [String]
}

nonisolated struct TranscriptEnhancementResult: Equatable, Sendable {
    let text: String
    let provider: String
    let model: String
}

protocol TranscriptEnhancing: Sendable {
    func enhance(_ request: TranscriptEnhancementRequest) async throws -> TranscriptEnhancementResult
}

nonisolated enum TranscriptEnhancementError: LocalizedError {
    case emptyInput
    case emptyResult
    case implausibleResult(String)
    case invalidResponse
    case server(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .emptyInput: "There is no transcript to process."
        case .emptyResult: "Smart Dictation returned no text."
        case let .implausibleResult(reason): "Smart Dictation rejected the result: \(reason)"
        case .invalidResponse: "Smart Dictation received an invalid provider response."
        case let .server(statusCode, message): "Smart Dictation failed (HTTP \(statusCode)): \(message)"
        }
    }
}

nonisolated struct EnhancementResponseValidator: Sendable {
    func validate(
        output: String,
        input: String,
        protectedTerms: [String]
    ) throws -> String {
        let result = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw TranscriptEnhancementError.emptyResult }
        let maximumCharacters = max(2_000, input.count * 5)
        guard result.count <= maximumCharacters else {
            throw TranscriptEnhancementError.implausibleResult("the response is unexpectedly long")
        }

        let presentProtectedTerms = protectedTerms.filter {
            !$0.isEmpty && input.localizedCaseInsensitiveContains($0)
        }
        let required = Set(extractProtectedTokens(from: input) + presentProtectedTerms)
        let missing = required.filter { !result.localizedCaseInsensitiveContains($0) }
        guard missing.isEmpty else {
            throw TranscriptEnhancementError.implausibleResult(
                "a number, URL or protected dictionary term is missing"
            )
        }
        return result
    }

    private func extractProtectedTokens(from text: String) -> [String] {
        let pattern = #"https?://\S+|\b\d+(?:[.,:]\d+)*\b"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }
}
