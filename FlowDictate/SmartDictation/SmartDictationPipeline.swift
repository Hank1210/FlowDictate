import Foundation
import OSLog

struct SmartDictationRunFailure: LocalizedError {
    let underlyingError: Error
    let record: DictationRecord

    var errorDescription: String? { underlyingError.localizedDescription }
}

@MainActor
final class SmartDictationPipeline {
    private let historyStore: DictationHistoryStore
    private let formatter: SpokenFormattingProcessor
    private let dictionaryProcessor: PersonalDictionaryProcessor

    init(
        historyStore: DictationHistoryStore,
        formatter: SpokenFormattingProcessor = SpokenFormattingProcessor(),
        dictionaryProcessor: PersonalDictionaryProcessor = PersonalDictionaryProcessor()
    ) {
        self.historyStore = historyStore
        self.formatter = formatter
        self.dictionaryProcessor = dictionaryProcessor
    }

    func run(
        record: DictationRecord,
        spokenFormattingEnabled: Bool,
        dictionaryEntries: [DictionaryEntry],
        style: WritingStyleProfile,
        enhancementModel: String,
        fallback: SmartDictationFallback,
        enhancer: (any TranscriptEnhancing)?
    ) async throws -> DictationRecord {
        guard let original = record.originalTranscript else {
            throw TranscriptEnhancementError.emptyInput
        }
        var updated = record
        updated.processingStatus = .formatting
        updated.spokenFormattingEnabled = spokenFormattingEnabled
        updated.writingStyleID = style.id
        updated.enhancementErrorCategory = nil
        updated.enhancementErrorMessage = nil
        updated.enhancementFallback = nil
        updated.updatedAt = Date()
        try await persist(updated)

        let formatted = spokenFormattingEnabled
            ? formatter.process(original, language: updated.language).text
            : original
        updated.formattedTranscript = formatted

        let dictionaryResult = dictionaryProcessor.process(
            formatted,
            entries: dictionaryEntries,
            language: updated.language
        )
        updated.dictionaryTranscript = dictionaryResult.text
        updated.dictionaryReplacementCount = dictionaryResult.replacementCount
        updated.processingStatus = .formatted
        updated.finalText = dictionaryResult.text
        updated.updatedAt = Date()
        try await persist(updated)

        guard style.usesAI else {
            updated.processingStatus = .completed
            updated.enhancementProviderID = nil
            updated.enhancementModelID = nil
            updated.updatedAt = Date()
            try await persist(updated)
            return updated
        }
        guard let enhancer else { throw TranscriptionProviderError.missingAPIKey }
        return try await enhance(
            record: updated,
            style: style,
            model: enhancementModel,
            fallback: fallback,
            dictionaryEntries: dictionaryEntries,
            enhancer: enhancer
        )
    }

    func retryEnhancement(
        record: DictationRecord,
        style: WritingStyleProfile,
        model: String,
        fallback: SmartDictationFallback,
        dictionaryEntries: [DictionaryEntry],
        enhancer: any TranscriptEnhancing
    ) async throws -> DictationRecord {
        try await enhance(
            record: record,
            style: style,
            model: model,
            fallback: fallback,
            dictionaryEntries: dictionaryEntries,
            enhancer: enhancer
        )
    }

    func processWithStyle(
        record: DictationRecord,
        style: WritingStyleProfile,
        model: String,
        fallback: SmartDictationFallback,
        dictionaryEntries: [DictionaryEntry],
        enhancer: (any TranscriptEnhancing)?
    ) async throws -> DictationRecord {
        guard let localText = record.dictionaryTranscript ?? record.formattedTranscript ?? record.originalTranscript else {
            throw TranscriptEnhancementError.emptyInput
        }
        var updated = record
        updated.writingStyleID = style.id
        updated.enhancementErrorCategory = nil
        updated.enhancementErrorMessage = nil
        updated.enhancementFallback = nil
        updated.updatedAt = Date()

        guard style.usesAI else {
            updated.finalText = localText
            updated.processingStatus = .completed
            updated.enhancementProviderID = nil
            updated.enhancementModelID = nil
            try await persist(updated)
            return updated
        }
        guard let enhancer else { throw TranscriptionProviderError.missingAPIKey }
        try await persist(updated)
        return try await enhance(
            record: updated,
            style: style,
            model: model,
            fallback: fallback,
            dictionaryEntries: dictionaryEntries,
            enhancer: enhancer
        )
    }

