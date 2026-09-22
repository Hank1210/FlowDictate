import Darwin
import Foundation
import os

nonisolated protocol MixedRecordingSessionStoring: Sendable {
    func recordingRootURL() async throws -> URL
    func prepareSession(id: UUID) async throws -> MeetingSessionPaths
    func create(_ manifest: MixedRecordingSession) async throws
    func save(_ manifest: MixedRecordingSession) async throws
}

extension MeetingSessionStore: MixedRecordingSessionStoring {}

typealias MixedTrackLevelHandler = @Sendable (Float) -> Void
typealias MixedRecordingLevelHandler = @Sendable (
    RecordingTrackRole,
    Float
) -> Void
typealias MixedTrackWarningHandler = @Sendable (MixedTrackWarningKind) -> Void
typealias MixedRecordingWarningHandler = @Sendable (MixedRecordingWarning) -> Void

nonisolated enum MixedTrackWarningKind: String, Codable, Hashable, Sendable {
    case clipping
    case sourceLost
}

nonisolated struct MixedRecordingWarning: Codable, Hashable, Sendable, Identifiable {
    var role: RecordingTrackRole
    var kind: MixedTrackWarningKind

    var id: String { "\(role.rawValue)-\(kind.rawValue)" }

    var trackTitle: String {
        role == .localSpeaker ? "Microphone" : "System Audio"
    }

    var message: String {
        switch kind {
        case .clipping:
            role == .localSpeaker
                ? "Microphone clipping detected — reduce the input level or increase your distance."
                : "System Audio clipping detected — the original track is still being preserved."
        case .sourceLost:
            "\(trackTitle) lost — the other original track continues to be saved."
        }
    }
}

nonisolated protocol MixedTrackRecording: Sendable {
    var role: RecordingTrackRole { get }

    func setLevelHandler(_ handler: MixedTrackLevelHandler?) async
    func setWarningHandler(_ handler: MixedTrackWarningHandler?) async
    func prepare(outputURL: URL) async throws
    func start(requestedHostTime: UInt64) async throws -> MixedTrackStartResult
    func stop() async throws -> MixedTrackCaptureResult
    func cancel() async -> MixedTrackCaptureResult?
}

extension MixedTrackRecording {
    func setWarningHandler(_ handler: MixedTrackWarningHandler?) async {}
}

nonisolated protocol MixedRecordingSessionCoordinating: Sendable {
    func setLevelHandler(_ handler: MixedRecordingLevelHandler?) async
    func setWarningHandler(_ handler: MixedRecordingWarningHandler?) async
    func start(_ request: MixedRecordingSessionRequest) async throws -> MixedRecordingSession
    func stop() async throws -> MixedRecordingSession
    func cancel() async throws -> MixedRecordingSession
}

extension MixedRecordingSessionCoordinating {
    func setWarningHandler(_ handler: MixedRecordingWarningHandler?) async {}
}

nonisolated struct MixedTrackStartResult: Sendable, Equatable {
    var firstAnchor: TrackTimestampAnchor
}

nonisolated struct MixedTrackCaptureResult: Sendable, Equatable {
    var formatIdentifier: String
    var sampleRate: Double
    var channelCount: Int
    var firstHostTime: UInt64
    var lastHostTime: UInt64
    var durationMilliseconds: Int64
    var byteCount: Int64
    var timestampAnchors: [TrackTimestampAnchor]
    var gaps: [TrackGap]
    var quality: TrackQualityMetrics
}

nonisolated struct MixedRecordingSessionRequest: Sendable, Equatable {
    var sessionID: UUID
    var recordID: UUID
    var providerID: String
    var engineID: String
    var modelID: String
    var language: String?
    var privacyMode: PrivacyMode?
    var profileID: UUID?

    init(
        sessionID: UUID = UUID(),
        recordID: UUID = UUID(),
        providerID: String,
        engineID: String,
        modelID: String,
        language: String?,
        privacyMode: PrivacyMode? = nil,
        profileID: UUID? = nil
    ) {
        self.sessionID = sessionID
        self.recordID = recordID
        self.providerID = providerID
        self.engineID = engineID
        self.modelID = modelID
        self.language = language
        self.privacyMode = privacyMode
        self.profileID = profileID
    }
}

