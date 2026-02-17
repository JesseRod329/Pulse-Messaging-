import XCTest

final class BoppyV2AppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOwnerCanOpenPrimarySurfaces() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["auth.continueOwner"].waitForExistence(timeout: 6))
        XCTAssertTrue(waitForAnyElement(app, identifier: "auth.card", timeout: 2))
        XCTAssertTrue(waitForAnyElement(app, identifier: "auth.trustStrip", timeout: 2))
        app.buttons["auth.continueOwner"].tap()

        XCTAssertTrue(app.buttons["tab.feed"].waitForExistence(timeout: 10))

        app.buttons["tab.feed"].tap()
        tapIfExists(app.buttons["feed.refresh"])

        app.buttons["tab.orders"].tap()
        tapIfExists(app.buttons["orders.filter.pending"])
        tapIfExists(app.buttons["orders.row"].firstMatch)
        tapIfExists(app.buttons["orders.assignDriver"])
        tapIfExists(app.buttons["Done"])
        tapIfExists(app.buttons["orders.row"].firstMatch)
        tapIfExists(app.buttons["Close"])

        app.buttons["tab.dispatch"].tap()
        tapIfExists(app.buttons["dispatch.refresh"])

        app.buttons["tab.profile"].tap()
        tapIfExists(app.buttons["profile.refreshAdmin"])
        XCTAssertTrue(app.buttons["profile.openInventoryCatalog"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["profile.openAdminControls"].waitForExistence(timeout: 3))
        tapIfExists(app.buttons["profile.signOut"])
    }

    func testDriverCanUseOrdersAndDispatch() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["auth.continueDriver"].waitForExistence(timeout: 6))
        app.buttons["auth.continueDriver"].tap()

        XCTAssertTrue(app.buttons["tab.orders"].waitForExistence(timeout: 10))

        app.buttons["tab.orders"].tap()
        tapIfExists(app.buttons["orders.filter.active"])
        tapIfExists(app.buttons["orders.row"].firstMatch)

        app.buttons["tab.dispatch"].tap()
        tapIfExists(app.buttons["dispatch.refresh"])

        app.buttons["tab.profile"].tap()
        tapIfExists(app.buttons["profile.signOut"])
    }

    func testFollowerCanOpenQuickOrder() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["auth.continueFollower"].waitForExistence(timeout: 6))
        app.buttons["auth.continueFollower"].tap()

        XCTAssertTrue(app.buttons["tab.feed"].waitForExistence(timeout: 10))

        app.buttons["tab.feed"].tap()
        tapIfExists(app.buttons["feed.post.quickOrder"].firstMatch)
        fillIfExists(app.textFields["Street"], value: "123 Main St")
        fillIfExists(app.textFields["City"], value: "Austin")
        fillIfExists(app.textFields["State"], value: "TX")
        fillIfExists(app.textFields["ZIP"], value: "78701")
        tapIfExists(app.buttons["orderSheet.submit"])

        app.buttons["tab.orders"].tap()
        tapIfExists(app.buttons["orders.filter.all"])
        tapIfExists(app.buttons["orders.row"].firstMatch)
        tapIfExists(app.buttons["Close"])

        app.buttons["tab.profile"].tap()
        tapIfExists(app.buttons["profile.signOut"])
    }

    func testMixedModeLegacyOrdersStillLoads() {
        let app = launchApp(extraLaunchArguments: ["-legacy-orders"])
        XCTAssertTrue(app.buttons["auth.continueOwner"].waitForExistence(timeout: 6))
        app.buttons["auth.continueOwner"].tap()

        XCTAssertTrue(app.buttons["tab.orders"].waitForExistence(timeout: 10))
        app.buttons["tab.orders"].tap()
        tapIfExists(app.buttons["orders.row"].firstMatch)
    }

    func testFollowerSeesRoleRestrictionToastOnDispatchTab() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["auth.continueFollower"].waitForExistence(timeout: 6))
        app.buttons["auth.continueFollower"].tap()

        XCTAssertTrue(app.buttons["tab.dispatch"].waitForExistence(timeout: 8))
        app.buttons["tab.dispatch"].tap()
        XCTAssertTrue(app.staticTexts["shell.roleToast"].waitForExistence(timeout: 2))
    }

    private func launchApp(extraLaunchArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: [
            "-force-local-demo",
            "-show-auth-screen",
            "-auth-demo-shortcuts"
        ])
        app.launchArguments.append(contentsOf: extraLaunchArguments)
        app.launch()
        return app
    }

    private func tapIfExists(_ element: XCUIElement, timeout: TimeInterval = 2.5) {
        guard element.waitForExistence(timeout: timeout), element.isHittable else { return }
        element.tap()
    }

    private func waitForAnyElement(_ app: XCUIApplication, identifier: String, timeout: TimeInterval) -> Bool {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
            .waitForExistence(timeout: timeout)
    }

    private func fillIfExists(_ field: XCUIElement, value: String, timeout: TimeInterval = 2.5) {
        guard field.waitForExistence(timeout: timeout), field.isHittable else { return }
        field.tap()
        if let existing = field.value as? String, !existing.isEmpty, existing != field.label {
            let delete = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count)
            field.typeText(delete)
        }
        field.typeText(value)
    }
}
