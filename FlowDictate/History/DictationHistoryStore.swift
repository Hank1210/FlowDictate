import Foundation

enum DictationHistoryError: LocalizedError {
    case recordNotFound

    var errorDescription: String? {
        "The dictation history entry could not be found."
    }
}

nonisolated struct HistoryRetentionResult: Equatable, Sendable {
    var removedCount = 0
    var archivedCount = 0
}

actor DictationHistoryStore {
    private struct Envelope: Codable {
        var schemaVersion: Int
        var records: [DictationRecord]
    }

    private let fileURL: URL
    private let fileManager: FileManager
    private var recordsByID: [UUID: DictationRecord] = [:]
    private var loaded = false

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.fileURL = base
                .appendingPathComponent("FlowDictate", isDirectory: true)
                .appendingPathComponent("History", isDirectory: true)
                .appendingPathComponent("dictations.json")
        }
    }

    func upsert(_ record: DictationRecord) throws {
        try loadIfNeeded()
        recordsByID[record.id] = record
        try persist()
    }

    func record(id: UUID) throws -> DictationRecord? {
        try loadIfNeeded()
        return recordsByID[id]
    }

    func all(includeArchived: Bool = false) throws -> [DictationRecord] {
        try loadIfNeeded()
        return recordsByID.values
            .filter { includeArchived || $0.archivedAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func recent(limit: Int) throws -> [DictationRecord] {
        Array(try all().prefix(limit))
    }

    func lastInsertable() throws -> DictationRecord? {
        try all().first(where: \.canInsert)
    }

    func delete(id: UUID) throws {
        try loadIfNeeded()
        recordsByID.removeValue(forKey: id)
        try persist()
    }

    func archive(id: UUID, now: Date = Date()) throws {
        try loadIfNeeded()
        guard var record = recordsByID[id] else { throw DictationHistoryError.recordNotFound }
        compactForArchive(&record, now: now)
        recordsByID[id] = record
        try persist()
    }

    func knownAudioRelativePaths() throws -> Set<String> {
        try loadIfNeeded()
        return Set(recordsByID.values.map(\.audioRelativePath))
    }

    func applyRetention(
        maximumAgeDays: Int,
        maximumRecordCount: Int,
        now: Date = Date()
    ) throws -> HistoryRetentionResult {
        try loadIfNeeded()
        var result = HistoryRetentionResult()

        // Archived records only keep the metadata needed to retain their audio.
        // Once that audio has gone, the tombstone is no longer needed either.
        let obsoleteArchiveIDs = recordsByID.values
            .filter { $0.archivedAt != nil && $0.audioFileSize <= 0 }
            .map(\.id)
        for id in obsoleteArchiveIDs {
            recordsByID.removeValue(forKey: id)
            result.removedCount += 1
        }

        let active = recordsByID.values
            .filter { $0.archivedAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
        let cutoff = maximumAgeDays >= 0
            ? Calendar.current.date(byAdding: .day, value: -maximumAgeDays, to: now)
            : nil
        let countCandidates = maximumRecordCount >= 0
            ? Set(active.dropFirst(maximumRecordCount).map(\.id))
            : []

        for var record in active {
            let expiredByAge = cutoff.map { record.createdAt < $0 } ?? false
            guard expiredByAge || countCandidates.contains(record.id) else { continue }
            guard !record.isAutomaticallyProtected else { continue }

            if record.audioFileSize > 0 {
                compactForArchive(&record, now: now)
                recordsByID[record.id] = record
                result.archivedCount += 1
            } else {
                recordsByID.removeValue(forKey: record.id)
                result.removedCount += 1
            }
        }
        if result != HistoryRetentionResult() { try persist() }
        return result
    }

    private func compactForArchive(_ record: inout DictationRecord, now: Date) {
        record.archivedAt = now
        record.updatedAt = now
        record.originalTranscript = nil
        record.finalText = nil
        record.targetApplicationName = nil
        record.targetBundleIdentifier = nil
        record.errorCategory = nil
        record.errorMessage = nil
    }

    func recoverInterrupted(now: Date = Date()) throws -> [DictationRecord] {
        try loadIfNeeded()
        var recovered: [DictationRecord] = []
        for (id, var record) in recordsByID {
            switch record.status {
            case .transcribing:
                record.status = .transcriptionFailed
                record.errorCategory = .interrupted
                record.errorMessage = "Transcription was interrupted when FlowDictate stopped."
            case .inserting:
                record.status = .insertionUnknown
                record.errorCategory = .interrupted
                record.errorMessage = "Insertion may have completed before FlowDictate stopped. Review before inserting again."
            default:
                continue
            }
            record.updatedAt = now
            recordsByID[id] = record
            recovered.append(record)
        }
        if !recovered.isEmpty { try persist() }
        return recovered
    }

    private func loadIfNeeded() throws {
        guard !loaded else { return }
        guard fileManager.fileExists(atPath: fileURL.path) else {
            loaded = true
            return
        }
        let data = try Data(contentsOf: fileURL)
        let envelope = try JSONDecoder.flowDictate.decode(Envelope.self, from: data)
        recordsByID = Dictionary(uniqueKeysWithValues: envelope.records.map { ($0.id, $0) })
        loaded = true
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let envelope = Envelope(
            schemaVersion: FlowDictateVersion.historySchema,
            records: Array(recordsByID.values)
        )
        let data = try JSONEncoder.flowDictate.encode(envelope)
        try data.write(to: fileURL, options: .atomic)
    }
}

private extension JSONEncoder {
    nonisolated static var flowDictate: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    nonisolated static var flowDictate: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
