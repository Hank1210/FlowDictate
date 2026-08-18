//
//  FlowDictateTests.swift
//  FlowDictateTests
//
//  Created by Frank Euler on 16.08.26.
//

import AppKit
import Carbon.HIToolbox
import CoreAudio
import Foundation
import ServiceManagement
import Testing
@testable import FlowDictate

struct FlowDictateTests {
    @Test func dictationStateStartRules() {
        #expect(DictationState.idle.acceptsStart)
        #expect(DictationState.failed(message: "test", retainedAudioURL: nil).acceptsStart)
        #expect(!DictationState.recording.acceptsStart)
        #expect(!DictationState.transcribing.acceptsStart)
        #expect(!DictationState.inserting.acceptsStart)
        #expect(DictationState.success.acceptsStart)
    }

    @Test func multipartBodyContainsFieldsFileAndClosingBoundary() throws {
        let body = MultipartFormDataBuilder(boundary: "boundary")
            .addingField(name: "model", value: "test-model")
            .addingOptionalField(name: "language", value: nil)
            .addingFile(
                name: "file",
                filename: "recording.wav",
                mimeType: "audio/wav",
                data: Data([0x01, 0x02, 0x03])
            )
            .build()

        let text = String(decoding: body, as: UTF8.self)
        #expect(text.contains("name=\"model\""))
        #expect(text.contains("test-model"))
        #expect(text.contains("filename=\"recording.wav\""))
        #expect(text.contains("Content-Type: audio/wav"))
        #expect(!text.contains("name=\"language\""))
        #expect(text.hasSuffix("--boundary--\r\n"))
    }

    @Test func openAITranscriptionPayloadDecodes() throws {
        let data = Data(#"{"text":"Hello from FlowDictate"}"#.utf8)
        let payload = try JSONDecoder().decode(OpenAITranscriptionPayload.self, from: data)
        #expect(payload.text == "Hello from FlowDictate")
    }

    @MainActor
    @Test func pasteboardSnapshotRestoresMultipleRepresentations() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("FlowDictateTests-\(UUID())"))
        pasteboard.clearContents()

        let originalItem = NSPasteboardItem()
        originalItem.setString("original", forType: .string)
        originalItem.setData(Data([0xCA, 0xFE]), forType: .init("dev.flowdictate.test"))
        #expect(pasteboard.writeObjects([originalItem]))

        let snapshot = PasteboardSnapshot.capture(from: pasteboard)
        pasteboard.clearContents()
        #expect(pasteboard.setString("transcript", forType: .string))
        #expect(snapshot.restore(to: pasteboard))

