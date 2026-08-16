import Foundation
import OSLog

enum FlowLogger {
    nonisolated private static let subsystem = Bundle.main.bundleIdentifier ?? "FlowDictate"

    nonisolated static let app = Logger(subsystem: subsystem, category: "app")
    nonisolated static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    nonisolated static let audio = Logger(subsystem: subsystem, category: "audio")
    nonisolated static let transcription = Logger(subsystem: subsystem, category: "transcription")
    nonisolated static let insertion = Logger(subsystem: subsystem, category: "insertion")
}
