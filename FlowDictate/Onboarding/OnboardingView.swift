import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController {
    init(coordinator: DictationCoordinator) {
        let rootView = OnboardingView(coordinator: coordinator)
        let window = NSWindow(contentViewController: NSHostingController(rootView: rootView))
        window.title = "Welcome to FlowDictate"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 680, height: 540))
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}

struct OnboardingView: View {
    @ObservedObject var coordinator: DictationCoordinator
    @State private var step = 0
    @State private var apiKey = ""
    @State private var validating = false

    private let steps = ["Welcome", "Storage", "API Key", "Permissions", "Shortcuts", "Ready"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Color.accentColor : Color.secondary.opacity(0.2))
                        .frame(height: 5)
                }
            }
            .padding()

            Group {
                switch step {
                case 0: welcome
                case 1: storage
                case 2: credentials
                case 3: permissions
                case 4: shortcuts
                default: ready
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(32)

            Divider()
            HStack {
                Button("Back") { step -= 1 }.disabled(step == 0)
                Spacer()
                Text(coordinator.setupMessage ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
                if step < steps.count - 1 {
                    Button("Continue") { step += 1 }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!canContinue)
                } else {
                    Button("Start FlowDictate") { coordinator.completeOnboarding() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!coordinator.apiKeyConfigured || !coordinator.recordingLocationConfigured)
                }
            }
            .padding()
        }
        .onAppear {
            coordinator.refreshConfigurationStatus()
            coordinator.refreshPermissionStatus()
        }
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            Image(systemName: "waveform.circle.fill").font(.system(size: 72)).foregroundStyle(.tint)
            Text("Welcome to FlowDictate").font(.largeTitle.bold())
            Text("Dictate into any app from the menu bar. Your recordings and history stay on this Mac; audio is sent to OpenAI only when you request transcription.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 520)
        }
    }

    private var storage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Choose where recordings are stored", systemImage: "folder")
                .font(.title2.bold())
            Text("The recommended location is a Recordings folder inside Documents. macOS asks you to confirm the folder once so FlowDictate can keep secure write access.")
                .foregroundStyle(.secondary)
            statusRow("Recordings folder", value: coordinator.recordingLocationPath ?? "Not configured",
                      ready: coordinator.recordingLocationConfigured)
            HStack {
                Button("Use Documents/Recordings…") { coordinator.chooseRecordingDirectory(recommended: true) }
                Button("Choose Another Folder…") { coordinator.chooseRecordingDirectory(recommended: false) }
            }
            if coordinator.recordingLocationConfigured {
                Button("Import Phase 1 Recordings") { coordinator.migrateLegacyRecordings() }
            }
        }
    }

    private var credentials: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Connect OpenAI", systemImage: "key.fill").font(.title2.bold())
            Text("Each installation uses the owner's API key. It is stored only in macOS Keychain and is never included in recordings, history, logs, or exports.")
                .foregroundStyle(.secondary)
            statusRow("API key", value: coordinator.apiKeyConfigured ? "Configured" : "Missing",
                      ready: coordinator.apiKeyConfigured)
            SecureField("OpenAI API key", text: $apiKey)
                .textContentType(.password)
            Button(validating ? "Checking…" : "Verify and Save Securely") {
                validating = true
                Task {
                    if await coordinator.validateAndSaveAPIKey(apiKey) { apiKey = "" }
                    validating = false
                }
            }
            .disabled(validating || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Allow system access", systemImage: "checkmark.shield.fill").font(.title2.bold())
            Text("Microphone records your voice. Speech Recognition can show an optional local live preview. Accessibility lets FlowDictate paste the final transcript.")
                .foregroundStyle(.secondary)
            statusRow("Microphone", value: coordinator.microphonePermissionGranted ? "Allowed" : "Required",
                      ready: coordinator.microphonePermissionGranted)
            statusRow("Accessibility", value: coordinator.accessibilityPermissionGranted ? "Allowed" : "Required",
                      ready: coordinator.accessibilityPermissionGranted)
            statusRow(
                "Speech Recognition (optional)",
                value: coordinator.speechPermissionState.title,
                ready: coordinator.speechPermissionState == .authorized
                    || !coordinator.settings.livePreviewEnabled
            )
            Toggle(
                "Show local Live Preview while recording",
                isOn: Binding(
                    get: { coordinator.settings.livePreviewEnabled },
                    set: { coordinator.settings.livePreviewEnabled = $0 }
                )
            )
            HStack {
                Button("Request Permissions") { coordinator.requestRequiredPermissions() }
                if coordinator.settings.livePreviewEnabled
                    && coordinator.speechPermissionState == .notDetermined {
                    Button("Allow Live Preview") {
                        coordinator.requestSpeechRecognitionPermission()
                    }
                } else if coordinator.settings.livePreviewEnabled
                    && coordinator.speechPermissionState != .authorized {
                    Button("Speech Recognition Settings") {
                        coordinator.openSpeechRecognitionSettings()
                    }
                }
                Button("Microphone Settings") { coordinator.openMicrophoneSettings() }
                Button("Accessibility Settings") { coordinator.openAccessibilitySettings() }
            }
        }
    }

    private var shortcuts: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Keyboard shortcuts", systemImage: "keyboard").font(.title2.bold())
            ShortcutRecorderView(title: "Start / Stop", configuration: coordinator.settings.dictationHotKey,
                                 onChange: coordinator.setDictationHotKey)
            ShortcutRecorderView(title: "Cancel", configuration: coordinator.settings.cancelHotKey,
                                 onChange: coordinator.setCancelHotKey)
            ShortcutRecorderView(title: "Restore Last", configuration: coordinator.settings.restoreHotKey,
                                 onChange: coordinator.setRestoreHotKey)
            Text("You can change these later in Settings → Dictation.").foregroundStyle(.secondary)
        }
    }

    private var ready: some View {
        VStack(spacing: 18) {
            let prerequisitesReady = coordinator.apiKeyConfigured && coordinator.recordingLocationConfigured
            Image(systemName: prerequisitesReady ? "checkmark.circle.fill" : "exclamationmark.triangle")
                .font(.system(size: 72)).foregroundStyle(prerequisitesReady ? .green : .orange)
            Text(prerequisitesReady ? "FlowDictate is ready" : "Setup needs attention")
                .font(.largeTitle.bold())
            Text("Place the cursor in another app and press \(coordinator.settings.dictationHotKey.displayName) to begin.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Toggle("Launch FlowDictate at login", isOn: Binding(
                get: { coordinator.launchAtLogin.isEnabled },
                set: { coordinator.launchAtLogin.setEnabled($0) }
            ))
            .frame(width: 280)
        }
    }

    private var canContinue: Bool {
        switch step {
        case 1: coordinator.recordingLocationConfigured
        case 2: coordinator.apiKeyConfigured
        default: true
        }
    }

    private func statusRow(_ title: String, value: String, ready: Bool) -> some View {
        HStack {
            Image(systemName: ready ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(ready ? .green : .orange)
            Text(title).fontWeight(.medium)
            Spacer()
            Text(value).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
        }
        .padding(12).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}
