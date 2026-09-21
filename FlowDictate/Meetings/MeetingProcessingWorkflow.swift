import Foundation

nonisolated protocol MeetingTrackTranscriptionRunning: Sendable {
    func run(sessionID: UUID) async throws -> MixedRecordingSession
}

extension TrackTranscriptionRunner: MeetingTrackTranscriptionRunning {}

nonisolated protocol MeetingTranscriptMerging: Sendable {
    func run(sessionID: UUID) async throws -> MixedRecordingSession
}

extension MeetingTranscriptMergeRunner: MeetingTranscriptMerging {}

/// Mirrors durable meeting state into the compact user History record. The
/// session manifest remains authoritative for paths, per-track transcripts and
/// recovery; diagnostic capture sessions are never discovered or imported.
actor MeetingHistorySynchronizer {
    private let sessionStore: MeetingSessionStore
    private let historyStore: DictationHistoryStore

    init(
        sessionStore: MeetingSessionStore,
        historyStore: DictationHistoryStore
    ) {
        self.sessionStore = sessionStore
        self.historyStore = historyStore
    }

    @discardableResult
    func sync(
        _ session: MixedRecordingSession,
        targetBundleIdentifier: String? = nil,
        targetApplicationName: String? = nil
    ) async throws -> DictationRecord {
        let existing = try await historyStore.record(id: session.recordID)
        // Completed archived rows are deliberately compact. A later startup
        // must not rehydrate transcript or target metadata from the manifest.
        if let existing, existing.archivedAt != nil {
            return existing
        }
        var record = try DictationRecord.meetingSession(
            session,
            targetBundleIdentifier: targetBundleIdentifier
                ?? existing?.targetBundleIdentifier,
            targetApplicationName: targetApplicationName
                ?? existing?.targetApplicationName
        )
        record.archivedAt = existing?.archivedAt
        try await historyStore.upsert(record)
        return record
    }

    /// Recovers only manifests already linked from History. This deliberately
    /// excludes capture probes and development diagnostics that also use the
    /// MeetingSessions directory but are not user dictations.
    @discardableResult
    func recoverLinkedSessions(now: Date = Date()) async throws -> [DictationRecord] {
        let linkedRecords = try await historyStore.all()
            .filter { $0.meetingSummary != nil }
        var recovered: [DictationRecord] = []

        for record in linkedRecords {
            guard let sessionID = record.meetingSummary?.sessionID,
                  var session = try await sessionStore.load(sessionID: sessionID) else {
                continue
            }
            let previous = session
            session.normalizeInterruptedWork(now: max(now, session.updatedAt))
            if session != previous {
                try await sessionStore.save(session)
            }
            recovered.append(try await sync(session))
        }
        return recovered
    }
}

/// Connects the already recoverable per-track transcription and deterministic
/// merge stages to History at durable stage boundaries.
actor MeetingProcessingWorkflow {
    private let sessionStore: MeetingSessionStore
    private let trackRunner: any MeetingTrackTranscriptionRunning
    private let mergeRunner: any MeetingTranscriptMerging
    private let historySynchronizer: MeetingHistorySynchronizer

    init(
        sessionStore: MeetingSessionStore,
        trackRunner: any MeetingTrackTranscriptionRunning,
        mergeRunner: any MeetingTranscriptMerging,
        historySynchronizer: MeetingHistorySynchronizer
    ) {
        self.sessionStore = sessionStore
        self.trackRunner = trackRunner
        self.mergeRunner = mergeRunner
        self.historySynchronizer = historySynchronizer
    }

    func run(sessionID: UUID) async throws -> MixedRecordingSession {
        guard let initial = try await sessionStore.load(sessionID: sessionID) else {
            throw TrackTranscriptionRunnerError.sessionNotFound(sessionID)
        }
        try await historySynchronizer.sync(initial)

        do {
            let transcribed = try await trackRunner.run(sessionID: sessionID)
            try await historySynchronizer.sync(transcribed)
            guard transcribed.status == .merging else { return transcribed }

            let completed = try await mergeRunner.run(sessionID: sessionID)
            try await historySynchronizer.sync(completed)
            return completed
        } catch {
            if let latest = try? await sessionStore.load(sessionID: sessionID) {
                _ = try? await historySynchronizer.sync(latest)
            }
            throw error
        }
    }
}
