import Foundation

/// Adapts a meeting track to FlowDictate's existing single-file and long-form
/// transcription pipeline without adding synthetic rows to the user's History.
@MainActor
final class LongFormTrackTranscriptionExecutor: TrackTranscriptionExecuting {
    typealias ProviderResolver = @MainActor @Sendable (
        TrackTranscriptionRequest
    ) async throws -> any TranscriptionProvider

    private let providerResolver: ProviderResolver
    private let maximumAttempts: Int
    private let longFormConfiguration: LongFormConfiguration
    private let now: @Sendable () -> Date

    init(
        maximumAttempts: Int = 3,
        longFormConfiguration: LongFormConfiguration = .default,
        now: @escaping @Sendable () -> Date = Date.init,
        providerResolver: @escaping ProviderResolver
    ) {
        self.maximumAttempts = max(1, maximumAttempts)
        self.longFormConfiguration = longFormConfiguration
        self.now = now
        self.providerResolver = providerResolver
    }

    nonisolated func transcribe(
        _ request: TrackTranscriptionRequest
    ) async throws -> TrackTranscriptionOutput {
        try await execute(request)
    }

    private func execute(
        _ request: TrackTranscriptionRequest
    ) async throws -> TrackTranscriptionOutput {
        let workflowDirectory = request.transcriptionDirectory.appendingPathComponent(
            "track-workflows",
            isDirectory: true
        )
        let historyStore = DictationHistoryStore(
            fileURL: workflowDirectory.appendingPathComponent("records.json")
        )
        let sessionStore = TranscriptionSessionStore(
            rootURL: workflowDirectory.appendingPathComponent("long-form", isDirectory: true)
        )

        if let completed = try await historyStore.record(id: request.transcriptionSessionID),
           completed.status == .transcribed,
           completed.originalTranscript?.trimmingCharacters(
               in: .whitespacesAndNewlines
           ).isEmpty == false {
            return try output(from: completed, role: request.role)
        }

        guard let providerID = TranscriptionProviderID(rawValue: request.providerID) else {
            throw TranscriptionProviderError.providerUnavailable(
                reason: "The frozen meeting transcription provider is not supported."
            )
        }
        if providerID == .openAI {
            try NetworkPolicy(
                mode: request.privacyMode,
                cloudEnhancementEnabled: false
            ).requirePermission(for: .transcription)
        }

        let provider = try await providerResolver(request)
        let runner = TranscriptionRunner(
            historyStore: historyStore,
            sessionStore: sessionStore,
            longFormConfiguration: longFormConfiguration
        )
        let existing = try await historyStore.record(id: request.transcriptionSessionID)
        let record = existing ?? makeRecord(request)
        let completed = try await runner.run(
            record: record,
            audioURL: request.audioURL,
            language: request.language,
            maximumAttempts: maximumAttempts,
            provider: provider
        )
        return try output(from: completed, role: request.role)
    }

    private func makeRecord(_ request: TrackTranscriptionRequest) -> DictationRecord {
        let endedAt = now()
        let duration = Double(request.durationMilliseconds) / 1_000
        return DictationRecord.newRecording(
            id: request.transcriptionSessionID,
            startedAt: endedAt.addingTimeInterval(-duration),
            endedAt: endedAt,
            duration: duration,
            status: .recorded,
            audioRelativePath: request.audioRelativePath,
            audioFileSize: request.byteCount,
            providerID: request.providerID,
            modelID: request.modelID,
            language: request.language,
            targetBundleIdentifier: nil,
            targetApplicationName: nil,
            sourceMetadata: AudioSourceMetadata(
                source: request.role == .localSpeaker ? .microphone : .systemAudio,
                sampleRate: request.sampleRate,
                channelCount: request.channelCount
            )
        )
    }

    private func output(
        from record: DictationRecord,
        role: RecordingTrackRole
    ) throws -> TrackTranscriptionOutput {
        guard let transcript = record.originalTranscript,
              !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TrackTranscriptionRunnerError.invalidOutput(role)
        }
        let segmentCount = max(record.transcriptionSegmentCount ?? 1, 1)
        let completedSegmentCount = record.transcriptionSegmentCount == nil
            ? 1
            : record.completedTranscriptionSegmentCount
        return TrackTranscriptionOutput(
            transcript: transcript,
            providerID: record.providerID,
            modelID: record.modelID,
            segmentCount: segmentCount,
            completedSegmentCount: completedSegmentCount
        )
    }
}
