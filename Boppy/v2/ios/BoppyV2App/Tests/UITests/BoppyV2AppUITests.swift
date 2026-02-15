import XCTest

final class BoppyV2AppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOwnerPrimaryButtonsAcrossTabs() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["auth.continueOwner"].waitForExistence(timeout: 5))
        app.buttons["auth.continueOwner"].tap()

        XCTAssertTrue(app.buttons["tab.feed"].waitForExistence(timeout: 10))

        app.buttons["tab.feed"].tap()
        tapIfExists(app.buttons["feed.refresh"])
        tapIfExists(app.buttons["feed.openThreads"])
        tapIfExists(app.otherElements["feed.thread.card"].firstMatch)
        tapIfExists(app.buttons["feed.closeThreads"])
        tapIfExists(app.buttons["feed.createChannel"])
        tapIfExists(app.buttons["feed.createInvite"])
        tapIfExists(app.buttons["feed.publishPost"])

        app.buttons["tab.orders"].tap()
        tapIfExists(app.buttons["orders.menu"])
        tapIfExists(app.buttons["orders.refresh"])
        tapIfExists(app.buttons["orders.filter.all"])
        tapIfExists(app.buttons["orders.filter.pending"])
        tapIfExists(app.buttons["orders.filter.active"])
        tapIfExists(app.buttons["orders.filter.done"])
        tapIfExists(app.buttons["orders.toggleTimeline"].firstMatch)
        tapIfExists(app.buttons["orders.updateStatus"])
        tapIfExists(app.buttons["orders.assignDriver"])

        app.buttons["tab.dispatch"].tap()
        tapIfExists(app.buttons["dispatch.optimizeRoute"])
        tapIfExists(app.buttons["dispatch.refresh"])
        tapIfExists(app.buttons["dispatch.saveRouteChanges"])
        tapIfExists(app.buttons["dispatch.optimizeInline"])
        tapIfExists(app.buttons["dispatch.recenterInline"])
        tapIfExists(app.buttons["dispatch.openAppleMaps"])
        tapIfExists(app.buttons["dispatch.stop.details"].firstMatch)
        tapIfExists(app.buttons["dispatch.stop.details.done"])
        tapIfExists(app.buttons["dispatch.stop.complete"].firstMatch)
        tapIfExists(app.buttons["dispatch.stop.moveUp"].firstMatch)
        tapIfExists(app.buttons["dispatch.stop.moveDown"].firstMatch)
        tapIfExists(app.buttons["dispatch.buildRoute"])

        app.buttons["tab.profile"].tap()
        tapIfExists(app.buttons["profile.refreshAdmin"])
        tapIfExists(app.buttons["profile.channelFilter.active"])
        tapIfExists(app.buttons["profile.channelFilter.archived"])
        tapIfExists(app.buttons["profile.selectChannel"].firstMatch)
        tapIfExists(app.buttons["profile.archiveChannel"].firstMatch)
        tapIfExists(app.buttons["profile.createInvite"])
        tapIfExists(app.buttons["profile.generateInvite"])
        tapIfExists(app.buttons["profile.inventory.decrement"])
        tapIfExists(app.buttons["profile.inventory.increment"])
        tapIfExists(app.buttons["profile.inventory.addSample"])
        tapIfExists(app.buttons["profile.inventory.refresh"])
        tapIfExists(app.buttons["profile.viewSensitiveActions"])
    }

    func testDriverPrimaryButtonsAcrossTabs() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["auth.continueDriver"].waitForExistence(timeout: 5))
        app.buttons["auth.continueDriver"].tap()

        XCTAssertTrue(app.buttons["tab.orders"].waitForExistence(timeout: 10))

        app.buttons["tab.orders"].tap()
        tapIfExists(app.buttons["orders.menu"])
        tapIfExists(app.buttons["orders.refresh"])
        tapIfExists(app.buttons["orders.filter.all"])
        tapIfExists(app.buttons["orders.filter.pending"])
        tapIfExists(app.buttons["orders.filter.active"])
        tapIfExists(app.buttons["orders.filter.done"])
        tapIfExists(app.buttons["orders.toggleTimeline"].firstMatch)

        app.buttons["tab.dispatch"].tap()
        tapIfExists(app.buttons["dispatch.refresh"])
        tapIfExists(app.buttons["dispatch.saveRouteChanges"])
        tapIfExists(app.buttons["dispatch.stop.call"])
        tapIfExists(app.buttons["dispatch.stop.details"])
        tapIfExists(app.buttons["dispatch.stop.details.done"])
        tapIfExists(app.buttons["dispatch.stop.complete"])

        app.buttons["tab.profile"].tap()
        tapIfExists(app.buttons["profile.signOut"])
    }

    func testFollowerQuickOrderFlowButtons() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["auth.continueFollower"].waitForExistence(timeout: 5))
        app.buttons["auth.continueFollower"].tap()

        XCTAssertTrue(app.buttons["tab.feed"].waitForExistence(timeout: 10))

        app.buttons["tab.feed"].tap()
        tapIfExists(app.buttons["feed.refresh"])
        tapIfExists(app.buttons["feed.openThreads"])
        tapIfExists(app.otherElements["feed.thread.card"].firstMatch)
        tapIfExists(app.buttons["feed.closeThreads"])
        tapIfExists(app.buttons["feed.joinChannel"])
        tapIfExists(app.buttons["feed.post.reaction"].firstMatch)

        let quickOrderButton = app.buttons["feed.post.quickOrder"].firstMatch
        if quickOrderButton.waitForExistence(timeout: 6), quickOrderButton.isHittable {
            quickOrderButton.tap()
            tapIfExists(app.buttons["feed.quickOrder.standard"])
            fillIfExists(app.textFields["Street"], value: "123 Main St")
            fillIfExists(app.textFields["City"], value: "Austin")
            fillIfExists(app.textFields["State"], value: "TX")
            fillIfExists(app.textFields["ZIP"], value: "78701")
            if app.buttons["orderSheet.submit"].waitForExistence(timeout: 2), app.buttons["orderSheet.submit"].isEnabled {
                app.buttons["orderSheet.submit"].tap()
            } else {
                tapIfExists(app.buttons["orderSheet.cancel"])
            }
        }

        app.buttons["tab.orders"].tap()
        tapIfExists(app.buttons["orders.menu"])
        tapIfExists(app.buttons["orders.refresh"])
        tapIfExists(app.buttons["orders.filter.all"])
        tapIfExists(app.buttons["orders.filter.pending"])
        tapIfExists(app.buttons["orders.filter.active"])
        tapIfExists(app.buttons["orders.filter.done"])
        tapIfExists(app.buttons["orders.toggleTimeline"].firstMatch)

        app.buttons["tab.profile"].tap()
        tapIfExists(app.buttons["profile.signOut"])
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("-force-local-demo")
        app.launch()
        return app
    }

    private func tapIfExists(_ element: XCUIElement, timeout: TimeInterval = 2.5) {
        guard element.waitForExistence(timeout: timeout), element.isHittable else { return }
        element.tap()
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
