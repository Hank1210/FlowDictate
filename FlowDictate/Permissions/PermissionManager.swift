import AVFoundation
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

struct PermissionManager {
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
}
