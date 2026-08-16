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

    var body: some Scene {
        MenuBarExtra {
            Phase0Menu(coordinator: coordinator)
        } label: {
            Image(systemName: coordinator.state.symbolName)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            Phase0SettingsView(coordinator: coordinator)
        }
    }
}
