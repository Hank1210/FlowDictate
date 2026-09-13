import Foundation

nonisolated struct MeetingSessionPaths: Sendable, Equatable {
    var sessionDirectory: URL
    var manifestURL: URL
    var tracksDirectory: URL
    var derivedDirectory: URL
    var transcriptionDirectory: URL
}

nonisolated enum MeetingSessionStoreError: LocalizedError, Equatable {
    case sessionAlreadyExists(UUID)
    case mismatchedSessionIdentifier(expected: UUID, actual: UUID)

    var errorDescription: String? {
        switch self {
        case let .sessionAlreadyExists(id):
            "A meeting session already exists for \(id.uuidString)."
        case let .mismatchedSessionIdentifier(expected, actual):
            "Meeting session directory \(expected.uuidString) contains manifest \(actual.uuidString)."
        }
    }
}

actor MeetingSessionStore {
    private let explicitRootURL: URL?
    private let recordingLocationStore: RecordingLocationStore
    private let fileManager: FileManager
    private let fileIO = SerialFileIO(label: "de.euler.FlowDictate.meeting-session-file-io")

    init(
        rootURL: URL? = nil,
        recordingLocationStore: RecordingLocationStore = RecordingLocationStore(),
        fileManager: FileManager = .default
    ) {
        explicitRootURL = rootURL
        self.recordingLocationStore = recordingLocationStore
        self.fileManager = fileManager
    }

    func prepareSession(id: UUID) async throws -> MeetingSessionPaths {
        let paths = try paths(for: id)
        let fileManager = SerialFileManagerReference(fileManager)
        return try await fileIO.perform {
            try Self.createDirectories(paths, fileManager: fileManager.value)
            return paths
        }
    }

    func create(_ manifest: MixedRecordingSession) async throws {
        let validated = try manifest.validated()
        let paths = try paths(for: validated.id)
        let fileManager = SerialFileManagerReference(fileManager)
        try await fileIO.perform {
            guard !fileManager.value.fileExists(atPath: paths.manifestURL.path) else {
                throw MeetingSessionStoreError.sessionAlreadyExists(validated.id)
            }
            try Self.createDirectories(paths, fileManager: fileManager.value)
            try Self.write(validated, to: paths.manifestURL)
        }
    }

    func save(_ manifest: MixedRecordingSession) async throws {
        let validated = try manifest.validated()
        let paths = try paths(for: validated.id)
        let fileManager = SerialFileManagerReference(fileManager)
        try await fileIO.perform {
            try Self.createDirectories(paths, fileManager: fileManager.value)
            try Self.write(validated, to: paths.manifestURL)
        }
    }

    func load(sessionID: UUID) async throws -> MixedRecordingSession? {
        let manifestURL = try paths(for: sessionID).manifestURL
        let fileManager = SerialFileManagerReference(fileManager)
        return try await fileIO.perform {
            guard fileManager.value.fileExists(atPath: manifestURL.path) else { return nil }
            return try Self.decodeManifest(at: manifestURL, expectedID: sessionID)
        }
    }

    func all() async throws -> [MixedRecordingSession] {
        let rootURL = try resolvedRootURL()
        let fileManager = SerialFileManagerReference(fileManager)
        return try await fileIO.perform {
            guard fileManager.value.fileExists(atPath: rootURL.path) else { return [] }
            return try fileManager.value.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            .compactMap { directory -> (UUID, URL)? in
                guard let id = UUID(uuidString: directory.lastPathComponent) else { return nil }
                let manifestURL = directory.appendingPathComponent("session.json")
                guard fileManager.value.fileExists(atPath: manifestURL.path) else { return nil }
                return (id, manifestURL)
            }
            .map { try Self.decodeManifest(at: $0.1, expectedID: $0.0) }
            .sorted {
                if $0.createdAt == $1.createdAt { return $0.id.uuidString < $1.id.uuidString }
                return $0.createdAt < $1.createdAt
            }
        }
    }

    func normalizeInterruptedSessions(now: Date = Date()) async throws -> [MixedRecordingSession] {
        var normalized: [MixedRecordingSession] = []
        for var manifest in try await all() {
            let previous = manifest
            manifest.normalizeInterruptedWork(now: now)
            guard manifest != previous else { continue }
            try await save(manifest)
            normalized.append(manifest)
        }
        return normalized
    }

    private func resolvedRootURL() throws -> URL {
        if let explicitRootURL { return explicitRootURL }
        return try recordingLocationStore.resolvedDirectory()
            .appendingPathComponent("MeetingSessions", isDirectory: true)
    }

    private func paths(for id: UUID) throws -> MeetingSessionPaths {
        let sessionDirectory = try resolvedRootURL()
            .appendingPathComponent(id.uuidString, isDirectory: true)
        return MeetingSessionPaths(
            sessionDirectory: sessionDirectory,
            manifestURL: sessionDirectory.appendingPathComponent("session.json"),
            tracksDirectory: sessionDirectory.appendingPathComponent("tracks", isDirectory: true),
            derivedDirectory: sessionDirectory.appendingPathComponent("derived", isDirectory: true),
            transcriptionDirectory: sessionDirectory.appendingPathComponent(
                "transcription",
                isDirectory: true
            )
        )
    }

    private nonisolated static func createDirectories(
        _ paths: MeetingSessionPaths,
        fileManager: FileManager
    ) throws {
        for directory in [
            paths.tracksDirectory,
            paths.derivedDirectory,
            paths.transcriptionDirectory
        ] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private nonisolated static func write(
        _ manifest: MixedRecordingSession,
        to url: URL
    ) throws {
        try encoder.encode(manifest).write(to: url, options: .atomic)
    }

    private nonisolated static func decodeManifest(
        at url: URL,
        expectedID: UUID
    ) throws -> MixedRecordingSession {
        let manifest = try decoder.decode(
            MixedRecordingSession.self,
            from: Data(contentsOf: url)
        )
        guard manifest.id == expectedID else {
            throw MeetingSessionStoreError.mismatchedSessionIdentifier(
                expected: expectedID,
                actual: manifest.id
            )
        }
        return try manifest.validated()
    }

    private nonisolated static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private nonisolated static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
