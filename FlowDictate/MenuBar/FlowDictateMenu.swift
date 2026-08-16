import AppKit
import SwiftUI

struct FlowDictateMenu: View {
    @ObservedObject var coordinator: DictationCoordinator

    var body: some View {
        Text(coordinator.state.title)

        Button(coordinator.primaryActionTitle) {
            coordinator.requestToggle()
        }
        .disabled(coordinator.isProcessing)

        Button("Cancel Dictation") {
            coordinator.requestCancel()
        }
        .disabled(!coordinator.canCancel)

        Divider()

        Menu("Microphone") {
            Button {
                coordinator.selectInputDevice(uid: nil)
            } label: {
                selectionLabel("System Default", selected: coordinator.settings.inputDeviceUID == nil)
            }

            ForEach(coordinator.inputDevices) { device in
                Button {
                    coordinator.selectInputDevice(uid: device.uid)
                } label: {
                    selectionLabel(
                        device.name + (device.isDefault ? " (Default)" : ""),
                        selected: coordinator.settings.inputDeviceUID == device.uid
                    )
                }
            }

            Divider()
            Button("Refresh Devices") {
                coordinator.refreshInputDevices()
            }
        }

        if case .failed(_, let retainedAudioURL?) = coordinator.state {
            Button("Show Retained Recording") {
                coordinator.revealRetainedAudio()
            }
            .help(retainedAudioURL.path)
        }

        SettingsLink {
            Text("Settings…")
        }

        Divider()

        Button("Quit FlowDictate") {
            NSApplication.shared.terminate(nil)
        }
    }

    @ViewBuilder
    private func selectionLabel(_ title: String, selected: Bool) -> some View {
        if selected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}

struct FlowDictateSettingsView: View {
    @ObservedObject var coordinator: DictationCoordinator
    @ObservedObject private var settings: AppSettings
    @ObservedObject private var launchAtLogin: LaunchAtLoginManager
    @State private var apiKey = ""

    init(coordinator: DictationCoordinator) {
        self.coordinator = coordinator
        _settings = ObservedObject(wrappedValue: coordinator.settings)
        _launchAtLogin = ObservedObject(wrappedValue: coordinator.launchAtLogin)
    }

    var body: some View {
        TabView {
            generalSettings
                .tabItem { Label("General", systemImage: "gear") }
            dictationSettings
                .tabItem { Label("Dictation", systemImage: "keyboard") }
            audioSettings
                .tabItem { Label("Audio", systemImage: "mic") }
            transcriptionSettings
                .tabItem { Label("Transcription", systemImage: "text.bubble") }
            advancedSettings
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 560, height: 390)
        .onAppear {
            coordinator.refreshInputDevices()
            coordinator.refreshConfigurationStatus()
            coordinator.refreshPermissionStatus()
            launchAtLogin.refresh()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            coordinator.refreshPermissionStatus()
            coordinator.refreshInputDevices()
            launchAtLogin.refresh()
        }
    }

    private var generalSettings: some View {
        settingsForm {
            Section("Startup") {
                Toggle(
                    "Launch FlowDictate at login",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )
                if let message = launchAtLogin.errorMessage {
                    Text(message).foregroundStyle(.red).font(.caption)
                }
                if let message = launchAtLogin.statusMessage {
                    Text(message).foregroundStyle(.secondary).font(.caption)
                    Button("Open Login Items Settings") {
                        launchAtLogin.openLoginItemsSettings()
                    }
                }
            }

            Section("Permissions") {
                permissionRow(
                    "Microphone",
                    granted: coordinator.microphonePermissionGranted,
                    action: coordinator.openMicrophoneSettings
                )
                permissionRow(
                    "Accessibility",
                    granted: coordinator.accessibilityPermissionGranted,
                    action: coordinator.openAccessibilitySettings
                )
            }
        }
    }

    private var dictationSettings: some View {
        settingsForm {
            Section("Keyboard Shortcuts") {
                ShortcutRecorderView(
                    title: "Start / Stop",
                    configuration: settings.dictationHotKey,
                    onChange: coordinator.setDictationHotKey
                )
                ShortcutRecorderView(
                    title: "Cancel",
                    configuration: settings.cancelHotKey,
                    onChange: coordinator.setCancelHotKey
                )
                Text("Click a shortcut, then press a key combination. Escape cancels recording the shortcut.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var audioSettings: some View {
        settingsForm {
            Section("Input") {
                Picker(
                    "Microphone",
                    selection: Binding(
                        get: { settings.inputDeviceUID },
                        set: { coordinator.selectInputDevice(uid: $0) }
                    )
                ) {
                    Text("System Default").tag(nil as String?)
                    ForEach(coordinator.inputDevices) { device in
                        Text(device.name + (device.isDefault ? " (Default)" : ""))
                            .tag(Optional(device.uid))
                    }
                }

                HStack {
                    Text("Input level")
                    ProgressView(value: coordinator.audioLevel)
                    Text("\(Int(coordinator.audioLevel * 100))%")
                        .monospacedDigit()
                        .frame(width: 42, alignment: .trailing)
                }

                Button("Refresh Devices") {
                    coordinator.refreshInputDevices()
                }
            }
        }
    }

    private var transcriptionSettings: some View {
        settingsForm {
            Section("OpenAI") {
                HStack {
                    Text("API key")
                    Spacer()
                    Label(
                        coordinator.apiKeyConfigured ? "Configured" : "Missing",
                        systemImage: coordinator.apiKeyConfigured
                            ? "checkmark.circle.fill"
                            : "xmark.circle"
                    )
                    .foregroundStyle(coordinator.apiKeyConfigured ? .green : .secondary)
                }

                SecureField("New API key", text: $apiKey)
                    .textContentType(.password)

                HStack {
                    Button("Save in Keychain") {
                        coordinator.saveAPIKey(apiKey)
                        apiKey = ""
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Remove from Keychain", role: .destructive) {
                        coordinator.deleteAPIKey()
                    }
                }
            }

            Section("Recognition") {
                TextField("Model", text: $settings.transcriptionModel)
                Picker("Language", selection: $settings.transcriptionLanguage) {
                    ForEach(TranscriptionLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
            }
        }
    }

    private var advancedSettings: some View {
        settingsForm {
            Section("Text Insertion") {
                HStack {
                    Text("Clipboard restore delay")
                    Slider(value: $settings.clipboardRestoreDelay, in: 0.3...2.0, step: 0.1)
                    Text(settings.clipboardRestoreDelay, format: .number.precision(.fractionLength(1)))
                        .monospacedDigit()
                    Text("s")
                }
            }

            Section("Local Audio") {
                Text("Recordings are retained locally. History and retention controls follow in Phase 2.")
                    .foregroundStyle(.secondary)
                Button("Show Recordings Folder") {
                    coordinator.revealRecordingsFolder()
                }
            }
        }
    }

    private func settingsForm<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        Form(content: content)
            .formStyle(.grouped)
            .padding()
    }

    private func permissionRow(
        _ title: String,
        granted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Label(
                granted ? "Allowed" : "Required",
                systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.circle"
            )
            .foregroundStyle(granted ? .green : .orange)
            Button("Open System Settings", action: action)
        }
    }
}
