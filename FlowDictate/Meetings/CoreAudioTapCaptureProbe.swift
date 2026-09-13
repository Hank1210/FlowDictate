import CoreAudio
import Foundation

nonisolated enum SystemAudioCaptureBackend: String, Codable, Sendable, Equatable {
    case coreAudioTap
    case screenCaptureKit
}

nonisolated struct SystemAudioCaptureStrategy: Sendable {
    let preferredBackend: SystemAudioCaptureBackend
    let minimumOperatingSystem: OperatingSystemVersion
    let requiresAudioCaptureUsageDescription: Bool
    let permissionSettingsLabel: String

    static func candidate(
        for version: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
    ) -> Self {
        if isAtLeastMacOS14_2(version) {
            return Self(
                preferredBackend: .coreAudioTap,
                minimumOperatingSystem: OperatingSystemVersion(
                    majorVersion: 14,
                    minorVersion: 2,
                    patchVersion: 0
                ),
                requiresAudioCaptureUsageDescription: true,
                permissionSettingsLabel: "System Audio Recording"
            )
        }
        return Self(
            preferredBackend: .screenCaptureKit,
            minimumOperatingSystem: OperatingSystemVersion(
                majorVersion: 14,
                minorVersion: 0,
                patchVersion: 0
            ),
            requiresAudioCaptureUsageDescription: false,
            permissionSettingsLabel: "Screen & System Audio Recording"
        )
    }

    private static func isAtLeastMacOS14_2(_ version: OperatingSystemVersion) -> Bool {
        version.majorVersion > 14
            || (version.majorVersion == 14 && version.minorVersion >= 2)
    }
}

nonisolated struct CoreAudioTapProbeReport: Sendable, Equatable {
    let callbackCount: Int
    let nonSilentCallbackCount: Int
    let frameCount: Int64
    let sampleRate: Double
    let channelCount: Int
    let firstHostTime: UInt64?
    let lastHostTime: UInt64?

    var capturedDuration: TimeInterval {
        guard sampleRate > 0 else { return 0 }
        return TimeInterval(frameCount) / sampleRate
    }
}

nonisolated enum CoreAudioTapProbeError: LocalizedError, Equatable {
    case requiresMacOS14_2
    case missingUsageDescription
    case operationFailed(operation: String, status: OSStatus)
    case invalidTapIdentifier
    case invalidTapFormat
    case noAudioCallbacks

    var errorDescription: String? {
        switch self {
        case .requiresMacOS14_2:
            "The audio-only Core Audio tap requires macOS 14.2 or later."
        case .missingUsageDescription:
            "The app is missing NSAudioCaptureUsageDescription."
        case let .operationFailed(operation, status):
            "Core Audio could not \(operation) (OSStatus \(statusDescription(status)))."
        case .invalidTapIdentifier:
            "Core Audio created a tap without a usable identifier."
        case .invalidTapFormat:
            "Core Audio created a tap without a usable audio format."
        case .noAudioCallbacks:
            "The Core Audio tap started but delivered no audio callbacks."
        }
    }

    private func statusDescription(_ status: OSStatus) -> String {
        let value = UInt32(bitPattern: status)
        let bytes = [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ]
        if bytes.allSatisfy({ $0 >= 32 && $0 <= 126 }) {
            return "'\(String(bytes: bytes, encoding: .ascii) ?? "????")' / \(status)"
        }
        return String(status)
    }
}

