@preconcurrency import AVFoundation
import CoreGraphics
@preconcurrency import CoreMedia
import Foundation
import OSLog
@preconcurrency import ScreenCaptureKit

enum SystemAudioRecorderError: LocalizedError {
    case permissionDenied
    case unavailable
    case noAudioReceived
    case writerFailed(String)
    case interrupted(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "System Audio access is required. Enable FlowDictate in System Settings → Privacy & Security → Screen & System Audio Recording."
        case .unavailable:
            "macOS did not provide a usable System Audio source."
        case .noAudioReceived:
            "No System Audio was received. Play audio in another app and try again."
        case let .writerFailed(message):
            "The System Audio file could not be written: \(message)"
        case let .interrupted(message):
            "System Audio capture was interrupted: \(message)"
        }
    }
}

nonisolated struct SystemAudioPermissionService: Sendable {
    var isAuthorized: Bool { CGPreflightScreenCaptureAccess() }

    func requestAccess() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    @MainActor
    func openSystemSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}

@MainActor
final class SystemAudioRecorder: NSObject, AudioRecording {
    private let store: AudioStore
    private let permissionService: SystemAudioPermissionService
    private let captureQueue = DispatchQueue(label: "FlowDictate.SystemAudioCapture")

    private var stream: SCStream?
    nonisolated(unsafe) private var captureWriter: SystemAudioFileWriter?
    private var recordingID: UUID?
    private var recordingURL: URL?
    private var startedAt: Date?

    private(set) var isRecording = false
    var levelHandler: (@MainActor (Float) -> Void)?
    var previewBufferHandler: (@Sendable (LivePreviewAudioBuffer) -> Void)?

    init(
        store: AudioStore,
        permissionService: SystemAudioPermissionService = SystemAudioPermissionService()
    ) {
        self.store = store
        self.permissionService = permissionService
        super.init()
    }

    func selectInputDevice(_ deviceID: AudioDeviceID?) {}

    func start() async throws {
        guard !isRecording else { throw AudioRecorderError.alreadyRecording }
        guard permissionService.isAuthorized || permissionService.requestAccess() else {
            throw SystemAudioRecorderError.permissionDenied
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: false
        )
        guard let display = content.displays.first else {
            throw SystemAudioRecorderError.unavailable
        }

        let id = UUID()
        let url = try store.makeRecordingURL(id: id, fileExtension: "m4a")
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = 48_000
        // Transcription gains no useful information from stereo. Mono AAC keeps
        // long recordings and uploads roughly half the size of the old stereo files.
        configuration.channelCount = 1
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        configuration.showsCursor = false
        configuration.queueDepth = 3

        let filter = SCContentFilter(
            display: display,
            excludingApplications: [],
            exceptingWindows: []
        )
        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: captureQueue)

        recordingID = id
        recordingURL = url
        startedAt = Date()
        captureWriter = SystemAudioFileWriter(
            url: url,
            defaultSampleRate: Double(configuration.sampleRate),
            defaultChannelCount: configuration.channelCount
        )
        self.stream = stream
        isRecording = true

