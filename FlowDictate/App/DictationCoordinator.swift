import AppKit
import Combine
import CoreAudio
import Foundation
import OSLog

@MainActor
final class DictationCoordinator: ObservableObject {
    @Published private(set) var state: DictationState = .idle
    @Published private(set) var inputDevices: [AudioInputDevice] = []
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var apiKeyConfigured = false
    @Published private(set) var microphonePermissionGranted = false
    @Published private(set) var accessibilityPermissionGranted = false

    let settings: AppSettings
    let launchAtLogin: LaunchAtLoginManager
    let dictationHotKeys = HotKeyConfiguration.dictationPresets
    let cancelHotKeys = HotKeyConfiguration.cancelPresets

    private let dictationHotKeyRegistrar: HotKeyRegistering
    private let cancelHotKeyRegistrar: HotKeyRegistering
    private let permissionManager: PermissionManaging
    private let recorder: AudioRecording
    private let injectedProvider: (any TranscriptionProvider)?
    private let injectedInserter: TextInserting?
    private let credentialStore: CredentialStoring
    private let audioDeviceService: AudioDeviceServing
    private let environment: [String: String]
    private let overlay: RecordingOverlayPresenting
    private let focusTargetProvider: @MainActor () -> FocusTarget?

    private var focusTarget: FocusTarget?
    private var isHandlingToggle = false
    private var lastHotKeyDate = Date.distantPast
    private var overlayDismissTask: Task<Void, Never>?

    convenience init() {
        let environment = ProcessInfo.processInfo.environment
        let isUITesting = environment["FLOWDICTATE_UI_TESTING"] == "1"
            || environment["XCTestConfigurationFilePath"] != nil
        let launchAtLogin = LaunchAtLoginManager(
            automaticallyEnableOnFirstLaunch: !isUITesting
        )
        self.init(
            settings: AppSettings(),
            dictationHotKeyRegistrar: isUITesting
                ? DisabledHotKeyRegistrar()
                : GlobalHotKeyRegistrar(registrationID: 1),
            cancelHotKeyRegistrar: isUITesting
                ? DisabledHotKeyRegistrar()
                : GlobalHotKeyRegistrar(registrationID: 2),
            permissionManager: PermissionManager(),
            recorder: MicrophoneRecorder(),
            provider: nil,
            inserter: nil,
            credentialStore: KeychainCredentialStore(),
            audioDeviceService: AudioDeviceService(),
            launchAtLogin: launchAtLogin,
            overlay: RecordingOverlayController(),
            focusTargetProvider: { FocusTarget.capture() },
            environment: environment
        )
    }

    init(
        settings: AppSettings,
        dictationHotKeyRegistrar: HotKeyRegistering,
        cancelHotKeyRegistrar: HotKeyRegistering,
        permissionManager: PermissionManaging,
        recorder: AudioRecording,
        provider: (any TranscriptionProvider)?,
        inserter: TextInserting?,
        credentialStore: CredentialStoring,
        audioDeviceService: AudioDeviceServing,
        launchAtLogin: LaunchAtLoginManager,
        overlay: RecordingOverlayPresenting,
        focusTargetProvider: @escaping @MainActor () -> FocusTarget?,
        environment: [String: String]
    ) {
        self.settings = settings
        self.dictationHotKeyRegistrar = dictationHotKeyRegistrar
        self.cancelHotKeyRegistrar = cancelHotKeyRegistrar
        self.permissionManager = permissionManager
        self.recorder = recorder
        injectedProvider = provider
        injectedInserter = inserter
        self.credentialStore = credentialStore
        self.audioDeviceService = audioDeviceService
        self.launchAtLogin = launchAtLogin
        self.overlay = overlay
        self.focusTargetProvider = focusTargetProvider
        self.environment = environment

        recorder.levelHandler = { [weak self] level in
            let activeLevel = self?.recorder.isRecording == true ? level : 0
            self?.audioLevel = activeLevel
            self?.overlay.updateLevel(activeLevel)
        }

        registerInitialHotKeys()
        refreshInputDevices()
        refreshConfigurationStatus()
        refreshPermissionStatus()
        FlowLogger.app.info("FlowDictate Phase 1 started")
    }

    deinit {
        overlayDismissTask?.cancel()
    }

    var primaryActionTitle: String {
        recorder.isRecording ? "Stop Dictation" : "Start Dictation"
    }

    var isProcessing: Bool {
        switch state {
        case .transcribing, .inserting:
            true
        case .idle, .recording, .success, .failed:
            false
        }
    }

