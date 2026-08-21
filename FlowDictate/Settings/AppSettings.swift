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
        static let historyRetentionDays = "historyRetentionDays"
        static let historyMaximumRecordCount = "historyMaximumRecordCount"
        static let livePreviewEnabled = "livePreviewEnabled"
        static let overlaySize = "overlaySize"
        static let livePreviewCharacterLimit = "livePreviewCharacterLimit"
        static let overlayPosition = "overlayPosition"
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

    @Published var historyRetentionDays: Int {
        didSet { defaults.set(historyRetentionDays, forKey: Key.historyRetentionDays) }
    }

    @Published var historyMaximumRecordCount: Int {
        didSet { defaults.set(historyMaximumRecordCount, forKey: Key.historyMaximumRecordCount) }
    }

    @Published var livePreviewEnabled: Bool {
        didSet { defaults.set(livePreviewEnabled, forKey: Key.livePreviewEnabled) }
    }

    @Published var overlaySize: OverlaySize {
        didSet { defaults.set(overlaySize.rawValue, forKey: Key.overlaySize) }
    }

    @Published var livePreviewCharacterLimit: Int {
        didSet {
            let clamped = min(max(livePreviewCharacterLimit, 50), 800)
            if clamped != livePreviewCharacterLimit {
                livePreviewCharacterLimit = clamped
            }
            defaults.set(clamped, forKey: Key.livePreviewCharacterLimit)
        }
    }

    @Published var overlayPosition: OverlayPosition {
        didSet { defaults.set(overlayPosition.rawValue, forKey: Key.overlayPosition) }
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

        let storedOnboardingVersion = defaults.integer(forKey: Key.onboardingVersion)
        onboardingVersion = storedOnboardingVersion
        automaticRetryEnabled = defaults.object(forKey: Key.automaticRetryEnabled) as? Bool ?? true
        let storedRetention = defaults.integer(forKey: Key.audioRetentionDays)
        audioRetentionDays = storedRetention == 0 ? 30 : storedRetention

        let existingInstallation = storedOnboardingVersion > 0
        if let storedHistoryDays = defaults.object(forKey: Key.historyRetentionDays) as? Int {
            historyRetentionDays = storedHistoryDays
        } else {
            historyRetentionDays = existingInstallation ? -1 : 365
        }
        if let storedHistoryMaximum = defaults.object(forKey: Key.historyMaximumRecordCount) as? Int {
            historyMaximumRecordCount = storedHistoryMaximum
        } else {
            historyMaximumRecordCount = existingInstallation ? -1 : 1_000
        }

        if let storedLivePreview = defaults.object(forKey: Key.livePreviewEnabled) as? Bool {
            livePreviewEnabled = storedLivePreview
        } else {
            livePreviewEnabled = !existingInstallation
        }
        overlaySize = OverlaySize(
            rawValue: defaults.string(forKey: Key.overlaySize) ?? ""
        ) ?? .standard
        let storedPreviewLimit = defaults.object(forKey: Key.livePreviewCharacterLimit) as? Int
        livePreviewCharacterLimit = min(max(storedPreviewLimit ?? 150, 50), 800)
        overlayPosition = OverlayPosition(
            rawValue: defaults.string(forKey: Key.overlayPosition) ?? ""
        ) ?? .bottomTrailing
    }

    private static func savedHotKey(_ defaults: UserDefaults, key: String) -> HotKeyConfiguration? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(HotKeyConfiguration.self, from: data)
    }
}