        do {
            try await stream.startCapture()
            FlowLogger.audio.info("System Audio recording started: \(url.lastPathComponent, privacy: .public)")
        } catch {
            reset(removeFile: true)
            throw error
        }
    }

    func stop() async throws -> AudioRecordingResult {
        guard isRecording, let id = recordingID, let url = recordingURL, let startedAt else {
            throw AudioRecorderError.notRecording
        }

        isRecording = false
        if let stream {
            try? await stream.stopCapture()
        }

        // stopCapture prevents new buffers. Drain the serial callback queue without
        // blocking the MainActor so the app and global shortcuts stay responsive.
        await drainCaptureQueue()
        let writerResult = await captureWriter?.finish()
        let duration = Date().timeIntervalSince(startedAt)
        let receivedAudio = writerResult?.didReceiveAudio == true
        let metadata = writerResult?.sourceMetadata ?? AudioSourceMetadata(
            source: .systemAudio,
            sampleRate: 48_000,
            channelCount: 1
        )
        let writerError = writerResult?.error
        reset(removeFile: !receivedAudio)
        levelHandler?(0)

        if let writerError {
            if receivedAudio, Self.isReadableAudioFile(url) {
                FlowLogger.audio.notice(
                    "System Audio capture ended early; preserving usable partial recording"
                )
                return AudioRecordingResult(
                    id: id,
                    url: url,
                    startedAt: startedAt,
                    duration: duration,
                    sourceMetadata: metadata
                )
            }
            try? FileManager.default.removeItem(at: url)
            throw SystemAudioRecorderError.writerFailed(writerError.localizedDescription)
        }
        guard receivedAudio, FileManager.default.fileExists(atPath: url.path) else {
            throw SystemAudioRecorderError.noAudioReceived
        }

        return AudioRecordingResult(
            id: id,
            url: url,
            startedAt: startedAt,
            duration: duration,
            sourceMetadata: metadata
        )
    }

    private nonisolated static func isReadableAudioFile(_ url: URL) -> Bool {
        guard let file = try? AVAudioFile(forReading: url) else { return false }
        return file.length > 0 && file.fileFormat.sampleRate > 0
    }

    private func drainCaptureQueue() async {
        await withCheckedContinuation { continuation in
            captureQueue.async {
                continuation.resume()
            }
        }
    }

    private func reset(removeFile: Bool) {
        let url = recordingURL
        stream = nil
        captureWriter = nil
        recordingID = nil
        recordingURL = nil
        startedAt = nil
        isRecording = false
        if removeFile, let url { try? FileManager.default.removeItem(at: url) }
    }

    private nonisolated func append(_ sampleBuffer: CMSampleBuffer) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        guard let captureWriter else { return }
        do {
            if let level = try captureWriter.append(sampleBuffer) {
                Task { @MainActor [weak self] in self?.levelHandler?(level) }
            }
        } catch {
            captureWriter.record(error)
            FlowLogger.audio.error("System Audio write failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension SystemAudioRecorder: SCStreamOutput, SCStreamDelegate {
    nonisolated func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .audio else { return }
        append(sampleBuffer)
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        captureWriter?.record(SystemAudioRecorderError.interrupted(error.localizedDescription))
        FlowLogger.audio.error(
            "System Audio stream stopped: \(error.localizedDescription, privacy: .public)"
        )
    }
}

