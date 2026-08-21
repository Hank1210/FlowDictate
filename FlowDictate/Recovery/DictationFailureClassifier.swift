import Foundation

enum DictationFailureClassifier {
    static func category(for error: Error) -> DictationErrorCategory {
        if let error = error as? URLError {
            switch error.code {
            case .timedOut: return .timeout
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
                 .cannotFindHost, .dnsLookupFailed: return .network
            default: return .network
            }
        }
        if let error = error as? TranscriptionProviderError {
            switch error {
            case .missingAPIKey: return .credentialMissing
            case .audioFileTooLarge: return .providerPermanent
            case let .server(statusCode, _):
                switch statusCode {
                case 401, 403: return .authentication
                case 429: return .rateLimit
                case 500...599: return .providerTemporary
                default: return .providerPermanent
                }
            case .invalidResponse, .emptyTranscript: return .providerPermanent
            }
        }
        if error is RecordingLocationError || error is AudioStoreError { return .storageUnavailable }
        if error is AudioRecorderError || error is AudioDeviceServiceError { return .audioDevice }
        if error is TextInsertionError { return .insertion }
        if error is FlowPermissionError { return .permission }
        return .unknown
    }

    static func isRetryable(_ error: Error) -> Bool {
        [.network, .timeout, .rateLimit, .providerTemporary].contains(category(for: error))
    }
}
