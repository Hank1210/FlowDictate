import Carbon.HIToolbox
import Foundation

struct HotKeyConfiguration: Codable, Identifiable, Hashable, Sendable {
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

    static let optionShiftSpace = HotKeyConfiguration(
        id: "option-shift-space",
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(optionKey | shiftKey),
        displayName: "Option + Shift + Space"
    )

    static let controlShiftSpace = HotKeyConfiguration(
        id: "control-shift-space",
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(controlKey | shiftKey),
        displayName: "Control + Shift + Space"
    )

    static let optionShiftD = HotKeyConfiguration(
        id: "option-shift-d",
        keyCode: UInt32(kVK_ANSI_D),
        modifiers: UInt32(optionKey | shiftKey),
        displayName: "Option + Shift + D"
    )

    static let dictationPresets = [optionSpace, controlSpace, optionD]
    static let cancelPresets = [optionShiftSpace, controlShiftSpace, optionShiftD]

    static func custom(keyCode: UInt32, modifiers: UInt32, keyName: String) -> Self {
        let modifierName = [
            (UInt32(controlKey), "Control"),
            (UInt32(optionKey), "Option"),
            (UInt32(shiftKey), "Shift"),
            (UInt32(cmdKey), "Command")
        ]
        .compactMap { mask, name in modifiers & mask != 0 ? name : nil }
        .joined(separator: " + ")
        let displayName = modifierName.isEmpty ? keyName : "\(modifierName) + \(keyName)"
        return HotKeyConfiguration(
            id: "custom-\(keyCode)-\(modifiers)",
            keyCode: keyCode,
            modifiers: modifiers,
            displayName: displayName
        )
    }
}