    var canCancel: Bool { recorder.isRecording }

    func requestToggle() {
        let now = Date()
        guard now.timeIntervalSince(lastHotKeyDate) >= 0.25 else {
            FlowLogger.hotkey.debug("Ignored repeated hotkey event")
            return
        }
        lastHotKeyDate = now
        Task { await toggleDictation() }
    }

    func requestCancel() {
        guard recorder.isRecording else { return }
        do {
            let recording = try recorder.stop()
            focusTarget = nil
            state = .idle
            audioLevel = 0
            overlay.hide()
            FlowLogger.audio.info(
                "Dictation cancelled; local audio retained at \(recording.url.path, privacy: .public)"
            )
        } catch {
            fail(error, retainedAudioURL: nil)
        }
    }

    func selectDictationHotKey(id: String) {
        guard let configuration = dictationHotKeys.first(where: { $0.id == id }) else { return }
        setDictationHotKey(configuration)
    }

    func setDictationHotKey(_ configuration: HotKeyConfiguration) {
        guard configuration != settings.dictationHotKey else { return }

        let previous = settings.dictationHotKey
        do {
            try registerDictationHotKey(configuration)
            settings.dictationHotKey = configuration
        } catch {
            try? registerDictationHotKey(previous)
            fail(error, retainedAudioURL: nil)
        }
    }

    func selectCancelHotKey(id: String) {
        guard let configuration = cancelHotKeys.first(where: { $0.id == id }) else { return }
        setCancelHotKey(configuration)
    }

    func setCancelHotKey(_ configuration: HotKeyConfiguration) {
        guard configuration != settings.cancelHotKey else { return }

        let previous = settings.cancelHotKey
        do {
            try registerCancelHotKey(configuration)
            settings.cancelHotKey = configuration
        } catch {
            try? registerCancelHotKey(previous)
            fail(error, retainedAudioURL: nil)
        }
    }

    func selectInputDevice(uid: String?) {
        guard !recorder.isRecording else { return }
        settings.inputDeviceUID = uid
        objectWillChange.send()
    }

