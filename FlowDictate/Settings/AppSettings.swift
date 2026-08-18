import Combine
import Foundation

enum TranscriptionLanguage: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case german = "de"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .german: "German"
        case .english: "English"
        }
    }

    var apiValue: String? {
        self == .automatic ? nil : rawValue
    }
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let dictationHotKey = "dictationHotKey"
        static let cancelHotKey = "cancelHotKey"
        static let dictationHotKeyData = "dictationHotKeyData"
        static let cancelHotKeyData = "cancelHotKeyData"
        static let restoreHotKeyData = "restoreHotKeyData"
        static let inputDeviceUID = "inputDeviceUID"
        static let transcriptionModel = "transcriptionModel"
        static let transcriptionLanguage = "transcriptionLanguage"
        static let clipboardRestoreDelay = "clipboardRestoreDelay"
        static let onboardingVersion = "onboardingVersion"
        static let automaticRetryEnabled = "automaticRetryEnabled"
        static let audioRetentionDays = "audioRetentionDays"
    }

    private let defaults: UserDefaults

    @Published var dictationHotKey: HotKeyConfiguration {
        didSet {
            defaults.set(dictationHotKey.id, forKey: Key.dictationHotKey)
            defaults.set(try? JSONEncoder().encode(dictationHotKey), forKey: Key.dictationHotKeyData)
        }
    }

    @Published var cancelHotKey: HotKeyConfiguration {
        didSet {
            defaults.set(cancelHotKey.id, forKey: Key.cancelHotKey)
            defaults.set(try? JSONEncoder().encode(cancelHotKey), forKey: Key.cancelHotKeyData)
        }
    }

    @Published var restoreHotKey: HotKeyConfiguration {
        didSet {
            defaults.set(try? JSONEncoder().encode(restoreHotKey), forKey: Key.restoreHotKeyData)
        }
    }

    @Published var inputDeviceUID: String? {
        didSet { defaults.set(inputDeviceUID, forKey: Key.inputDeviceUID) }
    }

    @Published var transcriptionModel: String {
        didSet { defaults.set(transcriptionModel, forKey: Key.transcriptionModel) }
    }

    @Published var transcriptionLanguage: TranscriptionLanguage {
        didSet { defaults.set(transcriptionLanguage.rawValue, forKey: Key.transcriptionLanguage) }
    }

    @Published var clipboardRestoreDelay: Double {
        didSet { defaults.set(clipboardRestoreDelay, forKey: Key.clipboardRestoreDelay) }
    }

    @Published var onboardingVersion: Int {
        didSet { defaults.set(onboardingVersion, forKey: Key.onboardingVersion) }
    }

    @Published var automaticRetryEnabled: Bool {
        didSet { defaults.set(automaticRetryEnabled, forKey: Key.automaticRetryEnabled) }
    }

    @Published var audioRetentionDays: Int {
        didSet { defaults.set(audioRetentionDays, forKey: Key.audioRetentionDays) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let dictationID = defaults.string(forKey: Key.dictationHotKey)
        dictationHotKey = Self.savedHotKey(defaults, key: Key.dictationHotKeyData)
            ?? HotKeyConfiguration.dictationPresets.first { $0.id == dictationID }
            ?? .optionSpace

        let cancelID = defaults.string(forKey: Key.cancelHotKey)
        cancelHotKey = Self.savedHotKey(defaults, key: Key.cancelHotKeyData)
            ?? HotKeyConfiguration.cancelPresets.first { $0.id == cancelID }
            ?? .optionShiftSpace

        restoreHotKey = Self.savedHotKey(defaults, key: Key.restoreHotKeyData)
            ?? .optionShiftZ

        inputDeviceUID = defaults.string(forKey: Key.inputDeviceUID)
        transcriptionModel = defaults.string(forKey: Key.transcriptionModel)
            ?? "gpt-4o-mini-transcribe"

        let languageValue = defaults.string(forKey: Key.transcriptionLanguage)
        transcriptionLanguage = TranscriptionLanguage(rawValue: languageValue ?? "") ?? .automatic

        let storedDelay = defaults.object(forKey: Key.clipboardRestoreDelay) as? Double
        clipboardRestoreDelay = storedDelay ?? 0.6

        onboardingVersion = defaults.integer(forKey: Key.onboardingVersion)
        automaticRetryEnabled = defaults.object(forKey: Key.automaticRetryEnabled) as? Bool ?? true
        let storedRetention = defaults.integer(forKey: Key.audioRetentionDays)
        audioRetentionDays = storedRetention == 0 ? 30 : storedRetention
    }

    private static func savedHotKey(_ defaults: UserDefaults, key: String) -> HotKeyConfiguration? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(HotKeyConfiguration.self, from: data)
    }
}