/// Development-only measurement path for the Phase 4.1 capture decision.
/// It never registers a screen output and never persists audio samples.
actor CoreAudioTapCaptureProbe {
    func run(for duration: Duration = .seconds(5)) async throws -> CoreAudioTapProbeReport {
        guard #available(macOS 14.2, *) else {
            throw CoreAudioTapProbeError.requiresMacOS14_2
        }
        guard Bundle.main.object(
            forInfoDictionaryKey: "NSAudioCaptureUsageDescription"
        ) as? String != nil else {
            throw CoreAudioTapProbeError.missingUsageDescription
        }

        let metrics = CoreAudioTapProbeMetrics()
        var tapID = AudioObjectID(kAudioObjectUnknown)
        var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        var ioProcID: AudioDeviceIOProcID?
        var deviceStarted = false

        do {
            let excludedProcessIDs = try currentProcessObjectID().map { [$0] } ?? []
            let tapDescription = CATapDescription(
                monoGlobalTapButExcludeProcesses: excludedProcessIDs
            )
            tapDescription.name = "FlowDictate 4.1 audio-only capture probe"
            tapDescription.isPrivate = true
            tapDescription.muteBehavior = .unmuted

            try check(
                AudioHardwareCreateProcessTap(tapDescription, &tapID),
                operation: "create the process tap"
            )
            let tapUID = try tapUID(for: tapID)
            let tapFormat = try tapFormat(for: tapID)

            let aggregateUID = "de.euler.FlowDictate.capture-probe.\(UUID().uuidString)"
            let aggregateDescription: [String: Any] = [
                kAudioAggregateDeviceNameKey: "FlowDictate 4.1 Capture Probe",
                kAudioAggregateDeviceUIDKey: aggregateUID,
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceIsStackedKey: false,
                kAudioAggregateDeviceTapListKey: [
                    [
                        kAudioSubTapUIDKey: tapUID,
                        kAudioSubTapDriftCompensationKey: true
                    ]
                ]
            ]
            try check(
                AudioHardwareCreateAggregateDevice(
                    aggregateDescription as CFDictionary,
                    &aggregateDeviceID
                ),
                operation: "create the private aggregate device"
            )

            let callbackQueue = DispatchQueue(
                label: "de.euler.FlowDictate.core-audio-tap-probe",
                qos: .userInitiated
            )
            try check(
                AudioDeviceCreateIOProcIDWithBlock(
                    &ioProcID,
                    aggregateDeviceID,
                    callbackQueue
                ) { _, inputData, inputTime, _, _ in
                    metrics.record(
                        inputData: inputData,
                        inputTime: inputTime,
                        format: tapFormat
                    )
                },
                operation: "install the aggregate-device IO callback"
            )
            try check(
                AudioDeviceStart(aggregateDeviceID, ioProcID),
                operation: "start audio-only capture"
            )
            deviceStarted = true

            try await Task.sleep(for: duration)
        } catch {
            cleanup(
                tapID: tapID,
                aggregateDeviceID: aggregateDeviceID,
                ioProcID: ioProcID,
                deviceStarted: deviceStarted
            )
            throw error
        }

        cleanup(
            tapID: tapID,
            aggregateDeviceID: aggregateDeviceID,
            ioProcID: ioProcID,
            deviceStarted: deviceStarted
        )
        let report = metrics.report()
        guard report.callbackCount > 0 else {
            throw CoreAudioTapProbeError.noAudioCallbacks
        }
        return report
    }

    @available(macOS 14.2, *)
    private func currentProcessObjectID() throws -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var processID = getpid()
        var processObjectID = AudioObjectID(kAudioObjectUnknown)
        var outputSize = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = withUnsafePointer(to: &processID) { qualifier in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                UInt32(MemoryLayout<pid_t>.size),
                qualifier,
                &outputSize,
                &processObjectID
            )
        }
        try check(status, operation: "resolve the current audio process")
        return processObjectID == kAudioObjectUnknown ? nil : processObjectID
    }

    @available(macOS 14.2, *)
    private func tapUID(for tapID: AudioObjectID) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<CFString>.size)
        var value: CFString = "" as CFString
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, pointer)
        }
        try check(status, operation: "read the tap identifier")
        let result = value as String
        guard !result.isEmpty else { throw CoreAudioTapProbeError.invalidTapIdentifier }
        return result
    }

    @available(macOS 14.2, *)
    private func tapFormat(for tapID: AudioObjectID) throws -> AudioStreamBasicDescription {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var value = AudioStreamBasicDescription()
        try check(
            AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &value),
            operation: "read the tap format"
        )
        guard value.mSampleRate > 0, value.mChannelsPerFrame > 0 else {
            throw CoreAudioTapProbeError.invalidTapFormat
        }
        return value
    }

    private func check(_ status: OSStatus, operation: String) throws {
        guard status == noErr else {
            throw CoreAudioTapProbeError.operationFailed(operation: operation, status: status)
        }
    }

    @available(macOS 14.2, *)
    private func cleanup(
        tapID: AudioObjectID,
        aggregateDeviceID: AudioObjectID,
        ioProcID: AudioDeviceIOProcID?,
        deviceStarted: Bool
    ) {
        if aggregateDeviceID != kAudioObjectUnknown {
            if deviceStarted { AudioDeviceStop(aggregateDeviceID, ioProcID) }
            if let ioProcID { AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID) }
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
        }
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
    }
}

nonisolated private final class CoreAudioTapProbeMetrics: @unchecked Sendable {
    private let lock = NSLock()
    private var callbackCount = 0
    private var nonSilentCallbackCount = 0
    private var frameCount: Int64 = 0
    private var firstHostTime: UInt64?
    private var lastHostTime: UInt64?
    private var sampleRate: Double = 0
    private var channelCount = 0

    func record(
        inputData: UnsafePointer<AudioBufferList>,
        inputTime: UnsafePointer<AudioTimeStamp>,
        format: AudioStreamBasicDescription
    ) {
        let buffers = UnsafeMutableAudioBufferListPointer(
            UnsafeMutablePointer(mutating: inputData)
        )
        let bytesPerFrame = Int(format.mBytesPerFrame)
        let observedFrames = buffers.first.map { buffer -> Int64 in
            guard bytesPerFrame > 0 else { return 0 }
            return Int64(Int(buffer.mDataByteSize) / bytesPerFrame)
        } ?? 0
        let containsNonZeroByte = buffers.contains { buffer in
            guard let data = buffer.mData, buffer.mDataByteSize > 0 else { return false }
            return UnsafeRawBufferPointer(
                start: data,
                count: Int(buffer.mDataByteSize)
            ).contains { $0 != 0 }
        }
        let hostTime = inputTime.pointee.mFlags.contains(.hostTimeValid)
            ? inputTime.pointee.mHostTime
            : nil

        lock.lock()
        callbackCount += 1
        if containsNonZeroByte { nonSilentCallbackCount += 1 }
        frameCount += observedFrames
        firstHostTime = firstHostTime ?? hostTime
        if let hostTime { lastHostTime = hostTime }
        sampleRate = format.mSampleRate
        channelCount = Int(format.mChannelsPerFrame)
        lock.unlock()
    }

    func report() -> CoreAudioTapProbeReport {
        lock.lock()
        defer { lock.unlock() }
        return CoreAudioTapProbeReport(
            callbackCount: callbackCount,
            nonSilentCallbackCount: nonSilentCallbackCount,
            frameCount: frameCount,
            sampleRate: sampleRate,
            channelCount: channelCount,
            firstHostTime: firstHostTime,
            lastHostTime: lastHostTime
        )
    }
}
