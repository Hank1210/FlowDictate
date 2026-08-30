import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation
import OSLog

enum TextInsertionError: LocalizedError {
    case targetUnavailable
    case clipboardWriteFailed
    case keyboardEventCreationFailed

    var errorDescription: String? {
        switch self {
        case .targetUnavailable:
            "The target application is no longer available. Place the cursor in a running application and try again."
        case .clipboardWriteFailed:
            "The transcript could not be written to the clipboard."
        case .keyboardEventCreationFailed:
            "The paste keyboard event could not be created."
        }
    }
}

@MainActor
protocol TextInserting: AnyObject {
    func insert(_ text: String, into target: FocusTarget) async throws
}

@MainActor
final class PasteboardTextInserter: TextInserting {
    private let pasteboard: NSPasteboard
    private var restoreDelay: Duration
    private var pendingRestorationTask: Task<Void, Never>?
    private var pendingOriginalSnapshot: PasteboardSnapshot?
    private var pendingInjectedChangeCount: Int?

    convenience init() {
        self.init(pasteboard: .general, restoreDelay: .milliseconds(600))
    }

    init(pasteboard: NSPasteboard, restoreDelay: Duration) {
        self.pasteboard = pasteboard
        self.restoreDelay = restoreDelay
    }

    func updateRestoreDelay(_ restoreDelay: Duration) {
        self.restoreDelay = restoreDelay
    }

    func insert(_ text: String, into target: FocusTarget) async throws {
        await waitForModifierRelease()
        guard await target.activate() else { throw TextInsertionError.targetUnavailable }

        pendingRestorationTask?.cancel()
        let snapshot: PasteboardSnapshot
        if let pendingOriginalSnapshot,
           pendingInjectedChangeCount == pasteboard.changeCount {
            snapshot = pendingOriginalSnapshot
        } else {
            snapshot = PasteboardSnapshot.capture(from: pasteboard)
        }
        pendingRestorationTask = nil
        pendingOriginalSnapshot = nil
        pendingInjectedChangeCount = nil

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            snapshot.restore(to: pasteboard)
            throw TextInsertionError.clipboardWriteFailed
        }
        let injectedChangeCount = pasteboard.changeCount

        do {
            try postPasteShortcut()
        } catch {
            snapshot.restore(to: pasteboard)
            throw error
        }

        pendingOriginalSnapshot = snapshot
        pendingInjectedChangeCount = injectedChangeCount
        let delay = restoreDelay
        pendingRestorationTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.restoreClipboardIfUnchanged(expectedChangeCount: injectedChangeCount)
        }
        FlowLogger.insertion.info("Transcript pasted; clipboard restoration scheduled")
    }

    private func restoreClipboardIfUnchanged(expectedChangeCount: Int) {
        defer {
            pendingRestorationTask = nil
            pendingOriginalSnapshot = nil
            pendingInjectedChangeCount = nil
        }
        guard pasteboard.changeCount == expectedChangeCount else {
            FlowLogger.insertion.notice(
                "Clipboard changed after paste; skipped restoration to avoid overwriting newer content"
            )
            return
        }
        guard let snapshot = pendingOriginalSnapshot,
              snapshot.restore(to: pasteboard) else {
            FlowLogger.insertion.error("Clipboard restoration returned false")
            return
        }
        FlowLogger.insertion.info("Clipboard restored after completed paste")
    }

    private func waitForModifierRelease(timeout: Duration = .seconds(2)) async {
        let relevantFlags: CGEventFlags = [
            .maskAlternate,
            .maskCommand,
            .maskControl,
            .maskShift,
            .maskSecondaryFn
        ]
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while clock.now < deadline {
            let flags = CGEventSource.flagsState(.combinedSessionState)
            if flags.intersection(relevantFlags).isEmpty {
                return
            }
            try? await Task.sleep(for: .milliseconds(25))
        }
    }

    private func postPasteShortcut() throws {
        guard
            let source = CGEventSource(stateID: .combinedSessionState),
            let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: true
            ),
            let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: false
            )
        else {
            throw TextInsertionError.keyboardEventCreationFailed
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
