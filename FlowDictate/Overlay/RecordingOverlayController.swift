import AppKit
import Combine
import SwiftUI

enum OverlayStatus: Equatable {
    case recording
    case processing
    case success
    case error(String)

    var title: String {
        switch self {
        case .recording: "Recording"
        case .processing: "Processing"
        case .success: "Inserted"
        case .error: "Dictation failed"
        }
    }

    var symbolName: String {
        switch self {
        case .recording: "mic.fill"
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
}

@MainActor
final class RecordingOverlayController: RecordingOverlayPresenting {
    private let model = RecordingOverlayModel()
    private var panel: NonActivatingPanel?

    func show(status: OverlayStatus, level: Float = 0, reposition: Bool = false) {
        model.status = status
        model.level = level
        let panel = panel ?? makePanel()
        if reposition || !panel.isVisible {
            position(panel, on: screenContainingMouse())
        }
        panel.orderFrontRegardless()
    }

    func updateLevel(_ level: Float) {
        model.level = level
    }

    func hide() {
        panel?.orderOut(nil)
        model.level = 0
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
        let origin = NSPoint(
            x: visibleFrame.maxX - panel.frame.width - 24,
            y: visibleFrame.minY + 24
        )
        panel.setFrameOrigin(origin)
    }
}

private final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct RecordingOverlayView: View {
    @ObservedObject var model: RecordingOverlayModel

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: model.status.symbolName)
                .font(.title2)
                .foregroundStyle(statusColor)
                .symbolEffect(.pulse, isActive: model.status == .recording)

            VStack(alignment: .leading, spacing: 7) {
                Text(model.status.title)
                    .font(.headline)

                if model.status == .recording {
                    LevelMeter(level: model.level)
                } else if case let .error(message) = model.status {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if model.status == .processing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(width: 250, height: 72)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.14))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recording-overlay")
    }

    private var statusColor: Color {
        switch model.status {
        case .recording: .red
        case .processing: .accentColor
        case .success: .green
        case .error: .orange
        }
    }
}

private struct LevelMeter: View {
    let level: Float

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.secondary.opacity(0.18))
                Capsule()
                    .fill(.red.gradient)
                    .frame(width: max(4, proxy.size.width * CGFloat(level)))
            }
        }
        .frame(height: 7)
        .animation(.linear(duration: 0.08), value: level)
    }
}
