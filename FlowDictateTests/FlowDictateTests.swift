//
//  FlowDictateTests.swift
//  FlowDictateTests
//
//  Created by Frank Euler on 16.08.26.
//

import AppKit
import AVFoundation
import Carbon.HIToolbox
import Combine
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

    @Test func systemAudioOverlayDoesNotClaimLiveTranscription() {
        let presentation = OverlayPreviewPresentation.resolve(
            source: .systemAudio,
            state: .disabled
        )

        #expect(presentation.heading == "SYSTEM AUDIO")
        #expect(!presentation.showsActivityIndicator)
        #expect(presentation.statusMessage?.contains("created after recording stops") == true)

        let microphone = OverlayPreviewPresentation.resolve(
            source: .microphone,
            state: .waiting
        )
        #expect(microphone.heading == "LIVE PREVIEW")
        #expect(microphone.showsActivityIndicator)
    }

    @Test func standardOverlayUsesConfiguredPreviewWindow() {
        let text = String(repeating: "a", count: 800)

        #expect(OverlayPreviewPresentation.visibleText(text, for: .expanded).count == 800)
        #expect(OverlayPreviewPresentation.visibleText(text, for: .standard).count == 800)
        #expect(OverlayPreviewPresentation.visibleText(text, for: .compact).isEmpty)
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

    @Test func openAIReturnsBeforeSlowTemporaryFileCleanupFinishes() async throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateCleanupSource-\(UUID()).m4a")
        try Data(repeating: 0x2A, count: 2_048).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SuccessfulOpenAIURLProtocol.self]
        let fileManager = SlowRemovalFileManager(delay: 0.6)
        let provider = OpenAITranscriptionProvider(
            apiKey: "test-key",
            session: URLSession(configuration: configuration),
            uploadPreparer: PassThroughAudioUploadPreparer(),
            fileManager: fileManager
        )

        let startedAt = ContinuousClock.now
        let result = try await provider.transcribe(
            TranscriptionRequest(audioURL: source, language: nil)
        )
        let elapsed = startedAt.duration(to: .now)

        #expect(result.text == "Cleanup stays off the response path")
        #expect(elapsed < .milliseconds(300))
        for _ in 0..<100 where fileManager.removalCount == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(fileManager.removalCount == 1)
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
        let statisticsResetDate = Date(timeIntervalSince1970: 1_750_000_000)
        settings.usageStatisticsResetDate = statisticsResetDate

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
        #expect(restored.usageStatisticsResetDate == statisticsResetDate)
    }

    @MainActor
    @Test func clipboardRestoreDelayIsClampedWhenLoadingLegacySettings() {
        let suiteName = "FlowDictateClipboardDelay-\(UUID())"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(13.0, forKey: "clipboardRestoreDelay")
        #expect(AppSettings(defaults: defaults).clipboardRestoreDelay == 2.0)

        defaults.set(0.05, forKey: "clipboardRestoreDelay")
        #expect(AppSettings(defaults: defaults).clipboardRestoreDelay == 0.3)
    }

    @MainActor
    @Test func meetingRecordingConsentIsExplicitPersistentAndResettable() {
        let suiteName = "FlowDictateMeetingConsent-\(UUID())"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var settings = AppSettings(defaults: defaults)
        #expect(!settings.hasAcceptedCurrentMeetingRecordingConsent)
        #expect(
            MixedRecordingConsentGate.requirement(
                for: .mixed,
                hasCurrentConsent: settings.hasAcceptedCurrentMeetingRecordingConsent
            ) == .confirmationRequired
        )
        #expect(
            MixedRecordingConsentGate.requirement(
                for: .microphone,
                hasCurrentConsent: false
            ).allowsRecording
        )

        settings.acceptCurrentMeetingRecordingConsent()
        settings = AppSettings(defaults: defaults)
        #expect(settings.hasAcceptedCurrentMeetingRecordingConsent)
        #expect(
            MixedRecordingConsentGate.requirement(
                for: .mixed,
                hasCurrentConsent: settings.hasAcceptedCurrentMeetingRecordingConsent
            ) == .satisfied
        )

        settings.resetMeetingRecordingConsent()
        #expect(!AppSettings(defaults: defaults).hasAcceptedCurrentMeetingRecordingConsent)
    }

    @Test func systemAudioCaptureStrategyUsesCoreAudioTapFromMacOS14_2() {
        let macOS14_1 = SystemAudioCaptureStrategy.candidate(
            for: OperatingSystemVersion(majorVersion: 14, minorVersion: 1, patchVersion: 9)
        )
        #expect(macOS14_1.preferredBackend == .screenCaptureKit)
        #expect(!macOS14_1.requiresAudioCaptureUsageDescription)
        #expect(macOS14_1.permissionSettingsLabel == "Screen & System Audio Recording")

        for version in [
            OperatingSystemVersion(majorVersion: 14, minorVersion: 2, patchVersion: 0),
            OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0),
            OperatingSystemVersion(majorVersion: 26, minorVersion: 6, patchVersion: 2)
        ] {
            let strategy = SystemAudioCaptureStrategy.candidate(for: version)
            #expect(strategy.preferredBackend == .coreAudioTap)
            #expect(strategy.requiresAudioCaptureUsageDescription)
            #expect(strategy.permissionSettingsLabel == "System Audio Recording Only")
            #expect(strategy.minimumOperatingSystem.majorVersion == 14)
            #expect(strategy.minimumOperatingSystem.minorVersion == 2)
        }
    }

    @Test func systemAudioPermissionStatusMatchesTheSelectedCaptureBackend() {
        let macOS14_1 = OperatingSystemVersion(
            majorVersion: 14,
            minorVersion: 1,
            patchVersion: 9
        )
        let macOS14_2 = OperatingSystemVersion(
            majorVersion: 14,
            minorVersion: 2,
            patchVersion: 0
        )

        let deniedScreenCapture = SystemAudioPermissionStatus.resolve(
            for: .systemAudio,
            version: macOS14_2,
            screenCaptureAuthorized: false,
            coreAudioTapSucceededThisSession: true
        )
        #expect(deniedScreenCapture.backend == .screenCaptureKit)
        #expect(deniedScreenCapture.readiness == .requestRequired)
        #expect(deniedScreenCapture.settingsLabel == "Screen & System Audio Recording")

        let allowedScreenCapture = SystemAudioPermissionStatus.resolve(
            for: .mixed,
            version: macOS14_1,
            screenCaptureAuthorized: true,
            coreAudioTapSucceededThisSession: false
        )
        #expect(allowedScreenCapture.backend == .screenCaptureKit)
        #expect(allowedScreenCapture.readiness == .authorized)

        let uncheckedCoreAudioTap = SystemAudioPermissionStatus.resolve(
            for: .mixed,
            version: macOS14_2,
            screenCaptureAuthorized: true,
            coreAudioTapSucceededThisSession: false
        )
        #expect(uncheckedCoreAudioTap.backend == .coreAudioTap)
        #expect(uncheckedCoreAudioTap.readiness == .verifiedWhenCaptureStarts)
        #expect(uncheckedCoreAudioTap.settingsLabel == "System Audio Recording Only")

        let verifiedCoreAudioTap = SystemAudioPermissionStatus.resolve(
            for: .mixed,
            version: macOS14_2,
            screenCaptureAuthorized: false,
            coreAudioTapSucceededThisSession: true
        )
        #expect(verifiedCoreAudioTap.readiness == .authorized)
    }

    @Test func systemAudioSettingsURLMatchesTheSelectedCaptureBackend() {
        #expect(
            SystemAudioPermissionService.systemSettingsURL(for: .screenCaptureKit)
                .absoluteString.contains("Privacy_ScreenCapture")
        )
        #expect(
            SystemAudioPermissionService.systemSettingsURL(for: .coreAudioTap)
                .absoluteString.contains("Privacy_AudioCapture")
        )
    }

    @Test func coreAudioTapProbeReportDerivesCapturedDurationFromFrames() {
        let cleanup = CoreAudioTapCleanupReport(
            stopStatus: noErr,
            destroyIOProcStatus: noErr,
            destroyAggregateDeviceStatus: noErr,
            destroyTapStatus: noErr,
            aggregateDeviceRemoved: true,
            tapRemoved: true
        )
        let report = CoreAudioTapProbeReport(
            requestedDuration: 5,
            wallDuration: 5.01,
            callbackCount: 100,
            nonSilentCallbackCount: 80,
            frameCount: 240_000,
            sampleRate: 48_000,
            channelCount: 1,
            firstHostTime: 1_000,
            lastHostTime: 6_000,
            firstSampleTime: 0,
            lastSampleTime: 239_000,
            missingHostTimeCount: 0,
            missingSampleTimeCount: 0,
            hostTimeRegressionCount: 0,
            sampleTimeRegressionCount: 0,
            sampleDiscontinuityCount: 0,
            largestPositiveSampleGapFrames: 0,
            largestHostTimeDeltaNanoseconds: 50_000_000,
            cleanup: cleanup
        )

        #expect(report.capturedDuration == 5)
        #expect(abs(report.stopDelay - 0.01) < 0.000_001)
        #expect(report.hasCapturedSignal)
        #expect(report.hasMonotonicTimeline)
        #expect(report.hasContinuousSampleTimeline)
        #expect(report.cleanup.succeeded)
        let repeated = CoreAudioTapRepeatedProbeReport(cycles: [report, report])
        #expect(repeated.completedCycleCount == 2)
        #expect(repeated.totalCallbackCount == 200)
        #expect(repeated.hasCapturedSignal)
        #expect(repeated.allCleanupSucceeded)
        #expect(repeated.allTimelinesMonotonic)

        let silentReport = CoreAudioTapProbeReport(
            requestedDuration: 5,
            wallDuration: 5,
            callbackCount: 100,
            nonSilentCallbackCount: 0,
            frameCount: 240_000,
            sampleRate: 48_000,
            channelCount: 1,
            firstHostTime: 1_000,
            lastHostTime: 6_000,
            firstSampleTime: 0,
            lastSampleTime: 239_000,
            missingHostTimeCount: 0,
            missingSampleTimeCount: 0,
            hostTimeRegressionCount: 0,
            sampleTimeRegressionCount: 0,
            sampleDiscontinuityCount: 0,
            largestPositiveSampleGapFrames: 0,
            largestHostTimeDeltaNanoseconds: 50_000_000,
            cleanup: cleanup
        )
        #expect(!silentReport.hasCapturedSignal)
        #expect(!CoreAudioTapRepeatedProbeReport(cycles: [silentReport]).hasCapturedSignal)

        let incompleteCleanup = CoreAudioTapCleanupReport(
            stopStatus: noErr,
            destroyIOProcStatus: nil,
            destroyAggregateDeviceStatus: noErr,
            destroyTapStatus: noErr,
            aggregateDeviceRemoved: true,
            tapRemoved: true
        )
        #expect(!incompleteCleanup.succeeded)
        #expect(incompleteCleanup.firstFailure != nil)
    }

    @Test func coreAudioTimedStopRunsOnlyOnce() async {
        let counter = LockedTestCounter()
        let timedStop = CoreAudioTapTimedStop {
            counter.increment()
            return noErr
        }

        let result = await withTaskGroup(of: CoreAudioTapTimedStop.Result.self) { group in
            group.addTask { await timedStop.wait(for: 60) }
            timedStop.stopNow()
            timedStop.stopNow()
            return await group.next()!
        }

        #expect(result.status == noErr)
        #expect(counter.value == 1)
    }

    @Test func coreAudioTimedStopFiresFromItsDedicatedTimer() async {
        let counter = LockedTestCounter()
        let timedStop = CoreAudioTapTimedStop {
            counter.increment()
            return noErr
        }

        let result = await timedStop.wait(for: 0.05)

        #expect(result.status == noErr)
        #expect(result.elapsed >= 0.04)
        #expect(result.elapsed < 1)
        #expect(counter.value == 1)
    }

    @Test func captureProbeArtifactsRemoveOnlyFilesFromStoppedProcesses() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateCaptureProbeArtifacts-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CaptureProbeArtifactStore(directoryURL: directory)
        let activeURL = try store.makeURL(processID: 111)
        let abandonedURL = try store.makeURL(processID: 222)
        let unrelatedURL = directory.appendingPathComponent("user-recording.m4a")
        let matchingDirectoryURL = directory.appendingPathComponent(
            "\(CaptureProbeArtifactStore.filePrefix)222-\(UUID().uuidString).m4a",
            isDirectory: true
        )
        try Data("active".utf8).write(to: activeURL)
        try Data("abandoned".utf8).write(to: abandonedURL)
        try Data("unrelated".utf8).write(to: unrelatedURL)
        try FileManager.default.createDirectory(
            at: matchingDirectoryURL,
            withIntermediateDirectories: false
        )

        let removed = try store.removeAbandonedArtifacts { $0 == 111 }

        #expect(removed.map(\.lastPathComponent) == [abandonedURL.lastPathComponent])
        #expect(FileManager.default.fileExists(atPath: activeURL.path))
        #expect(!FileManager.default.fileExists(atPath: abandonedURL.path))
        #expect(FileManager.default.fileExists(atPath: unrelatedURL.path))
        #expect(FileManager.default.fileExists(atPath: matchingDirectoryURL.path))
    }

    @Test func captureProbeArtifactRemovalRejectsPathsOutsideItsDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateCaptureProbeScope-\(UUID())", isDirectory: true)
        let probeDirectory = root.appendingPathComponent("probes", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = CaptureProbeArtifactStore(directoryURL: probeDirectory)
        let probeURL = try store.makeURL(processID: 333)
        let outsideURL = root.appendingPathComponent(
            "\(CaptureProbeArtifactStore.filePrefix)333-outside.m4a"
        )
        try Data("probe".utf8).write(to: probeURL)
        try Data("outside".utf8).write(to: outsideURL)

        try store.removeArtifact(at: outsideURL)
        try store.removeArtifact(at: probeURL)

        #expect(FileManager.default.fileExists(atPath: outsideURL.path))
        #expect(!FileManager.default.fileExists(atPath: probeURL.path))
    }

    @Test func coreAudioTapTimelineAnalyzerDetectsGapsAndRegressions() {
        var continuous = CoreAudioTapTimelineAnalyzer()
        continuous.record(hostTime: 1_000, sampleTime: 0, frameCount: 480)
        continuous.record(hostTime: 2_000, sampleTime: 480, frameCount: 480)
        continuous.record(hostTime: 3_000, sampleTime: 960, frameCount: 480)
        #expect(continuous.hostTimeRegressionCount == 0)
        #expect(continuous.sampleTimeRegressionCount == 0)
        #expect(continuous.sampleDiscontinuityCount == 0)

        var discontinuous = continuous
        discontinuous.record(hostTime: 2_999, sampleTime: 1_920, frameCount: 480)
        #expect(discontinuous.hostTimeRegressionCount == 1)
        #expect(discontinuous.sampleTimeRegressionCount == 0)
        #expect(discontinuous.sampleDiscontinuityCount == 1)
        #expect(discontinuous.largestPositiveSampleGapFrames == 480)

        discontinuous.record(hostTime: nil, sampleTime: nil, frameCount: 480)
        #expect(discontinuous.missingHostTimeCount == 1)
        #expect(discontinuous.missingSampleTimeCount == 1)

        discontinuous.record(hostTime: 4_000, sampleTime: 1_000, frameCount: 480)
        #expect(discontinuous.sampleTimeRegressionCount == 1)
    }

    @Test func screenCaptureTimelineAnalyzerDetectsGapsAndRegressions() {
        var continuous = ScreenCaptureTimelineAnalyzer()
        continuous.record(presentationTimeSeconds: 10, frameCount: 480, sampleRate: 48_000)
        continuous.record(presentationTimeSeconds: 10.01, frameCount: 480, sampleRate: 48_000)
        continuous.record(presentationTimeSeconds: 10.02, frameCount: 480, sampleRate: 48_000)
        #expect(continuous.report.callbackCount == 3)
        #expect(continuous.report.frameCount == 1_440)
        #expect(continuous.report.sampleRate == 48_000)
        #expect(continuous.report.capturedDuration == 0.03)
        #expect(continuous.report.sampleRateChangeCount == 0)
        #expect(continuous.report.hasMonotonicTimeline)
        #expect(continuous.report.discontinuityCount == 0)

        var discontinuous = continuous
        discontinuous.record(presentationTimeSeconds: 10.04, frameCount: 480, sampleRate: 48_000)
        #expect(discontinuous.report.discontinuityCount == 1)
        #expect(discontinuous.report.largestPositiveGapFrames == 480)

        discontinuous.record(presentationTimeSeconds: nil, frameCount: 480, sampleRate: 48_000)
        #expect(discontinuous.report.missingPresentationTimeCount == 1)
        #expect(!discontinuous.report.hasMonotonicTimeline)

        discontinuous.record(presentationTimeSeconds: 10.03, frameCount: 480, sampleRate: 48_000)
        #expect(discontinuous.report.presentationTimeRegressionCount == 1)

        discontinuous.record(presentationTimeSeconds: 10.04, frameCount: 441, sampleRate: 44_100)
        #expect(discontinuous.report.sampleRateChangeCount == 1)
    }

    @Test func systemAudioProbeDurationsMatchTheLongFormGateMatrix() {
        #expect(SystemAudioProbeDuration.fiveSeconds.rawValue == 5)
        #expect(SystemAudioProbeDuration.fiveMinutes.rawValue == 300)
        #expect(SystemAudioProbeDuration.thirtyMinutes.rawValue == 1_800)
        #expect(SystemAudioProbeDuration.sixtyMinutes.rawValue == 3_600)
    }

    @MainActor
    @Test func selectingMixedSourceRequiresConfirmationBeforeChangingSetting() {
        let presenter = MockMeetingRecordingConsentPresenter()
        let harness = makeCoordinatorHarness(
            meetingRecordingConsentPresenter: presenter
        )

        harness.coordinator.selectRecordingAudioSource(.mixed)

        #expect(presenter.presentationCount == 1)
        #expect(harness.coordinator.isMeetingRecordingConsentPresented)
        #expect(harness.coordinator.settings.recordingAudioSource == .microphone)

        presenter.cancel()
        #expect(!harness.coordinator.isMeetingRecordingConsentPresented)
        #expect(harness.coordinator.settings.recordingAudioSource == .microphone)

        harness.coordinator.selectRecordingAudioSource(.mixed)
        presenter.confirm(remember: true)
        #expect(harness.coordinator.settings.recordingAudioSource == .mixed)
        #expect(harness.coordinator.hasCurrentMeetingRecordingConsent)
        #expect(harness.coordinator.settings.hasAcceptedCurrentMeetingRecordingConsent)
    }

    @MainActor
    @Test func sessionOnlyMeetingConsentIsNotPersisted() {
        let presenter = MockMeetingRecordingConsentPresenter()
        let harness = makeCoordinatorHarness(
            meetingRecordingConsentPresenter: presenter
        )
        harness.coordinator.selectRecordingAudioSource(.mixed)

        presenter.confirm(remember: false)

        #expect(harness.coordinator.hasCurrentMeetingRecordingConsent)
        #expect(!harness.coordinator.settings.hasAcceptedCurrentMeetingRecordingConsent)
        harness.coordinator.resetMeetingRecordingConsent()
        #expect(!harness.coordinator.hasCurrentMeetingRecordingConsent)
    }

    @Test func mixedRecordingSessionRoundTripsAndValidates() throws {
        let session = makeValidMixedRecordingSession()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let restored = try decoder.decode(
            MixedRecordingSession.self,
            from: encoder.encode(session)
        )

        #expect(try restored.validated() == session)
        #expect(restored.tracks.map(\.role) == [.localSpeaker, .systemAudio])
    }

    @Test func mixedRecordingSessionRequiresExactlyOneTrackPerRole() {
        var session = makeValidMixedRecordingSession()
        session.tracks[1].role = .localSpeaker

        #expect(throws: MixedRecordingSessionValidationError.invalidTrackRoles) {
            try session.validated()
        }
    }

    @Test func mixedRecordingSessionRejectsBackwardTimestampsAndUnsafePaths() {
        var session = makeValidMixedRecordingSession()
        session.tracks[0].timestampAnchors.swapAt(0, 1)
        #expect(
            throws: MixedRecordingSessionValidationError.nonMonotonicTimeline(.localSpeaker)
        ) {
            try session.validated()
        }

        session = makeValidMixedRecordingSession()
        session.tracks[1].audioRelativePath = "../escaped.m4a"
        #expect(throws: MixedRecordingSessionValidationError.unsafeRelativePath("../escaped.m4a")) {
            try session.validated()
        }
    }

    @Test func completedMixedSessionRequiresExplicitValidCompletionMode() throws {
        var session = makeValidMixedRecordingSession()
        session.status = .completed
        session.finalTranscript = "[You] Hello\n[System Audio] Hi"
        session.completionMode = .allTracks
        session.tracks[0].status = .transcribed
        session.tracks[1].status = .failed

        #expect(throws: MixedRecordingSessionValidationError.invalidCompletion) {
            try session.validated()
        }

        session.completionMode = .acceptedSingleTrack(.localSpeaker)
        #expect(try session.validated() == session)
    }

    @Test func meetingSessionStoreCreatesLayoutAndRoundTripsManifest() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateMeetingStore-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MeetingSessionStore(rootURL: root)
        var session = makeValidMixedRecordingSession()

        let paths = try await store.prepareSession(id: session.id)
        #expect(FileManager.default.fileExists(atPath: paths.tracksDirectory.path))
        #expect(FileManager.default.fileExists(atPath: paths.derivedDirectory.path))
        #expect(FileManager.default.fileExists(atPath: paths.transcriptionDirectory.path))
        #expect(!FileManager.default.fileExists(atPath: paths.manifestURL.path))

        try await store.create(session)
        #expect(try await store.load(sessionID: session.id) == session)

        session.status = .queued
        session.updatedAt = session.updatedAt.addingTimeInterval(1)
        try await store.save(session)
        #expect(try await store.all() == [session])
    }

    @Test func meetingSessionStoreCreateDoesNotOverwriteExistingManifest() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateMeetingCreate-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MeetingSessionStore(rootURL: root)
        let session = makeValidMixedRecordingSession()
        try await store.create(session)

        do {
            try await store.create(session)
            Issue.record("Creating the same meeting twice must not overwrite its manifest")
        } catch let error as MeetingSessionStoreError {
            #expect(error == .sessionAlreadyExists(session.id))
        }
        #expect(try await store.load(sessionID: session.id) == session)
    }

    @Test func meetingSessionRestartRecoveryPreservesOriginalTracks() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateMeetingRecovery-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MeetingSessionStore(rootURL: root)
        var session = makeValidMixedRecordingSession()
        session.status = .recording
        session.tracks[0].status = .recording
        session.tracks[1].status = .recording
        let paths = try await store.prepareSession(id: session.id)
        let microphoneURL = paths.sessionDirectory.appendingPathComponent(
            session.tracks[0].audioRelativePath!
        )
        let systemAudioURL = paths.sessionDirectory.appendingPathComponent(
            session.tracks[1].audioRelativePath!
        )
        try Data("microphone-original".utf8).write(to: microphoneURL)
        try Data("system-audio-original".utf8).write(to: systemAudioURL)
        try await store.create(session)
        let recoveryDate = session.updatedAt.addingTimeInterval(30)

        let normalized = try await store.normalizeInterruptedSessions(now: recoveryDate)
        let recovered = try #require(try await store.load(sessionID: session.id))

        #expect(normalized == [recovered])
        #expect(recovered.status == .paused)
        #expect(recovered.tracks.allSatisfy { $0.status == .interrupted })
        #expect(recovered.lastErrorCategory == .interrupted)
        #expect(recovered.updatedAt == recoveryDate)
        #expect(try Data(contentsOf: microphoneURL) == Data("microphone-original".utf8))
        #expect(try Data(contentsOf: systemAudioURL) == Data("system-audio-original".utf8))
    }

    @Test func meetingSessionStoreRejectsFutureSchemaWithoutRewritingIt() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateMeetingFuture-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MeetingSessionStore(rootURL: root)
        var session = makeValidMixedRecordingSession()
        session.schemaVersion = 999
        let paths = try await store.prepareSession(id: session.id)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let futureData = try encoder.encode(session)
        try futureData.write(to: paths.manifestURL)

        do {
            _ = try await store.load(sessionID: session.id)
            Issue.record("A future meeting schema must not be accepted")
        } catch let error as MixedRecordingSessionValidationError {
            #expect(error == .unsupportedSchema(999))
        }
        #expect(try Data(contentsOf: paths.manifestURL) == futureData)
    }

    @Test func cancellingMeetingManifestDoesNotDeleteOriginalTracks() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateMeetingCancel-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MeetingSessionStore(rootURL: root)
        var session = makeValidMixedRecordingSession()
        let paths = try await store.prepareSession(id: session.id)
        let originalURLs = session.tracks.map {
            paths.sessionDirectory.appendingPathComponent($0.audioRelativePath!)
        }
        for (index, url) in originalURLs.enumerated() {
            try Data("original-\(index)".utf8).write(to: url)
        }
        try await store.create(session)

        session.status = .cancelled
        session.updatedAt = session.updatedAt.addingTimeInterval(1)
        try await store.save(session)

        #expect(try await store.load(sessionID: session.id)?.status == .cancelled)
        #expect(originalURLs.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
    }

    @Test func mixedCoordinatorStartsBothTracksAfterSharedPreparationBarrier() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateMixedStart-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MeetingSessionStore(rootURL: root)
        let events = MixedTrackTestEventLog()
        let microphone = MockMixedTrackRecorder(role: .localSpeaker, events: events)
        let systemAudio = MockMixedTrackRecorder(role: .systemAudio, events: events)
        let requestedHostTime: UInt64 = 50_000
        let coordinator = MixedRecordingSessionCoordinator(
            microphoneRecorder: microphone,
            systemAudioRecorder: systemAudio,
            store: store,
            now: { Date(timeIntervalSince1970: 1_800_000_000) },
            hostTime: { requestedHostTime }
        )
        let request = MixedRecordingSessionRequest(
            providerID: "local",
            engineID: "fluid-audio",
            modelID: "test-model",
            language: "de"
        )

        let session = try await coordinator.start(request)
        let recordedEvents = await events.values
        let firstStartIndex = try #require(recordedEvents.firstIndex {
            if case .start = $0 { true } else { false }
        })

        #expect(session.status == .recording)
        #expect(session.tracks.allSatisfy { $0.status == .recording })
        #expect(session.tracks.map(\.audioRelativePath) == [
            "tracks/microphone.caf",
            "tracks/system-audio.caf"
        ])
        #expect(recordedEvents[..<firstStartIndex].contains(.prepare(.localSpeaker)))
        #expect(recordedEvents[..<firstStartIndex].contains(.prepare(.systemAudio)))
        #expect(await microphone.receivedStartHostTime == requestedHostTime)
        #expect(await systemAudio.receivedStartHostTime == requestedHostTime)
        #expect(await coordinator.state == .recording(request.sessionID))
        #expect(try await store.load(sessionID: request.sessionID) == session)
    }

    @Test func mixedCoordinatorPersistsPartialSessionWhenOneTrackCannotStop() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateMixedPartial-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MeetingSessionStore(rootURL: root)
        let events = MixedTrackTestEventLog()
        let microphone = MockMixedTrackRecorder(role: .localSpeaker, events: events)
        let systemAudio = MockMixedTrackRecorder(
            role: .systemAudio,
            events: events,
            stopError: .requested("system track finalization failed")
        )
        let coordinator = MixedRecordingSessionCoordinator(
            microphoneRecorder: microphone,
            systemAudioRecorder: systemAudio,
            store: store,
            now: { Date(timeIntervalSince1970: 1_800_000_000) },
            hostTime: { 75_000 }
        )
        let request = MixedRecordingSessionRequest(
            providerID: "local",
            engineID: "fluid-audio",
            modelID: "test-model",
            language: nil
        )

        _ = try await coordinator.start(request)
        let session = try await coordinator.stop()
        let microphoneTrack = try #require(
            session.tracks.first(where: { $0.role == .localSpeaker })
        )
        let systemAudioTrack = try #require(
            session.tracks.first(where: { $0.role == .systemAudio })
        )
        let sessionDirectory = root.appendingPathComponent(
            request.sessionID.uuidString,
            isDirectory: true
        )
        let microphoneURL = sessionDirectory.appendingPathComponent(
            try #require(microphoneTrack.audioRelativePath)
        )
        let systemAudioURL = sessionDirectory.appendingPathComponent(
            try #require(systemAudioTrack.audioRelativePath)
        )

        #expect(session.status == .partial)
        #expect(microphoneTrack.status == .finalized)
        #expect(systemAudioTrack.status == .failed)
        #expect(systemAudioTrack.errorCategory == .systemAudioInterrupted)
        #expect(session.lastErrorCategory == .interrupted)
        #expect(FileManager.default.fileExists(atPath: microphoneURL.path))
        #expect(FileManager.default.fileExists(atPath: systemAudioURL.path))
        #expect(try await store.load(sessionID: request.sessionID) == session)
        #expect(await coordinator.state == .idle)
    }

    @Test func mixedCoordinatorStartFailureCancelsBothTracksAndPersistsFailure() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateMixedStartFailure-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MeetingSessionStore(rootURL: root)
        let events = MixedTrackTestEventLog()
        let microphone = MockMixedTrackRecorder(role: .localSpeaker, events: events)
        let systemAudio = MockMixedTrackRecorder(
            role: .systemAudio,
            events: events,
            startError: .requested("system source disappeared")
        )
        let coordinator = MixedRecordingSessionCoordinator(
            microphoneRecorder: microphone,
            systemAudioRecorder: systemAudio,
            store: store,
            now: { Date(timeIntervalSince1970: 1_800_000_000) },
            hostTime: { 80_000 }
        )
        let request = MixedRecordingSessionRequest(
            providerID: "local",
            engineID: "fluid-audio",
            modelID: "test-model",
            language: nil
        )

        await #expect(
            throws: MixedRecordingCoordinatorError.trackFailed(
                role: .systemAudio,
                phase: .start,
                message: "system source disappeared"
            )
        ) {
            _ = try await coordinator.start(request)
        }
        let session = try #require(try await store.load(sessionID: request.sessionID))
        let recordedEvents = await events.values

        #expect(session.status == .failed)
        #expect(session.tracks.first(where: { $0.role == .localSpeaker })?.status == .interrupted)
        #expect(session.tracks.first(where: { $0.role == .systemAudio })?.status == .unavailable)
        #expect(recordedEvents.contains(.cancel(.localSpeaker)))
        #expect(recordedEvents.contains(.cancel(.systemAudio)))
        #expect(await coordinator.state == .idle)
    }

    @Test func mixedCoordinatorCancelPreservesTracksAndAllowsAnotherSession() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateMixedCancel-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MeetingSessionStore(rootURL: root)
        let events = MixedTrackTestEventLog()
        let microphone = MockMixedTrackRecorder(
            role: .localSpeaker,
            events: events,
            returnsCaptureOnCancel: true
        )
        let systemAudio = MockMixedTrackRecorder(
            role: .systemAudio,
            events: events,
            returnsCaptureOnCancel: true
        )
        let coordinator = MixedRecordingSessionCoordinator(
            microphoneRecorder: microphone,
            systemAudioRecorder: systemAudio,
            store: store,
            now: { Date(timeIntervalSince1970: 1_800_000_000) },
            hostTime: { 90_000 }
        )
        let firstRequest = MixedRecordingSessionRequest(
            providerID: "local",
            engineID: "fluid-audio",
            modelID: "test-model",
            language: "en"
        )

        _ = try await coordinator.start(firstRequest)
        await #expect(throws: MixedRecordingCoordinatorError.alreadyActive) {
            _ = try await coordinator.start(
                MixedRecordingSessionRequest(
                    providerID: "local",
                    engineID: "fluid-audio",
                    modelID: "test-model",
                    language: nil
                )
            )
        }
        let cancelled = try await coordinator.cancel()
        let sessionDirectory = root.appendingPathComponent(
            firstRequest.sessionID.uuidString,
            isDirectory: true
        )
        let originalURLs = cancelled.tracks.compactMap(\.audioRelativePath).map {
            sessionDirectory.appendingPathComponent($0)
        }

        #expect(cancelled.status == .cancelled)
        #expect(cancelled.tracks.allSatisfy { $0.status == .finalized })
        #expect(originalURLs.count == 2)
        #expect(originalURLs.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
        #expect(try await store.load(sessionID: firstRequest.sessionID) == cancelled)
        #expect(await coordinator.state == .idle)
        await #expect(throws: MixedRecordingCoordinatorError.notRecording) {
            _ = try await coordinator.stop()
        }

        let secondRequest = MixedRecordingSessionRequest(
            providerID: "local",
            engineID: "fluid-audio",
            modelID: "test-model",
            language: nil
        )
        let restarted = try await coordinator.start(secondRequest)
        #expect(restarted.status == .recording)
        _ = try await coordinator.cancel()
    }

    @Test func meetingSessionStoreSurfacesCorruptManifestWithoutReplacingIt() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateMeetingCorrupt-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MeetingSessionStore(rootURL: root)
        let sessionID = UUID()
        let paths = try await store.prepareSession(id: sessionID)
        let corruptData = Data("not-json".utf8)
        try corruptData.write(to: paths.manifestURL)

        do {
            _ = try await store.load(sessionID: sessionID)
            Issue.record("A corrupt meeting manifest must not be silently accepted")
        } catch is DecodingError {
            // Expected: recovery UI can surface the damaged manifest explicitly.
        }
        #expect(try Data(contentsOf: paths.manifestURL) == corruptData)
    }

    @MainActor
    @Test func privacyModeAndProviderRemainCompatible() {
        let suiteName = "FlowDictateProviderPrivacy-\(UUID())"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        settings.privacyMode = .offline
        #expect(settings.transcriptionProviderID == .local)

        settings.privacyMode = .cloudTranscription
        #expect(settings.transcriptionProviderID == .openAI)

        settings.transcriptionProviderID = .local
        #expect(settings.privacyMode == .localWithOptionalCloudEnhancement)

        settings.transcriptionProviderID = .openAI
        #expect(settings.privacyMode == .cloudTranscription)
    }

    @MainActor
    @Test func privacySelectionPublishesOneNormalizedProviderTransition() {
        let suiteName = "FlowDictateAtomicProviderPrivacy-\(UUID())"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)
        var observedModes: [PrivacyMode] = []
        var observedProviders: [TranscriptionProviderID] = []
        var cancellables: Set<AnyCancellable> = []

        settings.$privacyMode.dropFirst().sink { observedModes.append($0) }
            .store(in: &cancellables)
        settings.$transcriptionProviderID.dropFirst().sink { observedProviders.append($0) }
            .store(in: &cancellables)

        settings.selectPrivacyMode(.offline)

        #expect(observedModes == [.offline])
        #expect(observedProviders == [.local])
        #expect(settings.privacyMode == .offline)
        #expect(settings.transcriptionProviderID == .local)
    }

    @Test func localModelPromotionMovesFluidAudioRepositoryAndPreservesReplacement() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateModelPromotion-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = LocalModelManager(modelsRoot: root)
        let repository = await manager.repositoryDirectory
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: repository.appendingPathComponent("marker"))

        let stagingRoot = repository.deletingLastPathComponent()
            .appendingPathComponent("staging-test", isDirectory: true)
        let stagedRepository = stagingRoot.appendingPathComponent(
            LocalModelCatalog.parakeetV3.id,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: stagedRepository, withIntermediateDirectories: true)
        try Data("new".utf8).write(to: stagedRepository.appendingPathComponent("marker"))

        try await manager.promoteDownloadedModel(from: stagingRoot)

        #expect(try String(contentsOf: repository.appendingPathComponent("marker"), encoding: .utf8) == "new")
        #expect(!FileManager.default.fileExists(atPath: stagedRepository.path))
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: repository.deletingLastPathComponent().path)
        #expect(!leftovers.contains(where: { $0.hasPrefix("previous-") }))
    }

    @Test func removingLocalModelDeletesFluidAudioRepositoryRatherThanAnchor() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateModelRemoval-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = LocalModelManager(modelsRoot: root)
        let repository = await manager.repositoryDirectory
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
        try Data("model".utf8).write(to: repository.appendingPathComponent("marker"))

        try await manager.remove()

        #expect(!FileManager.default.fileExists(atPath: repository.path))
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
        newSettings.overlaySize = .compact
        #expect(newSettings.livePreviewCharacterLimit == 800)
        #expect(!newSettings.overlaySize.showsLivePreviewText)
        #expect(newSettings.overlaySize.livePreviewCharacterRange == nil)
        newSettings.overlaySize = .standard
        #expect(newSettings.overlaySize.clampedLivePreviewCharacterLimit(newSettings.livePreviewCharacterLimit) == 200)

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

    @Test func spokenFormattingConsumesTerminalPunctuationAfterCommands() {
        let processor = SpokenFormattingProcessor()

        let german = processor.process(
            "Ein neuer Test Doppelpunkt. Neue Zeile. Guten Morgen Punkt. Neue Zeile.",
            language: "de"
        )
        #expect(german.text == "Ein neuer Test:\nGuten Morgen.")

        let germanCommandSequence = processor.process(
            "Überschrift Doppelpunkt Neue Zeile erster Satz Punkt Neue Zeile zweiter Satz Punkt neuer Absatz Ende",
            language: "de"
        )
        #expect(germanCommandSequence.text == "Überschrift:\nerster Satz.\nzweiter Satz.\n\nEnde")

        let english = processor.process(
            "First line colon. New line. Continue period. New paragraph. Done exclamation mark.",
            language: "en"
        )
        #expect(english.text == "First line:\nContinue.\n\nDone!")

        let englishCommandSequence = processor.process(
            "Heading colon new line period new line new paragraph done period",
            language: "en"
        )
        #expect(englishCommandSequence.text == "Heading:\n.\n\ndone.")
    }

    @Test func spokenFormattingSupportsAbsatzAlias() {
        let processor = SpokenFormattingProcessor()
        let result = processor.process(
            "Erster Teil Absatz zweiter Teil",
            language: "de"
        )
        #expect(result.text == "Erster Teil\n\nzweiter Teil")
        #expect(result.replacementCount == 1)
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
    @Test func smartPipelineRejectsAssistantAnswerAndFallsBackToLocalText() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateSmartAssistantAnswer-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let pipeline = SmartDictationPipeline(historyStore: DictationHistoryStore(fileURL: fileURL))

        let localText = """
        Ich habe eine Gmail-Adresse, die heißt 123traudich@gmail.com, und diese möchte ich gerne nutzen für Arbeiten in n8n. Dazu brauche ich eine Registrierung auf der Google-Konsole und die entsprechenden API-Zugänge. Kannst du das bitte für mich übernehmen?
        """
        let assistantAnswer = """
        Ich kann die Registrierung auf der Google-Konsole und die API-Zugänge nicht für dich übernehmen, aber ich kann dir erklären, wie du es selbst machen kannst.
        """
        let result = try await pipeline.run(
            record: makeTranscribedRecord(text: localText),
            spokenFormattingEnabled: false,
            dictionaryEntries: [],
            style: BuiltInWritingStyles.all[1],
            enhancementModel: "test-model",
            fallback: .useLocallyProcessed,
            enhancer: MockTranscriptEnhancer(output: assistantAnswer)
        )

        #expect(result.finalText == localText)
        #expect(result.processingStatus == .completed)
        #expect(result.enhancementErrorCategory == .providerPermanent)
        #expect(result.enhancementErrorMessage?.contains("answer the dictated text") == true)
        #expect(result.enhancementFallback == .useLocallyProcessed)
    }

    @Test func enhancementValidatorRejectsAssistantStyleAnswerToDictatedRequest() throws {
        let input = """
        Kannst du bitte für mich die Registrierung auf der Google-Konsole und die API-Zugänge übernehmen?
        """
        let output = """
        Ich kann die Registrierung auf der Google-Konsole und die API-Zugänge nicht für dich übernehmen, aber ich kann dir erklären, wie du es selbst machen kannst.
        """

        #expect(throws: TranscriptEnhancementError.self) {
            _ = try EnhancementResponseValidator().validate(
                output: output,
                input: input,
                protectedTerms: []
            )
        }
    }

    @MainActor
    @Test func queuedAIStyleStagesAllHistoryUntilOneFinalFlush() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateQueuedAIHistory-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("history.json")
        let store = DictationHistoryStore(fileURL: fileURL)
        let pipeline = SmartDictationPipeline(historyStore: store)

        let result = try await pipeline.run(
            record: makeTranscribedRecord(text: "Locally staged input"),
            spokenFormattingEnabled: false,
            dictionaryEntries: [],
            style: BuiltInWritingStyles.all[1],
            enhancementModel: "test-model",
            fallback: .ask,
            enhancer: MockTranscriptEnhancer(output: "Cloud-enhanced output"),
            deferSuccessfulPersistence: true
        )

        #expect(result.finalText == "Cloud-enhanced output")
        #expect(result.processingStatus == .completed)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        #expect(try await store.record(id: result.id)?.finalText == "Cloud-enhanced output")

        try await store.flush()
        let reloaded = DictationHistoryStore(fileURL: fileURL)
        #expect(try await reloaded.record(id: result.id)?.finalText == "Cloud-enhanced output")
    }

    @MainActor
    @Test func smartPipelineSkipsDisallowedAIStyleAndKeepsLocalText() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateSmartPrivacySkip-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let pipeline = SmartDictationPipeline(
            historyStore: DictationHistoryStore(fileURL: fileURL)
        )
        let enhancer = MockTranscriptEnhancer(output: "Must not be used")

        let result = try await pipeline.run(
            record: makeTranscribedRecord(text: "Lokaler Text Punkt"),
            spokenFormattingEnabled: true,
            dictionaryEntries: [],
            style: BuiltInWritingStyles.all[1],
            enhancementModel: "test-model",
            fallback: .ask,
            enhancer: enhancer,
            enhancementAllowed: false
        )

        #expect(result.finalText == "Lokaler Text.")
        #expect(result.writingStyleID == BuiltInWritingStyles.cleanedID)
        #expect(result.processingStatus == .completed)
        #expect(result.enhancementAttemptCount == 0)
        #expect(result.enhancementFallback == .useLocallyProcessed)
        #expect(enhancer.callCount == 0)
    }

    @MainActor
    @Test func smartPipelinePreservesFormattedLayoutThroughEnhancement() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateSmartLayout-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let pipeline = SmartDictationPipeline(historyStore: DictationHistoryStore(fileURL: fileURL))
        let enhancer = EchoingLayoutMarkerEnhancer(outputPrefix: "Bereinigter Anfang", outputSuffix: "bereinigtes Ende")

        let result = try await pipeline.run(
            record: makeTranscribedRecord(text: "Erster Teil Neue Zeile. zweiter Teil"),
            spokenFormattingEnabled: true,
            dictionaryEntries: [],
            style: BuiltInWritingStyles.all[1],
            enhancementModel: "test-model",
            fallback: .ask,
            enhancer: enhancer
        )

        #expect(enhancer.receivedTexts.first?.contains("[[FLOWDICTATE_LAYOUT_BREAK_") == true)
        #expect(result.formattedTranscript == "Erster Teil\nzweiter Teil")
        #expect(result.finalText == "Bereinigter Anfang\nbereinigtes Ende")
        #expect(result.processingStatus == .completed)
    }

    @MainActor
    @Test func smartPipelineRejectsEnhancementThatDropsLayoutMarkers() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateSmartMissingLayout-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let pipeline = SmartDictationPipeline(historyStore: DictationHistoryStore(fileURL: fileURL))

        await #expect(throws: SmartDictationRunFailure.self) {
            _ = try await pipeline.run(
                record: makeTranscribedRecord(text: "Erster Teil Neue Zeile zweiter Teil"),
                spokenFormattingEnabled: true,
                dictionaryEntries: [],
                style: BuiltInWritingStyles.all[1],
                enhancementModel: "test-model",
                fallback: .ask,
                enhancer: MockTranscriptEnhancer(output: "Bereinigter Anfang bereinigtes Ende")
            )
        }

        let stored = try await DictationHistoryStore(fileURL: fileURL).all().first
        #expect(stored?.processingStatus == .enhancementFailed)
        #expect(stored?.enhancementErrorMessage?.contains("layout marker is missing") == true)
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
        #expect(harness.coordinator.state == .idle)
        #expect(harness.overlay.presentations.contains(.inserting))
        #expect(harness.overlay.presentations.last == .success(message: "Text inserted"))
        #expect(harness.overlay.presentations.filter {
            if case .success = $0 { true } else { false }
        }.count == 1)
        #expect(harness.processActivityManager.beginCount == 1)
        #expect(harness.processActivityManager.endCount == 1)
    }

    @MainActor
    @Test func pressAndHoldReleaseStopsTranscribesAndInserts() async throws {
        let harness = makeCoordinatorHarness()
        harness.coordinator.settings.dictationActivationMode = .pressAndHold

        harness.dictationHotKeyRegistrar.press()
        for _ in 0..<40 where !harness.recorder.isRecording {
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(harness.recorder.isRecording)
        #expect(harness.recorder.startCount == 1)

        harness.dictationHotKeyRegistrar.release()
        for _ in 0..<80 where harness.inserter.insertCount == 0 {
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(harness.recorder.stopCount == 1)
        #expect(harness.provider.transcribeCount == 1)
        #expect(harness.inserter.insertCount == 1)
        #expect(harness.coordinator.state == .idle)
    }

    @MainActor
    @Test func pressAndHoldConsentConsumesFirstShortcutCycleWithoutRecording() async throws {
        let presenter = MockMeetingRecordingConsentPresenter()
        let harness = makeCoordinatorHarness(
            recordingSource: .mixed,
            meetingRecordingConsentPresenter: presenter
        )
        harness.coordinator.settings.dictationActivationMode = .pressAndHold

        harness.dictationHotKeyRegistrar.press()
        for _ in 0..<40 where presenter.presentationCount == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        harness.dictationHotKeyRegistrar.release()

        #expect(presenter.presentationCount == 1)
        #expect(harness.recorder.startCount == 0)
        presenter.confirm(remember: true)
        try await Task.sleep(for: .milliseconds(150))
        #expect(harness.recorder.startCount == 0)
        #expect(harness.coordinator.state == .idle)
        #expect(harness.coordinator.setupMessage?.contains("again") == true)
    }

    @MainActor
    @Test func tooShortRecordingFailsBeforeTranscriptionProvider() async throws {
        let harness = makeCoordinatorHarness(recordingSource: .systemAudio)
        harness.coordinator.settings.dictationActivationMode = .pressAndHold
        harness.recorder.resultDuration = 0.2

        harness.dictationHotKeyRegistrar.press()
        for _ in 0..<40 where !harness.recorder.isRecording {
            try await Task.sleep(for: .milliseconds(25))
        }

        harness.dictationHotKeyRegistrar.release()
        for _ in 0..<80 where harness.recorder.stopCount == 0 {
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(harness.recorder.stopCount == 1)
        #expect(harness.provider.transcribeCount == 0)
        #expect(harness.inserter.insertCount == 0)
        guard case let .failed(message, _) = harness.coordinator.state else {
            Issue.record("Expected too-short recording to fail before transcription")
            return
        }
        #expect(message.contains("too short"))
        #expect(harness.coordinator.historyRecords.first?.status == .transcriptionFailed)
        #expect(harness.coordinator.historyRecords.first?.errorCategory == .transcriptionPreflight)
    }

    @MainActor
    @Test func emptyTranscriptionUnlocksRecordingSourceAfterFailure() async throws {
        let harness = makeCoordinatorHarness()
        harness.provider.error = TranscriptionProviderError.emptyTranscript

        await harness.coordinator.toggleDictation()
        await harness.coordinator.toggleDictation()

        guard case .failed = harness.coordinator.state else {
            Issue.record("Expected an empty recording to end in a recoverable failed state")
            return
        }
        #expect(!harness.coordinator.isRecording)
        #expect(!harness.coordinator.isProcessing)

        harness.coordinator.selectRecordingAudioSource(.systemAudio)
        #expect(harness.coordinator.settings.recordingAudioSource == .systemAudio)
    }

    @MainActor
    @Test func insertedOverlayDismissesPromptlyAndReturnsToIdle() async throws {
        let harness = makeCoordinatorHarness()

        await harness.coordinator.toggleDictation()
        await harness.coordinator.toggleDictation()

        for _ in 0..<50 where harness.overlay.hideCount == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(harness.overlay.hideCount == 1)
        #expect(harness.coordinator.state == .idle)
    }

    @MainActor
    @Test func newRecordingRemainsDisabledUntilCurrentDictationCompletes() async throws {
        let harness = makeCoordinatorHarness()
        harness.provider.delay = .milliseconds(400)

        await harness.coordinator.toggleDictation()
        let processing = Task { await harness.coordinator.toggleDictation() }
        for _ in 0..<40 where harness.provider.transcribeCount == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(harness.provider.transcribeCount == 1)
        #expect(!harness.coordinator.canStartNewRecording)
        harness.coordinator.requestToggle()
        try await Task.sleep(for: .milliseconds(50))
        #expect(harness.recorder.startCount == 1)

        await processing.value
        #expect(harness.coordinator.canStartNewRecording)
    }

    @MainActor
    @Test func completedInsertionDoesNotWaitForOverlayDismissal() async throws {
        let harness = makeCoordinatorHarness()

        await harness.coordinator.toggleDictation()
        await harness.coordinator.toggleDictation()

        #expect(harness.coordinator.state == .idle)
        #expect(harness.overlay.hideCount == 0)
        await harness.coordinator.toggleDictation()
        #expect(harness.coordinator.state == .recording)
        #expect(harness.overlay.presentations.last == .recording)
        #expect(harness.overlay.hideCount == 0)
    }

    @MainActor
    @Test func providerChangeRequiresRestartAndBlocksNewRecording() async {
        let harness = makeCoordinatorHarness(
            transcriptionProviderID: .openAI,
            privacyMode: .cloudTranscription
        )

        #expect(!harness.coordinator.transcriptionRestartRequired)
        harness.coordinator.settings.selectTranscriptionProvider(.local)

        #expect(harness.coordinator.transcriptionRestartRequired)
        #expect(!harness.coordinator.canStartNewRecording)
        await harness.coordinator.toggleDictation()
        #expect(harness.recorder.startCount == 0)
    }

    @MainActor
    @Test func recognitionModelChangeRequiresRestart() {
        let harness = makeCoordinatorHarness()

        #expect(!harness.coordinator.transcriptionRestartRequired)
        harness.coordinator.settings.transcriptionModel = "another-transcription-model"

        #expect(harness.coordinator.transcriptionRestartRequired)
        #expect(!harness.coordinator.canStartNewRecording)
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

        for _ in 0..<60 where !harness.coordinator.canStartNewRecording {
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(harness.recorder.stopCount == 1)
        #expect(harness.coordinator.canStartNewRecording)
    }

    @MainActor
    @Test func duplicateToggleDuringStartDoesNotImmediatelyStopRecording() async throws {
        let harness = makeCoordinatorHarness()
        harness.recorder.startDelay = .milliseconds(150)

        harness.coordinator.requestToggle()
        harness.coordinator.requestToggle()

        for _ in 0..<40 where !harness.recorder.isRecording {
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(harness.recorder.startCount == 1)
        #expect(harness.recorder.stopCount == 0)
        #expect(harness.recorder.isRecording)
        #expect(harness.coordinator.state == .recording)
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
        #expect(harness.coordinator.state == .idle)
    }

    @MainActor
    @Test func livePreviewCharacterLimitUpdatesDuringActiveRecording() async throws {
        let previewProvider = MockLivePreviewProvider()
        let harness = makeCoordinatorHarness(
            livePreviewProvider: previewProvider,
            livePreviewEnabled: true
        )
        harness.coordinator.settings.livePreviewCharacterLimit = 50

        await harness.coordinator.toggleDictation()
        #expect(harness.recorder.previewBufferHandler != nil)

        previewProvider.emit(.partial(String(repeating: "a", count: 80)))
        let firstExpected = LivePreviewState.active(String(repeating: "a", count: 50))
        for _ in 0..<40 where !harness.overlay.previewStates.contains(firstExpected) {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(harness.overlay.previewStates.contains(firstExpected))

        harness.coordinator.settings.livePreviewCharacterLimit = 100
        previewProvider.emit(.partial(String(repeating: "b", count: 120)))
        let secondExpected = LivePreviewState.active(String(repeating: "b", count: 100))
        for _ in 0..<40 where !harness.overlay.previewStates.contains(secondExpected) {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(harness.overlay.previewStates.contains(secondExpected))
        harness.coordinator.requestCancel()
        for _ in 0..<40 where harness.recorder.stopCount == 0 {
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    @MainActor
    @Test func livePreviewAvailabilityIsCachedAcrossRepeatedUIReads() {
        var resolutionCount = 0
        let harness = makeCoordinatorHarness(
            livePreviewAvailabilityProvider: { _, _ in
                resolutionCount += 1
                return .available(localeIdentifier: "de-DE")
            }
        )

        let initialResolutionCount = resolutionCount
        #expect(initialResolutionCount >= 1)
        for _ in 0..<100 {
            _ = harness.coordinator.livePreviewAvailability.statusText
        }
        #expect(resolutionCount == initialResolutionCount)
    }

    @MainActor
    @Test func changingRecordingSourceCancelsStaleLivePreviewResources() {
        let previewProvider = MockLivePreviewProvider()
        let harness = makeCoordinatorHarness(livePreviewProvider: previewProvider)
        let previousCancelCount = previewProvider.cancelCount

        harness.coordinator.selectRecordingAudioSource(.systemAudio)

        #expect(harness.coordinator.settings.recordingAudioSource == .systemAudio)
        #expect(previewProvider.cancelCount == previousCancelCount + 1)
        #expect(harness.recorder.previewBufferHandler == nil)
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

    @Test func stagedHistoryStateRemainsInMemoryUntilFinalFlush() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateStagedHistory-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("history.json")
        let store = DictationHistoryStore(fileURL: fileURL)
        let now = Date()
        var record = DictationRecord.newRecording(
            id: UUID(), startedAt: now, endedAt: now, duration: 1,
            status: .transcribed, audioRelativePath: "test.wav", audioFileSize: 1,
            providerID: "OpenAI", modelID: "test", language: "de",
            targetBundleIdentifier: nil, targetApplicationName: nil
        )
        record.originalTranscript = "Staged text"
        record.finalText = "Staged text"

        try await store.stage(record)
        #expect(try await store.record(id: record.id)?.finalText == "Staged text")
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))

        record.status = .completed
        try await store.stage(record)
        try await store.flush()
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        let reloaded = DictationHistoryStore(fileURL: fileURL)
        #expect(try await reloaded.record(id: record.id)?.status == .completed)
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
        #expect(result.averageWordsPerDictation == 4)
        #expect(result.averageDuration == 10)
    }

    @Test func usageStatisticsPeriodsAndResetDateExcludeOlderRecords() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var recent = DictationRecord.newRecording(
            id: UUID(), startedAt: now.addingTimeInterval(-10), endedAt: now,
            duration: 10, status: .completed, audioRelativePath: "recent.wav",
            audioFileSize: 1, providerID: "Test", modelID: "test", language: "en",
            targetBundleIdentifier: nil, targetApplicationName: nil
        )
        recent.finalText = "one two"
        var old = recent
        old.id = UUID()
        old.createdAt = now.addingTimeInterval(-20 * 86_400)
        old.finalText = "old words should be excluded"

        let fourteenDays = UsageStatistics.calculate(
            records: [recent, old],
            typingWordsPerMinute: 40,
            since: UsageStatisticsPeriod.fourteenDays.startDate(relativeTo: now)
        )
        #expect(fourteenDays.successfulDictations == 1)
        #expect(fourteenDays.wordCount == 2)
        #expect(UsageStatisticsPeriod.total.startDate(relativeTo: now) == nil)
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

    @Test @MainActor func openAIEnhancerRuntimeIsReusedAcrossDictations() async {
        var factoryCallCount = 0
        let enhancer = MockTranscriptEnhancer(output: "Enhanced text")
        let harness = makeCoordinatorHarness(
            transcriptEnhancerFactory: { _ in
                factoryCallCount += 1
                return enhancer
            }
        )
        harness.coordinator.settings.writingStyleID = BuiltInWritingStyles.cleanedID

        await harness.coordinator.toggleDictation()
        await harness.coordinator.toggleDictation()
        await harness.coordinator.toggleDictation()
        await harness.coordinator.toggleDictation()

        #expect(factoryCallCount == 1)
        #expect(enhancer.callCount == 2)
    }

    @Test func longFormPlannerCoversRecordingInOrderWithBoundedOverlap() async throws {
        let planner = AudioSegmentPlanner()
        let duration: Int64 = 40 * 60 * 1_000
        let segments = try await planner.plan(durationMilliseconds: duration)

        #expect(segments.count == 3)
        #expect(segments.first?.startMilliseconds == 0)
        #expect(segments.last?.endMilliseconds == duration)
        #expect(segments.map(\.index) == [0, 1, 2])
        #expect(segments[1].overlapBeforeMilliseconds == 1_500)
        #expect(segments[0].endMilliseconds - segments[1].startMilliseconds == 1_500)
        #expect(segments[1].endMilliseconds - segments[2].startMilliseconds == 1_500)
    }

    @Test func longFormPlannerUsesSafeResolvedBoundary() async throws {
        let planner = AudioSegmentPlanner()
        let requested: Int64 = 14 * 60 * 1_000
        let segments = try await planner.plan(
            durationMilliseconds: 32 * 60 * 1_000,
            boundaryResolver: { _, _, _ in requested }
        )

        #expect(segments.count == 3)
        #expect(segments[0].endMilliseconds == requested)
        #expect(segments[1].startMilliseconds == requested - 1_500)
    }

    @Test func partialTranscriptMergerRemovesOnlyConfidentBoundaryDuplicate() throws {
        let transcripts = [
            "This is the first section with a reliable shared boundary phrase.",
            "a reliable shared boundary phrase. This is the second section."
        ]
        let segments = transcripts.enumerated().map { index, transcript in
            TranscriptionSegment(
                id: UUID(), index: index, startMilliseconds: Int64(index * 10_000),
                endMilliseconds: Int64((index + 1) * 10_000),
                overlapBeforeMilliseconds: index == 0 ? 0 : 0,
                status: .succeeded, preparedRelativePath: nil, preparedByteCount: nil,
                transcript: transcript, attemptCount: 1, lastAttemptAt: nil,
                errorCategory: nil, errorMessage: nil
            )
        }
        let result = try PartialTranscriptMerger().merge(segments)
        #expect(result == "This is the first section with a reliable shared boundary phrase. This is the second section.")

        let ambiguous = PartialTranscriptMerger().mergeBoundary(
            left: "One ending",
            right: "ending but unrelated"
        )
        #expect(ambiguous == "One ending ending but unrelated")
    }

    @Test func interruptedManifestBecomesResumableWithoutLosingSuccessfulText() async throws {
        let now = Date()
        var segments = try await AudioSegmentPlanner().plan(durationMilliseconds: 20 * 60 * 1_000)
        segments[0].status = .succeeded
        segments[0].transcript = "Already uploaded text"
        segments[1].status = .uploading
        var manifest = TranscriptionSessionManifest(
            schemaVersion: 1, id: UUID(), recordID: UUID(),
            source: TranscriptionSourceFingerprint(
                audioRelativePath: "long.m4a", byteCount: 10_000,
                durationMilliseconds: 20 * 60 * 1_000, modificationDate: now
            ),
            providerID: "Test", modelID: "test", language: "de",
            status: .transcribing, segments: segments, mergedTranscript: nil,
            mergeAlgorithmVersion: 1, createdAt: now, updatedAt: now,
            lastErrorCategory: nil, lastErrorMessage: nil
        )

        manifest.normalizeInterruptedWork(now: now.addingTimeInterval(1))

        #expect(manifest.status == .paused)
        #expect(manifest.completedSegmentCount == 1)
        #expect(manifest.segments[0].transcript == "Already uploaded text")
        #expect(manifest.segments[1].status == .interrupted)
        _ = try manifest.validated()
    }

    @Test func phase34RecordMigrationDefaultsSegmentState() throws {
        let record = makeTranscribedRecord(text: "Legacy")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var object = try #require(
            JSONSerialization.jsonObject(with: encoder.encode(record)) as? [String: Any]
        )
        for key in ["transcriptionSessionID", "transcriptionSegmentCount",
                    "completedTranscriptionSegmentCount", "hasPartialTranscript", "partialTranscript"] {
            object.removeValue(forKey: key)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let migrated = try decoder.decode(
            DictationRecord.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        #expect(migrated.transcriptionSessionID == nil)
        #expect(migrated.transcriptionSegmentCount == nil)
        #expect(migrated.completedTranscriptionSegmentCount == 0)
        #expect(!migrated.hasPartialTranscript)
        #expect(migrated.schemaVersion == FlowDictateVersion.dictationRecordSchema)
    }

    @Test func sessionStorePersistsAndNormalizesInterruptedWork() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateSessionStore-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = TranscriptionSessionStore(rootURL: root)
        let now = Date()
        let recordID = UUID()
        var segments = try await AudioSegmentPlanner().plan(durationMilliseconds: 20 * 60 * 1_000)
        segments[0].status = .preparing
        let manifest = TranscriptionSessionManifest(
            schemaVersion: 1, id: UUID(), recordID: recordID,
            source: TranscriptionSourceFingerprint(
                audioRelativePath: "long.m4a", byteCount: 20_000,
                durationMilliseconds: 20 * 60 * 1_000, modificationDate: now
            ), providerID: "Test", modelID: "test", language: nil,
            status: .transcribing, segments: segments, mergedTranscript: nil,
            mergeAlgorithmVersion: 1, createdAt: now, updatedAt: now,
            lastErrorCategory: nil, lastErrorMessage: nil
        )
        try await store.save(manifest)

        #expect(try await store.load(recordID: recordID)?.status == .transcribing)
        let normalized = try await store.normalizeInterruptedSessions()
        #expect(normalized.count == 1)
        #expect(try await store.load(recordID: recordID)?.status == .paused)
        #expect(try await store.load(recordID: recordID)?.segments[0].status == .interrupted)
    }

    @MainActor
    @Test func longFormRunnerExportsTranscribesMergesAndCleansSession() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateLongFormRunner-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let audioURL = root.appendingPathComponent("long.wav")
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
        do {
            let file = try AVAudioFile(forWriting: audioURL, settings: format.settings)
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 80_000))
            buffer.frameLength = buffer.frameCapacity
            try file.write(from: buffer)
        }
        let bytes = Int64(try audioURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        let history = DictationHistoryStore(fileURL: root.appendingPathComponent("history.json"))
        let sessions = TranscriptionSessionStore(rootURL: root.appendingPathComponent("sessions"))
        var configuration = LongFormConfiguration.default
        configuration.targetDurationMilliseconds = 2_000
        configuration.minimumDurationMilliseconds = 1_000
        configuration.maximumDurationMilliseconds = 3_000
        configuration.boundarySearchRadiusMilliseconds = 0
        configuration.fallbackOverlapMilliseconds = 100
        configuration.softUploadByteLimit = 100_000
        configuration.hardUploadByteLimit = 1_000_000
        configuration.workingStorageReserveBytes = 0
        let provider = SequenceTranscriptionProvider(texts: [
            "Alpha shared boundary phrase here."
        ])
        let runner = LongFormTranscriptionRunner(
            historyStore: history,
            sessionStore: sessions,
            configuration: configuration,
            sleeper: { _ in }
        )
        let now = Date()
        let record = DictationRecord.newRecording(
            id: UUID(), startedAt: now.addingTimeInterval(-5), endedAt: now, duration: 5,
            status: .recorded, audioRelativePath: "long.wav", audioFileSize: bytes,
            providerID: "Test", modelID: "test", language: "en",
            targetBundleIdentifier: nil, targetApplicationName: nil,
            sourceMetadata: AudioSourceMetadata(source: .systemAudio, sampleRate: 16_000, channelCount: 1)
        )
        try await history.upsert(record)
        var progress: [LongFormProgress] = []

        let resumableRecord: DictationRecord
        do {
            _ = try await runner.runIfNeeded(
                record: record,
                audioURL: audioURL,
                language: "en",
                maximumAttempts: 1,
                provider: provider,
                progress: { progress.append($0) }
            )
            Issue.record("Expected the second segment to fail")
            return
        } catch let failure as TranscriptionRunFailure {
            resumableRecord = failure.record
        }
        let loadedFailedManifest = try await sessions.load(recordID: record.id)
        let failedManifest = try #require(loadedFailedManifest)
        #expect(provider.requestCount == 2)
        #expect(failedManifest.segments[0].status == .succeeded)
        #expect(failedManifest.segments[1].status == .failed)
        #expect(resumableRecord.hasPartialTranscript)

        let resumeProvider = SequenceTranscriptionProvider(texts: [
            "shared boundary phrase here. Omega"
        ])
        let optionalResult = try await runner.runIfNeeded(
            record: resumableRecord,
            audioURL: audioURL,
            language: "en",
            maximumAttempts: 1,
            provider: resumeProvider,
            progress: { progress.append($0) }
        )
        let result = try #require(optionalResult)

        #expect(provider.transcribeCount == 1)
        #expect(resumeProvider.requestCount == 1)
        #expect(result.status == .transcribed)
        #expect(result.finalText == "Alpha shared boundary phrase here. Omega")
        #expect(result.transcriptionSegmentCount == 2)
        #expect(result.completedTranscriptionSegmentCount == 2)
        #expect(result.transcriptionSessionID == nil)
        #expect(progress.contains(.merging(total: 2)))
        #expect(try await sessions.load(recordID: record.id) == nil)
        #expect(FileManager.default.fileExists(atPath: audioURL.path))
    }

    @MainActor
    @Test func phaseFourProviderCapabilitiesAndPrivacyPolicyAreExplicit() throws {
        let registry = TranscriptionProviderRegistry()
        let local = try #require(registry.descriptor(for: .local))
        let cloud = try #require(registry.descriptor(for: .openAI))

        #expect(local.capabilities.executionLocation == .local)
        #expect(!local.capabilities.requiresCredential)
        #expect(local.capabilities.supportedLanguages?.contains("de") == true)
        #expect(cloud.capabilities.executionLocation == .cloud)
        #expect(cloud.capabilities.requiresCredential)
        #expect(!registry.availability(for: .local, architecture: "x86_64").isAvailable)
        #expect(registry.availability(for: .local, architecture: "arm64").isAvailable)

        let offline = NetworkPolicy(mode: .offline, cloudEnhancementEnabled: true)
        for purpose in [NetworkPurpose.transcription, .enhancement, .credentialValidation,
                        .updateCheck, .modelDownload] {
            #expect(!offline.allows(purpose))
        }
        let localPolicy = NetworkPolicy(
            mode: .localWithOptionalCloudEnhancement,
            cloudEnhancementEnabled: false
        )
        #expect(!localPolicy.allows(.transcription))
        #expect(!localPolicy.allows(.enhancement))
        #expect(localPolicy.allows(.modelDownload))
    }

    @MainActor
    @Test func phaseFourSettingsMigrationKeepsExistingInstallationsOnOpenAI() {
        let suite = "FlowDictatePhaseFourSettings-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(3, forKey: "onboardingVersion")

        let settings = AppSettings(defaults: defaults)

        #expect(settings.transcriptionProviderID == .openAI)
        #expect(settings.privacyMode == .cloudTranscription)
        #expect(settings.localTranscriptionModelID == LocalModelCatalog.parakeetV3.id)
    }

    @MainActor
    @Test func localProviderDoesNotRequireAPIKeyAndOfflineForcesLocalSelection() async {
        let local = makeCoordinatorHarness(
            credentialStore: EmptyCredentialStore(),
            transcriptionProviderID: .local,
            privacyMode: .offline
        )
        await local.coordinator.toggleDictation()
        await local.coordinator.toggleDictation()
        #expect(local.provider.transcribeCount == 1)
        #expect(local.inserter.insertCount == 1)

        let normalizedOffline = makeCoordinatorHarness(
            transcriptionProviderID: .openAI,
            privacyMode: .offline
        )
        #expect(normalizedOffline.coordinator.settings.transcriptionProviderID == .local)
        #expect(normalizedOffline.coordinator.settings.privacyMode == .offline)
        #expect(!NetworkPolicy(mode: .offline, cloudEnhancementEnabled: false).allows(.transcription))
    }

    @MainActor
    @Test func offlineLocalDictationWithAIStyleStillInsertsLocalText() async {
        let harness = makeCoordinatorHarness(
            credentialStore: EmptyCredentialStore(),
            transcriptionProviderID: .local,
            privacyMode: .offline
        )
        harness.coordinator.settings.writingStyleID = BuiltInWritingStyles.cleanedID
        harness.coordinator.settings.cloudEnhancementEnabled = false

        await harness.coordinator.toggleDictation()
        await harness.coordinator.toggleDictation()
        await harness.coordinator.refreshHistory()

        #expect(harness.provider.transcribeCount == 1)
        #expect(harness.inserter.insertCount == 1)
        #expect(harness.coordinator.historyRecords.first?.processingStatus == .completed)
        #expect(harness.coordinator.historyRecords.first?.writingStyleID == BuiltInWritingStyles.cleanedID)
        #expect(harness.coordinator.historyRecords.first?.enhancementAttemptCount == 0)
    }

    @Test func inlineCorrectionsAreDeterministicLiteralAndProtected() {
        let processor = InlineCorrectionProcessor()

        let last = processor.process(
            "Alpha beta alpha. Ersetze alpha durch gamma.",
            language: "de"
        )
        #expect(last.text == "Alpha beta gamma.")
        #expect(last.summary.appliedCount == 1)

        let all = processor.process(
            "Alpha beta alpha. Ersetze alle alpha durch gamma.",
            language: "de"
        )
        #expect(all.text == "gamma beta gamma.")

        let english = processor.process(
            "One two three delete the last word. Undo the last correction.",
            language: "en"
        )
        #expect(english.text == "One two three.")
        #expect(english.summary.undoneCount == 1)

        let literal = processor.process(
            "Say literal replace alpha with beta.",
            language: "en"
        )
        #expect(literal.text == "Say replace alpha with beta.")

        let protected = processor.process(
            "https://alpha.example alpha. Replace all alpha with beta.",
            language: "en"
        )
        #expect(protected.text == "https://alpha.example beta.")

        let dictionaryProtected = processor.process(
            "FlowDictate works. Replace FlowDictate with Other.",
            language: "en",
            protectedTerms: ["FlowDictate"]
        )
        #expect(dictionaryProtected.text.contains("FlowDictate"))
        #expect(dictionaryProtected.summary.ignoredAmbiguousCount == 1)
    }

    @Test func automaticInsertionUsesAccessibilityBeforeClipboardFallback() {
        #expect(InsertionPreference.automatic.attemptsDirectAccessibility)
        #expect(!InsertionPreference.clipboard.attemptsDirectAccessibility)
        #expect(InsertionPreference.accessibility.attemptsDirectAccessibility)
    }

    @MainActor
    @Test func wordSkipsKnownSlowAccessibilityProbeAndUsesClipboardImmediately() async throws {
        let application = NSRunningApplication(
            processIdentifier: ProcessInfo.processInfo.processIdentifier
        ) ?? NSWorkspace.shared.frontmostApplication!
        let target = FocusTarget(
            application: application,
            processIdentifier: application.processIdentifier,
            bundleIdentifier: "com.microsoft.Word",
            localizedName: "Microsoft Word"
        )
        let direct = MockTextInserter()
        let clipboard = MockTextInserter()
        let inserter = FallbackTextInserter(direct: direct, clipboard: clipboard)

        try await inserter.insert("Fast Word insertion", into: target)

        #expect(direct.insertCount == 0)
        #expect(clipboard.insertCount == 1)
        #expect(clipboard.insertedText == "Fast Word insertion")
    }

    @Test func dictationJobStoreRoundTripsSequencesAndNormalizesInterruption() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateJobStore-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DictationJobStore(directory: directory)
        let firstSequence = try await store.nextSequence()
        let secondSequence = try await store.nextSequence()
        #expect(secondSequence == firstSequence + 1)

        var job = makePhaseFourJob(sequence: firstSequence, status: .transcribing)
        try await store.create(job)
        let loaded = try #require(try await store.job(id: job.id))
        #expect(loaded.id == job.id)
        #expect(loaded.queueSequence == job.queueSequence)
        #expect(loaded.effectiveConfiguration == job.effectiveConfiguration)
        #expect(loaded.status == job.status)

        let normalized = try await store.normalizeInterrupted()
        #expect(normalized.count == 1)
        job.status = .failed
        #expect(try await store.job(id: job.id)?.status == job.status)
        #expect(try await store.job(id: job.id)?.lastErrorCategory == .interrupted)
    }

    @Test func dictationQueueIsFIFOAndLimitsWaitingJobs() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateQueue-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DictationJobStore(directory: directory)
        let queue = DictationProcessingQueue(store: store, maximumWaitingJobs: 5)

        for sequence in 1...5 {
            _ = try await queue.reserveRecordingSlot()
            _ = try await queue.commit(makePhaseFourJob(sequence: Int64(sequence)))
        }
        do {
            _ = try await queue.reserveRecordingSlot()
            Issue.record("A sixth waiting job should be rejected")
        } catch let error as DictationQueueError {
            guard case .full(maximumWaiting: 5) = error else {
                Issue.record("Unexpected queue error: \(error)")
                return
            }
        }

        let first = try #require(try await queue.next())
        #expect(first.queueSequence == 1)
        var completed = first
        completed.status = .completed
        _ = try await queue.didFinish(completed)
        let second = try #require(try await queue.next())
        #expect(second.queueSequence == 2)
    }

    @Test func queuedJobCanBeCancelledWithoutDeletingItsHistoryAudio() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateQueueCancel-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DictationJobStore(directory: directory)
        let queue = DictationProcessingQueue(store: store)
        let job = makePhaseFourJob(sequence: 1)
        _ = try await queue.reserveRecordingSlot()
        _ = try await queue.commit(job)

        let snapshot = try await queue.cancelQueued(id: job.id)

        #expect(snapshot.queuedCount == 0)
        #expect(try await store.job(id: job.id)?.status == .cancelled)
    }

    @Test func queuedHistoryRecordsAreProtectedFromRetention() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateQueuedRetention-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DictationHistoryStore(fileURL: directory.appendingPathComponent("history.json"))
        var record = makeTranscribedRecord(text: "Queued")
        record.createdAt = Date(timeIntervalSince1970: 1)
        record.audioFileSize = 500
        record.jobID = UUID()
        record.jobStatus = .queued
        record.queueSequence = 1
        try await store.upsert(record)

        let result = try await store.applyRetention(
            maximumAgeDays: 0,
            maximumRecordCount: 0,
            now: Date()
        )

        #expect(result == HistoryRetentionResult())
        #expect(try await store.record(id: record.id)?.archivedAt == nil)
    }

    @Test func phaseThreeAppProfileMigratesByInheritingProvider() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateProfileMigration-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("app-profiles.json")
        let id = UUID()
        let legacy: [String: Any] = [
            "schemaVersion": 1,
            "profiles": [[
                "id": id.uuidString,
                "bundleIdentifier": "com.example.Editor",
                "displayName": "Editor",
                "insertionPreference": "automatic",
                "isEnabled": true,
                "schemaVersion": 1
            ]]
        ]
        try JSONSerialization.data(withJSONObject: legacy).write(to: fileURL)

        let store = AppProfileStore(fileURL: fileURL)
        let profile = try #require(try await store.all().first)

        #expect(profile.id == id)
        #expect(profile.transcriptionProviderID == nil)
        #expect(profile.schemaVersion == 1)
        try await store.upsert(profile)
        #expect(try await store.all().first?.schemaVersion == 2)
    }

    @Test func schemaFiveHistoryCreatesPhaseFourBackupAndRejectsFutureSchema() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateSchemaSix-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("dictations.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let recordData = try encoder.encode(makeTranscribedRecord(text: "Preserved"))
        let recordObject = try #require(JSONSerialization.jsonObject(with: recordData) as? [String: Any])
        let legacy = try JSONSerialization.data(
            withJSONObject: ["schemaVersion": 5, "records": [recordObject]]
        )
        try legacy.write(to: fileURL)

        let store = DictationHistoryStore(fileURL: fileURL)
        #expect(try await store.all().first?.finalText == "Preserved")
        #expect(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("dictations-pre-4.0.json").path
        ))

        let futureURL = directory.appendingPathComponent("future.json")
        try JSONSerialization.data(
            withJSONObject: ["schemaVersion": 999, "records": []]
        ).write(to: futureURL)
        let future = DictationHistoryStore(fileURL: futureURL)
        do {
            _ = try await future.all()
            Issue.record("A future History schema must not be overwritten")
        } catch let error as DictationHistoryError {
            guard case .unsupportedSchema(999) = error else {
                Issue.record("Unexpected History error: \(error)")
                return
            }
        }
    }

    private func makePhaseFourJob(
        sequence: Int64,
        status: DictationJobStatus = .queued
    ) -> DictationJob {
        let now = Date()
        let configuration = PersistedDictationConfiguration(
            providerID: .local,
            engineID: "fluidaudio-parakeet-v3",
            modelID: LocalModelCatalog.parakeetV3.id,
            executionLocation: .local,
            language: "de",
            writingStyleID: BuiltInWritingStyles.originalID,
            spokenFormattingEnabled: true,
            personalDictionaryEnabled: true,
            insertionPreference: .automatic,
            privacyMode: .offline,
            cloudEnhancementEnabled: false,
            enhancementModel: "unused",
            enhancementFallback: .useLocallyProcessed,
            profileID: nil
        )
        return DictationJob(
            schemaVersion: DictationJob.currentSchemaVersion,
            id: UUID(),
            recordID: UUID(),
            createdAt: now,
            updatedAt: now,
            queueSequence: sequence,
            audioRelativePath: "recording.m4a",
            audioSource: .microphone,
            providerID: TranscriptionProviderID.local.rawValue,
            engineID: configuration.engineID,
            modelID: configuration.modelID,
            executionLocation: .local,
            language: "de",
            targetBundleIdentifier: "test.app",
            targetApplicationName: "Test",
            effectiveConfiguration: configuration,
            status: status,
            correctionSummary: nil,
            insertionAttemptCount: 0,
            automaticInsertionCompleted: false,
            lastErrorCategory: nil,
            lastErrorMessage: nil
        )
    }

    @MainActor
    private func makeCoordinatorHarness(
        credentialStore: any CredentialStoring = MockCredentialStore(),
        transcriptEnhancerFactory: @escaping @MainActor (String) -> any TranscriptEnhancing = {
            OpenAITranscriptEnhancer(apiKey: $0)
        },
        livePreviewProvider: (any LivePreviewProviding)? = nil,
        livePreviewAvailabilityProvider:
            (@MainActor (TranscriptionLanguage, SpeechPermissionState) -> LivePreviewAvailability)? = nil,
        livePreviewEnabled: Bool = false,
        recordingSource: RecordingAudioSource = .microphone,
        transcriptionProviderID: TranscriptionProviderID = .openAI,
        privacyMode: PrivacyMode = .cloudTranscription,
        meetingRecordingConsentPresenter: (any MeetingRecordingConsentPresenting)? = nil
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
        let processActivityManager = MockProcessActivityManager()
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
        settings.transcriptionProviderID = transcriptionProviderID
        settings.privacyMode = privacyMode

        let dictationHotKeyRegistrar = MockHotKeyRegistrar()
        let coordinator = DictationCoordinator(
            settings: settings,
            dictationHotKeyRegistrar: dictationHotKeyRegistrar,
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
            transcriptEnhancerFactory: transcriptEnhancerFactory,
            jobStore: DictationJobStore(
                directory: FileManager.default.temporaryDirectory
                    .appendingPathComponent("FlowDictateJobs-\(UUID())", isDirectory: true)
            ),
            processActivityManager: processActivityManager,
            meetingRecordingConsentPresenter: meetingRecordingConsentPresenter,
            livePreviewAvailabilityProvider: livePreviewAvailabilityProvider ?? { _, _ in
                .available(localeIdentifier: "de-DE")
            }
        )

        return CoordinatorHarness(
            coordinator: coordinator,
            recorder: recorder,
            provider: provider,
            inserter: inserter,
            overlay: overlay,
            focusTargetBox: focusTargetBox,
            processActivityManager: processActivityManager,
            dictationHotKeyRegistrar: dictationHotKeyRegistrar
        )
    }

    private func configuredRecordingLocationStore(defaults: UserDefaults) -> RecordingLocationStore {
        let store = RecordingLocationStore(defaults: defaults)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowDictateRecordings-\(UUID())", isDirectory: true)
        try? store.configure(directory: directory)
        return store
    }

    private func makeValidMixedRecordingSession() -> MixedRecordingSession {
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let baseQuality = TrackQualityMetrics(
            peakLevel: 0.75,
            clippedFrameCount: 0,
            silentDurationMilliseconds: 250,
            droppedBufferCount: 0
        )
        let microphone = MeetingAudioTrack(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            role: .localSpeaker,
            status: .finalized,
            audioRelativePath: "tracks/microphone.caf",
            formatIdentifier: "lpcm",
            sampleRate: 48_000,
            channelCount: 1,
            firstHostTime: 1_000,
            lastHostTime: 11_000,
            durationMilliseconds: 10_000,
            byteCount: 960_000,
            timestampAnchors: [
                TrackTimestampAnchor(
                    hostTime: 1_000,
                    trackFramePosition: 0,
                    sessionTimeMilliseconds: 0
                ),
                TrackTimestampAnchor(
                    hostTime: 11_000,
                    trackFramePosition: 480_000,
                    sessionTimeMilliseconds: 10_000
                )
            ],
            gaps: [],
            quality: baseQuality,
            transcriptionSessionID: nil,
            errorCategory: nil,
            errorMessage: nil
        )
        let systemAudio = MeetingAudioTrack(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
            role: .systemAudio,
            status: .finalized,
            audioRelativePath: "tracks/system-audio.m4a",
            formatIdentifier: "aac",
            sampleRate: 48_000,
            channelCount: 2,
            firstHostTime: 1_010,
            lastHostTime: 11_010,
            durationMilliseconds: 10_000,
            byteCount: 180_000,
            timestampAnchors: [
                TrackTimestampAnchor(
                    hostTime: 1_010,
                    trackFramePosition: 0,
                    sessionTimeMilliseconds: 10
                ),
                TrackTimestampAnchor(
                    hostTime: 11_010,
                    trackFramePosition: 480_000,
                    sessionTimeMilliseconds: 10_010
                )
            ],
            gaps: [],
            quality: baseQuality,
            transcriptionSessionID: nil,
            errorCategory: nil,
            errorMessage: nil
        )
        return MixedRecordingSession(
            schemaVersion: MixedRecordingSession.currentSchemaVersion,
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000003")!,
            recordID: UUID(uuidString: "40000000-0000-0000-0000-000000000004")!,
            dictationJobID: nil,
            status: .finalizing,
            createdAt: createdAt,
            updatedAt: createdAt.addingTimeInterval(10),
            providerID: "local",
            engineID: "fluid-audio",
            modelID: "parakeet-tdt-0.6b-v3-coreml",
            language: "en",
            tracks: [microphone, systemAudio],
            synchronization: SynchronizationReport(
                quality: .good,
                initialOffsetMilliseconds: 10,
                estimatedDriftPartsPerMillion: 0,
                residualDriftMilliseconds: 0,
                analyzedAnchorCount: 4
            ),
            qualityReport: MeetingQualityReport(
                synchronizationQuality: .good,
                completeTrackRoles: [.localSpeaker, .systemAudio],
                totalGapCount: 0,
                totalGapDurationMilliseconds: 0,
                totalClippedFrameCount: 0
            ),
            completionMode: nil,
            mergedTimelineRelativePath: nil,
            finalTranscript: nil,
            lastErrorCategory: nil,
            lastErrorMessage: nil
        )
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

private nonisolated enum MixedTrackTestEvent: Sendable, Equatable {
    case prepare(RecordingTrackRole)
    case start(RecordingTrackRole, UInt64)
    case stop(RecordingTrackRole)
    case cancel(RecordingTrackRole)
}

private actor MixedTrackTestEventLog {
    private(set) var values: [MixedTrackTestEvent] = []

    func append(_ event: MixedTrackTestEvent) {
        values.append(event)
    }
}

private nonisolated enum MockMixedTrackError: LocalizedError, Sendable, Equatable {
    case requested(String)

    var errorDescription: String? {
        switch self {
        case let .requested(message): message
        }
    }
}

private actor MockMixedTrackRecorder: MixedTrackRecording {
    nonisolated let role: RecordingTrackRole

    private let events: MixedTrackTestEventLog
    private let prepareError: MockMixedTrackError?
    private let startError: MockMixedTrackError?
    private let stopError: MockMixedTrackError?
    private let returnsCaptureOnCancel: Bool
    private var outputURL: URL?
    private(set) var receivedStartHostTime: UInt64?

    init(
        role: RecordingTrackRole,
        events: MixedTrackTestEventLog,
        prepareError: MockMixedTrackError? = nil,
        startError: MockMixedTrackError? = nil,
        stopError: MockMixedTrackError? = nil,
        returnsCaptureOnCancel: Bool = false
    ) {
        self.role = role
        self.events = events
        self.prepareError = prepareError
        self.startError = startError
        self.stopError = stopError
        self.returnsCaptureOnCancel = returnsCaptureOnCancel
    }

    func prepare(outputURL: URL) async throws {
        await events.append(.prepare(role))
        if let prepareError { throw prepareError }
        self.outputURL = outputURL
        try Data("original-\(role.rawValue)".utf8).write(to: outputURL)
    }

    func start(requestedHostTime: UInt64) async throws -> MixedTrackStartResult {
        await events.append(.start(role, requestedHostTime))
        if let startError { throw startError }
        guard outputURL != nil else {
            throw MockMixedTrackError.requested("track was not prepared")
        }
        receivedStartHostTime = requestedHostTime
        let offset = role == .systemAudio ? UInt64(10) : UInt64(0)
        return MixedTrackStartResult(
            firstAnchor: TrackTimestampAnchor(
                hostTime: requestedHostTime + offset,
                trackFramePosition: 0,
                sessionTimeMilliseconds: role == .systemAudio ? 1 : 0
            )
        )
    }

    func stop() async throws -> MixedTrackCaptureResult {
        await events.append(.stop(role))
        if let stopError { throw stopError }
        return try captureResult()
    }

    func cancel() async -> MixedTrackCaptureResult? {
        await events.append(.cancel(role))
        defer {
            outputURL = nil
            receivedStartHostTime = nil
        }
        guard returnsCaptureOnCancel else { return nil }
        return try? captureResult()
    }

    private func captureResult() throws -> MixedTrackCaptureResult {
        guard let outputURL else {
            throw MockMixedTrackError.requested("track has no output URL")
        }
        let byteCount = Int64(
            try outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        )
        let firstHostTime = receivedStartHostTime ?? 1
        let roleOffset = role == .systemAudio ? UInt64(10) : UInt64(0)
        let firstAnchorHostTime = firstHostTime + roleOffset
        return MixedTrackCaptureResult(
            formatIdentifier: "lpcm",
            sampleRate: 48_000,
            channelCount: 1,
            firstHostTime: firstAnchorHostTime,
            lastHostTime: firstAnchorHostTime + 48_000,
            durationMilliseconds: 1_000,
            byteCount: byteCount,
            timestampAnchors: [
                TrackTimestampAnchor(
                    hostTime: firstAnchorHostTime,
                    trackFramePosition: 0,
                    sessionTimeMilliseconds: role == .systemAudio ? 1 : 0
                ),
                TrackTimestampAnchor(
                    hostTime: firstAnchorHostTime + 48_000,
                    trackFramePosition: 48_000,
                    sessionTimeMilliseconds: role == .systemAudio ? 1_001 : 1_000
                )
            ],
            gaps: [],
            quality: TrackQualityMetrics(
                peakLevel: 0.5,
                clippedFrameCount: 0,
                silentDurationMilliseconds: 0,
                droppedBufferCount: 0
            )
        )
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
    let processActivityManager: MockProcessActivityManager
    let dictationHotKeyRegistrar: MockHotKeyRegistrar
}

@MainActor
private final class MockProcessActivityManager: ProcessActivityManaging {
    private final class Token: NSObject {}
    private(set) var beginCount = 0
    private(set) var endCount = 0

    func beginUserInitiatedActivity(reason: String) -> NSObjectProtocol {
        beginCount += 1
        return Token()
    }

    func endActivity(_ activity: NSObjectProtocol) {
        endCount += 1
    }
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
    var startDelay: Duration?
    var stopDelay: Duration?
    var resultDuration: TimeInterval = 1
    var sourceMetadata = AudioSourceMetadata.microphoneDefault

    func selectInputDevice(_ deviceID: AudioDeviceID?) {}

    func start() async throws {
        startCount += 1
        if let startDelay { try await Task.sleep(for: startDelay) }
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
            duration: resultDuration,
            sourceMetadata: sourceMetadata
        )
    }
}

private nonisolated final class MockTranscriptionProvider: TranscriptionProvider, @unchecked Sendable {
    private(set) var transcribeCount = 0
    var error: Error?
    var delay: Duration?

    func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionResult {
        transcribeCount += 1
        if let delay { try await Task.sleep(for: delay) }
        if let error { throw error }
        return TranscriptionResult(
            text: "Transcribed text",
            provider: "Test",
            model: "test-model"
        )
    }
}

private nonisolated final class RetryingMockTranscriptionProvider: TranscriptionProvider, @unchecked Sendable {
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

private nonisolated final class SequenceTranscriptionProvider: TranscriptionProvider, @unchecked Sendable {
    private let texts: [String]
    private(set) var transcribeCount = 0
    private(set) var requestCount = 0

    init(texts: [String]) { self.texts = texts }

    func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionResult {
        requestCount += 1
        guard transcribeCount < texts.count else { throw TranscriptionProviderError.emptyTranscript }
        let text = texts[transcribeCount]
        transcribeCount += 1
        return TranscriptionResult(text: text, provider: "Test", model: "test")
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
    private var pressHandler: (@MainActor () -> Void)?
    private var releaseHandler: (@MainActor () -> Void)?

    func register(
        _ configuration: HotKeyConfiguration,
        pressed: @escaping @MainActor () -> Void,
        released: @escaping @MainActor () -> Void
    ) throws {
        pressHandler = pressed
        releaseHandler = released
    }

    func press() { pressHandler?() }
    func release() { releaseHandler?() }

    func unregister() {
        pressHandler = nil
        releaseHandler = nil
    }
}

@MainActor
private final class MockMeetingRecordingConsentPresenter: MeetingRecordingConsentPresenting {
    private(set) var presentationCount = 0
    private var onConfirm: ((Bool) -> Void)?
    private var onCancel: (() -> Void)?

    func present(
        onConfirm: @escaping @MainActor (Bool) -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        presentationCount += 1
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    func confirm(remember: Bool) {
        let action = onConfirm
        clear()
        action?(remember)
    }

    func cancel() {
        let action = onCancel
        clear()
        action?()
    }

    private func clear() {
        onConfirm = nil
        onCancel = nil
    }
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

private struct EmptyCredentialStore: CredentialStoring {
    func readAPIKey() throws -> String? { nil }
    func saveAPIKey(_ value: String) throws {}
    func deleteAPIKey() throws {}
}

private nonisolated final class PassThroughAudioUploadPreparer: AudioUploadPreparing, @unchecked Sendable {
    func prepare(_ sourceURL: URL) async throws -> PreparedAudioUpload {
        PreparedAudioUpload(
            fileURL: sourceURL,
            filename: sourceURL.lastPathComponent,
            mimeType: "audio/m4a",
            temporaryFileURL: nil
        )
    }
}

private nonisolated final class SuccessfulOpenAIURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(
            self,
            didLoad: Data(#"{"text":"Cleanup stays off the response path"}"#.utf8)
        )
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private nonisolated final class SlowRemovalFileManager: FileManager, @unchecked Sendable {
    private let delay: TimeInterval
    private let lock = NSLock()
    private var storedRemovalCount = 0

    init(delay: TimeInterval) {
        self.delay = delay
        super.init()
    }

    var removalCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedRemovalCount
    }

    override func removeItem(at URL: URL) throws {
        Thread.sleep(forTimeInterval: delay)
        try super.removeItem(at: URL)
        lock.lock()
        storedRemovalCount += 1
        lock.unlock()
    }
}

private nonisolated final class LockedTestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }

    func increment() {
        lock.lock()
        storedValue += 1
        lock.unlock()
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

private final class EchoingLayoutMarkerEnhancer: TranscriptEnhancing, @unchecked Sendable {
    private(set) var receivedTexts: [String] = []
    private let outputPrefix: String
    private let outputSuffix: String

    init(outputPrefix: String, outputSuffix: String) {
        self.outputPrefix = outputPrefix
        self.outputSuffix = outputSuffix
    }

    func enhance(_ request: TranscriptEnhancementRequest) async throws -> TranscriptEnhancementResult {
        receivedTexts.append(request.text)
        let markerPattern = #"\[\[FLOWDICTATE_LAYOUT_BREAK_\d+\]\]"#
        let expression = try NSRegularExpression(pattern: markerPattern)
        let match = expression.firstMatch(
            in: request.text,
            range: NSRange(request.text.startIndex..., in: request.text)
        )
        let marker = match
            .flatMap { Range($0.range, in: request.text) }
            .map { String(request.text[$0]) } ?? ""
        return TranscriptEnhancementResult(
            text: "\(outputPrefix) \(marker) \(outputSuffix)",
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