    func recoverInterruptedLocalProcessing(
        record: DictationRecord,
        spokenFormattingEnabled: Bool,
        dictionaryEntries: [DictionaryEntry],
        intendedStyle: WritingStyleProfile
    ) async throws -> DictationRecord {
        var updated = try await run(
            record: record,
            spokenFormattingEnabled: spokenFormattingEnabled,
            dictionaryEntries: dictionaryEntries,
            style: BuiltInWritingStyles.all[0],
            enhancementModel: "",
            fallback: .ask,
            enhancer: nil
        )
        guard intendedStyle.usesAI else { return updated }
        updated.writingStyleID = intendedStyle.id
        updated.processingStatus = .enhancementFailed
        updated.enhancementErrorCategory = .interrupted
        updated.enhancementErrorMessage = "Local processing was recovered. AI enhancement was not restarted automatically."
        updated.enhancementFallback = .ask
        updated.updatedAt = Date()
        try await persist(updated)
        return updated
    }

    private func enhance(
        record: DictationRecord,
        style: WritingStyleProfile,
        model: String,
        fallback: SmartDictationFallback,
        dictionaryEntries: [DictionaryEntry],
        enhancer: any TranscriptEnhancing
    ) async throws -> DictationRecord {
        guard let input = record.dictionaryTranscript ?? record.formattedTranscript ?? record.originalTranscript else {
            throw TranscriptEnhancementError.emptyInput
        }
        var updated = record
        updated.processingStatus = .enhancing
        updated.enhancementAttemptCount += 1
        updated.enhancementModelID = model
        updated.enhancementErrorCategory = nil
        updated.enhancementErrorMessage = nil
        updated.updatedAt = Date()
        try await persist(updated)

        do {
            let result = try await enhancer.enhance(
                TranscriptEnhancementRequest(
                    text: input,
                    styleInstruction: style.instruction,
                    language: updated.language,
                    model: model,
                    protectedTerms: dictionaryEntries.filter(\.isEnabled).map(\.replacement)
                )
            )
            updated.finalText = result.text
            updated.processingStatus = .enhanced
            updated.enhancementProviderID = result.provider
            updated.enhancementModelID = result.model
            updated.updatedAt = Date()
            try await persist(updated)
            updated.processingStatus = .completed
            updated.updatedAt = Date()
            try await persist(updated)
            return updated
        } catch {
            updated.processingStatus = .enhancementFailed
            updated.enhancementErrorCategory = enhancementCategory(for: error)
            updated.enhancementErrorMessage = error.localizedDescription
            updated.enhancementFallback = fallback
            updated.updatedAt = Date()

            switch fallback {
            case .ask:
                try await persist(updated)
                throw SmartDictationRunFailure(underlyingError: error, record: updated)
            case .useLocallyProcessed:
                updated.finalText = input
                updated.processingStatus = .completed
                try await persist(updated)
                return updated
            case .useOriginal:
                updated.finalText = updated.originalTranscript
                updated.processingStatus = .completed
                try await persist(updated)
                return updated
            }
        }
    }

    private func persist(_ record: DictationRecord) async throws {
        do { try await historyStore.upsert(record) }
        catch { throw TranscriptionPersistenceFailure(underlyingError: error, record: record) }
    }

    private func enhancementCategory(for error: Error) -> DictationErrorCategory {
        if let error = error as? TranscriptEnhancementError {
            switch error {
            case let .server(code, _):
                switch code {
                case 401, 403: return .authentication
                case 429: return .rateLimit
                case 500...599: return .providerTemporary
                default: return .providerPermanent
                }
            case .emptyInput, .emptyResult, .implausibleResult, .invalidResponse:
                return .providerPermanent
            }
        }
        return DictationFailureClassifier.category(for: error)
    }
}