    func refreshInputDevices() {
        do {
            inputDevices = try audioDeviceService.inputDevices()
            if let selectedUID = settings.inputDeviceUID,
               !inputDevices.contains(where: { $0.uid == selectedUID }) {
                settings.inputDeviceUID = nil
            }
        } catch {
            inputDevices = []
            FlowLogger.audio.error(
                "Could not enumerate input devices: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func saveAPIKey(_ value: String) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        do {
            try credentialStore.saveAPIKey(normalized)
            refreshConfigurationStatus()
            if case .failed = state { state = .idle }
        } catch {
            fail(error, retainedAudioURL: nil)
        }
    }

    func deleteAPIKey() {
        do {
            try credentialStore.deleteAPIKey()
            refreshConfigurationStatus()
        } catch {
            fail(error, retainedAudioURL: nil)
        }
    }

    func refreshConfigurationStatus() {
        let environmentValue = environment["OPENAI_API_KEY"]
        if let environmentValue,
           !environmentValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            apiKeyConfigured = true
            return
        }

        let keychainValue = try? credentialStore.readAPIKey()
        apiKeyConfigured = [keychainValue ?? nil]
            .compactMap { $0 }
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func refreshPermissionStatus() {
        microphonePermissionGranted = permissionManager.hasMicrophoneAccess
        accessibilityPermissionGranted = permissionManager.hasEventPostingAccess
    }

    func revealRetainedAudio() {
        guard case let .failed(_, retainedAudioURL?) = state else { return }
        NSWorkspace.shared.activateFileViewerSelecting([retainedAudioURL])
    }

    func revealRecordingsFolder() {
        do {
            let directory = try AudioStore().recordingsDirectory()
            NSWorkspace.shared.open(directory)
        } catch {
            fail(error, retainedAudioURL: nil)
        }
    }

    func openMicrophoneSettings() {
        permissionManager.openMicrophoneSettings()
    }

    func openAccessibilitySettings() {
        permissionManager.openAccessibilitySettings()
    }

    private func registerInitialHotKeys() {
        do {
            try registerDictationHotKey(settings.dictationHotKey)
            try registerCancelHotKey(settings.cancelHotKey)
        } catch {
            state = .failed(message: error.localizedDescription, retainedAudioURL: nil)
            FlowLogger.hotkey.error(
                "Hotkey registration failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func registerDictationHotKey(_ configuration: HotKeyConfiguration) throws {
        try dictationHotKeyRegistrar.register(configuration) { [weak self] in
            self?.requestToggle()
        }
    }

    private func registerCancelHotKey(_ configuration: HotKeyConfiguration) throws {
        try cancelHotKeyRegistrar.register(configuration) { [weak self] in
            self?.requestCancel()
        }
    }

    func toggleDictation() async {
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
        guard apiKeyConfigured else {
            fail(TranscriptionProviderError.missingAPIKey, retainedAudioURL: nil)
            return
        }

        guard let target = focusTargetProvider() else {
            fail(
                TextInsertionError.targetUnavailable,
                retainedAudioURL: nil,
                message: "Place the cursor in another application before starting dictation."
            )
            return
        }

        do {
            try await permissionManager.ensureMicrophoneAccess()
            try permissionManager.ensureEventPostingAccess()
            refreshPermissionStatus()
            let deviceID = try audioDeviceService.deviceID(forUID: settings.inputDeviceUID)
            recorder.selectInputDevice(deviceID)
            try recorder.start()
            overlayDismissTask?.cancel()
            focusTarget = target
            state = .recording
            overlay.show(status: .recording, reposition: true)
            FlowLogger.app.info(
                "Dictation started for \(target.localizedName, privacy: .public)"
            )
        } catch AudioDeviceServiceError.selectedDeviceUnavailable {
            settings.inputDeviceUID = nil
            recorder.selectInputDevice(nil)
            do {
                try recorder.start()
                focusTarget = target
                state = .recording
                overlay.show(status: .recording, reposition: true)
            } catch {
                fail(error, retainedAudioURL: nil)
            }
        } catch {
            refreshPermissionStatus()
            fail(error, retainedAudioURL: nil)
        }
    }

    private func stopAndTranscribe() async {
        let recording: AudioRecordingResult
        do {
            recording = try recorder.stop()
        } catch {
            fail(error, retainedAudioURL: nil)
            return
        }

        guard let target = focusTarget else {
            fail(TextInsertionError.targetUnavailable, retainedAudioURL: recording.url)
            return
        }

        state = .transcribing
        overlay.show(status: .processing)
        do {
            let provider = try activeProvider()
            let result = try await provider.transcribe(
                TranscriptionRequest(
                    audioURL: recording.url,
                    language: settings.transcriptionLanguage.apiValue
                )
            )
            state = .inserting
            let inserter = injectedInserter ?? PasteboardTextInserter(
                pasteboard: .general,
                restoreDelay: .milliseconds(Int(settings.clipboardRestoreDelay * 1_000))
            )
            try await inserter.insert(result.text, into: target)
            focusTarget = nil
            state = .success
            overlay.show(status: .success)
            scheduleOverlayDismiss(after: .milliseconds(900), transitionToIdle: true)
        } catch {
            fail(error, retainedAudioURL: recording.url)
        }
    }

    private func activeProvider() throws -> any TranscriptionProvider {
        if let injectedProvider { return injectedProvider }

        let environmentKey = environment["OPENAI_API_KEY"]
        let keychainKey: String?
        if let environmentKey,
           !environmentKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            keychainKey = nil
        } else {
            keychainKey = try credentialStore.readAPIKey()
        }
        let apiKey = [environmentKey, keychainKey]
            .compactMap { $0 }
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard let apiKey else { throw TranscriptionProviderError.missingAPIKey }

        let environmentModel = environment["FLOWDICTATE_TRANSCRIPTION_MODEL"]
        let configuredModel = settings.transcriptionModel
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let model = environmentModel?.isEmpty == false
            ? environmentModel!
            : (configuredModel.isEmpty ? "gpt-4o-mini-transcribe" : configuredModel)
        return OpenAITranscriptionProvider(apiKey: apiKey, model: model)
    }

    private func fail(
        _ error: Error,
        retainedAudioURL: URL?,
        message: String? = nil
    ) {
        let displayMessage = message ?? error.localizedDescription
        state = .failed(message: displayMessage, retainedAudioURL: retainedAudioURL)
        focusTarget = nil
        audioLevel = 0
        overlay.show(status: .error(displayMessage))
        scheduleOverlayDismiss(after: .seconds(3), transitionToIdle: false)
        FlowLogger.app.error("Dictation failed: \(displayMessage, privacy: .public)")
    }

    private func scheduleOverlayDismiss(after duration: Duration, transitionToIdle: Bool) {
        overlayDismissTask?.cancel()
        overlayDismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, let self else { return }
            overlay.hide()
            if transitionToIdle, state == .success {
                state = .idle
            }
        }
    }
}
