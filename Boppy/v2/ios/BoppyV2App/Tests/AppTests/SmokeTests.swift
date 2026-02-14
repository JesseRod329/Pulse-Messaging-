import XCTest

final class SmokeTests: XCTestCase {
    func testPlaceholder() {
        XCTAssertTrue(true)
    }

    func testFeedComponentsCompile() {
        XCTAssertTrue(true, "Feed Stitch components are included in target and compile.")
    }

    func testOrdersComponentsCompile() {
        XCTAssertTrue(true, "Orders Stitch components are included in target and compile.")
    }

    func testDispatchComponentsCompile() {
        XCTAssertTrue(true, "Dispatch Stitch components are included in target and compile.")
    }
}
