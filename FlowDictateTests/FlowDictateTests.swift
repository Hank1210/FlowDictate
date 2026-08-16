//
//  FlowDictateTests.swift
//  FlowDictateTests
//
//  Created by Frank Euler on 16.08.26.
//

import AppKit
import Foundation
import Testing
@testable import FlowDictate

struct FlowDictateTests {
    @Test func dictationStateStartRules() {
        #expect(DictationState.idle.acceptsStart)
        #expect(DictationState.failed(message: "test", retainedAudioURL: nil).acceptsStart)
        #expect(!DictationState.recording.acceptsStart)
        #expect(!DictationState.transcribing.acceptsStart)
        #expect(!DictationState.inserting.acceptsStart)
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
    @Test func shortcutSelectionPersists() {
        let suiteName = "FlowDictateTests-\(UUID())"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = ShortcutSettings(defaults: defaults)
        settings.select(.optionD)
        let restored = ShortcutSettings(defaults: defaults)

        #expect(restored.selected == .optionD)
    }
}
