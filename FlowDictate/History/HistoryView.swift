import AppKit
import SwiftUI

@MainActor
final class HistoryWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?

    init(coordinator: DictationCoordinator) {
        let window = NSWindow(contentViewController: NSHostingController(rootView: HistoryView(coordinator: coordinator)))
        window.title = "FlowDictate History"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 900, height: 560))
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
    }

    func windowWillClose(_ notification: Notification) { onClose?() }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}

struct HistoryView: View {
    let coordinator: DictationCoordinator
    @State private var selection: UUID?
    @State private var searchText = ""
    @State private var filter: HistoryFilter = .all
    @State private var historyRecords: [DictationRecord]
    @State private var retryingRecordIDs: Set<UUID>
    @State private var retryingEnhancementRecordIDs: Set<UUID>
    @State private var writingStyles: [WritingStyleProfile]

    init(coordinator: DictationCoordinator) {
        self.coordinator = coordinator
        _historyRecords = State(initialValue: coordinator.historyRecords)
        _retryingRecordIDs = State(initialValue: coordinator.retryingRecordIDs)
        _retryingEnhancementRecordIDs = State(initialValue: coordinator.retryingEnhancementRecordIDs)
        _writingStyles = State(initialValue: coordinator.writingStyles)
    }

    enum HistoryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case successful = "Successful"
        case failed = "Needs Attention"
        case cancelled = "Cancelled"
        var id: String { rawValue }
    }

    private var records: [DictationRecord] {
        historyRecords.filter { record in
            let matchesText = searchText.isEmpty
                || record.previewText.localizedCaseInsensitiveContains(searchText)
                || record.targetApplicationName?.localizedCaseInsensitiveContains(searchText) == true
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .successful: matchesFilter = record.status == .completed || record.status == .transcribed
            case .failed:
                matchesFilter = record.processingStatus == .enhancementFailed
                    || [.transcriptionFailed, .insertionFailed, .insertionUnknown, .recovered, .audioMissing, .audioCorrupt].contains(record.status)
            case .cancelled: matchesFilter = record.status == .cancelled
            }
            return matchesText && matchesFilter
        }
    }

    private var selectedRecord: DictationRecord? {
        historyRecords.first { $0.id == selection }
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
        .onReceive(coordinator.$historyRecords) { historyRecords = $0 }
        .onReceive(coordinator.$retryingRecordIDs) { retryingRecordIDs = $0 }
        .onReceive(coordinator.$retryingEnhancementRecordIDs) { retryingEnhancementRecordIDs = $0 }
        .onReceive(coordinator.$writingStyles) { writingStyles = $0 }
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
                if let error = record.enhancementErrorMessage {
                    VStack(alignment: .leading, spacing: 5) {
                        Label(
                            record.processingStatus == .enhancementFailed
                                ? "Smart Dictation needs attention"
                                : "Smart Dictation fallback used",
                            systemImage: "sparkles"
                        )
                            .font(.headline).foregroundStyle(.indigo)
                        Text(error).foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.indigo.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                }
                if let total = record.transcriptionSegmentCount, total > 0,
                   record.status != .completed {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Long recording", systemImage: "square.stack.3d.up")
                            .font(.headline)
                        ProgressView(
                            value: Double(record.completedTranscriptionSegmentCount),
                            total: Double(total)
                        )
                        Text("\(record.completedTranscriptionSegmentCount) of \(total) segments completed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                }

                transcriptStages(record)

                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                    GridRow { Text("Recorded").foregroundStyle(.secondary); Text(record.createdAt.formatted()) }
                    GridRow { Text("Duration").foregroundStyle(.secondary); Text("\(record.duration, format: .number.precision(.fractionLength(1))) seconds") }
                    GridRow {
                        Text("Audio source").foregroundStyle(.secondary)
                        Label(record.audioSource.shortTitle, systemImage: record.audioSource.symbolName)
                    }
                    if record.audioSampleRate > 0 {
                        GridRow {
                            Text("Audio format").foregroundStyle(.secondary)
                            Text("\(Int(record.audioSampleRate)) Hz · \(record.audioChannelCount) ch")
                        }
                    }
                    GridRow { Text("Provider").foregroundStyle(.secondary); Text(record.providerID.isEmpty ? "—" : record.providerID) }
                    GridRow { Text("Model").foregroundStyle(.secondary); Text(record.modelID.isEmpty ? "—" : record.modelID) }
                    GridRow { Text("Attempts").foregroundStyle(.secondary); Text("\(record.attemptCount)") }
                    if let total = record.transcriptionSegmentCount {
                        GridRow {
                            Text("Segments").foregroundStyle(.secondary)
                            Text("\(record.completedTranscriptionSegmentCount) / \(total)")
                        }
                    }
                    GridRow {
                        Text("Writing style").foregroundStyle(.secondary)
                        Text(styleName(for: record))
                    }
                    GridRow {
                        Text("Dictionary changes").foregroundStyle(.secondary)
                        Text("\(record.dictionaryReplacementCount)")
                    }
                    if let model = record.enhancementModelID {
                        GridRow { Text("Enhancement model").foregroundStyle(.secondary); Text(model) }
                        GridRow { Text("Enhancement attempts").foregroundStyle(.secondary); Text("\(record.enhancementAttemptCount)") }
                    }
                    if let fallback = record.enhancementFallback {
                        GridRow { Text("Enhancement fallback").foregroundStyle(.secondary); Text(fallback.title) }
                    }
                }
                HStack(alignment: .top) {
                    Button("Play Audio") { coordinator.playAudio(for: record) }.disabled(record.audioFileSize == 0)
                    Button("Show in Finder") { coordinator.revealAudio(for: record) }.disabled(record.audioFileSize == 0)
                    Menu("Copy") {
                        Button("Copy Original") { coordinator.copyOriginalText(from: record) }
                            .disabled(record.originalTranscript == nil)
                        Button("Copy Final") { coordinator.copyText(from: record) }
                            .disabled(!record.canInsert)
                    }
                    Button("Export Text…") { coordinator.exportText(from: record) }.disabled(!record.canInsert)
                    Button("Insert at Cursor") { coordinator.reinsert(record) }.disabled(!record.canInsert)
                    Button(record.transcriptionSessionID == nil ? "Retry Transcription" : "Continue Transcription") {
                        coordinator.retryTranscription(record)
                    }
                        .disabled(!record.canRetry || retryingRecordIDs.contains(record.id))
                }
                HStack {
                    if record.processingStatus == .enhancementFailed {
                        Button("Use Local Text") { coordinator.insertLocallyProcessedText(record) }
                        Button("Use Original") { coordinator.insertOriginalText(record) }
                        Button("Retry Enhancement") { coordinator.retryEnhancement(record) }
                            .disabled(!record.canRetryEnhancement || retryingEnhancementRecordIDs.contains(record.id))
                    }
                    Menu("Process with Style") {
                        ForEach(writingStyles.filter(\.isEnabled)) { style in
                            Button(style.name) { coordinator.reprocess(record, writingStyleID: style.id) }
                        }
                    }
                    .disabled(record.originalTranscript == nil)
                    Button("Reapply Local Rules") { coordinator.reapplyLocalRules(record) }
                        .disabled(record.originalTranscript == nil)
                }
                Divider()
                Button("Delete History Entry", role: .destructive) {
                    coordinator.deleteHistoryRecord(record, deleteAudio: false); selection = nil
                }
            }.padding(24)
        }
    }

    private func transcriptStages(_ record: DictationRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if record.hasPartialTranscript {
                transcriptBox("RECOVERED PARTIAL", text: record.partialTranscript)
            }
            transcriptBox("ORIGINAL", text: record.originalTranscript)
            if let formatted = record.formattedTranscript, formatted != record.originalTranscript {
                transcriptBox("FORMATTED", text: formatted)
            }
            if let dictionary = record.dictionaryTranscript, dictionary != record.formattedTranscript {
                transcriptBox("DICTIONARY", text: dictionary)
            }
            transcriptBox("FINAL", text: record.finalText)
        }
    }

    private func transcriptBox(_ label: String, text: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(label == "FINAL" ? Color.indigo : Color.secondary)
            Text(text ?? "No text available.")
                .foregroundStyle(text == nil ? .secondary : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            label == "FINAL" ? Color.indigo.opacity(0.06) : Color.secondary.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 9)
        )
    }

    private func styleName(for record: DictationRecord) -> String {
        writingStyles.first { $0.id == record.writingStyleID }?.name
            ?? (record.writingStyleID == BuiltInWritingStyles.originalID ? "Original" : "Unavailable style")
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
