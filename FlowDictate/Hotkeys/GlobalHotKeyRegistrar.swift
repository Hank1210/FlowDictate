import Carbon.HIToolbox
import Foundation
import OSLog

enum HotKeyRegistrationError: LocalizedError {
    case installationFailed(OSStatus)
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .installationFailed(status):
            "Could not install the global hotkey handler (\(status))."
        case let .registrationFailed(status):
            "The selected global hotkey could not be registered (\(status)). It may already be in use."
        }
    }
}

@MainActor
protocol HotKeyRegistering: AnyObject {
    func register(_ configuration: HotKeyConfiguration, handler: @escaping @MainActor () -> Void) throws
    func unregister()
}

@MainActor
final class GlobalHotKeyRegistrar: HotKeyRegistering {
    nonisolated private static let signature: OSType = 0x464C4F57 // "FLOW"

    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var handler: (@MainActor () -> Void)?

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    func register(
        _ configuration: HotKeyConfiguration,
        handler: @escaping @MainActor () -> Void
    ) throws {
        unregister()
        self.handler = handler

        if eventHandlerRef == nil {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            let status = InstallEventHandler(
                GetApplicationEventTarget(),
                Self.eventCallback,
                1,
                &eventType,
                Unmanaged.passUnretained(self).toOpaque(),
                &eventHandlerRef
            )
            guard status == noErr else {
                throw HotKeyRegistrationError.installationFailed(status)
            }
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(
            configuration.keyCode,
            configuration.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            OptionBits(kEventHotKeyExclusive),
            &hotKeyRef
        )
        guard status == noErr else {
            throw HotKeyRegistrationError.registrationFailed(status)
        }

        FlowLogger.hotkey.info("Registered hotkey: \(configuration.displayName, privacy: .public)")
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func invokeHandler() {
        handler?()
    }

    private nonisolated static let eventCallback: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else { return OSStatus(eventNotHandledErr) }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr, hotKeyID.signature == signature else {
            return OSStatus(eventNotHandledErr)
        }

        let registrar = Unmanaged<GlobalHotKeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
        MainActor.assumeIsolated {
            registrar.invokeHandler()
        }
        return noErr
    }
}
