import AppKit
import Combine
import SwiftUI

enum OverlayStatus: Equatable {
    case recording
    case finalizing
    case processing
    case success(message: String)
    case error(String)

    var title: String {
        switch self {
        case .recording: "Recording"
        case .finalizing: "Finalizing…"
        case .processing: "Processing"
        case .success: "Inserted"
        case .error: "Dictation failed"
        }
    }

    var symbolName: String {
        switch self {
        case .recording: "mic.fill"
        case .finalizing: "ellipsis.circle"
        case .processing: "ellipsis"
        case .success: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }
}

@MainActor
protocol RecordingOverlayPresenting: AnyObject {
    func show(status: OverlayStatus, level: Float, reposition: Bool)
    func updateLevel(_ level: Float)
    func updatePreview(_ state: LivePreviewState)
    func updateSource(_ source: RecordingAudioSource)
    func configure(size: OverlaySize, position: OverlayPosition)
    func hide()
}

extension RecordingOverlayPresenting {
    func show(status: OverlayStatus, level: Float = 0, reposition: Bool = false) {
        show(status: status, level: level, reposition: reposition)
    }

    func updateSource(_ source: RecordingAudioSource) {}
}

@MainActor
private final class RecordingOverlayModel: ObservableObject {
    @Published var status: OverlayStatus = .recording
    @Published var level: Float = 0
    @Published var previewState: LivePreviewState = .disabled
    @Published var size: OverlaySize = .standard
    @Published var source: RecordingAudioSource = .microphone

    var usesSingleRowLayout: Bool {
        size == .compact || status != .recording
    }

    var contentSize: CGSize {
        let configuredSize: CGSize = switch size {
        case .compact: CGSize(width: 320, height: 60)
        case .standard: CGSize(width: 390, height: 136)
        case .expanded: CGSize(width: 500, height: 236)
        }
        guard status != .recording else { return configuredSize }
        if case .error = status {
            return CGSize(width: min(configuredSize.width, 390), height: 76)
        }
        return CGSize(width: min(configuredSize.width, 390), height: 60)
    }
}

@MainActor
final class RecordingOverlayController: RecordingOverlayPresenting {
    private let model = RecordingOverlayModel()
    private var panel: NonActivatingPanel?
    private var successHideWorkItem: DispatchWorkItem?
    private var overlayPosition: OverlayPosition = .bottomTrailing
    private var currentScreen: NSScreen?

    func show(status: OverlayStatus, level: Float = 0, reposition: Bool = false) {
        successHideWorkItem?.cancel()
        model.status = status
        model.level = level
        let panel = panel ?? makePanel()
        resize(panel)
        if reposition || !panel.isVisible {
            let screen = screenContainingMouse()
            currentScreen = screen
            position(panel, on: screen)
        }
        panel.orderFrontRegardless()
        if case .success = status {
            let workItem = DispatchWorkItem { [weak panel] in
                panel?.orderOut(nil)
            }
            successHideWorkItem = workItem
            // Defensive fallback: the coordinator normally hides after 0.9 seconds.
            // Keep a completed overlay from ever remaining on screen indefinitely.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: workItem)
        }
    }

    func updateLevel(_ level: Float) {
        model.level = level
    }

    func updatePreview(_ state: LivePreviewState) {
        model.previewState = state
    }

    func updateSource(_ source: RecordingAudioSource) {
        model.source = source
    }

    func configure(size: OverlaySize, position: OverlayPosition) {
        model.size = size
        overlayPosition = position
        guard let panel else { return }
        resize(panel)
        self.position(panel, on: currentScreen ?? screenContainingMouse())
    }

    func hide() {
        successHideWorkItem?.cancel()
        successHideWorkItem = nil
        panel?.orderOut(nil)
        model.level = 0
        model.previewState = .disabled
    }

