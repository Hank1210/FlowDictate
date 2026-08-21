import Foundation
import Speech

@MainActor
final class AppleSpeechLivePreviewProvider: LivePreviewProviding {
    private var recognitionTask: SFSpeechRecognitionTask?
    private var feedTask: Task<Void, Never>?
    private var request: SFSpeechAudioBufferRecognitionRequest?

    var isAvailable: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    func start(
        buffers: AsyncStream<LivePreviewAudioBuffer>,
        localeIdentifier: String,
        updateHandler: @escaping @MainActor (String) -> Void
    ) throws {
        stop()
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw LivePreviewProviderError.permissionDenied
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)),
              recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else {
            throw LivePreviewProviderError.recognizerUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        self.request = request

        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            guard error == nil, let result else { return }
            let text = result.bestTranscription.formattedString
            Task { @MainActor in updateHandler(text) }
        }

        feedTask = Task {
            for await buffer in buffers {
                guard !Task.isCancelled, let pcmBuffer = buffer.makePCMBuffer() else { continue }
                request.append(pcmBuffer)
            }
            request.endAudio()
        }
    }

    func stop() {
        feedTask?.cancel()
        feedTask = nil
        request?.endAudio()
        request = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    deinit {
        feedTask?.cancel()
        recognitionTask?.cancel()
    }
}
