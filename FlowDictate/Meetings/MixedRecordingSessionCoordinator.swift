import Darwin
import Foundation

nonisolated protocol MixedRecordingSessionStoring: Sendable {
    func prepareSession(id: UUID) async throws -> MeetingSessionPaths
    func create(_ manifest: MixedRecordingSession) async throws
    func save(_ manifest: MixedRecordingSession) async throws
}

extension MeetingSessionStore: MixedRecordingSessionStoring {}

nonisolated protocol MixedTrackRecording: Sendable {
    var role: RecordingTrackRole { get }

    func prepare(outputURL: URL) async throws
    func start(requestedHostTime: UInt64) async throws -> MixedTrackStartResult
    func stop() async throws -> MixedTrackCaptureResult
    func cancel() async -> MixedTrackCaptureResult?
}

nonisolated protocol MixedRecordingSessionCoordinating: Sendable {
    func start(_ request: MixedRecordingSessionRequest) async throws -> MixedRecordingSession
    func stop() async throws -> MixedRecordingSession
    func cancel() async throws -> MixedRecordingSession
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
        case let .invalidRecorderRole(expected, actual):
            "The mixed recorder role is \(actual.rawValue); expected \(expected.rawValue)."
        case let .trackFailed(role, phase, message):
            "The \(role.rawValue) track failed during \(phase.rawValue): \(message)"
        }
    }
}

actor MixedRecordingSessionCoordinator {
    private let microphoneRecorder: any MixedTrackRecording
    private let systemAudioRecorder: any MixedTrackRecording
    private let store: any MixedRecordingSessionStoring
    private let synchronizationAnalyzer: SynchronizationAnalyzer
    private let qualityAnalyzer: MeetingQualityAnalyzer
    private let now: @Sendable () -> Date
    private let hostTime: @Sendable () -> UInt64

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
        hostTime: @escaping @Sendable () -> UInt64 = { mach_continuous_time() }
    ) {
        self.microphoneRecorder = microphoneRecorder
        self.systemAudioRecorder = systemAudioRecorder
        self.store = store
        self.synchronizationAnalyzer = synchronizationAnalyzer
        self.qualityAnalyzer = qualityAnalyzer
        self.now = now
        self.hostTime = hostTime
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

        let operationID = UUID()
        activeOperationID = operationID
        state = .preparing(request.sessionID)

        do {
            let paths = try await store.prepareSession(id: request.sessionID)
            var session = makePreparingSession(request: request)
            try await store.create(session)
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
            session.status = .recording
            session.updatedAt = now()
            try await store.save(session)
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

        applyStop(microphoneOutcome, role: .localSpeaker, to: &session)
        applyStop(systemAudioOutcome, role: .systemAudio, to: &session)
        applyAnalysis(to: &session)
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
