import AppKit
import SwiftUI

struct Phase0Menu: View {
    @ObservedObject var coordinator: DictationCoordinator

    var body: some View {
        Text(coordinator.state.title)

        Button(coordinator.primaryActionTitle) {
            coordinator.requestToggle()
        }
        .disabled(isProcessing)

        if case .failed(_, let retainedAudioURL?) = coordinator.state {
            Button("Show Retained Recording") {
                coordinator.revealRetainedAudio()
            }
            .help(retainedAudioURL.path)
        }

        Divider()

        SettingsLink {
            Text("Phase 0 Settings…")
        }

        Divider()

        Button("Quit FlowDictate") {
            NSApplication.shared.terminate(nil)
        }
    }

    private var isProcessing: Bool {
        switch coordinator.state {
        case .transcribing, .inserting:
            true
        case .idle, .recording, .failed:
            false
        }
    }
}

struct Phase0SettingsView: View {
    @ObservedObject var coordinator: DictationCoordinator

    var body: some View {
        Form {
            Section("Dictation Shortcut") {
                Picker(
                    "Shortcut",
                    selection: Binding(
                        get: { coordinator.selectedHotKey.id },
                        set: { coordinator.selectHotKey(id: $0) }
                    )
                ) {
                    ForEach(coordinator.availableHotKeys) { configuration in
                        Text(configuration.displayName).tag(configuration.id)
                    }
                }
            }

            Section("Phase 0 Readiness") {
                readinessRow("OpenAI API key", ready: coordinator.apiKeyConfigured)
                readinessRow("Microphone", ready: coordinator.microphonePermissionGranted)
                readinessRow("Accessibility", ready: coordinator.accessibilityPermissionGranted)
            }

            Text("Set OPENAI_API_KEY in the local scheme under Run → Arguments → Environment Variables, not in Arguments Passed On Launch. Permissions are requested when dictation starts.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 300)
        .padding()
    }

    private func readinessRow(_ title: String, ready: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: ready ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(ready ? .green : .secondary)
        }
    }
}
