import Foundation
import OSLog
import Speech

@MainActor
final class AppleSpeechLivePreviewProvider: LivePreviewProviding {
    private var recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var feedTask: Task<Void, Never>?
    private var request: SFSpeechAudioBufferRecognitionRequest?

    var isAvailable: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    func start(
        buffers: AsyncStream<LivePreviewAudioBuffer>,
        localeIdentifier: String,
        eventHandler: @escaping @MainActor (LivePreviewEvent) -> Void
    ) throws {
        cancel()
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw LivePreviewProviderError.permissionDenied
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)),
              recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else {
            throw LivePreviewProviderError.recognizerUnavailable
        }
        self.recognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.taskHint = .dictation
        request.addsPunctuation = true
        self.request = request

        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let error {
                Task { @MainActor in eventHandler(.failed(error.localizedDescription)) }
                return
            }
            guard let result else { return }
            let event: LivePreviewEvent = result.isFinal
                ? .finalSegment(result.bestTranscription.formattedString)
                : .partial(result.bestTranscription.formattedString)
            Task { @MainActor in eventHandler(event) }
        }

        feedTask = Task {
            var didLogFirstBuffer = false
            for await buffer in buffers {
                if !didLogFirstBuffer {
                    didLogFirstBuffer = true
                    FlowLogger.audio.info(
                        "Live Preview received audio: \(buffer.sampleRate, privacy: .public) Hz, \(buffer.channelCount, privacy: .public) channel(s)"
                    )
                }
                guard !Task.isCancelled, let pcmBuffer = buffer.makePCMBuffer() else { continue }
                request.append(pcmBuffer)
            }
            request.endAudio()
        }
    }

    func finish() {
        cleanup()
    }

    func cancel() {
        cleanup()
    }

    private func cleanup() {
        feedTask?.cancel()
        feedTask = nil
        request?.endAudio()
        request = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognizer = nil
    }

    deinit {
        feedTask?.cancel()
        recognitionTask?.cancel()
    }
}
