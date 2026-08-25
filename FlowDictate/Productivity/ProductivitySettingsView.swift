import SwiftUI

struct ProductivitySettingsView: View {
    @ObservedObject var coordinator: DictationCoordinator
    @ObservedObject private var settings: AppSettings

    init(coordinator: DictationCoordinator) {
        self.coordinator = coordinator
        _settings = ObservedObject(wrappedValue: coordinator.settings)
    }

    var body: some View {
        Form {
            Section("Local Usage Statistics") {
                Toggle("Show usage statistics", isOn: $settings.showUsageStatistics)
                if settings.showUsageStatistics {
                    let statistics = coordinator.usageStatistics
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                        metric("Successful dictations", "\(statistics.successfulDictations)")
                        metric("Dictated words", "\(statistics.wordCount)")
                        metric("Recording time", duration(statistics.totalDuration))
                        metric("Estimated time saved", duration(statistics.estimatedSecondsSaved))
                        metric("Retries", "\(statistics.retryCount)")
                    }
                    HStack {
                        Text("Typing speed")
                        Slider(value: $settings.typingWordsPerMinute, in: 10...120, step: 5)
                        Text("\(Int(settings.typingWordsPerMinute)) wpm")
                            .monospacedDigit().frame(width: 70)
                    }
                    Text("Statistics are calculated only from your local History and are never uploaded.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Community Updates") {
                Toggle("Check for new stable releases once per day", isOn: $settings.updateCheckEnabled)
                Button("Check Now") {
                    Task { await coordinator.checkForUpdates() }
                }
                .disabled(coordinator.isCheckingForUpdates)
                if let release = coordinator.availableRelease {
                    LabeledContent("Available", value: release.name)
                    if !release.summary.isEmpty {
                        Text(release.summary).font(.caption).foregroundStyle(.secondary)
                    }
                    Button("Open GitHub Release Page") { coordinator.openAvailableRelease() }
                }
                Text("FlowDictate never downloads or installs an update automatically.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func metric(_ label: String, _ value: String) -> some View {
        GridRow { Text(label).foregroundStyle(.secondary); Text(value).monospacedDigit() }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}
