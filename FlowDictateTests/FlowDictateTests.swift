//
//  FlowDictateTests.swift
//  FlowDictateTests
//
//  Created by Frank Euler on 16.08.26.
//

import AppKit
import AVFoundation
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
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateMultipartSource-\(UUID()).wav")
        try Data([0x01, 0x02, 0x03]).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let upload = try MultipartUploadFileBuilder(boundary: "boundary").build(
            fields: [("model", "test-model"), ("language", nil)],
            fileFieldName: "file",
            filename: "recording.wav",
            mimeType: "audio/wav",
            sourceURL: source
        )
        defer { upload.cleanup() }

        let text = String(decoding: try Data(contentsOf: upload.url), as: UTF8.self)
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
    @Test func openAIRejectsOversizedPreparedAudioBeforeNetworkAccess() async throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateOversized-\(UUID()).m4a")
        #expect(FileManager.default.createFile(atPath: source.path, contents: nil))
        let handle = try FileHandle(forWritingTo: source)
        try handle.truncate(atOffset: UInt64(OpenAITranscriptionProvider.maximumAudioFileBytes + 1))
        try handle.close()
        defer { try? FileManager.default.removeItem(at: source) }

        let provider = OpenAITranscriptionProvider(
            apiKey: "test-key",
            uploadPreparer: PassThroughAudioUploadPreparer()
        )
        do {
            _ = try await provider.transcribe(
                TranscriptionRequest(audioURL: source, language: nil)
            )
            Issue.record("Expected an oversized-audio error")
        } catch let error as TranscriptionProviderError {
            guard case .audioFileTooLarge = error else {
                Issue.record("Unexpected provider error: \(error)")
                return
            }
        }
    }

    @MainActor
    @Test func audioUploadPreparerCreatesAndCleansCompactM4A() async throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateUploadSource-\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: source) }
        let format = try #require(AVAudioFormat(
            standardFormatWithSampleRate: 16_000,
            channels: 1
        ))
        do {
            let file = try AVAudioFile(forWriting: source, settings: format.settings)
            let buffer = try #require(AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: 1_600
            ))
            buffer.frameLength = buffer.frameCapacity
            try file.write(from: buffer)
        }

        let prepared = try await AudioUploadPreparer().prepareCompactUpload(source)
        #expect(prepared.fileURL.pathExtension == "m4a")
        #expect(prepared.temporaryFileURL != nil)
        #expect(FileManager.default.fileExists(atPath: prepared.fileURL.path))
        prepared.cleanup()
        #expect(!FileManager.default.fileExists(atPath: prepared.fileURL.path))
        #expect(FileManager.default.fileExists(atPath: source.path))
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
        settings.historyRetentionDays = 365
        settings.historyMaximumRecordCount = 500

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
        #expect(restored.historyRetentionDays == 365)
        #expect(restored.historyMaximumRecordCount == 500)
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
    @Test func restoreUsesRecordedApplicationWhenNoExternalAppIsFrontmost() async throws {
        let harness = makeCoordinatorHarness()
        await harness.coordinator.toggleDictation()
        await harness.coordinator.toggleDictation()
        #expect(harness.inserter.insertCount == 1)

        harness.focusTargetBox.target = nil
        harness.coordinator.restoreLastDictation()
        for _ in 0..<40 where harness.inserter.insertCount < 2 {
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(harness.inserter.insertCount == 2)
        #expect(harness.inserter.insertedText == "Transcribed text")
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
            errorMessage: nil, cancelled: false, updatedAt: now, schemaVersion: 1,
            archivedAt: nil
        )
        try await store.upsert(record)
        #expect(try await store.record(id: id)?.status == .transcribing)

        let recovered = try await store.recoverInterrupted()
        #expect(recovered.count == 1)
        #expect(try await store.record(id: id)?.status == .transcriptionFailed)

        let reloaded = DictationHistoryStore(fileURL: fileURL)
        #expect(try await reloaded.record(id: id)?.errorCategory == .interrupted)
    }

    @Test func phaseTwoHistoryWithoutArchivedAtStillDecodes() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateLegacyHistory-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("history.json")
        let now = Date()
        let record = DictationRecord.newRecording(
            id: UUID(), startedAt: now, endedAt: now, duration: 1, status: .completed,
            audioRelativePath: "legacy.wav", audioFileSize: 0, providerID: "OpenAI",
            modelID: "test", language: nil, targetBundleIdentifier: nil,
            targetApplicationName: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let recordData = try encoder.encode(record)
        var recordJSON = try #require(
            JSONSerialization.jsonObject(with: recordData) as? [String: Any]
        )
        recordJSON.removeValue(forKey: "archivedAt")
        let envelope = ["schemaVersion": 1, "records": [recordJSON]] as [String: Any]
        try JSONSerialization.data(withJSONObject: envelope).write(to: fileURL)

        let store = DictationHistoryStore(fileURL: fileURL)
        #expect(try await store.all().count == 1)
        #expect(try await store.all().first?.archivedAt == nil)
    }

    @Test func historyRetentionArchivesAudioAndRemovesTextOnlyRecords() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateRetention-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let store = DictationHistoryStore(fileURL: fileURL)
        let now = Date()
        var withAudio = DictationRecord.newRecording(
            id: UUID(), startedAt: now, endedAt: now, duration: 1, status: .completed,
            audioRelativePath: "audio.wav", audioFileSize: 100, providerID: "Test",
            modelID: "test", language: nil, targetBundleIdentifier: nil,
            targetApplicationName: nil
        )
        withAudio.finalText = "Audio"
        var textOnly = DictationRecord.newRecording(
            id: UUID(), startedAt: now.addingTimeInterval(-1),
            endedAt: now.addingTimeInterval(-1), duration: 1, status: .completed,
            audioRelativePath: "removed.wav", audioFileSize: 0, providerID: "Test",
            modelID: "test", language: nil, targetBundleIdentifier: nil,
            targetApplicationName: nil
        )
        textOnly.finalText = "Text"
        try await store.upsert(withAudio)
        try await store.upsert(textOnly)

        let result = try await store.applyRetention(
            maximumAgeDays: -1,
            maximumRecordCount: 0,
            now: now
        )

        #expect(result.archivedCount == 1)
        #expect(result.removedCount == 1)
        #expect(try await store.all().isEmpty)
        #expect(try await store.knownAudioRelativePaths().contains("audio.wav"))

        var archived = try #require(await store.all(includeArchived: true).first)
        #expect(archived.finalText == nil)
        archived.audioFileSize = 0
        try await store.upsert(archived)
        let purgeResult = try await store.applyRetention(
            maximumAgeDays: -1,
            maximumRecordCount: -1,
            now: now
        )
        #expect(purgeResult.removedCount == 1)
        #expect(try await store.all(includeArchived: true).isEmpty)
    }

    @Test func historyRetentionProtectsFailedRecords() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateProtectedRetention-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let store = DictationHistoryStore(fileURL: fileURL)
        let now = Date()
        var record = DictationRecord.newRecording(
            id: UUID(), startedAt: now, endedAt: now, duration: 1,
            status: .transcriptionFailed, audioRelativePath: "failed.wav",
            audioFileSize: 0, providerID: "Test", modelID: "test", language: nil,
            targetBundleIdentifier: nil, targetApplicationName: nil
        )
        record.errorCategory = .network
        try await store.upsert(record)

        let result = try await store.applyRetention(
            maximumAgeDays: 0,
            maximumRecordCount: 0,
            now: now.addingTimeInterval(1)
        )
        #expect(result == HistoryRetentionResult())
        #expect(try await store.record(id: record.id) != nil)
    }

    @Test func historyStoreHandlesOneThousandPhaseThreeSizedRecords() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateHistoryPerformance-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let now = Date()
        let longText = String(repeating: "FlowDictate phase three transcript. ", count: 30)
        let records = (0..<1_000).map { index -> DictationRecord in
            var record = DictationRecord.newRecording(
                id: UUID(), startedAt: now.addingTimeInterval(Double(-index)),
                endedAt: now.addingTimeInterval(Double(-index)), duration: 20,
                status: .completed, audioRelativePath: "\(index).wav", audioFileSize: 0,
                providerID: "OpenAI", modelID: "test", language: "de",
                targetBundleIdentifier: "test.app", targetApplicationName: "Test"
            )
            record.originalTranscript = longText
            record.finalText = longText
            return record
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(TestHistoryEnvelope(
            schemaVersion: FlowDictateVersion.historySchema,
            records: records
        )).write(to: fileURL, options: .atomic)

        let clock = ContinuousClock()
        let start = clock.now
        let store = DictationHistoryStore(fileURL: fileURL)
        #expect(try await store.all().count == 1_000)
        var newest = records[0]
        newest.updatedAt = Date()
        try await store.upsert(newest)
        let elapsed = start.duration(to: clock.now)
        #expect(elapsed < .seconds(2))
    }

    @Test func livePreviewBufferChannelDropsOldestBuffers() async {
        let channel = LivePreviewBufferChannel(limit: 2)
        for value in 1...3 {
            channel.yield(LivePreviewAudioBuffer(
                sampleRate: 16_000,
                channelCount: 1,
                frameCount: 1,
                channelSamples: [[Float(value)]]
            ))
        }
        channel.finish()

        var values: [Float] = []
        for await buffer in channel.stream {
            values.append(buffer.channelSamples[0][0])
        }
        #expect(values == [2, 3])
        #expect(channel.droppedBufferCount == 1)
    }

    @MainActor
    @Test func transcriptionRunnerRetriesTemporaryFailure() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateRunner-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let store = DictationHistoryStore(fileURL: fileURL)
        let provider = RetryingMockTranscriptionProvider()
        let runner = TranscriptionRunner(historyStore: store, sleeper: { _ in })
        let now = Date()
        let record = DictationRecord.newRecording(
            id: UUID(), startedAt: now, endedAt: now, duration: 1,
            status: .recorded, audioRelativePath: "test.wav", audioFileSize: 1,
            providerID: "Test", modelID: "test", language: "de",
            targetBundleIdentifier: nil, targetApplicationName: nil
        )

        let result = try await runner.run(
            record: record,
            audioURL: URL(fileURLWithPath: "/tmp/test.wav"),
            language: "de",
            maximumAttempts: 3,
            provider: provider
        )

        #expect(provider.transcribeCount == 2)
        #expect(result.attemptCount == 2)
        #expect(result.status == .transcribed)
        #expect(result.finalText == "Recovered transcription")
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
        let application = NSRunningApplication(
            processIdentifier: ProcessInfo.processInfo.processIdentifier
        ) ?? NSWorkspace.shared.frontmostApplication!
        let target = FocusTarget(
            application: application,
            processIdentifier: application.processIdentifier,
            bundleIdentifier: application.bundleIdentifier,
            localizedName: "FlowDictate Tests"
        )
        let focusTargetBox = FocusTargetBox(target)

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
            focusTargetProvider: { focusTargetBox.target },
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
            overlay: overlay,
            focusTargetBox: focusTargetBox
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
    let focusTargetBox: FocusTargetBox
}

@MainActor
private final class FocusTargetBox {
    var target: FocusTarget?

    init(_ target: FocusTarget?) {
        self.target = target
    }
}

@MainActor
private final class MockAudioRecorder: AudioRecording {
    var isRecording = false
    var levelHandler: (@MainActor (Float) -> Void)?
    var previewBufferHandler: (@Sendable (LivePreviewAudioBuffer) -> Void)?
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
private final class RetryingMockTranscriptionProvider: TranscriptionProvider {
    private(set) var transcribeCount = 0

    func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionResult {
        transcribeCount += 1
        if transcribeCount == 1 {
            throw URLError(.networkConnectionLost)
        }
        return TranscriptionResult(
            text: "Recovered transcription",
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

@MainActor
private final class PassThroughAudioUploadPreparer: AudioUploadPreparing {
    func prepare(_ sourceURL: URL) async throws -> PreparedAudioUpload {
        PreparedAudioUpload(
            fileURL: sourceURL,
            filename: sourceURL.lastPathComponent,
            mimeType: "audio/m4a",
            temporaryFileURL: nil
        )
    }
}

private struct TestHistoryEnvelope: Encodable {
    let schemaVersion: Int
    let records: [DictationRecord]
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
