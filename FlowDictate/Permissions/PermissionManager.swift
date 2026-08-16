import AVFoundation
import AppKit
import CoreGraphics
import Foundation

enum FlowPermissionError: LocalizedError {
    case microphoneDenied
    case eventPostingDenied

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            "Microphone access is required. Enable FlowDictate in System Settings → Privacy & Security → Microphone."
        case .eventPostingDenied:
            "Accessibility access is required to paste text. Enable FlowDictate in System Settings → Privacy & Security → Accessibility, then try again."
        }
    }
}

@MainActor
protocol PermissionManaging {
    func ensureMicrophoneAccess() async throws
    func ensureEventPostingAccess() throws
    var hasMicrophoneAccess: Bool { get }
    var hasEventPostingAccess: Bool { get }
    func openMicrophoneSettings()
    func openAccessibilitySettings()
}

struct PermissionManager: PermissionManaging {
    func ensureMicrophoneAccess() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .audio) else {
                throw FlowPermissionError.microphoneDenied
            }
        case .denied, .restricted:
            throw FlowPermissionError.microphoneDenied
        @unknown default:
            throw FlowPermissionError.microphoneDenied
        }
    }

    @MainActor
    func ensureEventPostingAccess() throws {
        guard CGPreflightPostEventAccess() || CGRequestPostEventAccess() else {
            throw FlowPermissionError.eventPostingDenied
        }
    }

    var hasMicrophoneAccess: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    var hasEventPostingAccess: Bool {
        CGPreflightPostEventAccess()
    }

    func openMicrophoneSettings() {
        openPrivacySettings(anchor: "Privacy_Microphone")
    }

    func openAccessibilitySettings() {
        openPrivacySettings(anchor: "Privacy_Accessibility")
    }

    private func openPrivacySettings(anchor: String) {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
