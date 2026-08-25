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
        #expect(!DictationState.finalizing.acceptsStart)
        #expect(!DictationState.transcribing.acceptsStart)
        #expect(!DictationState.enhancing.acceptsStart)
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
        settings.recordingAudioSource = .systemAudio
        settings.dictationActivationMode = .pressAndHold
        settings.transcriptionModel = "test-model"
        settings.transcriptionLanguage = .german
        settings.clipboardRestoreDelay = 1.2
        settings.onboardingVersion = 2
        settings.automaticRetryEnabled = false
        settings.audioRetentionDays = 90
        settings.historyRetentionDays = 365
        settings.historyMaximumRecordCount = 500
        settings.livePreviewEnabled = true
        settings.overlaySize = .expanded
        settings.livePreviewCharacterLimit = 320
        settings.overlayPosition = .bottomCenter

        let restored = AppSettings(defaults: defaults)

        #expect(restored.dictationHotKey == settings.dictationHotKey)
        #expect(restored.cancelHotKey == .controlShiftSpace)
        #expect(restored.restoreHotKey == .controlShiftZ)
        #expect(restored.inputDeviceUID == "test-microphone")
        #expect(restored.recordingAudioSource == .systemAudio)
        #expect(restored.dictationActivationMode == .pressAndHold)
        #expect(restored.transcriptionModel == "test-model")
        #expect(restored.transcriptionLanguage == .german)
        #expect(restored.clipboardRestoreDelay == 1.2)
        #expect(restored.onboardingVersion == 2)
        #expect(!restored.automaticRetryEnabled)
        #expect(restored.audioRetentionDays == 90)
        #expect(restored.historyRetentionDays == 365)
        #expect(restored.historyMaximumRecordCount == 500)
        #expect(restored.livePreviewEnabled)
        #expect(restored.overlaySize == .expanded)
        #expect(restored.livePreviewCharacterLimit == 320)
        #expect(restored.overlayPosition == .bottomCenter)
    }

    @MainActor
    @Test func livePreviewDefaultsAreMigrationSafeAndCharacterLimitIsClamped() {
        let newSuite = "FlowDictateNewPreviewSettings-\(UUID())"
        let newDefaults = UserDefaults(suiteName: newSuite)!
        defer { newDefaults.removePersistentDomain(forName: newSuite) }
        let newSettings = AppSettings(defaults: newDefaults)
        #expect(newSettings.livePreviewEnabled)
        #expect(newSettings.overlaySize == .standard)
        #expect(newSettings.livePreviewCharacterLimit == 150)
        #expect(newSettings.overlayPosition == .bottomTrailing)
        newSettings.livePreviewCharacterLimit = 5_000
        #expect(newSettings.livePreviewCharacterLimit == 800)

        let existingSuite = "FlowDictateExistingPreviewSettings-\(UUID())"
        let existingDefaults = UserDefaults(suiteName: existingSuite)!
        defer { existingDefaults.removePersistentDomain(forName: existingSuite) }
        existingDefaults.set(2, forKey: "onboardingVersion")
        let existingSettings = AppSettings(defaults: existingDefaults)
        #expect(!existingSettings.livePreviewEnabled)
    }

    @Test func transcriptionLanguageMapsAutomaticToNil() {
        #expect(TranscriptionLanguage.automatic.apiValue == nil)
        #expect(TranscriptionLanguage.german.apiValue == "de")
        #expect(TranscriptionLanguage.english.apiValue == "en")
    }

    @Test func spokenFormattingSupportsGermanCommandsAndLiteralEscape() {
        let processor = SpokenFormattingProcessor()
        let result = processor.process(
            "Hallo Komma das ist wörtlich Punkt Punkt neuer Absatz Aufzählung Ende Ausrufezeichen",
            language: "de"
        )
        #expect(result.text == "Hallo, das ist Punkt.\n\n• Ende!")
        #expect(result.replacementCount == 5)
    }

    @Test func spokenFormattingSupportsEnglishAndProtectsURLs() {
        let processor = SpokenFormattingProcessor()
        let result = processor.process(
            "Visit https://example.com/period and continue comma new line done period",
            language: "en"
        )
        #expect(result.text == "Visit https://example.com/period and continue,\ndone.")
    }

    @Test func spokenFormattingRemovesAutomaticCommasAndFormatsNumberedItems() {
        let processor = SpokenFormattingProcessor()
        let result = processor.process(
            "Ja, guten Morgen, neue Zeile, dies ist eine Testzeile, neue Zeile, Doppelpunkt, Punkt 1, bla bla, Punkt 2, Miau.",
            language: "de"
        )
        #expect(result.text == "Ja, guten Morgen\ndies ist eine Testzeile\n:\n1. bla bla\n2. Miau.")
        #expect(result.replacementCount == 5)
    }

    @Test func personalDictionaryUsesWholeWordsLongestFirstAndDoesNotCascade() {
        let now = Date()
        let entries = [
            DictionaryEntry(
                id: UUID(), spokenForm: "Flow Diktat", replacement: "FlowDictate",
                language: "de", caseSensitive: false, matchWholeWordsOnly: true,
                isEnabled: true, createdAt: now, updatedAt: now
            ),
            DictionaryEntry(
                id: UUID(), spokenForm: "Flow", replacement: "Stream",
                language: "de", caseSensitive: false, matchWholeWordsOnly: true,
                isEnabled: true, createdAt: now.addingTimeInterval(1), updatedAt: now
            ),
            DictionaryEntry(
                id: UUID(), spokenForm: "FlowDictate", replacement: "MustNotCascade",
                language: "de", caseSensitive: false, matchWholeWordsOnly: true,
                isEnabled: true, createdAt: now.addingTimeInterval(2), updatedAt: now
            )
        ]
        let result = PersonalDictionaryProcessor().process(
            "Flow Diktat und Workflow Flow", entries: entries, language: "de"
        )
        #expect(result.text == "FlowDictate und Workflow Stream")
        #expect(result.replacementCount == 2)
    }

    @MainActor
    @Test func smartDictationSettingsPersistWithSafeDefaults() {
        let suite = "FlowDictateSmartSettings-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var settings = AppSettings(defaults: defaults)
        #expect(!settings.spokenFormattingEnabled)
        #expect(settings.personalDictionaryEnabled)
        #expect(settings.writingStyleID == BuiltInWritingStyles.originalID)
        #expect(settings.smartDictationFallback == .ask)

        settings.spokenFormattingEnabled = true
        settings.personalDictionaryEnabled = false
        settings.writingStyleID = BuiltInWritingStyles.emailID
        settings.enhancementModel = "test-enhancement-model"
        settings.smartDictationFallback = .useLocallyProcessed
        settings = AppSettings(defaults: defaults)
        #expect(settings.spokenFormattingEnabled)
        #expect(!settings.personalDictionaryEnabled)
        #expect(settings.writingStyleID == BuiltInWritingStyles.emailID)
        #expect(settings.enhancementModel == "test-enhancement-model")
        #expect(settings.smartDictationFallback == .useLocallyProcessed)
    }

    @Test func dictionaryAndWritingStyleStoresRoundTrip() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateSmartStores-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Date()
        let dictionaryStore = DictionaryStore(fileURL: directory.appendingPathComponent("dictionary.json"))
        let entry = DictionaryEntry(
            id: UUID(), spokenForm: "Eulersche Zahl", replacement: "e",
            language: "de", caseSensitive: false, matchWholeWordsOnly: true,
            isEnabled: true, createdAt: now, updatedAt: now
        )
        try await dictionaryStore.upsert(entry)
        #expect(try await dictionaryStore.all() == [entry])

        let styleStore = WritingStyleStore(fileURL: directory.appendingPathComponent("styles.json"))
        let style = WritingStyleProfile(
            id: UUID(), name: "Concise", instruction: "Make the text concise without losing facts.",
            isBuiltIn: false, isEnabled: true, schemaVersion: 1
        )
        try await styleStore.upsert(style)
        #expect(try await styleStore.profile(id: style.id) == style)
        #expect(try await styleStore.all().count == BuiltInWritingStyles.all.count + 1)
    }

    @MainActor
    @Test func smartPipelineOriginalNeverCallsEnhancer() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateSmartOriginal-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let store = DictationHistoryStore(fileURL: fileURL)
        let pipeline = SmartDictationPipeline(historyStore: store)
        let enhancer = MockTranscriptEnhancer(output: "must not be used")
        var record = makeTranscribedRecord(text: "Hallo Punkt")
        record = try await pipeline.run(
            record: record,
            spokenFormattingEnabled: true,
            dictionaryEntries: [],
            style: BuiltInWritingStyles.all[0],
            enhancementModel: "test",
            fallback: .ask,
            enhancer: enhancer
        )
        #expect(record.originalTranscript == "Hallo Punkt")
        #expect(record.finalText == "Hallo.")
        #expect(record.processingStatus == .completed)
        #expect(enhancer.callCount == 0)
    }

    @MainActor
    @Test func smartPipelineEnhancesAndFallbackKeepsLocalText() async throws {
        let successURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateSmartSuccess-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: successURL) }
        let successPipeline = SmartDictationPipeline(historyStore: DictationHistoryStore(fileURL: successURL))
        let successEnhancer = MockTranscriptEnhancer(output: "Professioneller Text 42")
        let success = try await successPipeline.run(
            record: makeTranscribedRecord(text: "Text 42"), spokenFormattingEnabled: false,
            dictionaryEntries: [], style: BuiltInWritingStyles.all[4], enhancementModel: "test-model",
            fallback: .ask, enhancer: successEnhancer
        )
        #expect(success.finalText == "Professioneller Text 42")
        #expect(success.enhancementAttemptCount == 1)
        #expect(success.processingStatus == .completed)

        let failureURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateSmartFallback-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: failureURL) }
        let failurePipeline = SmartDictationPipeline(historyStore: DictationHistoryStore(fileURL: failureURL))
        let fallback = try await failurePipeline.run(
            record: makeTranscribedRecord(text: "Lokaler Text"), spokenFormattingEnabled: false,
            dictionaryEntries: [], style: BuiltInWritingStyles.all[4], enhancementModel: "test-model",
            fallback: .useLocallyProcessed, enhancer: MockTranscriptEnhancer(error: URLError(.notConnectedToInternet))
        )
        #expect(fallback.finalText == "Lokaler Text")
        #expect(fallback.processingStatus == .completed)
        #expect(fallback.enhancementErrorCategory == .network)
        #expect(fallback.enhancementFallback == .useLocallyProcessed)
    }

    @MainActor
    @Test func changingWritingStyleStartsFromExistingLocalStage() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateStyleOnly-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let pipeline = SmartDictationPipeline(historyStore: DictationHistoryStore(fileURL: fileURL))
        var record = makeTranscribedRecord(text: "Raw Punkt")
        record.formattedTranscript = "Previously formatted."
        record.dictionaryTranscript = "Protected local result 42"
        let enhancer = MockTranscriptEnhancer(output: "Styled local result 42")

        let result = try await pipeline.processWithStyle(
            record: record,
            style: BuiltInWritingStyles.all[4],
            model: "test-model",
            fallback: .ask,
            dictionaryEntries: [],
            enhancer: enhancer
        )

        #expect(enhancer.receivedTexts == ["Protected local result 42"])
        #expect(result.originalTranscript == "Raw Punkt")
        #expect(result.formattedTranscript == "Previously formatted.")
        #expect(result.finalText == "Styled local result 42")
    }

    @Test func interruptedLocalProcessingIsMarkedForDeterministicRecovery() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateInterruptedLocal-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let store = DictationHistoryStore(fileURL: fileURL)
        var record = makeTranscribedRecord(text: "Recover me")
        record.processingStatus = .formatting
        try await store.upsert(record)

        let recovered = try await store.recoverInterrupted()

        #expect(recovered.first?.processingStatus == .notStarted)
        #expect(recovered.first?.enhancementErrorCategory == .interrupted)
        #expect(try await store.record(id: record.id)?.originalTranscript == "Recover me")
    }

    @Test func phaseThreeHistoryMigrationCreatesBackupAndPreservesText() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateSmartMigration-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("dictations.json")
        let record = makeTranscribedRecord(text: "Existing transcript")
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        var object = try #require(JSONSerialization.jsonObject(with: encoder.encode(record)) as? [String: Any])
        for key in ["formattedTranscript", "dictionaryTranscript", "writingStyleID", "processingStatus",
                    "enhancementProviderID", "enhancementModelID", "enhancementAttemptCount",
                    "enhancementErrorCategory", "enhancementErrorMessage", "enhancementFallback",
                    "dictionaryReplacementCount",
                    "spokenFormattingEnabled"] {
            object.removeValue(forKey: key)
        }
        try JSONSerialization.data(withJSONObject: ["schemaVersion": 2, "records": [object]])
            .write(to: fileURL)
        let store = DictationHistoryStore(fileURL: fileURL)
        let migrated = try #require(await store.all().first)
        #expect(migrated.originalTranscript == "Existing transcript")
        #expect(migrated.finalText == "Existing transcript")
        #expect(migrated.writingStyleID == BuiltInWritingStyles.originalID)
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("dictations-pre-3.2.json").path))
    }

    @Test func audioLevelNormalizationHandlesSilenceAndClipping() {
        let silence: [Float] = [0, 0, 0]
        let quiet: [Float] = [0.05, -0.05]
        let loud: [Float] = [1, -1]

        let silenceLevel = silence.withUnsafeBufferPointer(AudioLevelMeter.normalizedRMS)
        let quietLevel = quiet.withUnsafeBufferPointer(AudioLevelMeter.normalizedRMS)
        let loudLevel = loud.withUnsafeBufferPointer(AudioLevelMeter.normalizedRMS)
        let aggregatedQuietLevel = AudioLevelMeter.normalizedRMS(
            sumOfSquares: 0.005,
            sampleCount: 2
        )

        #expect(silenceLevel == 0)
        #expect(quietLevel > 0.6 && quietLevel < 1)
        #expect(abs(aggregatedQuietLevel - quietLevel) < 0.000_1)
        #expect(loudLevel == 1)
    }

    @MainActor
    @Test func cancelStopsRecordingWithoutCallingProviderOrInserter() async throws {
        let harness = makeCoordinatorHarness()

        await harness.coordinator.toggleDictation()
        #expect(harness.coordinator.state == .recording)

        harness.coordinator.requestCancel()

        for _ in 0..<40 where harness.recorder.stopCount == 0 {
            try await Task.sleep(for: .milliseconds(25))
        }

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
        #expect(harness.overlay.presentations.last == .success(message: "Text inserted"))
    }

    @MainActor
    @Test func systemAudioCompletionConfirmsAndRetainsClipboardText() async throws {
        let pasteboard = NSPasteboard.general
        let originalClipboard = PasteboardSnapshot.capture(from: pasteboard)
        defer { originalClipboard.restore(to: pasteboard) }
        let harness = makeCoordinatorHarness(recordingSource: .systemAudio)

        await harness.coordinator.toggleDictation()
        await harness.coordinator.toggleDictation()

        #expect(pasteboard.string(forType: .string) == "Transcribed text")
        #expect(
            harness.coordinator.latestOutputNotice
                == "System Audio transcript copied to the clipboard."
        )
        #expect(
            harness.overlay.presentations.last
                == .success(message: "Text inserted · copied to clipboard")
        )
    }

    @MainActor
    @Test func stopShortcutIsAcknowledgedBeforeSlowRecorderFinalization() async throws {
        let harness = makeCoordinatorHarness()
        await harness.coordinator.toggleDictation()
        harness.recorder.stopDelay = .milliseconds(250)

        harness.coordinator.requestToggle()

        #expect(harness.coordinator.state == .finalizing)
        #expect(harness.overlay.presentations.last == .finalizing)

        for _ in 0..<60 where harness.coordinator.state != .success {
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(harness.recorder.stopCount == 1)
        #expect(harness.coordinator.state == .success)
    }

    @MainActor
    @Test func openingSettingsDuringRecordingReassertsOverlayWithoutRestartingAudio() async throws {
        let harness = makeCoordinatorHarness()
        await harness.coordinator.toggleDictation()
        let presentationCount = harness.overlay.presentations.count

        harness.coordinator.restoreRecordingOverlayAfterSettingsActivation()

        #expect(harness.coordinator.state == .recording)
        #expect(harness.recorder.startCount == 1)
        #expect(harness.overlay.presentations.count == presentationCount + 1)
        #expect(harness.overlay.presentations.last == .recording)
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
    @Test func restoreDoesNotInterruptAnActiveRecording() async throws {
        let harness = makeCoordinatorHarness()
        await harness.coordinator.toggleDictation()

        harness.coordinator.restoreLastDictation()
        try await Task.sleep(for: .milliseconds(50))

        #expect(harness.coordinator.state == .recording)
        #expect(harness.recorder.isRecording)
        #expect(harness.inserter.insertCount == 0)
    }

    @MainActor
    @Test func previewFailureDoesNotInterruptRecordingOrFinalTranscription() async throws {
        let previewProvider = MockLivePreviewProvider()
        let harness = makeCoordinatorHarness(
            livePreviewProvider: previewProvider,
            livePreviewEnabled: true
        )

        await harness.coordinator.toggleDictation()
        #expect(harness.recorder.previewBufferHandler != nil)
        #expect(previewProvider.startCount == 1)
        previewProvider.emit(.failed("Preview test failure"))
        #expect(harness.coordinator.state == .recording)
        #expect(harness.recorder.previewBufferHandler == nil)

        await harness.coordinator.toggleDictation()
        #expect(harness.provider.transcribeCount == 1)
        #expect(harness.inserter.insertCount == 1)
        #expect(harness.coordinator.state == .success)
    }

    @MainActor
    @Test func disabledPreviewDoesNotStartProviderOrAttachAudioHandler() async throws {
        let previewProvider = MockLivePreviewProvider()
        let harness = makeCoordinatorHarness(livePreviewProvider: previewProvider)

        await harness.coordinator.toggleDictation()

        #expect(harness.coordinator.state == .recording)
        #expect(previewProvider.startCount == 0)
        #expect(harness.recorder.previewBufferHandler == nil)

        harness.coordinator.requestCancel()
        for _ in 0..<40 where harness.recorder.stopCount == 0 {
            try await Task.sleep(for: .milliseconds(25))
        }
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
        recordJSON.removeValue(forKey: "audioSource")
        recordJSON.removeValue(forKey: "audioSampleRate")
        recordJSON.removeValue(forKey: "audioChannelCount")
        let envelope = ["schemaVersion": 1, "records": [recordJSON]] as [String: Any]
        try JSONSerialization.data(withJSONObject: envelope).write(to: fileURL)

        let store = DictationHistoryStore(fileURL: fileURL)
        #expect(try await store.all().count == 1)
        #expect(try await store.all().first?.archivedAt == nil)
        #expect(try await store.all().first?.audioSource == .microphone)
        #expect(try await store.all().first?.audioSampleRate == 0)
    }

    @Test func phaseThreeThreeUsageStatisticsRemainLocalAndDeterministic() {
        let now = Date()
        var completed = DictationRecord.newRecording(
            id: UUID(), startedAt: now.addingTimeInterval(-10), endedAt: now,
            duration: 10, status: .completed, audioRelativePath: "one.wav",
            audioFileSize: 1, providerID: "Test", modelID: "test", language: "de",
            targetBundleIdentifier: nil, targetApplicationName: nil
        )
        completed.finalText = "one two three four"
        completed.attemptCount = 2
        var failed = completed
        failed.id = UUID()
        failed.status = .transcriptionFailed

        let result = UsageStatistics.calculate(
            records: [completed, failed], typingWordsPerMinute: 60
        )
        #expect(result.successfulDictations == 1)
        #expect(result.wordCount == 4)
        #expect(result.retryCount == 1)
        #expect(result.totalDuration == 10)
        #expect(result.estimatedSecondsSaved == 0)
    }

    @Test func phaseThreeThreeReleaseComparisonUsesSemanticComponents() {
        #expect(GitHubReleaseChecker.isNewer("3.3.0", than: "3.2.9"))
        #expect(GitHubReleaseChecker.isNewer("3.2.10", than: "3.2.9"))
        #expect(!GitHubReleaseChecker.isNewer("3.2.0", than: "3.2.0"))
        #expect(!GitHubReleaseChecker.isNewer("3.1.9", than: "3.2.0"))
    }

    @Test func appProfilesRoundTripByBundleIdentifier() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateProfiles-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppProfileStore(fileURL: directory.appendingPathComponent("profiles.json"))
        var profile = AppDictationProfile.new(
            bundleIdentifier: "com.example.editor", displayName: "Editor"
        )
        profile.language = .german
        profile.transcriptionModel = "custom-model"
        profile.insertionPreference = .clipboard
        try await store.upsert(profile)

        let restored = try #require(await store.all().first)
        #expect(restored.bundleIdentifier == "com.example.editor")
        #expect(restored.language == .german)
        #expect(restored.transcriptionModel == "custom-model")
        #expect(restored.insertionPreference == .clipboard)
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

    @Test func livePreviewBufferOwnsImmutableAudioSamples() throws {
        let format = try #require(AVAudioFormat(
            standardFormatWithSampleRate: 16_000,
            channels: 1
        ))
        let source = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4))
        source.frameLength = 4
        source.floatChannelData?[0][0] = 0.75

        let preview = try #require(LivePreviewAudioBuffer(copying: source))
        source.floatChannelData?[0][0] = 0.25
        let speechBuffer = try #require(preview.makePCMBuffer())

        #expect(preview.channelSamples[0][0] == 0.75)
        #expect(speechBuffer.floatChannelData?[0][0] == 0.75)
    }

    @Test func audioLevelUpdatesAreLimitedToTenPerSecond() {
        let gate = AudioLevelUpdateGate(updatesPerSecond: 10)
        #expect(gate.shouldPublish(at: 1))
        #expect(!gate.shouldPublish(at: 1.05))
        #expect(gate.shouldPublish(at: 1.11))
    }

    @MainActor
    @Test func livePreviewCoordinatorLimitsTextAndIgnoresEventsAfterCancel() async throws {
        let provider = MockLivePreviewProvider()
        let coordinator = LivePreviewCoordinator(
            provider: provider,
            updateInterval: .milliseconds(1)
        )
        var states: [LivePreviewState] = []
        coordinator.stateDidChange = { states.append($0) }
        let handler = try coordinator.start(configuration: LivePreviewConfiguration(
            localeIdentifier: "de-DE",
            characterLimit: 50
        ))
        handler(LivePreviewAudioBuffer(
            sampleRate: 16_000,
            channelCount: 1,
            frameCount: 1,
            channelSamples: [[0]]
        ))
        provider.emit(.partial(String(repeating: "a", count: 70)))
        let expectedState = LivePreviewState.active(String(repeating: "a", count: 50))
        for _ in 0..<20 where !states.contains(expectedState) {
            try await Task.sleep(for: .milliseconds(5))
        }

        #expect(provider.startCount == 1)
        #expect(states.contains(expectedState))
        coordinator.cancel()
        provider.emit(.partial("must be ignored"))
        try await Task.sleep(for: .milliseconds(10))
        #expect(coordinator.state == .disabled)
        #expect(provider.cancelCount >= 1)
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
        credentialStore: any CredentialStoring = MockCredentialStore(),
        livePreviewProvider: (any LivePreviewProviding)? = nil,
        livePreviewEnabled: Bool = false,
        recordingSource: RecordingAudioSource = .microphone
    ) -> CoordinatorHarness {
        let suiteName = "FlowDictateCoordinatorTests-\(UUID())"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let recorder = MockAudioRecorder()
        recorder.sourceMetadata = AudioSourceMetadata(
            source: recordingSource,
            sampleRate: 48_000,
            channelCount: 1
        )
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
        let settings = AppSettings(defaults: defaults)
        settings.livePreviewEnabled = livePreviewEnabled
        settings.recordingAudioSource = recordingSource

        let coordinator = DictationCoordinator(
            settings: settings,
            dictationHotKeyRegistrar: MockHotKeyRegistrar(),
            cancelHotKeyRegistrar: MockHotKeyRegistrar(),
            restoreHotKeyRegistrar: MockHotKeyRegistrar(),
            permissionManager: MockPermissionManager(),
            recorder: recorder,
            systemAudioRecorder: recorder,
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
            ),
            livePreviewProvider: livePreviewProvider,
            livePreviewAvailabilityProvider: { _, _ in
                .available(localeIdentifier: "de-DE")
            }
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

    private func makeTranscribedRecord(text: String) -> DictationRecord {
        let now = Date()
        var record = DictationRecord.newRecording(
            id: UUID(), startedAt: now, endedAt: now, duration: 1,
            status: .transcribed, audioRelativePath: "test.wav", audioFileSize: 100,
            providerID: "Test", modelID: "test-transcribe", language: "de",
            targetBundleIdentifier: nil, targetApplicationName: nil
        )
        record.originalTranscript = text
        record.finalText = text
        return record
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
    var stopDelay: Duration?
    var sourceMetadata = AudioSourceMetadata.microphoneDefault

    func selectInputDevice(_ deviceID: AudioDeviceID?) {}

    func start() async throws {
        startCount += 1
        isRecording = true
    }

    func stop() async throws -> AudioRecordingResult {
        stopCount += 1
        isRecording = false
        if let stopDelay { try await Task.sleep(for: stopDelay) }
        return AudioRecordingResult(
            id: UUID(),
            url: FileManager.default.temporaryDirectory.appendingPathComponent("test.wav"),
            startedAt: Date(),
            duration: 1,
            sourceMetadata: sourceMetadata
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
private final class MockLivePreviewProvider: LivePreviewProviding {
    var isAvailable = true
    private(set) var startCount = 0
    private(set) var finishCount = 0
    private(set) var cancelCount = 0
    private var eventHandler: (@MainActor (LivePreviewEvent) -> Void)?

    func start(
        buffers: AsyncStream<LivePreviewAudioBuffer>,
        localeIdentifier: String,
        eventHandler: @escaping @MainActor (LivePreviewEvent) -> Void
    ) throws {
        startCount += 1
        self.eventHandler = eventHandler
    }

    func finish() { finishCount += 1 }
    func cancel() { cancelCount += 1 }
    func emit(_ event: LivePreviewEvent) { eventHandler?(event) }
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
    var speechRecognitionStatus: SpeechPermissionState { .authorized }
    func requestSpeechRecognitionAccess() async -> SpeechPermissionState { .authorized }
    func openMicrophoneSettings() {}
    func openAccessibilitySettings() {}
    func openSpeechRecognitionSettings() {}
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

private final class MockTranscriptEnhancer: TranscriptEnhancing, @unchecked Sendable {
    private(set) var callCount = 0
    private(set) var receivedTexts: [String] = []
    private let output: String?
    private let error: Error?

    init(output: String) { self.output = output; error = nil }
    init(error: Error) { output = nil; self.error = error }

    func enhance(_ request: TranscriptEnhancementRequest) async throws -> TranscriptEnhancementResult {
        callCount += 1
        receivedTexts.append(request.text)
        if let error { throw error }
        return TranscriptEnhancementResult(
            text: output ?? request.text,
            provider: "Mock",
            model: request.model
        )
    }
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
    private(set) var previewStates: [LivePreviewState] = []

    func show(status: OverlayStatus, level: Float, reposition: Bool) {
        presentations.append(status)
    }

    func updateLevel(_ level: Float) {}

    func updatePreview(_ state: LivePreviewState) { previewStates.append(state) }

    func configure(size: OverlaySize, position: OverlayPosition) {}

    func hide() {
        hideCount += 1
    }
}
