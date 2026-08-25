import AppKit
import AVFoundation
import Combine
import CoreAudio
import Foundation
import OSLog
import UniformTypeIdentifiers

@MainActor
final class DictationCoordinator: ObservableObject {
    static let currentOnboardingVersion = FlowDictateVersion.onboardingSchema

    @Published private(set) var state: DictationState = .idle
    @Published private(set) var inputDevices: [AudioInputDevice] = []
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var apiKeyConfigured = false
    @Published private(set) var microphonePermissionGranted = false
    @Published private(set) var accessibilityPermissionGranted = false
    @Published private(set) var speechPermissionState: SpeechPermissionState = .notDetermined
    @Published private(set) var systemAudioPermissionGranted = false
    @Published private(set) var recordingLocationConfigured = false
    @Published private(set) var recordingLocationPath: String?
    @Published private(set) var historyRecords: [DictationRecord] = []
    @Published private(set) var retryingRecordIDs: Set<UUID> = []
    @Published private(set) var retryingEnhancementRecordIDs: Set<UUID> = []
    @Published private(set) var dictionaryEntries: [DictionaryEntry] = []
    @Published private(set) var writingStyles: [WritingStyleProfile] = BuiltInWritingStyles.all
    @Published private(set) var appProfiles: [AppDictationProfile] = []
    @Published private(set) var setupMessage: String?
    @Published private(set) var isPreviewTestRunning = false
    @Published private(set) var isSystemAudioTestRunning = false
    @Published private(set) var isSmartDictationTestRunning = false
    @Published private(set) var smartDictationTestOutput: String?
    @Published private(set) var availableRelease: GitHubReleaseInfo?
    @Published private(set) var isCheckingForUpdates = false
    @Published private(set) var updateCheckMessage: String?
    @Published private(set) var latestOutputNotice: String?
    @Published private(set) var latestOutputURL: URL?

    let settings: AppSettings
    let launchAtLogin: LaunchAtLoginManager
    let recordingLocationStore: RecordingLocationStore
    let dictationHotKeys = HotKeyConfiguration.dictationPresets
    let cancelHotKeys = HotKeyConfiguration.cancelPresets
    let restoreHotKeys = HotKeyConfiguration.restorePresets

    private let dictationHotKeyRegistrar: HotKeyRegistering
    private let cancelHotKeyRegistrar: HotKeyRegistering
    private let restoreHotKeyRegistrar: HotKeyRegistering
    private let permissionManager: PermissionManaging
    private let microphoneRecorder: AudioRecording
    private let systemAudioRecorder: AudioRecording
    private let injectedProvider: (any TranscriptionProvider)?
    private let injectedInserter: TextInserting?
    private let credentialStore: CredentialStoring
    private let audioDeviceService: AudioDeviceServing
    private let environment: [String: String]
    private let overlay: RecordingOverlayPresenting
    private let focusTargetProvider: @MainActor () -> FocusTarget?
    private let historyStore: DictationHistoryStore
    private let audioStore: AudioStore
    private let transcriptionRunner: TranscriptionRunner
    private let dictionaryStore: DictionaryStore
    private let writingStyleStore: WritingStyleStore
    private let appProfileStore: AppProfileStore
    private let smartDictationPipeline: SmartDictationPipeline
    private let injectedEnhancer: (any TranscriptEnhancing)?
    private let livePreviewCoordinator: LivePreviewCoordinator
    private let livePreviewAvailabilityProvider:
        @MainActor (TranscriptionLanguage, SpeechPermissionState) -> LivePreviewAvailability

    private var focusTarget: FocusTarget?
    private var lastExternalFocusTarget: FocusTarget?
    private var isHandlingToggle = false
    private var lastHotKeyDate = Date.distantPast
    private var overlayDismissTask: Task<Void, Never>?
    private var onboardingWindowController: NSWindowController?
    private var historyWindowController: HistoryWindowController?
    private var audioPlayer: AVAudioPlayer?
    private var previewTestTask: Task<Void, Never>?
    private var systemAudioTestTask: Task<Void, Never>?
    private var didLogLivePreviewText = false
    private var cachedAPIKey: String?
    private var didLoadAPIKeyFromKeychain = false
    private var sessionRecorder: AudioRecording?
    private var sessionConfiguration: EffectiveDictationConfiguration?
    private var holdHotKeyIsDown = false
    private var holdReleaseTask: Task<Void, Never>?
    private var activeDictationTask: Task<Void, Never>?
    private var retryTranscriptionTasks: [UUID: Task<Void, Never>] = [:]

    private var recorder: AudioRecording {
        if let sessionRecorder { return sessionRecorder }
        return settings.recordingAudioSource == .systemAudio
            ? systemAudioRecorder
            : microphoneRecorder
    }

    convenience init() {
        let environment = ProcessInfo.processInfo.environment
        let isUITesting = environment["FLOWDICTATE_UI_TESTING"] == "1"
            || environment["XCTestConfigurationFilePath"] != nil
        let settings = AppSettings()
        let locationStore = RecordingLocationStore()
        let audioStore = AudioStore(locationStore: locationStore)
        self.init(
            settings: settings,
            dictationHotKeyRegistrar: isUITesting ? DisabledHotKeyRegistrar() : GlobalHotKeyRegistrar(registrationID: 1),
            cancelHotKeyRegistrar: isUITesting ? DisabledHotKeyRegistrar() : GlobalHotKeyRegistrar(registrationID: 2),
            restoreHotKeyRegistrar: isUITesting ? DisabledHotKeyRegistrar() : GlobalHotKeyRegistrar(registrationID: 3),
            permissionManager: PermissionManager(),
            recorder: MicrophoneRecorder(store: audioStore),
            provider: nil,
            inserter: nil,
            credentialStore: KeychainCredentialStore(),
            audioDeviceService: AudioDeviceService(),
            launchAtLogin: LaunchAtLoginManager(automaticallyEnableOnFirstLaunch: !isUITesting),
            overlay: RecordingOverlayController(),
            focusTargetProvider: { FocusTarget.capture() },
            environment: environment,
            recordingLocationStore: locationStore,
            historyStore: DictationHistoryStore(),
            audioStore: audioStore,
            automaticallyPresentOnboarding: !isUITesting
        )
    }