nonisolated enum MixedRecordingCoordinatorState: Sendable, Equatable {
    case idle
    case preparing(UUID)
    case recording(UUID)
    case finalizing(UUID)
}

nonisolated enum MixedRecordingCoordinatorPhase: String, Sendable, Equatable {
    case prepare
    case start
    case stop
}

nonisolated enum MixedRecordingCoordinatorError: LocalizedError, Sendable, Equatable {
    case alreadyActive
    case notRecording
    case transitionInProgress
    case insufficientRecordingStorage(requiredBytes: Int64, availableBytes: Int64)
    case invalidRecorderRole(expected: RecordingTrackRole, actual: RecordingTrackRole)
    case trackFailed(
        role: RecordingTrackRole,
        phase: MixedRecordingCoordinatorPhase,
        message: String
    )

    var errorDescription: String? {
        switch self {
        case .alreadyActive:
            "A mixed recording session is already active."
        case .notRecording:
            "No mixed recording session is active."
        case .transitionInProgress:
            "The mixed recording session is already finalizing."
        case let .insufficientRecordingStorage(required, available):
            "Mixed recording needs at least \(required / 1_000_000) MB of free disk space; \(max(0, available) / 1_000_000) MB is available. Free space before starting."
        case let .invalidRecorderRole(expected, actual):
            "The mixed recorder role is \(actual.rawValue); expected \(expected.rawValue)."
        case let .trackFailed(role, phase, message):
            "The \(role.rawValue) track failed during \(phase.rawValue): \(message)"
        }
    }
}

private nonisolated enum MixedRecordingStorageCapacity {
    static func availableBytes(at recordingRoot: URL) throws -> Int64 {
        let fileManager = FileManager.default
        var location = recordingRoot.standardizedFileURL
        while !fileManager.fileExists(atPath: location.path) {
            let parent = location.deletingLastPathComponent()
            guard parent.path != location.path else { break }
            location = parent
        }
        let attributes = try fileManager.attributesOfFileSystem(forPath: location.path)
        guard let freeBytes = (attributes[.systemFreeSize] as? NSNumber)?.int64Value else {
            throw CocoaError(.fileReadUnknown)
        }
        return freeBytes
    }
}