/// Owns all AVAssetWriter work on ScreenCaptureKit's serial capture queue.
/// Only the small, Sendable level value is forwarded to the main actor.
nonisolated final class SystemAudioFileWriter: @unchecked Sendable {
    struct Result: Sendable {
        var didReceiveAudio: Bool
        var sourceMetadata: AudioSourceMetadata
        var error: Error?
    }

    private let url: URL
    private var writer: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var didReceiveAudio = false
    private var failure: Error?
    private var lastLevelUpdate = ContinuousClock.now
    private var sourceMetadata: AudioSourceMetadata

    init(url: URL, defaultSampleRate: Double, defaultChannelCount: Int) {
        self.url = url
        sourceMetadata = AudioSourceMetadata(
            source: .systemAudio,
            sampleRate: defaultSampleRate,
            channelCount: defaultChannelCount
        )
    }

    func append(_ sampleBuffer: CMSampleBuffer) throws -> Float? {
        if writer == nil { try configure(for: sampleBuffer) }
        guard let writer, let writerInput else { return nil }
        if writer.status == .unknown {
            guard writer.startWriting() else {
                throw writer.error ?? SystemAudioRecorderError.writerFailed("Could not start writer")
            }
            writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        }
        guard writer.status == .writing else {
            throw writer.error ?? SystemAudioRecorderError.writerFailed("Unknown writer state")
        }
        guard writerInput.isReadyForMoreMediaData else { return nil }
        guard writerInput.append(sampleBuffer) else {
            throw writer.error ?? SystemAudioRecorderError.writerFailed("Could not append audio")
        }
        didReceiveAudio = true

        let now = ContinuousClock.now
        guard lastLevelUpdate.duration(to: now) >= .milliseconds(100) else { return nil }
        lastLevelUpdate = now
        return Self.estimatedLevel(from: sampleBuffer)
    }

    func record(_ error: Error) {
        if failure == nil { failure = error }
    }

    func finish() async -> Result {
        writerInput?.markAsFinished()
        if let writer, writer.status == .writing { await writer.finishWriting() }
        return Result(
            didReceiveAudio: didReceiveAudio,
            sourceMetadata: sourceMetadata,
            error: failure ?? writer?.error
        )
    }

    private func configure(for sampleBuffer: CMSampleBuffer) throws {
        guard let description = CMSampleBufferGetFormatDescription(sampleBuffer),
              let basic = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee else {
            throw SystemAudioRecorderError.unavailable
        }
        sourceMetadata.sampleRate = basic.mSampleRate
        sourceMetadata.channelCount = Int(basic.mChannelsPerFrame)
        let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: max(basic.mSampleRate, 8_000),
            AVNumberOfChannelsKey: max(Int(basic.mChannelsPerFrame), 1),
            AVEncoderBitRateKey: basic.mChannelsPerFrame == 1 ? 64_000 : 128_000
        ])
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else { throw SystemAudioRecorderError.unavailable }
        writer.add(input)
        self.writer = writer
        writerInput = input
    }

    private static func estimatedLevel(from sampleBuffer: CMSampleBuffer) -> Float {
        guard let description = CMSampleBufferGetFormatDescription(sampleBuffer),
              let basic = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee,
              basic.mFormatID == kAudioFormatLinearPCM else { return 0 }

        var requiredSize = 0
        var retainedBlockBuffer: CMBlockBuffer?
        _ = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &requiredSize,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            blockBufferOut: &retainedBlockBuffer
        )
        guard requiredSize >= MemoryLayout<AudioBufferList>.size else { return 0 }

        let storage = UnsafeMutableRawPointer.allocate(
            byteCount: requiredSize,
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { storage.deallocate() }
        let audioBufferList = storage.bindMemory(to: AudioBufferList.self, capacity: 1)
        guard CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: audioBufferList,
            bufferListSize: requiredSize,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            blockBufferOut: &retainedBlockBuffer
        ) == noErr else { return 0 }

        var sumOfSquares = 0.0
        var sampleCount = 0
        for buffer in UnsafeMutableAudioBufferListPointer(audioBufferList) {
            guard let data = buffer.mData else { continue }
            let byteCount = Int(buffer.mDataByteSize)
            switch basic.mBitsPerChannel {
            case 32 where basic.mFormatFlags & kAudioFormatFlagIsFloat != 0:
                let samples = data.assumingMemoryBound(to: Float.self)
                let count = byteCount / MemoryLayout<Float>.size
                for index in 0..<count {
                    let sample = Double(samples[index])
                    sumOfSquares += sample * sample
                }
                sampleCount += count
            case 64 where basic.mFormatFlags & kAudioFormatFlagIsFloat != 0:
                let samples = data.assumingMemoryBound(to: Double.self)
                let count = byteCount / MemoryLayout<Double>.size
                for index in 0..<count {
                    let sample = samples[index]
                    sumOfSquares += sample * sample
                }
                sampleCount += count
            case 16:
                let samples = data.assumingMemoryBound(to: Int16.self)
                let count = byteCount / MemoryLayout<Int16>.size
                for index in 0..<count {
                    let sample = Double(samples[index]) / Double(Int16.max)
                    sumOfSquares += sample * sample
                }
                sampleCount += count
            case 32:
                let samples = data.assumingMemoryBound(to: Int32.self)
                let count = byteCount / MemoryLayout<Int32>.size
                for index in 0..<count {
                    let sample = Double(samples[index]) / Double(Int32.max)
                    sumOfSquares += sample * sample
                }
                sampleCount += count
            default:
                continue
            }
        }
        return AudioLevelMeter.normalizedRMS(
            sumOfSquares: sumOfSquares,
            sampleCount: sampleCount
        )
    }
}