    init(
        settings: AppSettings,
        dictationHotKeyRegistrar: HotKeyRegistering,
        cancelHotKeyRegistrar: HotKeyRegistering,
        restoreHotKeyRegistrar: HotKeyRegistering,
        permissionManager: PermissionManaging,
        recorder: AudioRecording,
        systemAudioRecorder: AudioRecording? = nil,
        provider: (any TranscriptionProvider)?,
        inserter: TextInserting?,
        credentialStore: CredentialStoring,
        audioDeviceService: AudioDeviceServing,
        launchAtLogin: LaunchAtLoginManager,
        overlay: RecordingOverlayPresenting,
        focusTargetProvider: @escaping @MainActor () -> FocusTarget?,
        environment: [String: String],
        recordingLocationStore: RecordingLocationStore,
        historyStore: DictationHistoryStore = DictationHistoryStore(),
        audioStore: AudioStore? = nil,
        livePreviewProvider: (any LivePreviewProviding)? = nil,
        dictionaryStore: DictionaryStore? = nil,
        writingStyleStore: WritingStyleStore? = nil,
        appProfileStore: AppProfileStore? = nil,
        transcriptEnhancer: (any TranscriptEnhancing)? = nil,
        livePreviewAvailabilityProvider:
            (@MainActor (TranscriptionLanguage, SpeechPermissionState) -> LivePreviewAvailability)? = nil,
        automaticallyPresentOnboarding: Bool = false
    ) {
        self.settings = settings
        self.dictationHotKeyRegistrar = dictationHotKeyRegistrar
        self.cancelHotKeyRegistrar = cancelHotKeyRegistrar
        self.restoreHotKeyRegistrar = restoreHotKeyRegistrar
        self.permissionManager = permissionManager
        microphoneRecorder = recorder
        self.systemAudioRecorder = systemAudioRecorder
            ?? SystemAudioRecorder(store: audioStore ?? AudioStore(locationStore: recordingLocationStore))
        injectedProvider = provider
        injectedInserter = inserter
        self.credentialStore = credentialStore
        self.audioDeviceService = audioDeviceService
        self.launchAtLogin = launchAtLogin
        self.overlay = overlay
        self.focusTargetProvider = focusTargetProvider
        self.environment = environment
        self.recordingLocationStore = recordingLocationStore
        self.historyStore = historyStore
        self.audioStore = audioStore ?? AudioStore(locationStore: recordingLocationStore)
        transcriptionRunner = TranscriptionRunner(historyStore: historyStore)
        self.dictionaryStore = dictionaryStore ?? DictionaryStore()
        self.writingStyleStore = writingStyleStore ?? WritingStyleStore()
        self.appProfileStore = appProfileStore ?? AppProfileStore()
        smartDictationPipeline = SmartDictationPipeline(historyStore: historyStore)
        injectedEnhancer = transcriptEnhancer
        livePreviewCoordinator = LivePreviewCoordinator(
            provider: livePreviewProvider ?? AppleSpeechLivePreviewProvider()
        )
        self.livePreviewAvailabilityProvider = livePreviewAvailabilityProvider
            ?? { language, permission in
                LivePreviewAvailabilityResolver.resolve(
                    language: language,
                    permission: permission
                )
            }

        for candidate in [microphoneRecorder, self.systemAudioRecorder] {
            candidate.levelHandler = { [weak self, weak candidate] level in
                let activeLevel = candidate?.isRecording == true ? level : 0
                self?.audioLevel = activeLevel
                self?.overlay.updateLevel(activeLevel)
            }
        }
        livePreviewCoordinator.stateDidChange = { [weak self] state in
            self?.overlay.updatePreview(state)
            switch state {
            case .waiting:
                FlowLogger.audio.info("Live Preview recognition started")
            case .active:
                if self?.didLogLivePreviewText == false {
                    self?.didLogLivePreviewText = true
                    FlowLogger.audio.info("Live Preview produced provisional text")
                }
            case let .unavailable(message):
                self?.recorder.previewBufferHandler = nil
                FlowLogger.audio.notice(
                    "Live Preview unavailable: \(message, privacy: .public)"
                )
            case let .failed(message):
                self?.recorder.previewBufferHandler = nil
                FlowLogger.audio.error(
                    "Live Preview recognition failed: \(message, privacy: .public)"
                )
            case .disabled:
                break
            }
        }

        registerInitialHotKeys()
        refreshInputDevices()
        refreshConfigurationStatus()
        refreshPermissionStatus()
        Task { [weak self] in
            await self?.refreshSmartDictationData()
            await self?.refreshAppProfiles()
            await self?.recoverAndRefreshHistory()
            if self?.settings.updateCheckEnabled == true,
               self?.settings.lastUpdateCheck?.timeIntervalSinceNow ?? -.infinity < -86_400 {
                await self?.checkForUpdates(manual: false)
            }
            guard automaticallyPresentOnboarding, let self, self.needsOnboarding else { return }
            try? await Task.sleep(for: .milliseconds(400))
            self.showOnboarding()
        }
        FlowLogger.app.info("FlowDictate \(FlowDictateVersion.displayString, privacy: .public) started")
    }

    deinit {
        overlayDismissTask?.cancel()
        previewTestTask?.cancel()
        systemAudioTestTask?.cancel()
    }

    var primaryActionTitle: String {
        switch state {
        case .recording: "Stop Dictation"
        case .finalizing: "Finalizing…"
        default: "Start Dictation"
        }
    }
    var isRecording: Bool { recorder.isRecording }
    var canCancel: Bool { state == .recording && recorder.isRecording }
    var isProcessing: Bool {
        switch state {
        case .finalizing, .transcribing, .enhancing, .inserting: true
        default: false
        }
    }
    var latestEnhancementFailure: DictationRecord? {
        historyRecords.first { $0.processingStatus == .enhancementFailed }
    }
    var needsOnboarding: Bool {
        settings.onboardingVersion < Self.currentOnboardingVersion
            || !apiKeyConfigured || !recordingLocationConfigured
    }

    func requestToggle() {
        let now = Date()
        guard now.timeIntervalSince(lastHotKeyDate) >= 0.25 else { return }
        lastHotKeyDate = now
        if recorder.isRecording {
            // Acknowledge the shortcut immediately. System Audio may need a moment
            // to close a long M4A, but the user should never have to press twice.
            state = .finalizing
            audioLevel = 0
            overlay.show(status: .finalizing)
        }
        activeDictationTask = Task { [weak self] in
            await self?.toggleDictation()
            self?.activeDictationTask = nil
        }
    }

    func requestCancel() {
        if isPreviewTestRunning {
            previewTestTask?.cancel()
            return
        }
        if isSystemAudioTestRunning {
            systemAudioTestTask?.cancel()
            return
        }
        if state == .transcribing {
            activeDictationTask?.cancel()
            for task in retryTranscriptionTasks.values { task.cancel() }
            return
        }
        guard recorder.isRecording else { return }
        Task { await cancelRecording() }
    }

    private func cancelRecording() async {
        do {
            let recording = try await recorder.stop()
            recorder.previewBufferHandler = nil
            livePreviewCoordinator.cancel()
            let target = focusTarget
            focusTarget = nil
            state = .idle
            audioLevel = 0
            overlay.hide()
            sessionRecorder = nil
            sessionConfiguration = nil
            Task {
                var record = makeRecord(from: recording, target: target, status: .cancelled)
                record.cancelled = true
                await persistBestEffort(record, context: "cancelled recording")
                await refreshHistory()
            }
        } catch {
            sessionRecorder = nil
            sessionConfiguration = nil
            fail(error, retainedAudioURL: nil)
        }
    }

    func selectDictationHotKey(id: String) {
        if let value = dictationHotKeys.first(where: { $0.id == id }) { setDictationHotKey(value) }
    }

    func setDictationHotKey(_ value: HotKeyConfiguration) {
        guard value != settings.dictationHotKey else { return }
        let old = settings.dictationHotKey
        do { try registerDictationHotKey(value); settings.dictationHotKey = value }
        catch { try? registerDictationHotKey(old); fail(error, retainedAudioURL: nil) }
    }

    func selectCancelHotKey(id: String) {
        if let value = cancelHotKeys.first(where: { $0.id == id }) { setCancelHotKey(value) }
    }

    func setCancelHotKey(_ value: HotKeyConfiguration) {
        guard value != settings.cancelHotKey else { return }
        let old = settings.cancelHotKey
        do { try registerCancelHotKey(value); settings.cancelHotKey = value }
        catch { try? registerCancelHotKey(old); fail(error, retainedAudioURL: nil) }
    }

    func setRestoreHotKey(_ value: HotKeyConfiguration) {
        guard value != settings.restoreHotKey else { return }
        let old = settings.restoreHotKey
        do { try registerRestoreHotKey(value); settings.restoreHotKey = value }
        catch { try? registerRestoreHotKey(old); fail(error, retainedAudioURL: nil) }
    }

    func selectInputDevice(uid: String?) {
        guard !recorder.isRecording else { return }
        settings.inputDeviceUID = uid
        objectWillChange.send()
    }

    func refreshInputDevices() {
        // Core Audio device enumeration can briefly contend with the active input graph.
        // Keep the running recording untouched when Settings becomes active.
        guard !recorder.isRecording else { return }
        do {
            inputDevices = try audioDeviceService.inputDevices()
            if let uid = settings.inputDeviceUID, !inputDevices.contains(where: { $0.uid == uid }) {
                settings.inputDeviceUID = nil
            }
        } catch {
            inputDevices = []
            FlowLogger.audio.error("Could not enumerate input devices: \(error.localizedDescription, privacy: .public)")
        }
    }

    func restoreRecordingOverlayAfterSettingsActivation() {
        guard recorder.isRecording else { return }
        // Opening a Settings scene can reorder auxiliary AppKit panels. Reassert the
        // existing overlay without restarting the recorder or Speech recognition.
        overlay.show(status: .recording, level: audioLevel, reposition: false)
        overlay.updateSource(settings.recordingAudioSource)
        overlay.updatePreview(livePreviewCoordinator.state)
    }

    func saveAPIKey(_ value: String) {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        do {
            try credentialStore.saveAPIKey(value)
            cachedAPIKey = value
            didLoadAPIKeyFromKeychain = true
            setupMessage = "API key stored securely in Keychain."
            refreshConfigurationStatus()
            if case .failed = state { state = .idle }
        } catch { fail(error, retainedAudioURL: nil) }
    }

    func validateAndSaveAPIKey(_ value: String) async -> Bool {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { setupMessage = "Enter an API key."; return false }
        do {
            try await OpenAICredentialValidator().validate(apiKey: value)
            try credentialStore.saveAPIKey(value)
            cachedAPIKey = value
            didLoadAPIKeyFromKeychain = true
            setupMessage = "Connection verified. API key stored securely in Keychain."
            refreshConfigurationStatus()
            return true
        } catch { setupMessage = error.localizedDescription; return false }
    }