    private func makePanel() -> NonActivatingPanel {
        let panel = NonActivatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 250, height: 72),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: RecordingOverlayView(model: model))
        self.panel = panel
        return panel
    }

    private func screenContainingMouse() -> NSScreen {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(location, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    private func position(_ panel: NSPanel, on screen: NSScreen) {
        let visibleFrame = screen.visibleFrame
        let origin: NSPoint
        switch overlayPosition {
        case .bottomTrailing:
            origin = NSPoint(
                x: visibleFrame.maxX - panel.frame.width - 24,
                y: visibleFrame.minY + 24
            )
        case .bottomCenter:
            origin = NSPoint(
                x: visibleFrame.midX - panel.frame.width / 2,
                y: visibleFrame.minY + 24
            )
        case .menuBarTrailing:
            origin = NSPoint(
                x: visibleFrame.maxX - panel.frame.width - 24,
                y: visibleFrame.maxY - panel.frame.height - 24
            )
        }
        panel.setFrameOrigin(origin)
    }

    private func resize(_ panel: NSPanel) {
        panel.setContentSize(model.contentSize)
    }
}

private final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct RecordingOverlayView: View {
    @ObservedObject var model: RecordingOverlayModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var previousPreviewLineCount = 1

    var body: some View {
        Group {
            if model.usesSingleRowLayout {
                compactContent
            } else {
                regularContent
            }
        }
        .frame(width: model.contentSize.width, height: model.contentSize.height)
        .background(
            Color.black.opacity(0.94),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.13), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.34), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recording-overlay")
    }

    private var compactContent: some View {
        headerRow(indicatorDiameter: 30, meterWidth: 82, meterBars: 11)
            .padding(.horizontal, 13)
    }

    private var regularContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            headerRow(
                indicatorDiameter: 32,
                meterWidth: model.size == .expanded ? 132 : 96,
                meterBars: model.size == .expanded ? 16 : 12
            )

            if model.status == .recording {
                previewContent
            }
        }
        .padding(13)
    }

    private func headerRow(
        indicatorDiameter: CGFloat,
        meterWidth: CGFloat,
        meterBars: Int
    ) -> some View {
        HStack(spacing: 9) {
            statusIndicator(diameter: indicatorDiameter)
            statusHeader
            Spacer(minLength: 4)
            if model.status == .recording {
                AudioBars(level: model.level, barCount: meterBars, height: 17)
                    .frame(width: meterWidth)
            } else {
                secondaryStatusContent
            }
        }
    }

    private var statusHeader: some View {
        HStack(spacing: 8) {
            Text(model.status.title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1.15)
                .foregroundStyle(Color.white.opacity(0.94))
            if showsLiveBadge, model.size != .compact {
                Text("LIVE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.12), in: Capsule())
            }
            if model.status == .recording, model.size != .compact {
                Label(model.source.shortTitle, systemImage: model.source.symbolName)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.54))
                    .labelStyle(.titleAndIcon)
            }
        }
    }

    private var showsLiveBadge: Bool {
        guard model.status == .recording else { return false }
        return switch model.previewState {
        case .waiting, .active:
            true
        case .disabled, .unavailable, .failed:
            false
        }
    }

    @ViewBuilder
    private var secondaryStatusContent: some View {
        if case let .error(message) = model.status {
            Text(message)
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.68))
                .lineLimit(model.size == .compact ? 1 : 2)
        } else if model.status == .processing || model.status == .finalizing {
            ProgressView()
                .controlSize(.small)
                .tint(statusColor)
        } else if case let .success(message) = model.status {
            Text(message)
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.68))
        }
    }

    private func statusIndicator(diameter: CGFloat) -> some View {
        ZStack {
            if model.status == .recording {
                Circle()
                    .stroke(statusColor.opacity(0.18), lineWidth: 6)
                    .scaleEffect(reduceMotion ? 1 : 1.12)
            }
            Circle()
                .fill(statusColor.opacity(0.13))
            Image(systemName: model.status.symbolName)
                .font(.system(size: diameter * 0.4, weight: .semibold))
                .foregroundStyle(statusColor)
                .symbolEffect(.pulse, isActive: model.status == .recording && !reduceMotion)
        }
        .frame(width: diameter, height: diameter)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: model.status)
    }

    private var statusColor: Color {
        switch model.status {
        case .recording: .red
        case .processing, .finalizing: .accentColor
        case .success: .green
        case .error: .orange
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 5, height: 5)
                Text(previewHeading)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(0.9)
                    .foregroundStyle(Color.white.opacity(0.46))
            }

            switch model.previewState {
            case .disabled:
                Text("Preview is off")
                    .foregroundStyle(Color.white.opacity(0.44))
            case .waiting:
                HStack(spacing: 7) {
                    ProgressView().controlSize(.mini)
                    Text("Listening…")
                }
                .foregroundStyle(Color.white.opacity(0.72))
            case let .active(text):
                if model.size == .expanded {
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.disabled)
                                .foregroundStyle(previewTextColor)
                            Color.clear.frame(height: 1).id("preview-end")
                        }
                        .onChange(of: text) {
                            let lineCount = text.reduce(into: 1) { count, character in
                                if character == "\n" { count += 1 }
                            }
                            defer { previousPreviewLineCount = lineCount }
                            guard lineCount > previousPreviewLineCount else { return }
                            proxy.scrollTo("preview-end", anchor: .bottom)
                        }
                    }
                } else {
                    Text(text)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(previewTextColor)
                }
            case let .unavailable(message), let .failed(message):
                Text(message)
                    .foregroundStyle(Color.white.opacity(0.66))
                    .lineLimit(model.size == .expanded ? 4 : 3)
            }
        }
        .font(.system(size: model.size == .expanded ? 15 : 13, weight: .regular, design: .rounded))
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        }
    }

    private var previewTextColor: Color {
        Color(red: 0.82, green: 0.84, blue: 0.86)
    }

    private var previewHeading: String {
        switch model.previewState {
        case .unavailable, .failed:
            "PREVIEW STATUS"
        case .disabled, .waiting, .active:
            "LIVE TRANSCRIPT"
        }
    }

}

private struct AudioBars: View {
    let level: Float
    let barCount: Int
    let height: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(barColor(for: index))
                    .frame(maxWidth: .infinity)
                    .frame(height: barHeight(for: index))
            }
        }
        .frame(height: height)
        .animation(reduceMotion ? nil : .linear(duration: 0.08), value: level)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let pattern: [CGFloat] = [0.34, 0.58, 0.82, 0.48, 1, 0.68, 0.4]
        let shape = pattern[index % pattern.count]
        let active = max(CGFloat(level), 0.08)
        return max(3, height * shape * (0.25 + active * 0.75))
    }

    private func barColor(for index: Int) -> Color {
        let threshold = Float(index + 1) / Float(barCount)
        return threshold <= max(level, 0.04)
            ? Color(red: 0.22, green: 1, blue: 0.48)
            : Color(red: 0.22, green: 1, blue: 0.48).opacity(0.14)
    }
}
