import Foundation

@MainActor
final class LivePreviewCoordinator {
    private let provider: any LivePreviewProviding
    private let updateInterval: Duration
    private var sessionID: UUID?
    private var channel: LivePreviewBufferChannel?
    private var presentationTask: Task<Void, Never>?
    private var pendingText: String?
    private var characterLimit = 150

    var stateDidChange: (@MainActor (LivePreviewState) -> Void)?
    private(set) var state: LivePreviewState = .disabled {
        didSet {
            guard state != oldValue else { return }
            stateDidChange?(state)
        }
    }

    init(
        provider: any LivePreviewProviding,
        updateInterval: Duration = .milliseconds(100)
    ) {
        self.provider = provider
        self.updateInterval = updateInterval
    }

    func start(
        configuration: LivePreviewConfiguration
    ) throws -> @Sendable (LivePreviewAudioBuffer) -> Void {
        cancel()
        let id = UUID()
        let channel = LivePreviewBufferChannel(limit: 8)
        sessionID = id
        self.channel = channel
        characterLimit = min(max(configuration.characterLimit, 50), 800)
        state = .waiting

        do {
            try provider.start(
                buffers: channel.stream,
                localeIdentifier: configuration.localeIdentifier
            ) { [weak self] event in
                self?.handle(event, sessionID: id)
            }
        } catch {
            sessionID = nil
            self.channel = nil
            channel.finish()
            state = .unavailable(error.localizedDescription)
            throw error
        }

        return { buffer in channel.yield(buffer) }
    }

    func finish() {
        presentationTask?.cancel()
        presentationTask = nil
        pendingText = nil
        channel?.finish()
        channel = nil
        sessionID = nil
        provider.finish()
        state = .disabled
    }

    func cancel() {
        presentationTask?.cancel()
        presentationTask = nil
        pendingText = nil
        channel?.finish()
        channel = nil
        sessionID = nil
        provider.cancel()
        state = .disabled
    }

    private func handle(_ event: LivePreviewEvent, sessionID: UUID) {
        guard self.sessionID == sessionID else { return }
        switch event {
        case let .partial(text), let .finalSegment(text):
            schedulePresentation(text)
        case let .unavailable(message):
            stopPreview(with: .unavailable(message))
        case let .failed(message):
            stopPreview(with: .failed(message))
        case .finished:
            break
        }
    }

    private func schedulePresentation(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pendingText = String(trimmed.suffix(characterLimit))
        guard presentationTask == nil else { return }
        presentationTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: updateInterval)
            guard !Task.isCancelled, let text = pendingText else { return }
            pendingText = nil
            presentationTask = nil
            state = .active(text)
        }
    }

    private func stopPreview(with finalState: LivePreviewState) {
        presentationTask?.cancel()
        presentationTask = nil
        pendingText = nil
        channel?.finish()
        channel = nil
        sessionID = nil
        provider.cancel()
        state = finalState
    }

    deinit {
        presentationTask?.cancel()
    }
}