actor MixedRecordingSessionCoordinator {
    /// Five minutes of two 96 kHz mono Float32 originals plus a working reserve.
    static let minimumRecordingStorageBytes: Int64 = 500_000_000

    private let microphoneRecorder: any MixedTrackRecording
    private let systemAudioRecorder: any MixedTrackRecording
    private let store: any MixedRecordingSessionStoring
    private let synchronizationAnalyzer: SynchronizationAnalyzer
    private let qualityAnalyzer: MeetingQualityAnalyzer
    private let now: @Sendable () -> Date
    private let hostTime: @Sendable () -> UInt64
    private let availableStorageBytes: @Sendable (URL) throws -> Int64

    private(set) var state: MixedRecordingCoordinatorState = .idle
    private var activeSession: MixedRecordingSession?
    private var activeOperationID: UUID?

    init(
        microphoneRecorder: any MixedTrackRecording,
        systemAudioRecorder: any MixedTrackRecording,
        store: any MixedRecordingSessionStoring,
        synchronizationAnalyzer: SynchronizationAnalyzer = SynchronizationAnalyzer(),
        qualityAnalyzer: MeetingQualityAnalyzer = MeetingQualityAnalyzer(),
        now: @escaping @Sendable () -> Date = Date.init,
        hostTime: @escaping @Sendable () -> UInt64 = { mach_continuous_time() },
        availableStorageBytes: @escaping @Sendable (URL) throws -> Int64 = {
            try MixedRecordingStorageCapacity.availableBytes(at: $0)
        }
    ) {
        self.microphoneRecorder = microphoneRecorder
        self.systemAudioRecorder = systemAudioRecorder
        self.store = store
        self.synchronizationAnalyzer = synchronizationAnalyzer
        self.qualityAnalyzer = qualityAnalyzer
        self.now = now
        self.hostTime = hostTime
        self.availableStorageBytes = availableStorageBytes
    }

    func setLevelHandler(_ handler: MixedRecordingLevelHandler?) async {
        async let microphoneUpdate: Void = microphoneRecorder.setLevelHandler { level in
            handler?(.localSpeaker, level)
        }
        async let systemAudioUpdate: Void = systemAudioRecorder.setLevelHandler { level in
            handler?(.systemAudio, level)
        }
        _ = await (microphoneUpdate, systemAudioUpdate)
    }

    func setWarningHandler(_ handler: MixedRecordingWarningHandler?) async {
        async let microphoneUpdate: Void = microphoneRecorder.setWarningHandler { kind in
            handler?(MixedRecordingWarning(role: .localSpeaker, kind: kind))
        }
        async let systemAudioUpdate: Void = systemAudioRecorder.setWarningHandler { kind in
            handler?(MixedRecordingWarning(role: .systemAudio, kind: kind))
        }
        _ = await (microphoneUpdate, systemAudioUpdate)
    }

    func start(_ request: MixedRecordingSessionRequest) async throws -> MixedRecordingSession {
        guard state == .idle else { throw MixedRecordingCoordinatorError.alreadyActive }
        guard microphoneRecorder.role == .localSpeaker else {
            throw MixedRecordingCoordinatorError.invalidRecorderRole(
                expected: .localSpeaker,
                actual: microphoneRecorder.role
            )
        }
        guard systemAudioRecorder.role == .systemAudio else {
            throw MixedRecordingCoordinatorError.invalidRecorderRole(
                expected: .systemAudio,
                actual: systemAudioRecorder.role
            )
        }

        let signpostID = FlowLogger.meetingSignposter.makeSignpostID()
        let signpost = FlowLogger.meetingSignposter.beginInterval(
            "Mixed Session Start", id: signpostID,
            "session: \(request.sessionID.uuidString, privacy: .public)"
        )
        defer { FlowLogger.meetingSignposter.endInterval("Mixed Session Start", signpost) }

        let operationID = UUID()
        activeOperationID = operationID
        state = .preparing(request.sessionID)

        do {
            let recordingRoot = try await store.recordingRootURL()
            let available = try availableStorageBytes(recordingRoot)
            guard available >= Self.minimumRecordingStorageBytes else {
                throw MixedRecordingCoordinatorError.insufficientRecordingStorage(
                    requiredBytes: Self.minimumRecordingStorageBytes,
                    availableBytes: available
                )
            }
            let paths = try await store.prepareSession(id: request.sessionID)
            var session = makePreparingSession(request: request)
            try await store.create(session)
            FlowLogger.meetingSignposter.emitEvent(
                "Meeting Manifest Persisted", id: signpostID,
                "status: \(session.status.rawValue, privacy: .public)"
            )
            activeSession = session

            do {
                try await microphoneRecorder.prepare(
                    outputURL: paths.tracksDirectory.appendingPathComponent("microphone.caf")
                )
            } catch {
                try await failStart(
                    operationID: operationID,
                    session: &session,
                    role: .localSpeaker,
                    phase: .prepare,
                    error: error
                )
            }
            try ensureActive(operationID)
            FlowLogger.meetingSignposter.emitEvent(
                "Meeting Track Prepared", id: signpostID, "role: microphone"
            )

            do {
                try await systemAudioRecorder.prepare(
                    outputURL: paths.tracksDirectory.appendingPathComponent("system-audio.caf")
                )
            } catch {
                try await failStart(
                    operationID: operationID,
                    session: &session,
                    role: .systemAudio,
                    phase: .prepare,
                    error: error
                )
            }
            try ensureActive(operationID)
            FlowLogger.meetingSignposter.emitEvent(
                "Meeting Track Prepared", id: signpostID, "role: system-audio"
            )

            let requestedHostTime = hostTime()
            async let microphoneStart = Self.startOutcome(
                microphoneRecorder,
                requestedHostTime: requestedHostTime
            )
            async let systemAudioStart = Self.startOutcome(
                systemAudioRecorder,
                requestedHostTime: requestedHostTime
            )
            let (microphoneOutcome, systemAudioOutcome) = await (
                microphoneStart,
                systemAudioStart
            )
            try ensureActive(operationID)

            if case let .failure(message) = microphoneOutcome {
                try await failStart(
                    operationID: operationID,
                    session: &session,
                    role: .localSpeaker,
                    phase: .start,
                    message: message
                )
            }
            if case let .failure(message) = systemAudioOutcome {
                try await failStart(
                    operationID: operationID,
                    session: &session,
                    role: .systemAudio,
                    phase: .start,
                    message: message
                )
            }

            guard case let .success(microphoneResult) = microphoneOutcome,
                  case let .success(systemAudioResult) = systemAudioOutcome else {
                throw CancellationError()
            }
            applyStart(microphoneResult, role: .localSpeaker, to: &session)
            applyStart(systemAudioResult, role: .systemAudio, to: &session)
            FlowLogger.meetingSignposter.emitEvent(
                "Meeting First Sample", id: signpostID,
                "role: microphone, hostTime: \(microphoneResult.firstAnchor.hostTime)"
            )
            FlowLogger.meetingSignposter.emitEvent(
                "Meeting First Sample", id: signpostID,
                "role: system-audio, hostTime: \(systemAudioResult.firstAnchor.hostTime)"
            )
            session.status = .recording
            session.updatedAt = now()
            try await store.save(session)
            FlowLogger.meetingSignposter.emitEvent(
                "Meeting Manifest Persisted", id: signpostID,
                "status: \(session.status.rawValue, privacy: .public)"
            )
            try ensureActive(operationID)

            activeSession = session
            state = .recording(session.id)
            return session
        } catch {
            if activeOperationID == operationID {
                async let microphoneCancel = microphoneRecorder.cancel()
                async let systemAudioCancel = systemAudioRecorder.cancel()
                _ = await (microphoneCancel, systemAudioCancel)
                activeOperationID = nil
                activeSession = nil
                state = .idle
            }
            throw error
        }
    }

    func stop() async throws -> MixedRecordingSession {
        guard case let .recording(sessionID) = state,
              var session = activeSession else {
            if case .finalizing = state {
                throw MixedRecordingCoordinatorError.transitionInProgress
            }
            throw MixedRecordingCoordinatorError.notRecording
        }
        let operationID = try requireOperationID()
        let signpostID = FlowLogger.meetingSignposter.makeSignpostID()
        let signpost = FlowLogger.meetingSignposter.beginInterval(
            "Mixed Session Stop", id: signpostID,
            "session: \(sessionID.uuidString, privacy: .public)"
        )
        defer { FlowLogger.meetingSignposter.endInterval("Mixed Session Stop", signpost) }
        FlowLogger.meetingSignposter.emitEvent("Meeting Stop Requested", id: signpostID)
        state = .finalizing(sessionID)
        session.status = .finalizing
        session.updatedAt = now()
        activeSession = session
        // A transient manifest-write failure must never prevent the recorders from stopping.
        try? await store.save(session)

        async let microphoneStop = Self.stopOutcome(microphoneRecorder)
        async let systemAudioStop = Self.stopOutcome(systemAudioRecorder)
        let (microphoneOutcome, systemAudioOutcome) = await (microphoneStop, systemAudioStop)
        try ensureActive(operationID)

        for (role, outcome) in [
            (RecordingTrackRole.localSpeaker, microphoneOutcome),
            (RecordingTrackRole.systemAudio, systemAudioOutcome)
        ] {
            switch outcome {
            case let .success(result):
                FlowLogger.meetingSignposter.emitEvent(
                    "Meeting Last Sample", id: signpostID,
                    "role: \(role.rawValue, privacy: .public), hostTime: \(result.lastHostTime), bytes: \(result.byteCount), gaps: \(result.gaps.count), dropped: \(result.quality.droppedBufferCount), clipped: \(result.quality.clippedFrameCount)"
                )
                FlowLogger.meetingSignposter.emitEvent(
                    "Meeting Writer Finalized", id: signpostID,
                    "role: \(role.rawValue, privacy: .public), bytes: \(result.byteCount)"
                )
                if FlowLogger.meetingSignposter.isEnabled {
                    for gap in result.gaps {
                        FlowLogger.meetingSignposter.emitEvent(
                            "Meeting Track Gap", id: signpostID,
                            "role: \(role.rawValue, privacy: .public), startMs: \(gap.startMilliseconds), endMs: \(gap.endMilliseconds), reason: \(gap.reason.rawValue, privacy: .public)"
                        )
                    }
                }
            case .failure:
                FlowLogger.meetingSignposter.emitEvent(
                    "Meeting Track Lost", id: signpostID,
                    "role: \(role.rawValue, privacy: .public)"
                )
            }
        }

        applyStop(microphoneOutcome, role: .localSpeaker, to: &session)
        applyStop(systemAudioOutcome, role: .systemAudio, to: &session)
        let analysisSignpost = FlowLogger.meetingSignposter.beginInterval(
            "Meeting Synchronization", id: signpostID
        )
        applyAnalysis(to: &session)
        FlowLogger.meetingSignposter.endInterval(
            "Meeting Synchronization", analysisSignpost,
            "quality: \(session.synchronization?.quality.rawValue ?? "not-analyzed", privacy: .public), gaps: \(session.qualityReport?.totalGapCount ?? 0)"
        )
        let successfulTrackCount = [microphoneOutcome, systemAudioOutcome].reduce(0) {
            if case .success = $1 { $0 + 1 } else { $0 }
        }
        session.status = successfulTrackCount == 2
            ? .queued
            : successfulTrackCount == 1 ? .partial : .failed
        session.updatedAt = now()
        if successfulTrackCount < 2 {
            session.lastErrorCategory = .interrupted
            session.lastErrorMessage = "One or more mixed recording tracks could not be finalized."
        }
        do {
            try await store.save(session)
            FlowLogger.meetingSignposter.emitEvent(
                "Meeting Manifest Persisted", id: signpostID,
                "status: \(session.status.rawValue, privacy: .public)"
            )
            try ensureActive(operationID)
            activeOperationID = nil
            activeSession = nil
            state = .idle
            return session
        } catch {
            if activeOperationID == operationID {
                activeOperationID = nil
                activeSession = nil
                state = .idle
            }
            throw error
        }
    }

    func cancel() async throws -> MixedRecordingSession {
        guard var session = activeSession else {
            throw MixedRecordingCoordinatorError.notRecording
        }
        if case .finalizing = state {
            throw MixedRecordingCoordinatorError.transitionInProgress
        }

        activeOperationID = nil
        state = .finalizing(session.id)
        async let microphoneCancel = microphoneRecorder.cancel()
        async let systemAudioCancel = systemAudioRecorder.cancel()
        let (microphoneResult, systemAudioResult) = await (
            microphoneCancel,
            systemAudioCancel
        )

        applyCancellation(microphoneResult, role: .localSpeaker, to: &session)
        applyCancellation(systemAudioResult, role: .systemAudio, to: &session)
        applyAnalysis(to: &session)
        session.status = .cancelled
        session.updatedAt = now()
        do {
            try await store.save(session)
            activeSession = nil
            state = .idle
            return session
        } catch {
            activeSession = nil
            state = .idle
            throw error
        }
    }

    private func makePreparingSession(
        request: MixedRecordingSessionRequest
    ) -> MixedRecordingSession {
        let createdAt = now()
        let emptyQuality = TrackQualityMetrics(
            peakLevel: nil,
            clippedFrameCount: 0,
            silentDurationMilliseconds: 0,
            droppedBufferCount: 0
        )
        let tracks = [
            MeetingAudioTrack(
                id: UUID(),
                role: .localSpeaker,
                status: .preparing,
                audioRelativePath: "tracks/microphone.caf",
                formatIdentifier: nil,
                sampleRate: 0,
                channelCount: 0,
                firstHostTime: nil,
                lastHostTime: nil,
                durationMilliseconds: 0,
                byteCount: 0,
                timestampAnchors: [],
                gaps: [],
                quality: emptyQuality,
                transcriptionSessionID: nil,
                transcriptRelativePath: nil,
                errorCategory: nil,
                errorMessage: nil
            ),
            MeetingAudioTrack(
                id: UUID(),
                role: .systemAudio,
                status: .preparing,
                audioRelativePath: "tracks/system-audio.caf",
                formatIdentifier: nil,
                sampleRate: 0,
                channelCount: 0,
                firstHostTime: nil,
                lastHostTime: nil,
                durationMilliseconds: 0,
                byteCount: 0,
                timestampAnchors: [],
                gaps: [],
                quality: emptyQuality,
                transcriptionSessionID: nil,
                transcriptRelativePath: nil,
                errorCategory: nil,
                errorMessage: nil
            )
        ]
        return MixedRecordingSession(
            schemaVersion: MixedRecordingSession.currentSchemaVersion,
            id: request.sessionID,
            recordID: request.recordID,
            dictationJobID: nil,
            status: .preparing,
            createdAt: createdAt,
            updatedAt: createdAt,
            providerID: request.providerID,
            engineID: request.engineID,
            modelID: request.modelID,
            language: request.language,
            privacyMode: request.privacyMode,
            profileID: request.profileID,
            tracks: tracks,
            synchronization: nil,
            qualityReport: nil,
            completionMode: nil,
            mergedTimelineRelativePath: nil,
            finalTranscript: nil,
            lastErrorCategory: nil,
            lastErrorMessage: nil
        )
    }

    private func applyStart(
        _ result: MixedTrackStartResult,
        role: RecordingTrackRole,
        to session: inout MixedRecordingSession
    ) {
        guard let index = session.tracks.firstIndex(where: { $0.role == role }) else { return }
        session.tracks[index].status = .recording
        session.tracks[index].firstHostTime = result.firstAnchor.hostTime
        session.tracks[index].timestampAnchors = [result.firstAnchor]
    }

    private func applyStop(
        _ outcome: MixedTrackOperationOutcome<MixedTrackCaptureResult>,
        role: RecordingTrackRole,
        to session: inout MixedRecordingSession
    ) {
        guard let index = session.tracks.firstIndex(where: { $0.role == role }) else { return }
        switch outcome {
        case let .success(result):
            applyCaptureResult(result, to: &session.tracks[index])
        case let .failure(message):
            session.tracks[index].status = .failed
            session.tracks[index].errorCategory = role == .systemAudio
                ? .systemAudioInterrupted
                : .audioDevice
            session.tracks[index].errorMessage = message
        }
    }

    private func applyCancellation(
        _ result: MixedTrackCaptureResult?,
        role: RecordingTrackRole,
        to session: inout MixedRecordingSession
    ) {
        guard let index = session.tracks.firstIndex(where: { $0.role == role }) else { return }
        if let result {
            applyCaptureResult(result, to: &session.tracks[index])
        } else {
            session.tracks[index].status = .interrupted
            session.tracks[index].errorCategory = .interrupted
            session.tracks[index].errorMessage = "Track capture was cancelled before finalization."
        }
    }

    private func applyCaptureResult(
        _ result: MixedTrackCaptureResult,
        to track: inout MeetingAudioTrack
    ) {
        track.status = .finalized
        track.formatIdentifier = result.formatIdentifier
        track.sampleRate = result.sampleRate
        track.channelCount = result.channelCount
        track.firstHostTime = result.firstHostTime
        track.lastHostTime = result.lastHostTime
        track.durationMilliseconds = result.durationMilliseconds
        track.byteCount = result.byteCount
        track.timestampAnchors = result.timestampAnchors
        track.gaps = result.gaps
        track.quality = result.quality
        track.errorCategory = nil
        track.errorMessage = nil
    }

    private func applyAnalysis(to session: inout MixedRecordingSession) {
        let synchronization = synchronizationAnalyzer.analyze(tracks: session.tracks)
        session.synchronization = synchronization
        session.qualityReport = qualityAnalyzer.analyze(
            tracks: session.tracks,
            synchronization: synchronization
        )
    }

    private func failStart(
        operationID: UUID,
        session: inout MixedRecordingSession,
        role: RecordingTrackRole,
        phase: MixedRecordingCoordinatorPhase,
        error: Error
    ) async throws -> Never {
        try await failStart(
            operationID: operationID,
            session: &session,
            role: role,
            phase: phase,
            message: error.localizedDescription
        )
    }

    private func failStart(
        operationID: UUID,
        session: inout MixedRecordingSession,
        role: RecordingTrackRole,
        phase: MixedRecordingCoordinatorPhase,
        message: String
    ) async throws -> Never {
        guard activeOperationID == operationID else { throw CancellationError() }
        for index in session.tracks.indices {
            let isFailure = session.tracks[index].role == role
            session.tracks[index].status = isFailure ? .unavailable : .interrupted
            session.tracks[index].errorCategory = isFailure
                ? (role == .systemAudio ? .systemAudioUnavailable : .audioDevice)
                : .interrupted
            session.tracks[index].errorMessage = isFailure
                ? message
                : "The other track failed before mixed capture could start."
        }
        session.status = .failed
        session.updatedAt = now()
        session.lastErrorCategory = role == .systemAudio
            ? .systemAudioUnavailable
            : .audioDevice
        session.lastErrorMessage = message
        try await store.save(session)
        FlowLogger.meetingSignposter.emitEvent(
            "Meeting Track Lost", id: .exclusive,
            "role: \(role.rawValue, privacy: .public), phase: \(phase.rawValue, privacy: .public)"
        )
        activeSession = session
        throw MixedRecordingCoordinatorError.trackFailed(
            role: role,
            phase: phase,
            message: message
        )
    }

    private func requireOperationID() throws -> UUID {
        guard let activeOperationID else {
            throw MixedRecordingCoordinatorError.notRecording
        }
        return activeOperationID
    }

    private func ensureActive(_ operationID: UUID) throws {
        guard activeOperationID == operationID else { throw CancellationError() }
    }

    private nonisolated static func startOutcome(
        _ recorder: any MixedTrackRecording,
        requestedHostTime: UInt64
    ) async -> MixedTrackOperationOutcome<MixedTrackStartResult> {
        do {
            return .success(try await recorder.start(requestedHostTime: requestedHostTime))
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    private nonisolated static func stopOutcome(
        _ recorder: any MixedTrackRecording
    ) async -> MixedTrackOperationOutcome<MixedTrackCaptureResult> {
        do {
            return .success(try await recorder.stop())
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}

extension MixedRecordingSessionCoordinator: MixedRecordingSessionCoordinating {}

nonisolated private enum MixedTrackOperationOutcome<Value: Sendable>: Sendable {
    case success(Value)
    case failure(String)
}
