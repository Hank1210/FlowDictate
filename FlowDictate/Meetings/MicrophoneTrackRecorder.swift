@preconcurrency import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation

nonisolated enum MicrophoneTrackRecorderError: LocalizedError, Sendable, Equatable {
    case alreadyPrepared
    case notPrepared
    case invalidOutputURL
    case unavailableInput
    case noAudioReceived
    case captureCancelled
    case conversionFailed(String)
    case writerFailed(String)

    var errorDescription: String? {
        switch self {
        case .alreadyPrepared:
            "The microphone track is already prepared."
        case .notPrepared:
            "The microphone track is not prepared."
        case .invalidOutputURL:
            "The microphone original must use a CAF output path."
        case .unavailableInput:
            "No usable microphone input is available."
        case .noAudioReceived:
            "The microphone started but delivered no audio buffers."
        case .captureCancelled:
            "Microphone capture was cancelled."
        case let .conversionFailed(message):
            "The microphone audio could not be converted to mono Float32 PCM: \(message)"
        case let .writerFailed(message):
            "The microphone original could not be written: \(message)"
        }
    }
}

actor MicrophoneTrackRecorder: MixedTrackRecording {
    nonisolated let role: RecordingTrackRole = .localSpeaker

    private let inputDeviceID: AudioDeviceID?
    private let firstBufferTimeout: Duration
    private var engine: AVAudioEngine?
    private var sink: MicrophoneTrackCaptureSink?
    private var levelHandler: MixedTrackLevelHandler?
    private var hasInstalledTap = false
    private var isRecording = false

    init(
        inputDeviceID: AudioDeviceID? = nil,
        firstBufferTimeout: Duration = .seconds(2)
    ) {
        self.inputDeviceID = inputDeviceID
        self.firstBufferTimeout = firstBufferTimeout
    }

    func setLevelHandler(_ handler: MixedTrackLevelHandler?) async {
        levelHandler = handler
        sink?.setLevelHandler(handler)
    }

    func prepare(outputURL: URL) async throws {
        guard engine == nil else { throw MicrophoneTrackRecorderError.alreadyPrepared }
        guard outputURL.pathExtension.lowercased() == "caf" else {
            throw MicrophoneTrackRecorderError.invalidOutputURL
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        if let inputDeviceID, let audioUnit = inputNode.audioUnit {
            var deviceID = inputDeviceID
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

        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        let sourceFormat = inputNode.outputFormat(forBus: 0)
        guard hardwareFormat.sampleRate > 0,
              hardwareFormat.channelCount > 0,
              sourceFormat.sampleRate > 0,
              sourceFormat.channelCount > 0 else {
            throw MicrophoneTrackRecorderError.unavailableInput
        }
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sourceFormat.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw MicrophoneTrackRecorderError.unavailableInput
        }

        let sink = try MicrophoneTrackCaptureSink(
            outputURL: outputURL,
            sourceFormat: sourceFormat,
            outputFormat: outputFormat,
            levelHandler: levelHandler
        )
        inputNode.installTap(onBus: 0, bufferSize: 4_096, format: sourceFormat) {
            buffer,
            time
            in
            sink.append(buffer, at: time)
        }
        hasInstalledTap = true
        engine.prepare()
        self.engine = engine
        self.sink = sink
    }

    func start(requestedHostTime: UInt64) async throws -> MixedTrackStartResult {
        guard let engine, let sink, !isRecording else {
            throw MicrophoneTrackRecorderError.notPrepared
        }
        sink.begin(requestedHostTime: requestedHostTime)
        do {
            try engine.start()
            isRecording = true
            let anchor = try await sink.waitForFirstAnchor(timeout: firstBufferTimeout)
            return MixedTrackStartResult(firstAnchor: anchor)
        } catch {
            engine.stop()
            isRecording = false
            throw error
        }
    }

    func stop() async throws -> MixedTrackCaptureResult {
        guard engine != nil, let sink, isRecording else {
            throw MicrophoneTrackRecorderError.notPrepared
        }
        stopEngine()
        defer { reset() }
        return try sink.finish()
    }

    func cancel() async -> MixedTrackCaptureResult? {
        guard engine != nil || sink != nil else { return nil }
        sink?.cancelPendingStart()
        stopEngine()
        defer { reset() }
        guard let sink else { return nil }
        return try? sink.finish()
    }

    private func stopEngine() {
        guard let engine else { return }
        if hasInstalledTap {
            engine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        engine.stop()
        isRecording = false
    }

    private func reset() {
        engine = nil
        sink = nil
        hasInstalledTap = false
        isRecording = false
    }
}

/// Thread-safe endpoint used directly by AVAudioEngine's realtime callback.
/// The engine is stopped and its tap removed before `finish()` is called.
nonisolated final class MicrophoneTrackCaptureSink: @unchecked Sendable {
    private let lock = NSLock()
    private let outputURL: URL
    private let sourceFormat: AVAudioFormat
    private let outputFormat: AVAudioFormat
    private let converter: AVAudioConverter?
    private var file: AVAudioFile?
    private var metrics: PCMTrackMetrics
    private var failure: MicrophoneTrackRecorderError?
    private var hasBegun = false
    private var levelHandler: MixedTrackLevelHandler?
    private let levelUpdateGate = AudioLevelUpdateGate(updatesPerSecond: 10)

    init(
        outputURL: URL,
        sourceFormat: AVAudioFormat,
        outputFormat: AVAudioFormat,
        levelHandler: MixedTrackLevelHandler? = nil
    ) throws {
        self.outputURL = outputURL
        self.sourceFormat = sourceFormat
        self.outputFormat = outputFormat
        self.levelHandler = levelHandler
        converter = sourceFormat == outputFormat
            ? nil
            : AVAudioConverter(from: sourceFormat, to: outputFormat)
        if sourceFormat != outputFormat, converter == nil {
            throw MicrophoneTrackRecorderError.conversionFailed(
                "AVAudioConverter could not create the requested format conversion."
            )
        }
        file = try AVAudioFile(
            forWriting: outputURL,
            settings: outputFormat.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        metrics = PCMTrackMetrics(sampleRate: outputFormat.sampleRate)
    }

    func setLevelHandler(_ handler: MixedTrackLevelHandler?) {
        lock.lock()
        levelHandler = handler
        lock.unlock()
    }

    func begin(requestedHostTime: UInt64) {
        lock.lock()
        metrics = PCMTrackMetrics(
            requestedHostTime: requestedHostTime,
            sampleRate: outputFormat.sampleRate
        )
        failure = nil
        hasBegun = true
        lock.unlock()
    }

    func append(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        lock.lock()
        defer { lock.unlock() }
        guard hasBegun, failure == nil, let file else { return }
        do {
            let outputBuffer = try convertedBuffer(from: buffer)
            guard outputBuffer.frameLength > 0 else { return }
            try file.write(from: outputBuffer)
            metrics.record(buffer: outputBuffer, time: time)
            publishLevelIfNeeded(from: outputBuffer)
        } catch let error as MicrophoneTrackRecorderError {
            failure = error
        } catch {
            failure = .writerFailed(error.localizedDescription)
        }
    }

    private func publishLevelIfNeeded(from buffer: AVAudioPCMBuffer) {
        guard levelUpdateGate.shouldPublish(at: ProcessInfo.processInfo.systemUptime) else {
            return
        }
        levelHandler?(AudioLevelMeter.normalizedRMS(buffer))
    }

    func waitForFirstAnchor(timeout: Duration) async throws -> TrackTimestampAnchor {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            try Task.checkCancellation()
            let (anchor, failure) = startSnapshot()
            if let failure { throw failure }
            if let anchor { return anchor }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw MicrophoneTrackRecorderError.noAudioReceived
    }

    func cancelPendingStart() {
        lock.lock()
        if metrics.firstAnchor == nil, failure == nil {
            failure = .captureCancelled
        }
        lock.unlock()
    }

    func finish() throws -> MixedTrackCaptureResult {
        lock.lock()
        if let failure {
            file = nil
            lock.unlock()
            throw failure
        }
        guard hasBegun else {
            file = nil
            lock.unlock()
            throw MicrophoneTrackRecorderError.notPrepared
        }
        file = nil
        let metrics = self.metrics
        hasBegun = false
        lock.unlock()

        let byteCount = Int64(
            try outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        )
        do {
            return try metrics.captureResult(byteCount: byteCount)
        } catch PCMTrackMetricsError.noAudioReceived {
            throw MicrophoneTrackRecorderError.noAudioReceived
        }
    }

    private func convertedBuffer(from buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        guard buffer.format == sourceFormat else {
            throw MicrophoneTrackRecorderError.conversionFailed(
                "The input format changed while recording."
            )
        }
        guard let converter else { return buffer }
        let ratio = outputFormat.sampleRate / sourceFormat.sampleRate
        let capacity = AVAudioFrameCount(
            max(1, ceil(Double(buffer.frameLength) * ratio) + 32)
        )
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: capacity
        ) else {
            throw MicrophoneTrackRecorderError.conversionFailed(
                "The converted audio buffer could not be allocated."
            )
        }

        do {
            try converter.convert(to: outputBuffer, from: buffer)
        } catch {
            throw MicrophoneTrackRecorderError.conversionFailed(
                error.localizedDescription
            )
        }
        return outputBuffer
    }

    private func startSnapshot() -> (TrackTimestampAnchor?, MicrophoneTrackRecorderError?) {
        lock.lock()
        defer { lock.unlock() }
        return (metrics.firstAnchor, failure)
    }
}
