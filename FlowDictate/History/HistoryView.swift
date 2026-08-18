import AppKit
import SwiftUI

@MainActor
final class HistoryWindowController: NSWindowController {
    init(coordinator: DictationCoordinator) {
        let window = NSWindow(contentViewController: NSHostingController(rootView: HistoryView(coordinator: coordinator)))
        window.title = "FlowDictate History"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 900, height: 560))
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}

struct HistoryView: View {
    @ObservedObject var coordinator: DictationCoordinator
    @State private var selection: UUID?
    @State private var searchText = ""
    @State private var filter: HistoryFilter = .all

    enum HistoryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case successful = "Successful"
        case failed = "Needs Attention"
        case cancelled = "Cancelled"
        var id: String { rawValue }
    }

    private var records: [DictationRecord] {
        coordinator.historyRecords.filter { record in
            let matchesText = searchText.isEmpty
                || record.previewText.localizedCaseInsensitiveContains(searchText)
                || record.targetApplicationName?.localizedCaseInsensitiveContains(searchText) == true
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .successful: matchesFilter = record.status == .completed || record.status == .transcribed
            case .failed: matchesFilter = [.transcriptionFailed, .insertionFailed, .insertionUnknown, .recovered, .audioMissing, .audioCorrupt].contains(record.status)
            case .cancelled: matchesFilter = record.status == .cancelled
            }
            return matchesText && matchesFilter
        }
    }

    private var selectedRecord: DictationRecord? {
        coordinator.historyRecords.first { $0.id == selection }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 8) {
                Picker("Filter", selection: $filter) {
                    ForEach(HistoryFilter.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).padding(.horizontal)
                List(records, selection: $selection) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label(record.status.title, systemImage: record.status.symbolName)
                                .font(.caption).foregroundStyle(statusColor(record.status))
                            Spacer()
                            Text(record.createdAt, style: .time).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(record.previewText).lineLimit(2)
                        HStack {
                            Text(record.createdAt, style: .date)
                            if let app = record.targetApplicationName { Text("• \(app)") }
                            Text("• \(record.duration, format: .number.precision(.fractionLength(1))) s")
                        }.font(.caption).foregroundStyle(.secondary)
                    }.tag(record.id)
                }
                .searchable(text: $searchText, prompt: "Search transcripts and apps")
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 360)
        } detail: {
            if let record = selectedRecord { detail(record) }
            else { ContentUnavailableView("Select a Dictation", systemImage: "waveform") }
        }
        .task { await coordinator.refreshHistory() }
    }

    private func detail(_ record: DictationRecord) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label(record.status.title, systemImage: record.status.symbolName)
                    .font(.title2.bold()).foregroundStyle(statusColor(record.status))
                if let error = record.errorMessage {
                    Text(error).foregroundStyle(.red).padding(10)
                        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
                GroupBox("Transcript") {
                    Text(record.finalText ?? record.originalTranscript ?? "No transcript yet.")
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(4)
                }
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                    GridRow { Text("Recorded").foregroundStyle(.secondary); Text(record.createdAt.formatted()) }
                    GridRow { Text("Duration").foregroundStyle(.secondary); Text("\(record.duration, format: .number.precision(.fractionLength(1))) seconds") }
                    GridRow { Text("Provider").foregroundStyle(.secondary); Text(record.providerID.isEmpty ? "—" : record.providerID) }
                    GridRow { Text("Model").foregroundStyle(.secondary); Text(record.modelID.isEmpty ? "—" : record.modelID) }
                    GridRow { Text("Attempts").foregroundStyle(.secondary); Text("\(record.attemptCount)") }
                }
                HStack {
                    Button("Play Audio") { coordinator.playAudio(for: record) }.disabled(record.audioFileSize == 0)
                    Button("Show in Finder") { coordinator.revealAudio(for: record) }.disabled(record.audioFileSize == 0)
                    Button("Copy Text") { coordinator.copyText(from: record) }.disabled(!record.canInsert)
                    Button("Export Text…") { coordinator.exportText(from: record) }.disabled(!record.canInsert)
                    Button("Insert at Cursor") { coordinator.reinsert(record) }.disabled(!record.canInsert)
                    Button("Retry Transcription") { coordinator.retryTranscription(record) }
                        .disabled(!record.canRetry || coordinator.retryingRecordIDs.contains(record.id))
                }
                Divider()
                Button("Delete History Entry", role: .destructive) {
                    coordinator.deleteHistoryRecord(record, deleteAudio: false); selection = nil
                }
            }.padding(24)
        }
    }

    private func statusColor(_ status: DictationRecordStatus) -> Color {
        switch status {
        case .completed: .green
        case .transcribing, .inserting: .blue
        case .recorded, .transcribed: .secondary
        case .cancelled: .secondary
        default: .orange
        }
    }
}
