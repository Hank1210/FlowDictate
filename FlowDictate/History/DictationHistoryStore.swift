import Foundation

enum DictationHistoryError: LocalizedError {
    case recordNotFound

    var errorDescription: String? {
        "The dictation history entry could not be found."
    }
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

    func all() throws -> [DictationRecord] {
        try loadIfNeeded()
        return recordsByID.values.sorted { $0.createdAt > $1.createdAt }
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
        let envelope = Envelope(schemaVersion: 1, records: Array(recordsByID.values))
        let data = try JSONEncoder.flowDictate.encode(envelope)
        try data.write(to: fileURL, options: .atomic)
    }
}

private extension JSONEncoder {
    nonisolated static var flowDictate: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
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
