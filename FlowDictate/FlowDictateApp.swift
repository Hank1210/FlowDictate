//
//  FlowDictateApp.swift
//  FlowDictate
//
//  Created by Frank Euler on 16.08.26.
//

import SwiftUI

@main
struct FlowDictateApp: App {
    @StateObject private var coordinator = DictationCoordinator()
    #if DEBUG
    @State private var didRunCoreAudioTapLaunchProbe = false
    #endif

    var body: some Scene {
        MenuBarExtra {
            FlowDictateMenu(coordinator: coordinator)
        } label: {
            Image(systemName: coordinator.state.symbolName)
                #if DEBUG
                .onAppear {
                    guard !didRunCoreAudioTapLaunchProbe else { return }
                    let arguments = CommandLine.arguments
                    guard arguments.contains("--run-core-audio-tap-probe")
                            || arguments.contains("--run-core-audio-tap-cycle-probe") else { return }
                    didRunCoreAudioTapLaunchProbe = true
                    if arguments.contains("--run-core-audio-tap-cycle-probe") {
                        coordinator.runCoreAudioTapRepeatedCaptureProbe()
                    } else {
                        coordinator.runCoreAudioTapCaptureProbe()
                    }
                }
                #endif
        }
        .menuBarExtraStyle(.menu)

        Settings {
            FlowDictateSettingsView(coordinator: coordinator)
        }
    }
}
