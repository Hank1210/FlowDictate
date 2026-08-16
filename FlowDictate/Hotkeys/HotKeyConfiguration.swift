import Carbon.HIToolbox
import Combine
import Foundation

struct HotKeyConfiguration: Identifiable, Hashable, Sendable {
    let id: String
    let keyCode: UInt32
    let modifiers: UInt32
    let displayName: String

    static let optionSpace = HotKeyConfiguration(
        id: "option-space",
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(optionKey),
        displayName: "Option + Space"
    )

    static let controlSpace = HotKeyConfiguration(
        id: "control-space",
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(controlKey),
        displayName: "Control + Space"
    )

    static let optionD = HotKeyConfiguration(
        id: "option-d",
        keyCode: UInt32(kVK_ANSI_D),
        modifiers: UInt32(optionKey),
        displayName: "Option + D"
    )

    static let presets = [optionSpace, controlSpace, optionD]
}

@MainActor
final class ShortcutSettings: ObservableObject {
    private static let defaultsKey = "dictationHotKey"
    private let defaults: UserDefaults

    @Published private(set) var selected: HotKeyConfiguration

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedID = defaults.string(forKey: Self.defaultsKey)
        selected = HotKeyConfiguration.presets.first { $0.id == savedID } ?? .optionSpace
    }

    func select(_ configuration: HotKeyConfiguration) {
        selected = configuration
        defaults.set(configuration.id, forKey: Self.defaultsKey)
    }
}
