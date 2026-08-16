//
//  FlowDictateUITests.swift
//  FlowDictateUITests
//
//  Created by Frank Euler on 16.08.26.
//

import XCTest

final class FlowDictateUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMenuBarApplicationLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertNotEqual(app.state, .notRunning)
        app.terminate()
    }
}
