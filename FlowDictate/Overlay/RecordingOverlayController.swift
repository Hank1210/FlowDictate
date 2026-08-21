import AppKit
import Combine
import SwiftUI

enum OverlayStatus: Equatable {
    case recording
    case finalizing
    case processing
    case success
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
    func configure(size: OverlaySize, position: OverlayPosition)
    func hide()
}

extension RecordingOverlayPresenting {
    func show(status: OverlayStatus, level: Float = 0, reposition: Bool = false) {
        show(status: status, level: level, reposition: reposition)
    }
}

@MainActor
private final class RecordingOverlayModel: ObservableObject {
    @Published var status: OverlayStatus = .recording
    @Published var level: Float = 0
    @Published var previewState: LivePreviewState = .disabled
    @Published var size: OverlaySize = .standard
}

@MainActor
final class RecordingOverlayController: RecordingOverlayPresenting {
    private let model = RecordingOverlayModel()
    private var panel: NonActivatingPanel?
    private var overlayPosition: OverlayPosition = .bottomTrailing
    private var currentScreen: NSScreen?

    func show(status: OverlayStatus, level: Float = 0, reposition: Bool = false) {
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
    }

    func updateLevel(_ level: Float) {
        model.level = level
    }

    func updatePreview(_ state: LivePreviewState) {
        model.previewState = state
    }

    func configure(size: OverlaySize, position: OverlayPosition) {
        model.size = size
        overlayPosition = position
        guard let panel else { return }
        resize(panel)
        self.position(panel, on: currentScreen ?? screenContainingMouse())
    }

    func hide() {
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
        let size: NSSize = switch model.size {
        case .compact: NSSize(width: 360, height: 76)
        case .standard: NSSize(width: 430, height: 164)
        case .expanded: NSSize(width: 540, height: 280)
        }
        panel.setContentSize(size)
    }
}

private final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct RecordingOverlayView: View {
    @ObservedObject var model: RecordingOverlayModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if model.size == .compact {
                compactContent
            } else {
                regularContent
            }
        }
        .frame(width: dimensions.width, height: dimensions.height)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.18), radius: 22, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recording-overlay")
    }

    private var compactContent: some View {
        HStack(spacing: 13) {
            statusIndicator(diameter: 38)
            VStack(alignment: .leading, spacing: 5) {
                statusHeader
                if model.status == .recording {
                    AudioBars(level: model.level, barCount: 18, height: 19)
                } else {
                    secondaryStatusContent
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var regularContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 13) {
                statusIndicator(diameter: 42)
                VStack(alignment: .leading, spacing: 5) {
                    statusHeader
                    if model.status == .recording {
                        AudioBars(level: model.level, barCount: 24, height: 20)
                    } else {
                        secondaryStatusContent
                    }
                }
            }

            if model.status == .recording {
                previewContent
            }
        }
        .padding(16)
    }

    private var statusHeader: some View {
        HStack(spacing: 8) {
            Text(model.status.title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1.15)
            if model.status == .recording, model.previewState != .disabled {
                Text("LIVE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.12), in: Capsule())
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var secondaryStatusContent: some View {
        if case let .error(message) = model.status {
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(model.size == .compact ? 1 : 2)
        } else if model.status == .processing || model.status == .finalizing {
            ProgressView()
                .controlSize(.small)
                .tint(statusColor)
        } else {
            Text("Text inserted")
                .font(.caption)
                .foregroundStyle(.secondary)
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
                Text("LIVE TRANSCRIPT")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(0.9)
                    .foregroundStyle(.secondary)
            }

            switch model.previewState {
            case .disabled:
                Text("Preview is off")
                    .foregroundStyle(.tertiary)
            case .waiting:
                HStack(spacing: 7) {
                    ProgressView().controlSize(.mini)
                    Text("Listening…")
                }
                .foregroundStyle(.secondary)
            case let .active(text):
                if model.size == .expanded {
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.disabled)
                            Color.clear.frame(height: 1).id("preview-end")
                        }
                        .onChange(of: text) {
                            proxy.scrollTo("preview-end", anchor: .bottom)
                        }
                    }
                } else {
                    Text(text)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            case let .unavailable(message), let .failed(message):
                Text(message)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .font(.system(size: model.size == .expanded ? 15 : 13, weight: .regular, design: .rounded))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(.primary.opacity(0.055), lineWidth: 0.5)
        }
    }

    private var dimensions: (width: CGFloat, height: CGFloat) {
        switch model.size {
        case .compact: (360, 76)
        case .standard: (430, 164)
        case .expanded: (540, 280)
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
            ? Color(red: 1, green: 0.22, blue: 0.3)
            : Color.secondary.opacity(0.16)
    }
}
