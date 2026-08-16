import Foundation

enum AudioStoreError: LocalizedError {
    case applicationSupportUnavailable

    var errorDescription: String? {
        "The local recordings folder is unavailable."
    }
}

struct AudioStore: Sendable {
    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func makeRecordingURL(id: UUID = UUID(), date: Date = Date()) throws -> URL {
        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw AudioStoreError.applicationSupportUnavailable
        }

        let directory = applicationSupport
            .appendingPathComponent("FlowDictate", isDirectory: true)
            .appendingPathComponent("Recordings", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: date)
            .replacingOccurrences(of: ":", with: "-")
        return directory.appendingPathComponent("\(timestamp)-\(id.uuidString).wav")
    }

    func recordingsDirectory() throws -> URL {
        let probeURL = try makeRecordingURL()
        return probeURL.deletingLastPathComponent()
    }
}