    func deleteAPIKey() {
        do {
            try credentialStore.deleteAPIKey()
            cachedAPIKey = nil
            didLoadAPIKeyFromKeychain = true
            refreshConfigurationStatus()
        }
        catch { fail(error, retainedAudioURL: nil) }
    }

    func refreshConfigurationStatus() {
        let environmentKey = environment["OPENAI_API_KEY"]
        if environmentKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            apiKeyConfigured = true
        } else {
            apiKeyConfigured = (try? keychainAPIKey())?.isEmpty == false
        }
        recordingLocationConfigured = (try? recordingLocationStore.resolvedDirectory()) != nil
        recordingLocationPath = recordingLocationStore.displayPath
    }

    func refreshPermissionStatus() {
        microphonePermissionGranted = permissionManager.hasMicrophoneAccess
        accessibilityPermissionGranted = permissionManager.hasEventPostingAccess
        speechPermissionState = permissionManager.speechRecognitionStatus
        systemAudioPermissionGranted = SystemAudioPermissionService().isAuthorized
    }

    func chooseRecordingDirectory(recommended: Bool) {
        do {
            var copiedExistingAudio = false
            let url = try recordingLocationStore.chooseDirectory(recommended: recommended) { previous, selected in
                guard let previous,
                      previous.standardizedFileURL != selected.standardizedFileURL else { return }
                copiedExistingAudio = try copyExistingRecordings(from: previous, to: selected)
            }
            recordingLocationConfigured = true
            recordingLocationPath = url.path
            setupMessage = copiedExistingAudio
                ? "Recordings will be stored in \(url.path). Existing audio was copied safely."
                : "Recordings will be stored in \(url.path)."
        } catch RecordingLocationError.selectionCancelled { return }
        catch { setupMessage = error.localizedDescription }
    }

    func completeOnboarding() {
        guard apiKeyConfigured, recordingLocationConfigured else {
            setupMessage = "Configure an API key and a recordings folder first."
            return
        }
        settings.onboardingVersion = Self.currentOnboardingVersion
        setupMessage = "FlowDictate is ready."
        onboardingWindowController?.close()
    }

    func showOnboarding() {
        if let window = onboardingWindowController?.window { window.makeKeyAndOrderFront(nil) }
        else {
            onboardingWindowController = OnboardingWindowController(coordinator: self)
            onboardingWindowController?.showWindow(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func showHistory() {
        if let window = historyWindowController?.window { window.makeKeyAndOrderFront(nil) }
        else {
            let controller = HistoryWindowController(coordinator: self)
            controller.onClose = { [weak self, weak controller] in
                guard let self, self.historyWindowController === controller else { return }
                self.historyWindowController = nil
            }
            historyWindowController = controller
            controller.showWindow(nil)
        }
        Task { await refreshHistory() }
        NSApp.activate(ignoringOtherApps: true)
    }

    func revealRetainedAudio() {
        if case let .failed(_, url?) = state { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }
    func revealLatestOutput() {
        guard let latestOutputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([latestOutputURL])
    }
    func revealRecordingsFolder() {
        do { NSWorkspace.shared.open(try recordingLocationStore.resolvedDirectory()) }
        catch { fail(error, retainedAudioURL: nil) }
    }
    func revealAudio(for record: DictationRecord) {
        do { NSWorkspace.shared.activateFileViewerSelecting([try audioURL(for: record)]) }
        catch { fail(error, retainedAudioURL: nil) }
    }
    func playAudio(for record: DictationRecord) {
        do { audioPlayer = try AVAudioPlayer(contentsOf: audioURL(for: record)); audioPlayer?.play() }
        catch { fail(error, retainedAudioURL: nil) }
    }
    func copyText(from record: DictationRecord) {
        guard let text = record.finalText ?? record.originalTranscript else { return }
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string)
    }

    func copyOriginalText(from record: DictationRecord) {
        guard let text = record.originalTranscript else { return }
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string)
    }

    func insertOriginalText(_ record: DictationRecord) {
        guard let text = record.originalTranscript, let target = insertionTarget(for: record) else {
            fail(TextInsertionError.targetUnavailable, retainedAudioURL: try? audioURL(for: record)); return
        }
        var resolved = record
        resolved.finalText = text
        resolved.processingStatus = .completed
        resolved.enhancementFallback = .useOriginal
        Task { await insertStoredText(text, record: resolved, target: target) }
    }

    func exportText(from record: DictationRecord) {
        guard let text = record.finalText ?? record.originalTranscript else { return }
        let panel = NSSavePanel()
        panel.title = "Export Dictation Text"
        panel.nameFieldStringValue = "FlowDictate-\(record.id.uuidString).txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try text.write(to: url, atomically: true, encoding: .utf8) }
        catch { fail(error, retainedAudioURL: nil) }
    }

    func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.title = "Export FlowDictate Diagnostics"
        panel.nameFieldStringValue = "FlowDictate-Diagnostics.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let statusCounts = Dictionary(grouping: historyRecords, by: { $0.status.rawValue })
            .mapValues(\.count)
        let processingStatusCounts = Dictionary(
            grouping: historyRecords,
            by: { $0.processingStatus.rawValue }
        ).mapValues(\.count)
        let payload: [String: Any] = [
            "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "macOS": ProcessInfo.processInfo.operatingSystemVersionString,
            "apiKeyConfigured": apiKeyConfigured,
            "recordingLocationConfigured": recordingLocationConfigured,
            "microphonePermission": microphonePermissionGranted,
            "accessibilityPermission": accessibilityPermissionGranted,
            "historyStatusCounts": statusCounts,
            "smartProcessingStatusCounts": processingStatusCounts,
            "spokenFormattingEnabled": settings.spokenFormattingEnabled,
            "personalDictionaryEnabled": settings.personalDictionaryEnabled,
            "dictionaryEntryCount": dictionaryEntries.count,
            "customWritingStyleCount": writingStyles.filter { !$0.isBuiltIn }.count,
            "onboardingVersion": settings.onboardingVersion
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
        } catch { fail(error, retainedAudioURL: nil) }
    }

    func deleteHistoryRecord(_ record: DictationRecord, deleteAudio: Bool) {
        Task {
            do {
                if deleteAudio {
                    if let url = try? audioURL(for: record), FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                    }
                    try await historyStore.delete(id: record.id)
                    await transcriptionRunner.deleteLongFormSession(recordID: record.id)
                } else if record.audioFileSize > 0 {
                    try await historyStore.archive(id: record.id)
                    await transcriptionRunner.deleteLongFormSession(recordID: record.id)
                } else {
                    try await historyStore.delete(id: record.id)
                    await transcriptionRunner.deleteLongFormSession(recordID: record.id)
                }
            } catch {
                FlowLogger.app.error("History deletion failed: \(error.localizedDescription, privacy: .public)")
            }
            await refreshHistory()
        }
    }

    func retryTranscription(_ record: DictationRecord) {
        guard record.canRetry, !retryingRecordIDs.contains(record.id) else { return }
        retryingRecordIDs.insert(record.id)
        retryTranscriptionTasks[record.id] = Task {
            defer {
                retryingRecordIDs.remove(record.id)
                retryTranscriptionTasks[record.id] = nil
                if retryTranscriptionTasks.isEmpty, state == .transcribing {
                    state = .idle
                    overlay.hide()
                }
            }
            var updated = record
            do {
                let url = try audioURL(for: record)
                updated = try await transcriptionRunner.run(
                    record: updated,
                    audioURL: url,
                    language: updated.language,
                    maximumAttempts: settings.automaticRetryEnabled ? 3 : 1,
                    provider: try activeProvider(model: updated.modelID),
                    progress: { [weak self] progress in
                        self?.state = .transcribing
                        self?.overlay.show(status: .longForm(progress.statusText))
                    }
                )
                let style = selectedWritingStyle
                updated = try await smartDictationPipeline.run(
                    record: updated,
                    spokenFormattingEnabled: settings.spokenFormattingEnabled,
                    dictionaryEntries: settings.personalDictionaryEnabled ? dictionaryEntries : [],
                    style: style,
                    enhancementModel: settings.enhancementModel,
                    fallback: settings.smartDictationFallback,
                    enhancer: style.usesAI ? try activeEnhancer() : nil
                )
            } catch let failure as TranscriptionRunFailure {
                updated = failure.record
            } catch let failure as TranscriptionPersistenceFailure {
                FlowLogger.app.error("Retry history persistence failed: \(failure.localizedDescription, privacy: .public)")
                fail(failure, retainedAudioURL: try? audioURL(for: record))
            } catch let failure as SmartDictationRunFailure {
                updated = failure.record
                setupMessage = "Transcription recovered, but Smart Dictation still needs attention."
            } catch {
                if updated.originalTranscript == nil {
                    updated.status = .transcriptionFailed
                    updated.errorCategory = DictationFailureClassifier.category(for: error)
                    updated.errorMessage = error.localizedDescription
                } else {
                    updated.processingStatus = .enhancementFailed
                    updated.enhancementErrorCategory = DictationFailureClassifier.category(for: error)
                    updated.enhancementErrorMessage = error.localizedDescription
                }
                updated.updatedAt = Date()
                await persistBestEffort(updated, context: "transcription retry failure")
            }
            await refreshHistory()
        }
    }

    func reinsert(_ record: DictationRecord) {
        guard let text = record.finalText ?? record.originalTranscript,
              let target = insertionTarget(for: record) else {
            fail(TextInsertionError.targetUnavailable, retainedAudioURL: nil); return
        }
        Task { await insertStoredText(text, record: record, target: target) }
    }

    func restoreLastDictation() {
        guard !recorder.isRecording, !isHandlingToggle, state.acceptsStart else {
            setupMessage = "Finish the current dictation before restoring an earlier one."
            return
        }
        Task {
            do {
                guard let record = try await historyStore.lastInsertable() else {
                    failMessage("No successful dictation is available to restore."); return
                }
                reinsert(record)
            } catch {
                FlowLogger.app.error("History restore lookup failed: \(error.localizedDescription, privacy: .public)")
                fail(error, retainedAudioURL: nil)
            }
        }
    }

    func migrateLegacyRecordings() {
        Task {
            guard let legacy = AudioStore.legacyRecordingsDirectory(),
                  let files = try? FileManager.default.contentsOfDirectory(at: legacy, includingPropertiesForKeys: [.fileSizeKey]),
                  !files.isEmpty else { setupMessage = "No Phase 1 recordings were found."; return }
            do {
                let destination = try audioStore.recordingsDirectory()
                for source in files where source.pathExtension.lowercased() == "wav" {
                    let target = destination.appendingPathComponent(source.lastPathComponent)
                    if !FileManager.default.fileExists(atPath: target.path) { try FileManager.default.copyItem(at: source, to: target) }
                    let values = try target.resourceValues(forKeys: [.fileSizeKey])
                    let record = DictationRecord.migratedLegacyRecording(
                        relativePath: try audioStore.relativePath(for: target),
                        fileSize: Int64(values.fileSize ?? 0)
                    )
                    try await historyStore.upsert(record)
                }
                setupMessage = "Phase 1 recordings were copied into the selected folder."
                await refreshHistory()
            } catch { setupMessage = error.localizedDescription }
        }
    }

    func openMicrophoneSettings() { permissionManager.openMicrophoneSettings() }
    func openAccessibilitySettings() { permissionManager.openAccessibilitySettings() }
    func openSpeechRecognitionSettings() { permissionManager.openSpeechRecognitionSettings() }
    func openKeyboardSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    var livePreviewAvailability: LivePreviewAvailability {
        livePreviewAvailabilityProvider(settings.transcriptionLanguage, speechPermissionState)
    }

    func requestSpeechRecognitionPermission() {
        Task {
            speechPermissionState = await permissionManager.requestSpeechRecognitionAccess()
            switch speechPermissionState {
            case .authorized:
                setupMessage = "Speech Recognition is enabled for local Live Preview."
            case .denied:
                setupMessage = "Speech Recognition was denied. You can enable it later in System Settings."
            case .restricted:
                setupMessage = "Speech Recognition is restricted on this Mac."
            case .notDetermined:
                setupMessage = "Speech Recognition permission has not been decided yet."
            }
        }
    }

    func testLivePreview() {
        guard !isPreviewTestRunning, !recorder.isRecording, state.acceptsStart else { return }
        guard settings.livePreviewEnabled else {
            setupMessage = "Enable Live Preview before starting the test."
            return
        }
        isPreviewTestRunning = true
        previewTestTask = Task { [weak self] in
            guard let self else { return }
            var testAudioURL: URL?
            do {
                try await permissionManager.ensureMicrophoneAccess()
                if permissionManager.speechRecognitionStatus == .notDetermined {
                    speechPermissionState = await permissionManager.requestSpeechRecognitionAccess()
                } else {
                    refreshPermissionStatus()
                }
                guard speechPermissionState == .authorized else {
                    throw FlowPermissionError.speechRecognitionDenied
                }
                recorder.selectInputDevice(
                    try audioDeviceService.deviceID(forUID: settings.inputDeviceUID)
                )
                sessionRecorder = microphoneRecorder
                try await startRecorderWithPreview()
                guard recorder.previewBufferHandler != nil else {
                    throw LivePreviewProviderError.recognizerUnavailable
                }
                overlay.show(status: .recording, reposition: true)
                setupMessage = "Live Preview test is running for 5 seconds…"
                try await Task.sleep(for: .seconds(5))
            } catch is CancellationError {
                setupMessage = "Live Preview test cancelled."
            } catch {
                setupMessage = error.localizedDescription
                FlowLogger.audio.error(
                    "Live Preview test could not start: \(error.localizedDescription, privacy: .public)"
                )
            }

            if recorder.isRecording {
                do {
                    testAudioURL = try await recorder.stop().url
                } catch {
                    FlowLogger.audio.error(
                        "Preview test recorder cleanup failed: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
            recorder.previewBufferHandler = nil
            livePreviewCoordinator.cancel()
            overlay.hide()
            if let testAudioURL {
                do { try FileManager.default.removeItem(at: testAudioURL) }
                catch {
                    FlowLogger.audio.error(
                        "Preview test audio cleanup failed: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
            if setupMessage?.hasPrefix("Live Preview test is running") == true {
                setupMessage = "Live Preview test completed."
            }
            isPreviewTestRunning = false
            previewTestTask = nil
            sessionRecorder = nil
        }
    }

    func selectRecordingAudioSource(_ source: RecordingAudioSource) {
        guard !recorder.isRecording, !isProcessing, source != .mixed else { return }
        settings.recordingAudioSource = source
        refreshPermissionStatus()
    }

    func openSystemAudioSettings() {
        SystemAudioPermissionService().openSystemSettings()
    }

    func refreshPermissionStatuses() {
        refreshPermissionStatus()
    }

    func testSystemAudio() {
        guard !isSystemAudioTestRunning, !recorder.isRecording, state.acceptsStart else { return }
        isSystemAudioTestRunning = true
        systemAudioTestTask = Task { [weak self] in
            guard let self else { return }
            var temporaryURL: URL?
            do {
                sessionRecorder = systemAudioRecorder
                try await systemAudioRecorder.start()
                overlay.updateSource(.systemAudio)
                overlay.show(status: .recording, reposition: true)
                setupMessage = "System Audio test is running for 5 seconds…"
                try await Task.sleep(for: .seconds(5))
                temporaryURL = try await systemAudioRecorder.stop().url
                if let temporaryURL { try validateSystemAudioTestFile(temporaryURL) }
                setupMessage = "System Audio test completed successfully."
            } catch is CancellationError {
                if systemAudioRecorder.isRecording {
                    temporaryURL = try? await systemAudioRecorder.stop().url
                }
                setupMessage = "System Audio test cancelled."
            } catch {
                if systemAudioRecorder.isRecording { _ = try? await systemAudioRecorder.stop() }
                setupMessage = error.localizedDescription
            }
            if let temporaryURL { try? FileManager.default.removeItem(at: temporaryURL) }
            sessionRecorder = nil
            audioLevel = 0
            overlay.hide()
            isSystemAudioTestRunning = false
            systemAudioTestTask = nil
            refreshPermissionStatus()
        }
    }

    private func validateSystemAudioTestFile(_ url: URL) throws {
        let file = try AVAudioFile(forReading: url)
        guard file.length > 0, file.fileFormat.sampleRate > 0 else {
            throw SystemAudioRecorderError.noAudioReceived
        }
    }

    func requestRequiredPermissions() {
        Task {
            do {
                try await permissionManager.ensureMicrophoneAccess()
                try permissionManager.ensureEventPostingAccess()
            } catch {
                setupMessage = error.localizedDescription
            }
            refreshPermissionStatus()
        }
    }

    func toggleDictation() async {
        guard !isHandlingToggle, !isPreviewTestRunning, !isSystemAudioTestRunning else { return }
        isHandlingToggle = true
        defer { isHandlingToggle = false }
        if recorder.isRecording { await stopAndTranscribe() }
        else if state.acceptsStart { await startRecording() }
    }

    func refreshHistory() async {
        do { historyRecords = try await historyStore.all() }
        catch { FlowLogger.app.error("History load failed: \(error.localizedDescription, privacy: .public)") }
    }

    func refreshSmartDictationData() async {
        do {
            dictionaryEntries = try await dictionaryStore.all()
            writingStyles = try await writingStyleStore.all()
            if !writingStyles.contains(where: { $0.id == settings.writingStyleID && $0.isEnabled }) {
                settings.writingStyleID = BuiltInWritingStyles.originalID
            }
        } catch {
            FlowLogger.app.error("Smart Dictation data load failed: \(error.localizedDescription, privacy: .public)")
            setupMessage = error.localizedDescription
        }
    }

    func refreshAppProfiles() async {
        do { appProfiles = try await appProfileStore.all() }
        catch { setupMessage = error.localizedDescription }
    }

    func saveAppProfile(_ profile: AppDictationProfile) {
        Task {
            do {
                try await appProfileStore.upsert(profile)
                await refreshAppProfiles()
                setupMessage = "App profile saved."
            } catch { setupMessage = error.localizedDescription }
        }
    }

    func deleteAppProfile(_ profile: AppDictationProfile) {
        Task {
            do {
                try await appProfileStore.delete(id: profile.id)
                await refreshAppProfiles()
            } catch { setupMessage = error.localizedDescription }
        }
    }

    var recentProfileCandidates: [(bundleIdentifier: String, displayName: String)] {
        var seen = Set<String>()
        return historyRecords.compactMap { record in
            guard let bundle = record.targetBundleIdentifier,
                  let name = record.targetApplicationName,
                  !bundle.isEmpty,
                  !seen.contains(bundle),
                  !appProfiles.contains(where: { $0.bundleIdentifier == bundle }) else { return nil }
            seen.insert(bundle)
            return (bundle, name)
        }
    }

    var usageStatistics: UsageStatistics {
        usageStatistics(period: .total)
    }

    func usageStatistics(
        period: UsageStatisticsPeriod,
        now: Date = Date()
    ) -> UsageStatistics {
        let since = [period.startDate(relativeTo: now), settings.usageStatisticsResetDate]
            .compactMap { $0 }
            .max()
        return UsageStatistics.calculate(
            records: historyRecords,
            typingWordsPerMinute: settings.typingWordsPerMinute,
            since: since
        )
    }

    func checkForUpdates(manual: Bool = true) async {
        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true
        defer { isCheckingForUpdates = false }
        if manual { updateCheckMessage = nil }
        settings.lastUpdateCheck = Date()
        do {
            let release = try await GitHubReleaseChecker().latestStableRelease()
            let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
                as? String ?? "0"
            if let release, GitHubReleaseChecker.isNewer(release.version, than: current) {
                availableRelease = release
                if manual {
                    let message = "FlowDictate \(release.version) is available."
                    updateCheckMessage = message
                    setupMessage = message
                }
            } else if manual {
                availableRelease = nil
                let message = "FlowDictate is up to date."
                updateCheckMessage = message
                setupMessage = message
            }
        } catch {
            if manual {
                updateCheckMessage = error.localizedDescription
                setupMessage = error.localizedDescription
            }
        }
    }

    func openAvailableRelease() {
        guard let availableRelease else { return }
        NSWorkspace.shared.open(availableRelease.pageURL)
    }

    func saveDictionaryEntry(_ entry: DictionaryEntry) {
        Task {
            do {
                try await dictionaryStore.upsert(entry)
                await refreshSmartDictationData()
                setupMessage = "Dictionary entry saved."
            } catch { setupMessage = error.localizedDescription }
        }
    }

    func deleteDictionaryEntry(_ entry: DictionaryEntry) {
        Task {
            do {
                try await dictionaryStore.delete(id: entry.id)
                await refreshSmartDictationData()
                setupMessage = "Dictionary entry deleted."
            } catch { setupMessage = error.localizedDescription }
        }
    }

    func saveWritingStyle(_ style: WritingStyleProfile) {
        Task {
            do {
                try await writingStyleStore.upsert(style)
                await refreshSmartDictationData()
                settings.writingStyleID = style.id
                setupMessage = "Writing style saved."
            } catch { setupMessage = error.localizedDescription }
        }
    }

    func duplicateWritingStyle(_ style: WritingStyleProfile) {
        Task {
            do {
                let copy = try await writingStyleStore.duplicate(style)
                await refreshSmartDictationData()
                settings.writingStyleID = copy.id
                setupMessage = "Writing style duplicated."
            } catch { setupMessage = error.localizedDescription }
        }
    }

    func deleteWritingStyle(_ style: WritingStyleProfile) {
        Task {
            do {
                try await writingStyleStore.delete(id: style.id)
                if settings.writingStyleID == style.id {
                    settings.writingStyleID = BuiltInWritingStyles.originalID
                }
                await refreshSmartDictationData()
                setupMessage = "Writing style deleted."
            } catch { setupMessage = error.localizedDescription }
        }
    }

    func exportDictionary() { chooseSmartDictationExport(filename: "FlowDictate-Dictionary.json") { url in try await self.dictionaryStore.export(to: url) } }
    func exportWritingStyles() { chooseSmartDictationExport(filename: "FlowDictate-Writing-Styles.json") { url in try await self.writingStyleStore.export(to: url) } }
    func importDictionary() { chooseSmartDictationImport { url in try await self.dictionaryStore.importFile(from: url) } }
    func importWritingStyles() { chooseSmartDictationImport { url in try await self.writingStyleStore.importFile(from: url) } }

    func testSmartDictation(_ text: String) {
        guard !isSmartDictationTestRunning else { return }
        let original = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { smartDictationTestOutput = "Enter sample text first."; return }
        isSmartDictationTestRunning = true
        Task {
            defer { isSmartDictationTestRunning = false }
            let formatted = settings.spokenFormattingEnabled
                ? SpokenFormattingProcessor().process(original, language: settings.transcriptionLanguage.apiValue).text
                : original
            let entries = settings.personalDictionaryEnabled ? dictionaryEntries : []
            let local = PersonalDictionaryProcessor().process(
                formatted,
                entries: entries,
                language: settings.transcriptionLanguage.apiValue
            ).text
            let style = selectedWritingStyle
            guard style.usesAI else { smartDictationTestOutput = local; return }
            do {
                let result = try await activeEnhancer().enhance(
                    TranscriptEnhancementRequest(
                        text: local,
                        styleInstruction: style.instruction,
                        language: settings.transcriptionLanguage.apiValue,
                        model: settings.enhancementModel,
                        protectedTerms: entries.map(\.replacement)
                    )
                )
                smartDictationTestOutput = result.text
            } catch { smartDictationTestOutput = error.localizedDescription }
        }
    }

    func retryEnhancement(_ record: DictationRecord) {
        guard record.canRetryEnhancement, !retryingEnhancementRecordIDs.contains(record.id) else { return }
        retryingEnhancementRecordIDs.insert(record.id)
        Task {
            defer { retryingEnhancementRecordIDs.remove(record.id) }
            do {
                let style = writingStyles.first { $0.id == record.writingStyleID } ?? selectedWritingStyle
                _ = try await smartDictationPipeline.retryEnhancement(
                    record: record,
                    style: style,
                    model: record.enhancementModelID ?? settings.enhancementModel,
                    fallback: .ask,
                    dictionaryEntries: settings.personalDictionaryEnabled ? dictionaryEntries : [],
                    enhancer: try activeEnhancer()
                )
                setupMessage = "Smart Dictation completed."
            } catch { setupMessage = error.localizedDescription }
            await refreshHistory()
        }
    }

    func reprocess(_ record: DictationRecord, writingStyleID: UUID) {
        guard let style = writingStyles.first(where: { $0.id == writingStyleID }) else { return }
        Task {
            do {
                _ = try await smartDictationPipeline.processWithStyle(
                    record: record,
                    style: style,
                    model: settings.enhancementModel,
                    fallback: .ask,
                    dictionaryEntries: settings.personalDictionaryEnabled ? dictionaryEntries : [],
                    enhancer: style.usesAI ? try activeEnhancer() : nil
                )
                setupMessage = "Dictation reprocessed. Review the result in History."
            } catch { setupMessage = error.localizedDescription }
            await refreshHistory()
        }
    }

    func reapplyLocalRules(_ record: DictationRecord) {
        guard record.originalTranscript != nil else { return }
        let style = writingStyles.first { $0.id == record.writingStyleID } ?? selectedWritingStyle
        Task {
            do {
                _ = try await smartDictationPipeline.recoverInterruptedLocalProcessing(
                    record: record,
                    spokenFormattingEnabled: settings.spokenFormattingEnabled,
                    dictionaryEntries: settings.personalDictionaryEnabled ? dictionaryEntries : [],
                    intendedStyle: style
                )
                setupMessage = style.usesAI
                    ? "Local rules reapplied. Retry the writing style from History when ready."
                    : "Local rules reapplied. Review the result in History."
            } catch { setupMessage = error.localizedDescription }
            await refreshHistory()
        }
    }

    func insertLocallyProcessedText(_ record: DictationRecord) {
        guard let text = record.dictionaryTranscript ?? record.formattedTranscript ?? record.originalTranscript,
              let target = insertionTarget(for: record) else {
            fail(TextInsertionError.targetUnavailable, retainedAudioURL: try? audioURL(for: record)); return
        }
        var resolved = record
        resolved.finalText = text
        resolved.processingStatus = .completed
        resolved.enhancementFallback = .useLocallyProcessed
        Task { await insertStoredText(text, record: resolved, target: target) }
    }

    func applyRetentionSettings() {
        Task {
            do {
                try await applyRetentionPolicy()
                let result = try await historyStore.applyRetention(
                    maximumAgeDays: settings.historyRetentionDays,
                    maximumRecordCount: settings.historyMaximumRecordCount
                )
                FlowLogger.app.info(
                    "Manual retention removed \(result.removedCount, privacy: .public) and archived \(result.archivedCount, privacy: .public) records"
                )
                setupMessage = "Retention settings applied."
            } catch {
                FlowLogger.app.error("Manual retention failed: \(error.localizedDescription, privacy: .public)")
                setupMessage = error.localizedDescription
            }
            await refreshHistory()
        }
    }

    private func recoverAndRefreshHistory() async {
        do {
            let recovered = try await historyStore.recoverInterrupted()
            await transcriptionRunner.recoverInterruptedLongFormSessions()
            for record in recovered
            where record.processingStatus == .notStarted
                && record.enhancementErrorCategory == .interrupted
                && record.originalTranscript != nil {
                let intendedStyle = writingStyles.first { $0.id == record.writingStyleID }
                    ?? BuiltInWritingStyles.all[0]
                _ = try await smartDictationPipeline.recoverInterruptedLocalProcessing(
                    record: record,
                    spokenFormattingEnabled: record.spokenFormattingEnabled,
                    dictionaryEntries: settings.personalDictionaryEnabled ? dictionaryEntries : [],
                    intendedStyle: intendedStyle
                )
            }
            try await recoverOrphanedAudio()
            try await applyRetentionPolicy()
            let historyResult = try await historyStore.applyRetention(
                maximumAgeDays: settings.historyRetentionDays,
                maximumRecordCount: settings.historyMaximumRecordCount
            )
            if historyResult.removedCount > 0 || historyResult.archivedCount > 0 {
                FlowLogger.app.info(
                    "History retention removed \(historyResult.removedCount, privacy: .public) and archived \(historyResult.archivedCount, privacy: .public) records"
                )
            }
        }
        catch { FlowLogger.app.error("Recovery failed: \(error.localizedDescription, privacy: .public)") }
        await refreshHistory()
    }

    private func applyRetentionPolicy(now: Date = Date()) async throws {
        let days = settings.audioRetentionDays
        guard days >= 0, recordingLocationConfigured,
              let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now) else { return }
        for var record in try await historyStore.all(includeArchived: true)
        where record.status == .completed && record.recordingEndedAt < cutoff && record.audioFileSize > 0 {
            let url = try audioURL(for: record)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            record.audioFileSize = 0
            record.updatedAt = now
            try await historyStore.upsert(record)
        }
    }

    private func recoverOrphanedAudio() async throws {
        guard recordingLocationConfigured else { return }
        let known = try await historyStore.knownAudioRelativePaths()
        let directory = try audioStore.recordingsDirectory()
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
        for file in files where ["wav", "m4a", "recording"].contains(file.pathExtension.lowercased()) {
            let relative = try audioStore.relativePath(for: file)
            guard !known.contains(relative) else { continue }
            let values = try file.resourceValues(forKeys: [.fileSizeKey])
            try await historyStore.upsert(.recoveredAudio(
                relativePath: relative,
                fileSize: Int64(values.fileSize ?? 0),
                message: "Audio was found without a completed history entry."
            ))
        }
    }

    private func copyExistingRecordings(from previousRoot: URL, to selectedRoot: URL) throws -> Bool {
        let source = previousRoot.appendingPathComponent("Audio", isDirectory: true)
        guard FileManager.default.fileExists(atPath: source.path) else { return false }

        let previousAccess = previousRoot.startAccessingSecurityScopedResource()
        let selectedAccess = selectedRoot.startAccessingSecurityScopedResource()
        defer {
            if previousAccess { previousRoot.stopAccessingSecurityScopedResource() }
            if selectedAccess { selectedRoot.stopAccessingSecurityScopedResource() }
        }

        let destination = selectedRoot.appendingPathComponent("Audio", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        guard let enumerator = FileManager.default.enumerator(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return false }

        var copiedFile = false
        for case let item as URL in enumerator {
            let relativePath = String(item.path.dropFirst(source.path.count + 1))
            let target = destination.appendingPathComponent(relativePath)
            let values = try item.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            } else if !FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.createDirectory(
                    at: target.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try FileManager.default.copyItem(at: item, to: target)
                copiedFile = true
            }
        }
        return copiedFile
    }

    private func registerInitialHotKeys() {
        do {
            try registerDictationHotKey(settings.dictationHotKey)
            try registerCancelHotKey(settings.cancelHotKey)
            try registerRestoreHotKey(settings.restoreHotKey)
        } catch {
            state = .failed(message: error.localizedDescription, retainedAudioURL: nil)
        }
    }
    private func registerDictationHotKey(_ value: HotKeyConfiguration) throws {
        try dictationHotKeyRegistrar.register(
            value,
            pressed: { [weak self] in self?.dictationHotKeyPressed() },
            released: { [weak self] in self?.dictationHotKeyReleased() }
        )
    }

    private func dictationHotKeyPressed() {
        guard settings.dictationActivationMode == .pressAndHold else {
            requestToggle(); return
        }
        guard !holdHotKeyIsDown else { return }
        holdReleaseTask?.cancel()
        holdHotKeyIsDown = true
        guard !recorder.isRecording else { return }
        Task { [weak self] in await self?.toggleDictation() }
    }

    private func dictationHotKeyReleased() {
        guard settings.dictationActivationMode == .pressAndHold, holdHotKeyIsDown else { return }
        holdHotKeyIsDown = false
        holdReleaseTask?.cancel()
        holdReleaseTask = Task { [weak self] in
            guard let self else { return }
            // Starting ScreenCaptureKit can take a moment. Remember an early key-up
            // and stop as soon as the recorder has actually entered recording state.
            for _ in 0..<80 {
                guard !Task.isCancelled, !self.holdHotKeyIsDown else { return }
                if self.recorder.isRecording {
                    await self.toggleDictation()
                    return
                }
                if !self.isHandlingToggle { return }
                try? await Task.sleep(for: .milliseconds(25))
            }
        }
    }
    private func registerCancelHotKey(_ value: HotKeyConfiguration) throws {
        try cancelHotKeyRegistrar.register(value) { [weak self] in self?.requestCancel() }
    }
    private func registerRestoreHotKey(_ value: HotKeyConfiguration) throws {
        try restoreHotKeyRegistrar.register(value) { [weak self] in self?.restoreLastDictation() }
    }

    private func startRecording() async {
        latestOutputNotice = nil
        latestOutputURL = nil
        refreshConfigurationStatus()
        guard apiKeyConfigured else { showOnboarding(); fail(TranscriptionProviderError.missingAPIKey, retainedAudioURL: nil); return }
        guard recordingLocationConfigured else { showOnboarding(); fail(RecordingLocationError.notConfigured, retainedAudioURL: nil); return }
        guard let target = focusTargetProvider() else {
            fail(TextInsertionError.targetUnavailable, retainedAudioURL: nil,
                 message: "Place the cursor in another application before starting dictation."); return
        }
        do {
            if settings.recordingAudioSource == .microphone {
                try await permissionManager.ensureMicrophoneAccess()
            }
            try permissionManager.ensureEventPostingAccess()
            sessionConfiguration = effectiveConfiguration(for: target)
            refreshPermissionStatus()
            if settings.livePreviewEnabled, speechPermissionState == .notDetermined {
                speechPermissionState = await permissionManager.requestSpeechRecognitionAccess()
            }
            sessionRecorder = settings.recordingAudioSource == .systemAudio
                ? systemAudioRecorder
                : microphoneRecorder
            if settings.recordingAudioSource == .microphone {
                recorder.selectInputDevice(try audioDeviceService.deviceID(forUID: settings.inputDeviceUID))
            }
            try await startRecorderWithPreview()
            overlayDismissTask?.cancel()
            focusTarget = target
            lastExternalFocusTarget = target
            state = .recording
            overlay.updateSource(settings.recordingAudioSource)
            overlay.show(status: .recording, reposition: true)
        } catch AudioDeviceServiceError.selectedDeviceUnavailable {
            settings.inputDeviceUID = nil
            recorder.selectInputDevice(nil)
            do {
                sessionRecorder = microphoneRecorder
                try await startRecorderWithPreview()
                focusTarget = target
                lastExternalFocusTarget = target
                state = .recording
                overlay.updateSource(.microphone)
                overlay.show(status: .recording, reposition: true)
            }
            catch { sessionRecorder = nil; fail(error, retainedAudioURL: nil) }
        } catch { sessionRecorder = nil; refreshPermissionStatus(); fail(error, retainedAudioURL: nil) }
    }

    private func stopAndTranscribe() async {
        state = .finalizing
        audioLevel = 0
        overlay.show(status: .finalizing)
        let recording: AudioRecordingResult
        let stopStarted = ContinuousClock.now
        do {
            recording = try await recorder.stop()
            FlowLogger.audio.info(
                "Recording stop/finalization completed in \(String(describing: stopStarted.duration(to: .now)), privacy: .public)"
            )
        }
        catch { sessionRecorder = nil; fail(error, retainedAudioURL: nil); return }
        recorder.previewBufferHandler = nil
        sessionRecorder = nil
        livePreviewCoordinator.finish()
        latestOutputURL = recording.url
        guard let target = focusTarget else { fail(TextInsertionError.targetUnavailable, retainedAudioURL: recording.url); return }

        var record = makeRecord(from: recording, target: target, status: .recorded)
        do { try await historyStore.upsert(record); await refreshHistory() }
        catch {
            fail(error, retainedAudioURL: recording.url,
                 message: "The recording was saved, but its history entry could not be created: \(error.localizedDescription)")
            return
        }

        state = .transcribing
        do {
            record = try await transcriptionRunner.run(
                record: record,
                audioURL: recording.url,
                language: record.language,
                maximumAttempts: settings.automaticRetryEnabled ? 3 : 1,
                provider: try activeProvider(model: record.modelID),
                progress: { [weak self] progress in
                    self?.overlay.show(status: .longForm(progress.statusText))
                }
            )
            state = .enhancing
            overlay.show(status: .processing)
            let style = writingStyles.first { $0.id == record.writingStyleID && $0.isEnabled }
                ?? BuiltInWritingStyles.all[0]
            record = try await smartDictationPipeline.run(
                record: record,
                spokenFormattingEnabled: record.spokenFormattingEnabled,
                dictionaryEntries: settings.personalDictionaryEnabled ? dictionaryEntries : [],
                style: style,
                enhancementModel: settings.enhancementModel,
                fallback: settings.smartDictationFallback,
                enhancer: style.usesAI ? try activeEnhancer() : nil
            )
            state = .inserting
            overlay.show(status: .inserting)
            record.status = .inserting; record.updatedAt = Date()
            try await historyStore.upsert(record)
            let outputText = record.finalText ?? record.originalTranscript ?? ""
            var successMessage = "Text inserted"
            if record.audioSource == .systemAudio {
                let copied = copyToClipboard(outputText)
                latestOutputNotice = copied
                    ? "System Audio transcript copied to the clipboard."
                    : "System Audio transcript is available in History."
                successMessage = copied
                    ? "Text inserted · copied to clipboard"
                    : "Text inserted · clipboard unavailable"
            }
            try await makeInserter().insert(outputText, into: target)

            // The target application has accepted the text. Reflect that immediately;
            // rewriting the JSON History must not leave a completed insertion looking
            // as if it were still processing.
            focusTarget = nil
            state = .success
            overlay.show(status: .success(message: successMessage))
            sessionConfiguration = nil
            scheduleOverlayDismiss(after: .milliseconds(600), transitionToIdle: true)

            record.status = .completed; record.errorCategory = nil; record.errorMessage = nil; record.updatedAt = Date()
            do {
                try await historyStore.upsert(record)
            } catch {
                setupMessage = "Text was inserted, but the completed History status could not be saved."
                FlowLogger.app.error(
                    "Post-insertion History update failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        } catch let failure as TranscriptionRunFailure {
            record = failure.record
            copySystemAudioTranscriptForRecovery(record, recordingURL: recording.url)
            fail(failure.underlyingError, retainedAudioURL: recording.url)
        } catch let failure as TranscriptionPersistenceFailure {
            record = failure.record
            copySystemAudioTranscriptForRecovery(record, recordingURL: recording.url)
            fail(failure, retainedAudioURL: recording.url)
        } catch let failure as SmartDictationRunFailure {
            record = failure.record
            copySystemAudioTranscriptForRecovery(record, recordingURL: recording.url)
            fail(
                failure.underlyingError,
                retainedAudioURL: recording.url,
                message: "Smart Dictation failed. Your original and locally processed text were kept. \(failure.underlyingError.localizedDescription)"
            )
        } catch {
            record.status = record.originalTranscript == nil ? .transcriptionFailed : .insertionFailed
            record.errorCategory = DictationFailureClassifier.category(for: error)
            record.errorMessage = error.localizedDescription; record.updatedAt = Date()
            await persistBestEffort(record, context: "dictation failure")
            copySystemAudioTranscriptForRecovery(record, recordingURL: recording.url)
            fail(error, retainedAudioURL: recording.url)
        }
        await refreshHistory()
    }

    private func insertStoredText(_ text: String, record: DictationRecord, target: FocusTarget) async {
        var updated = record
        do {
            state = .inserting
            overlay.show(status: .inserting)
            updated.status = .inserting; updated.updatedAt = Date(); try await historyStore.upsert(updated)
            try await makeInserter().insert(text, into: target)
            state = .success
            overlay.show(status: .success(message: "Text inserted"))
            scheduleOverlayDismiss(after: .milliseconds(600), transitionToIdle: true)

            updated.status = .completed; updated.errorCategory = nil; updated.errorMessage = nil; updated.updatedAt = Date()
            do {
                try await historyStore.upsert(updated)
            } catch {
                setupMessage = "Text was inserted, but the completed History status could not be saved."
                FlowLogger.app.error(
                    "Post-insertion History update failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        } catch {
            updated.status = .insertionFailed; updated.errorCategory = .insertion
            updated.errorMessage = error.localizedDescription; updated.updatedAt = Date()
            await persistBestEffort(updated, context: "insertion failure")
            fail(error, retainedAudioURL: try? audioURL(for: record))
        }
        await refreshHistory()
    }

    private func makeRecord(from recording: AudioRecordingResult, target: FocusTarget?, status: DictationRecordStatus) -> DictationRecord {
        let attributes = try? FileManager.default.attributesOfItem(atPath: recording.url.path)
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        let now = Date()
        return .newRecording(
            id: recording.id,
            startedAt: recording.startedAt,
            endedAt: now,
            duration: recording.duration,
            status: status,
            audioRelativePath: (try? audioStore.relativePath(for: recording.url)) ?? recording.url.path,
            audioFileSize: size,
            providerID: "OpenAI",
            modelID: sessionConfiguration?.transcriptionModel ?? settings.transcriptionModel,
            language: (sessionConfiguration?.language ?? settings.transcriptionLanguage).apiValue,
            targetBundleIdentifier: target?.bundleIdentifier,
            targetApplicationName: target?.localizedName,
            sourceMetadata: recording.sourceMetadata
        )
        .withSmartConfiguration(
            writingStyleID: sessionConfiguration?.writingStyleID ?? settings.writingStyleID,
            spokenFormattingEnabled: sessionConfiguration?.spokenFormattingEnabled
                ?? settings.spokenFormattingEnabled
        )
    }

    private func persistBestEffort(_ record: DictationRecord, context: String) async {
        do {
            try await historyStore.upsert(record)
        } catch {
            FlowLogger.app.error(
                "Could not persist \(context, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func audioURL(for record: DictationRecord) throws -> URL {
        record.audioRelativePath.hasPrefix("/")
            ? URL(fileURLWithPath: record.audioRelativePath)
            : try audioStore.url(forRelativePath: record.audioRelativePath)
    }
    private func makeInserter() -> TextInserting {
        if let injectedInserter { return injectedInserter }
        let clipboard = PasteboardTextInserter(
            pasteboard: .general,
            restoreDelay: .milliseconds(Int(settings.clipboardRestoreDelay * 1_000))
        )
        if sessionConfiguration?.insertionPreference == .clipboard { return clipboard }
        return FallbackTextInserter(direct: AccessibilityTextInserter(), clipboard: clipboard)
    }

    private func prepareLivePreview() {
        recorder.previewBufferHandler = nil
        livePreviewCoordinator.cancel()
        didLogLivePreviewText = false
        overlay.configure(size: settings.overlaySize, position: settings.overlayPosition)
        if settings.recordingAudioSource == .systemAudio {
            overlay.updatePreview(.unavailable(RecordingAudioSource.systemAudioPreviewGuidance))
            FlowLogger.audio.info("Live Preview skipped for System Audio")
            return
        }
        FlowLogger.audio.info(
            "Preparing Live Preview: enabled=\(self.settings.livePreviewEnabled, privacy: .public), speechPermission=\(self.speechPermissionState.rawValue, privacy: .public)"
        )
        guard settings.livePreviewEnabled else {
            overlay.updatePreview(.disabled)
            FlowLogger.audio.info("Live Preview is disabled in Settings")
            return
        }
        let availability = livePreviewAvailability
        FlowLogger.audio.info(
            "Live Preview availability: \(availability.statusText, privacy: .public)"
        )
        guard case let .available(localeIdentifier) = availability else {
            overlay.updatePreview(.unavailable(availability.statusText))
            FlowLogger.audio.notice(
                "Live Preview was not started: \(availability.statusText, privacy: .public)"
            )
            return
        }
        FlowLogger.audio.info(
            "Starting local Live Preview with locale \(localeIdentifier, privacy: .public)"
        )
        do {
            recorder.previewBufferHandler = try livePreviewCoordinator.start(
                configuration: LivePreviewConfiguration(
                    localeIdentifier: localeIdentifier,
                    characterLimit: settings.livePreviewCharacterLimit
                )
            )
        } catch {
            recorder.previewBufferHandler = nil
            FlowLogger.audio.notice(
                "Live Preview could not start: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func startRecorderWithPreview() async throws {
        do {
            try await recorder.start()
            // Attach Speech only after the audio engine is stable. Starting the
            // recognizer first can race Core Audio device initialization.
            prepareLivePreview()
        } catch {
            recorder.previewBufferHandler = nil
            livePreviewCoordinator.cancel()
            throw error
        }
    }

    private func insertionTarget(for record: DictationRecord) -> FocusTarget? {
        if let current = focusTargetProvider() {
            lastExternalFocusTarget = current
            return current
        }
        if let recordedApplication = FocusTarget.capture(
            bundleIdentifier: record.targetBundleIdentifier
        ) {
            lastExternalFocusTarget = recordedApplication
            return recordedApplication
        }
        if let lastExternalFocusTarget, lastExternalFocusTarget.isAvailable {
            return lastExternalFocusTarget
        }
        return nil
    }
    private func activeProvider(model preferredModel: String? = nil) throws -> any TranscriptionProvider {
        if let injectedProvider { return injectedProvider }
        let environmentKey = environment["OPENAI_API_KEY"]
        let keychainKey = environmentKey?.isEmpty == false ? nil : try keychainAPIKey()
        guard let key = [environmentKey, keychainKey].compactMap({ $0 }).first(where: { !$0.isEmpty }) else {
            throw TranscriptionProviderError.missingAPIKey
        }
        let configured = (preferredModel ?? settings.transcriptionModel)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let model = environment["FLOWDICTATE_TRANSCRIPTION_MODEL"]?.isEmpty == false
            ? environment["FLOWDICTATE_TRANSCRIPTION_MODEL"]! : (configured.isEmpty ? "gpt-4o-mini-transcribe" : configured)
        return OpenAITranscriptionProvider(apiKey: key, model: model)
    }

    private var selectedWritingStyle: WritingStyleProfile {
        writingStyles.first { $0.id == settings.writingStyleID && $0.isEnabled }
            ?? BuiltInWritingStyles.all[0]
    }

    private func effectiveConfiguration(for target: FocusTarget) -> EffectiveDictationConfiguration {
        let profile = appProfiles.first {
            $0.isEnabled && $0.bundleIdentifier == target.bundleIdentifier
        }
        return EffectiveDictationConfiguration(
            language: profile?.language ?? settings.transcriptionLanguage,
            transcriptionModel: profile?.transcriptionModel?.trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty ?? settings.transcriptionModel,
            writingStyleID: profile?.writingStyleID ?? settings.writingStyleID,
            spokenFormattingEnabled: profile?.spokenFormattingEnabled
                ?? settings.spokenFormattingEnabled,
            insertionPreference: profile?.insertionPreference ?? .automatic,
            profileID: profile?.id
        )
    }

    private func activeEnhancer() throws -> any TranscriptEnhancing {
        if let injectedEnhancer { return injectedEnhancer }
        let environmentKey = environment["OPENAI_API_KEY"]
        let keychainKey = environmentKey?.isEmpty == false ? nil : try keychainAPIKey()
        guard let key = [environmentKey, keychainKey].compactMap({ $0 }).first(where: { !$0.isEmpty }) else {
            throw TranscriptionProviderError.missingAPIKey
        }
        return OpenAITranscriptEnhancer(apiKey: key)
    }

    private func chooseSmartDictationExport(
        filename: String,
        action: @escaping @MainActor (URL) async throws -> Void
    ) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = filename
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do { try await action(url); setupMessage = "Export completed." }
            catch { setupMessage = error.localizedDescription }
        }
    }

    private func chooseSmartDictationImport(
        action: @escaping @MainActor (URL) async throws -> Void
    ) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                try await action(url)
                await refreshSmartDictationData()
                setupMessage = "Import completed."
            } catch { setupMessage = error.localizedDescription }
        }
    }

    private func keychainAPIKey() throws -> String? {
        if didLoadAPIKeyFromKeychain { return cachedAPIKey }
        let value = try credentialStore.readAPIKey()
        cachedAPIKey = value
        didLoadAPIKeyFromKeychain = true
        return value
    }

    @discardableResult
    private func copyToClipboard(_ text: String) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(text, forType: .string)
    }

    private func copySystemAudioTranscriptForRecovery(
        _ record: DictationRecord,
        recordingURL: URL
    ) {
        guard record.audioSource == .systemAudio,
              let text = record.finalText
                ?? record.dictionaryTranscript
                ?? record.formattedTranscript
                ?? record.originalTranscript else { return }
        let copied = copyToClipboard(text)
        latestOutputURL = recordingURL
        latestOutputNotice = copied
            ? "System Audio transcript copied to the clipboard."
            : "System Audio transcript is available in History."
    }

    private func fail(_ error: Error, retainedAudioURL: URL?, message: String? = nil) {
        var resolvedMessage = message ?? error.localizedDescription
        if let retainedAudioURL, !resolvedMessage.contains(retainedAudioURL.path) {
            resolvedMessage += " Recording saved at \(retainedAudioURL.path)."
        }
        failMessage(resolvedMessage, retainedAudioURL: retainedAudioURL)
    }
    private func failMessage(_ message: String, retainedAudioURL: URL? = nil) {
        recorder.previewBufferHandler = nil
        livePreviewCoordinator.cancel()
        state = .failed(message: message, retainedAudioURL: retainedAudioURL)
        focusTarget = nil; audioLevel = 0
        sessionRecorder = nil
        sessionConfiguration = nil
        overlay.show(status: .error(message))
        scheduleOverlayDismiss(after: .seconds(3), transitionToIdle: false)
        FlowLogger.app.error("Dictation failed: \(message, privacy: .public)")
    }
    private func scheduleOverlayDismiss(after duration: Duration, transitionToIdle: Bool) {
        overlayDismissTask?.cancel()
        overlayDismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, let self else { return }
            overlay.hide()
            if transitionToIdle, state == .success { state = .idle }
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