        #expect(pasteboard.string(forType: .string) == "original")
        #expect(
            pasteboard.data(forType: .init("dev.flowdictate.test")) == Data([0xCA, 0xFE])
        )
    }

    @MainActor
    @Test func appSettingsPersistPhaseOneConfiguration() {
        let suiteName = "FlowDictateTests-\(UUID())"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        settings.dictationHotKey = .custom(
            keyCode: 42,
            modifiers: UInt32(optionKey | cmdKey),
            keyName: "K"
        )
        settings.cancelHotKey = .controlShiftSpace
        settings.restoreHotKey = .controlShiftZ
        settings.inputDeviceUID = "test-microphone"
        settings.transcriptionModel = "test-model"
        settings.transcriptionLanguage = .german
        settings.clipboardRestoreDelay = 1.2
        settings.onboardingVersion = 2
        settings.automaticRetryEnabled = false
        settings.audioRetentionDays = 90

        let restored = AppSettings(defaults: defaults)

        #expect(restored.dictationHotKey == settings.dictationHotKey)
        #expect(restored.cancelHotKey == .controlShiftSpace)
        #expect(restored.restoreHotKey == .controlShiftZ)
        #expect(restored.inputDeviceUID == "test-microphone")
        #expect(restored.transcriptionModel == "test-model")
        #expect(restored.transcriptionLanguage == .german)
        #expect(restored.clipboardRestoreDelay == 1.2)
        #expect(restored.onboardingVersion == 2)
        #expect(!restored.automaticRetryEnabled)
        #expect(restored.audioRetentionDays == 90)
    }

    @Test func transcriptionLanguageMapsAutomaticToNil() {
        #expect(TranscriptionLanguage.automatic.apiValue == nil)
        #expect(TranscriptionLanguage.german.apiValue == "de")
        #expect(TranscriptionLanguage.english.apiValue == "en")
    }

    @Test func audioLevelNormalizationHandlesSilenceAndClipping() {
        let silence: [Float] = [0, 0, 0]
        let quiet: [Float] = [0.05, -0.05]
        let loud: [Float] = [1, -1]

        let silenceLevel = silence.withUnsafeBufferPointer(AudioLevelMeter.normalizedRMS)
        let quietLevel = quiet.withUnsafeBufferPointer(AudioLevelMeter.normalizedRMS)
        let loudLevel = loud.withUnsafeBufferPointer(AudioLevelMeter.normalizedRMS)

        #expect(silenceLevel == 0)
        #expect(quietLevel > 0 && quietLevel < 1)
        #expect(loudLevel == 1)
    }

    @MainActor
    @Test func cancelStopsRecordingWithoutCallingProviderOrInserter() async throws {
        let harness = makeCoordinatorHarness()

        await harness.coordinator.toggleDictation()
        #expect(harness.coordinator.state == .recording)

        harness.coordinator.requestCancel()

        #expect(harness.coordinator.state == .idle)
        #expect(harness.recorder.startCount == 1)
        #expect(harness.recorder.stopCount == 1)
        #expect(harness.provider.transcribeCount == 0)
        #expect(harness.inserter.insertCount == 0)
        #expect(harness.overlay.hideCount == 1)
    }

    @MainActor
    @Test func stopTranscribesAndInsertsExactlyOnce() async throws {
        let harness = makeCoordinatorHarness()

        await harness.coordinator.toggleDictation()
        await harness.coordinator.toggleDictation()

        #expect(harness.recorder.startCount == 1)
        #expect(harness.recorder.stopCount == 1)
        #expect(harness.provider.transcribeCount == 1)
        #expect(harness.inserter.insertCount == 1)
        #expect(harness.inserter.insertedText == "Transcribed text")
        #expect(harness.coordinator.state == .success)
    }

    @MainActor
    @Test func launchAtLoginStatusMapsApprovalRequirement() {
        #expect(LaunchAtLoginState(serviceStatus: .enabled) == .enabled)
        #expect(LaunchAtLoginState(serviceStatus: .notRegistered) == .disabled)
        #expect(LaunchAtLoginState(serviceStatus: .requiresApproval) == .requiresApproval)
        #expect(LaunchAtLoginState(serviceStatus: .notFound) == .unavailable)
    }

    @Test func failureClassifierRetriesOnlyTemporaryFailures() {
        #expect(DictationFailureClassifier.isRetryable(URLError(.notConnectedToInternet)))
        #expect(DictationFailureClassifier.isRetryable(
            TranscriptionProviderError.server(statusCode: 503, message: "Unavailable")
        ))
        #expect(!DictationFailureClassifier.isRetryable(
            TranscriptionProviderError.server(statusCode: 401, message: "Unauthorized")
        ))
        #expect(DictationFailureClassifier.category(for:
            TranscriptionProviderError.server(statusCode: 429, message: "Limited")
        ) == .rateLimit)
    }

    @Test func historyStorePersistsAndRecoversInterruptedStates() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateHistoryTests-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("history.json")
        let store = DictationHistoryStore(fileURL: fileURL)
        let now = Date()
        let id = UUID()
        let record = DictationRecord(
            id: id, createdAt: now, recordingStartedAt: now, recordingEndedAt: now,
            duration: 1, status: .transcribing, audioRelativePath: "test.wav",
            audioFileSize: 1, originalTranscript: nil, finalText: nil,
            providerID: "OpenAI", modelID: "test", language: "de",
            targetBundleIdentifier: "test.app", targetApplicationName: "Test",
            attemptCount: 1, lastAttemptAt: now, errorCategory: nil, errorCode: nil,
            errorMessage: nil, cancelled: false, updatedAt: now, schemaVersion: 1
        )
        try await store.upsert(record)
        #expect(try await store.record(id: id)?.status == .transcribing)

        let recovered = try await store.recoverInterrupted()
        #expect(recovered.count == 1)
        #expect(try await store.record(id: id)?.status == .transcriptionFailed)

        let reloaded = DictationHistoryStore(fileURL: fileURL)
        #expect(try await reloaded.record(id: id)?.errorCategory == .interrupted)
    }

    @Test @MainActor func apiKeyIsReadOnlyOncePerAppSession() async {
        let credentialStore = CountingCredentialStore()
        let harness = makeCoordinatorHarness(credentialStore: credentialStore)
        #expect(credentialStore.readCount == 1)

        await harness.coordinator.toggleDictation()
        await harness.coordinator.toggleDictation()

        #expect(credentialStore.readCount == 1)
    }

    @MainActor
    private func makeCoordinatorHarness(
        credentialStore: any CredentialStoring = MockCredentialStore()
    ) -> CoordinatorHarness {
        let suiteName = "FlowDictateCoordinatorTests-\(UUID())"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let recorder = MockAudioRecorder()
        let provider = MockTranscriptionProvider()
        let inserter = MockTextInserter()
        let overlay = MockRecordingOverlay()
        let application = NSRunningApplication(processIdentifier: ProcessInfo.processInfo.processIdentifier)!
        let target = FocusTarget(
            application: application,
            processIdentifier: application.processIdentifier,
            bundleIdentifier: application.bundleIdentifier,
            localizedName: "FlowDictate Tests"
        )

        let coordinator = DictationCoordinator(
            settings: AppSettings(defaults: defaults),
            dictationHotKeyRegistrar: MockHotKeyRegistrar(),
            cancelHotKeyRegistrar: MockHotKeyRegistrar(),
            restoreHotKeyRegistrar: MockHotKeyRegistrar(),
            permissionManager: MockPermissionManager(),
            recorder: recorder,
            provider: provider,
            inserter: inserter,
            credentialStore: credentialStore,
            audioDeviceService: MockAudioDeviceService(),
            launchAtLogin: LaunchAtLoginManager(automaticallyEnableOnFirstLaunch: false),
            overlay: overlay,
            focusTargetProvider: { target },
            environment: [:],
            recordingLocationStore: configuredRecordingLocationStore(defaults: defaults),
            historyStore: DictationHistoryStore(
                fileURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("FlowDictateHistory-\(UUID()).json")
            )
        )

        return CoordinatorHarness(
            coordinator: coordinator,
            recorder: recorder,
            provider: provider,
            inserter: inserter,
            overlay: overlay
        )
    }

    private func configuredRecordingLocationStore(defaults: UserDefaults) -> RecordingLocationStore {
        let store = RecordingLocationStore(defaults: defaults)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateRecordings-\(UUID())", isDirectory: true)
        try? store.configure(directory: directory)
        return store
    }
}

