@preconcurrency import AVFoundation
import AudioToolbox
import CoreAudio
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

enum AudioLevelMeter {
    nonisolated static func normalizedRMS(_ samples: UnsafeBufferPointer<Float>) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for sample in samples {
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(samples.count))
        return min(max(rms * 8, 0), 1)
    }
}

@MainActor
protocol AudioRecording: AnyObject {
    var isRecording: Bool { get }
    var levelHandler: (@MainActor (Float) -> Void)? { get set }
    var previewBufferHandler: (@Sendable (LivePreviewAudioBuffer) -> Void)? { get set }
    func selectInputDevice(_ deviceID: AudioDeviceID?)
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
    private var selectedDeviceID: AudioDeviceID?

    var levelHandler: (@MainActor (Float) -> Void)?
    var previewBufferHandler: (@Sendable (LivePreviewAudioBuffer) -> Void)?

    var isRecording: Bool { engine?.isRunning == true }

    convenience init(locationStore: RecordingLocationStore? = nil) {
        self.init(store: AudioStore(locationStore: locationStore))
    }

    init(store: AudioStore) {
        self.store = store
    }

    func selectInputDevice(_ deviceID: AudioDeviceID?) {
        selectedDeviceID = deviceID
    }

    func start() throws {
        guard !isRecording else { throw AudioRecorderError.alreadyRecording }

        let id = UUID()
        let url = try store.makeRecordingURL(id: id)
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        if let selectedDeviceID, let audioUnit = inputNode.audioUnit {
            var deviceID = selectedDeviceID
            let status = AudioUnitSetProperty(
                audioUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &deviceID,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            guard status == noErr else {
                throw AudioDeviceServiceError.propertyUnavailable(status)
            }
        }

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

            if let previewBufferHandler = self.previewBufferHandler,
               let previewBuffer = LivePreviewAudioBuffer(copying: buffer) {
                previewBufferHandler(previewBuffer)
            }

            guard let channel = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0 else { return }
            let samples = UnsafeBufferPointer(start: channel, count: frameCount)
            let normalized = AudioLevelMeter.normalizedRMS(samples)
            Task { @MainActor [weak self] in
                self?.levelHandler?(normalized)
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
        levelHandler?(0)

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
