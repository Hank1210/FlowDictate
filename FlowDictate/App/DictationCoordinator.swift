import AppKit
import Combine
import Foundation
import OSLog

@MainActor
final class DictationCoordinator: ObservableObject {
    @Published private(set) var state: DictationState = .idle
    @Published private(set) var selectedHotKey: HotKeyConfiguration

    let availableHotKeys = HotKeyConfiguration.presets

    private let shortcutSettings: ShortcutSettings
    private let hotKeyRegistrar: HotKeyRegistering
    private let permissionManager: PermissionManager
    private let recorder: AudioRecording
    private let provider: any TranscriptionProvider
    private let inserter: TextInserting
    private let hasAPIKey: Bool

    private var focusTarget: FocusTarget?
    private var isHandlingToggle = false
    private var lastHotKeyDate = Date.distantPast

    convenience init() {
        self.init(
            shortcutSettings: ShortcutSettings(),
            hotKeyRegistrar: GlobalHotKeyRegistrar(),
            permissionManager: PermissionManager(),
            recorder: MicrophoneRecorder(),
            provider: nil,
            inserter: PasteboardTextInserter(),
            environment: ProcessInfo.processInfo.environment
        )
    }

    init(
        shortcutSettings: ShortcutSettings,
        hotKeyRegistrar: HotKeyRegistering,
        permissionManager: PermissionManager,
        recorder: AudioRecording,
        provider: (any TranscriptionProvider)? = nil,
        inserter: TextInserting,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        let apiKey = environment["OPENAI_API_KEY"] ?? ""
        let model = environment["FLOWDICTATE_TRANSCRIPTION_MODEL"] ?? "gpt-4o-mini-transcribe"

        self.shortcutSettings = shortcutSettings
        self.hotKeyRegistrar = hotKeyRegistrar
        self.permissionManager = permissionManager
        self.recorder = recorder
        self.provider = provider ?? OpenAITranscriptionProvider(apiKey: apiKey, model: model)
        self.inserter = inserter
        hasAPIKey = provider != nil || !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        selectedHotKey = shortcutSettings.selected

        registerHotKey(selectedHotKey)
        FlowLogger.app.info("FlowDictate Phase 0 started")
    }

    var primaryActionTitle: String {
        recorder.isRecording ? "Stop Dictation" : "Start Dictation"
    }

    var microphonePermissionGranted: Bool {
        permissionManager.hasMicrophoneAccess
    }

    var accessibilityPermissionGranted: Bool {
        permissionManager.hasEventPostingAccess
    }

    var apiKeyConfigured: Bool { hasAPIKey }

    func requestToggle() {
        let now = Date()
        guard now.timeIntervalSince(lastHotKeyDate) >= 0.25 else {
            FlowLogger.hotkey.debug("Ignored repeated hotkey event")
            return
        }
        lastHotKeyDate = now

        Task { await toggleDictation() }
    }

    func selectHotKey(id: String) {
        guard
            let configuration = availableHotKeys.first(where: { $0.id == id }),
            configuration != selectedHotKey
        else { return }

        let previous = selectedHotKey
        do {
            try hotKeyRegistrar.register(configuration) { [weak self] in
                self?.requestToggle()
            }
            shortcutSettings.select(configuration)
            selectedHotKey = configuration
            state = .idle
        } catch {
            registerHotKey(previous)
            state = .failed(message: error.localizedDescription, retainedAudioURL: nil)
        }
    }

    func revealRetainedAudio() {
        guard case let .failed(_, retainedAudioURL?) = state else { return }
        NSWorkspace.shared.activateFileViewerSelecting([retainedAudioURL])
    }

    private func registerHotKey(_ configuration: HotKeyConfiguration) {
        do {
            try hotKeyRegistrar.register(configuration) { [weak self] in
                self?.requestToggle()
            }
        } catch {
            state = .failed(message: error.localizedDescription, retainedAudioURL: nil)
            FlowLogger.hotkey.error("Hotkey registration failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func toggleDictation() async {
        guard !isHandlingToggle else { return }
        isHandlingToggle = true
        defer { isHandlingToggle = false }

        if recorder.isRecording {
            await stopAndTranscribe()
        } else if state.acceptsStart {
            await startRecording()
        }
    }

    private func startRecording() async {
        guard hasAPIKey else {
            state = .failed(
                message: TranscriptionProviderError.missingAPIKey.localizedDescription,
                retainedAudioURL: nil
            )
            return
        }

        guard let target = FocusTarget.capture() else {
            state = .failed(
                message: "Place the cursor in another application before starting dictation.",
                retainedAudioURL: nil
            )
            return
        }

        do {
            try await permissionManager.ensureMicrophoneAccess()
            try permissionManager.ensureEventPostingAccess()
            try recorder.start()
            focusTarget = target
            state = .recording
            FlowLogger.app.info(
                "Dictation started for \(target.localizedName, privacy: .public)"
            )
        } catch {
            state = .failed(message: error.localizedDescription, retainedAudioURL: nil)
            FlowLogger.app.error("Could not start dictation: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func stopAndTranscribe() async {
        let recording: AudioRecordingResult
        do {
            recording = try recorder.stop()
        } catch {
            state = .failed(message: error.localizedDescription, retainedAudioURL: nil)
            return
        }

        guard let target = focusTarget else {
            state = .failed(
                message: TextInsertionError.targetUnavailable.localizedDescription,
                retainedAudioURL: recording.url
            )
            return
        }

        state = .transcribing
        do {
            let result = try await provider.transcribe(
                TranscriptionRequest(audioURL: recording.url, language: nil)
            )
            state = .inserting
            try await inserter.insert(result.text, into: target)
            focusTarget = nil
            state = .idle
        } catch {
            state = .failed(message: error.localizedDescription, retainedAudioURL: recording.url)
            FlowLogger.app.error(
                "Dictation failed; audio retained at \(recording.url.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
