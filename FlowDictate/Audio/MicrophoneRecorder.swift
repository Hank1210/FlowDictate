@preconcurrency import AVFoundation
import Foundation
import OSLog

struct AudioRecordingResult: Sendable {
    let id: UUID
    let url: URL
    let startedAt: Date
    let duration: TimeInterval
}

enum AudioRecorderError: LocalizedError {
    case alreadyRecording
    case notRecording
    case unavailableInput

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            "A recording is already in progress."
        case .notRecording:
            "No recording is in progress."
        case .unavailableInput:
            "No usable microphone input is available."
        }
    }
}

@MainActor
protocol AudioRecording: AnyObject {
    var isRecording: Bool { get }
    func start() throws
    func stop() throws -> AudioRecordingResult
}

@MainActor
final class MicrophoneRecorder: AudioRecording {
    private let store: AudioStore
    private var engine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingID: UUID?
    private var recordingURL: URL?
    private var startedAt: Date?

    var isRecording: Bool { engine?.isRunning == true }

    convenience init() {
        self.init(store: AudioStore())
    }

    init(store: AudioStore) {
        self.store = store
    }

    func start() throws {
        guard !isRecording else { throw AudioRecorderError.alreadyRecording }

        let id = UUID()
        let url = try store.makeRecordingURL(id: id)
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw AudioRecorderError.unavailableInput
        }

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            do {
                try file.write(from: buffer)
            } catch {
                FlowLogger.audio.error("Audio file write failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw error
        }

        self.engine = engine
        audioFile = file
        recordingID = id
        recordingURL = url
        startedAt = Date()
        FlowLogger.audio.info("Recording started: \(url.lastPathComponent, privacy: .public)")
    }

    func stop() throws -> AudioRecordingResult {
        guard
            let engine,
            let id = recordingID,
            let url = recordingURL,
            let startedAt
        else {
            throw AudioRecorderError.notRecording
        }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil
        self.engine = nil
        recordingID = nil
        recordingURL = nil
        self.startedAt = nil

        let result = AudioRecordingResult(
            id: id,
            url: url,
            startedAt: startedAt,
            duration: Date().timeIntervalSince(startedAt)
        )
        FlowLogger.audio.info(
            "Recording stopped after \(result.duration, format: .fixed(precision: 2)) seconds"
        )
        return result
    }
}