@MainActor
private struct CoordinatorHarness {
    let coordinator: DictationCoordinator
    let recorder: MockAudioRecorder
    let provider: MockTranscriptionProvider
    let inserter: MockTextInserter
    let overlay: MockRecordingOverlay
}

@MainActor
private final class MockAudioRecorder: AudioRecording {
    var isRecording = false
    var levelHandler: (@MainActor (Float) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func selectInputDevice(_ deviceID: AudioDeviceID?) {}

    func start() throws {
        startCount += 1
        isRecording = true
    }

    func stop() throws -> AudioRecordingResult {
        stopCount += 1
        isRecording = false
        return AudioRecordingResult(
            id: UUID(),
            url: FileManager.default.temporaryDirectory.appendingPathComponent("test.wav"),
            startedAt: Date(),
            duration: 1
        )
    }
}

@MainActor
private final class MockTranscriptionProvider: TranscriptionProvider {
    private(set) var transcribeCount = 0

    func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionResult {
        transcribeCount += 1
        return TranscriptionResult(
            text: "Transcribed text",
            provider: "Test",
            model: "test-model"
        )
    }
}

@MainActor
private final class MockTextInserter: TextInserting {
    private(set) var insertCount = 0
    private(set) var insertedText: String?

    func insert(_ text: String, into target: FocusTarget) async throws {
        insertCount += 1
        insertedText = text
    }
}

@MainActor
private final class MockHotKeyRegistrar: HotKeyRegistering {
    func register(
        _ configuration: HotKeyConfiguration,
        handler: @escaping @MainActor () -> Void
    ) throws {}

    func unregister() {}
}

@MainActor
private struct MockPermissionManager: PermissionManaging {
    func ensureMicrophoneAccess() async throws {}
    func ensureEventPostingAccess() throws {}
    var hasMicrophoneAccess: Bool { true }
    var hasEventPostingAccess: Bool { true }
    func openMicrophoneSettings() {}
    func openAccessibilitySettings() {}
}

private struct MockCredentialStore: CredentialStoring {
    func readAPIKey() throws -> String? { "test-key" }
    func saveAPIKey(_ value: String) throws {}
    func deleteAPIKey() throws {}
}

private final class CountingCredentialStore: CredentialStoring, @unchecked Sendable {
    private(set) var readCount = 0

    func readAPIKey() throws -> String? {
        readCount += 1
        return "test-key"
    }

    func saveAPIKey(_ value: String) throws {}
    func deleteAPIKey() throws {}
}

@MainActor
private struct MockAudioDeviceService: AudioDeviceServing {
    func inputDevices() throws -> [AudioInputDevice] { [] }
    func deviceID(forUID uid: String?) throws -> AudioDeviceID? { nil }
}

@MainActor
private final class MockRecordingOverlay: RecordingOverlayPresenting {
    private(set) var presentations: [OverlayStatus] = []
    private(set) var hideCount = 0

    func show(status: OverlayStatus, level: Float, reposition: Bool) {
        presentations.append(status)
    }

    func updateLevel(_ level: Float) {}

    func hide() {
        hideCount += 1
    }
}
