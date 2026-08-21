import Foundation
import OSLog

struct TranscriptionRunFailure: LocalizedError {
    let underlyingError: Error
    let record: DictationRecord

    var errorDescription: String? { underlyingError.localizedDescription }
}

struct TranscriptionPersistenceFailure: LocalizedError {
    let underlyingError: Error
    let record: DictationRecord

    var errorDescription: String? {
        "The recording was saved, but FlowDictate could not update its history: \(underlyingError.localizedDescription)"
    }
}

@MainActor
final class TranscriptionRunner {
    typealias Sleeper = @MainActor (Duration) async throws -> Void

    private let historyStore: DictationHistoryStore
    private let sleeper: Sleeper

    init(
        historyStore: DictationHistoryStore,
        sleeper: @escaping Sleeper = { try await Task.sleep(for: $0) }
    ) {
        self.historyStore = historyStore
        self.sleeper = sleeper
    }

    func run(
        record: DictationRecord,
        audioURL: URL,
        language: String?,
        maximumAttempts: Int,
        provider: any TranscriptionProvider
    ) async throws -> DictationRecord {
        var updated = record
        let maximumAttempts = max(maximumAttempts, 1)

        for attempt in 1...maximumAttempts {
            updated.status = .transcribing
            updated.attemptCount += 1
            updated.lastAttemptAt = Date()
            updated.updatedAt = Date()
            try await persist(updated)

            let result: TranscriptionResult
            do {
                result = try await provider.transcribe(
                    TranscriptionRequest(audioURL: audioURL, language: language)
                )
            } catch {
                let shouldRetry = attempt < maximumAttempts
                    && DictationFailureClassifier.isRetryable(error)
                if shouldRetry {
                    try await sleeper(attempt == 1 ? .milliseconds(500) : .milliseconds(1_500))
                    continue
                }

                updated.status = .transcriptionFailed
                updated.errorCategory = DictationFailureClassifier.category(for: error)
                updated.errorMessage = error.localizedDescription
                updated.updatedAt = Date()
                do {
                    try await historyStore.upsert(updated)
                } catch {
                    FlowLogger.app.error(
                        "Could not persist transcription failure: \(error.localizedDescription, privacy: .public)"
                    )
                }
                throw TranscriptionRunFailure(underlyingError: error, record: updated)
            }

            updated.status = .transcribed
            updated.originalTranscript = result.text
            updated.finalText = result.text
            updated.providerID = result.provider
            updated.modelID = result.model
            updated.errorCategory = nil
            updated.errorCode = nil
            updated.errorMessage = nil
            updated.updatedAt = Date()
            try await persist(updated)
            return updated
        }

        preconditionFailure("At least one transcription attempt must run")
    }

    private func persist(_ record: DictationRecord) async throws {
        do {
            try await historyStore.upsert(record)
        } catch {
            throw TranscriptionPersistenceFailure(underlyingError: error, record: record)
        }
    }
}
