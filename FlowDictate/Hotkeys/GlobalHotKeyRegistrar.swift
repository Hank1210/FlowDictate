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

extension HotKeyRegistering {
    func register(
        _ configuration: HotKeyConfiguration,
        pressed: @escaping @MainActor () -> Void,
        released: @escaping @MainActor () -> Void
    ) throws {
        try register(configuration, handler: pressed)
    }
}

@MainActor
final class DisabledHotKeyRegistrar: HotKeyRegistering {
    func register(
        _ configuration: HotKeyConfiguration,
        handler: @escaping @MainActor () -> Void
    ) throws {}

    func unregister() {}
}

@MainActor
final class GlobalHotKeyRegistrar: HotKeyRegistering {
    nonisolated private static let signature: OSType = 0x464C4F57 // "FLOW"

    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var handler: (@MainActor () -> Void)?
    private var releaseHandler: (@MainActor () -> Void)?
    private let registrationID: UInt32

    init(registrationID: UInt32 = 1) {
        self.registrationID = registrationID
    }

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
        try register(configuration, pressed: handler, released: {})
    }

    func register(
        _ configuration: HotKeyConfiguration,
        pressed: @escaping @MainActor () -> Void,
        released: @escaping @MainActor () -> Void
    ) throws {
        unregister()
        self.handler = pressed
        releaseHandler = released

        if eventHandlerRef == nil {
            var eventTypes = [
                EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
            ]
            let status = InstallEventHandler(
                GetApplicationEventTarget(),
                Self.eventCallback,
                eventTypes.count,
                &eventTypes,
                Unmanaged.passUnretained(self).toOpaque(),
                &eventHandlerRef
            )
            guard status == noErr else {
                throw HotKeyRegistrationError.installationFailed(status)
            }
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: registrationID)
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

    private func invokeHandler(released: Bool) {
        if released { releaseHandler?() } else { handler?() }
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
        let registrar = Unmanaged<GlobalHotKeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
        guard
            status == noErr,
            hotKeyID.signature == signature,
            hotKeyID.id == registrar.registrationID
        else {
            return OSStatus(eventNotHandledErr)
        }

        MainActor.assumeIsolated {
            registrar.invokeHandler(released: GetEventKind(event) == UInt32(kEventHotKeyReleased))
        }
        return noErr
    }
}
