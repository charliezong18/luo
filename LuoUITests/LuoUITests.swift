import XCTest

/// Drives the real app on a simulator: the left-edge swipe-back on every level
/// (the complaint that triggered this work), plus the 卦象 grid and 按卦象查
/// screens. Screenshots are attached (keepAlways) so a script can export them
/// from the .xcresult bundle.
final class LuoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    /// The system back gesture: a drag that starts on the left screen edge.
    private func swipeBackFromLeftEdge() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .default, thenHoldForDuration: 0.1)
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSutraDetailSwipesBackToListThenHome() {
        app.buttons["读经"].tap()
        XCTAssertTrue(app.buttons["卦象"].waitForExistence(timeout: 5), "读经 list did not open")
        app.staticTexts["乾"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["第 1 卦"].waitForExistence(timeout: 5), "detail did not push")
        snap("01-sutra-detail")
        swipeBackFromLeftEdge()
        XCTAssertTrue(app.staticTexts["屯"].waitForExistence(timeout: 5), "swipe did not pop detail → list")
        XCTAssertFalse(app.navigationBars["第 1 卦"].exists)
        swipeBackFromLeftEdge()
        XCTAssertTrue(app.buttons["六爻"].waitForExistence(timeout: 5), "swipe did not pop list → home")
        snap("00-home")
    }

    func testRitualScreenSwipesBackHome() {
        app.buttons["六爻"].tap()
        XCTAssertTrue(app.staticTexts["心中默念所问"].waitForExistence(timeout: 8), "六爻 did not open")
        swipeBackFromLeftEdge()
        XCTAssertTrue(app.buttons["读经"].waitForExistence(timeout: 5), "swipe did not pop 六爻 → home")
    }

    func testCastLogSwipesBackHome() {
        app.buttons["卦例记录"].tap()
        XCTAssertTrue(app.navigationBars["卦例记录"].waitForExistence(timeout: 5), "卦例记录 did not open")
        swipeBackFromLeftEdge()
        XCTAssertTrue(app.buttons["读经"].waitForExistence(timeout: 5), "swipe did not pop 卦例记录 → home")
    }

    func testShapeGridOpensDetailAndSwipesBack() {
        app.buttons["读经"].tap()
        XCTAssertTrue(app.buttons["卦象"].waitForExistence(timeout: 5))
        app.buttons["卦象"].tap()
        let tai = app.buttons["grid.11"]
        XCTAssertTrue(tai.waitForExistence(timeout: 5), "grid cell for 泰 not found")
        snap("02-sutra-grid")
        tai.tap()
        XCTAssertTrue(app.navigationBars["第 11 卦"].waitForExistence(timeout: 5), "grid cell did not open 泰")
        swipeBackFromLeftEdge()
        XCTAssertTrue(app.buttons["grid.11"].waitForExistence(timeout: 5), "swipe did not return to grid")
    }

    func testLookupInputMapsToHexagramAndOpensDetail() {
        app.buttons["读经"].tap()
        XCTAssertTrue(app.buttons["查卦"].waitForExistence(timeout: 5))
        app.buttons["查卦"].tap()
        XCTAssertTrue(app.buttons["line.1"].waitForExistence(timeout: 5), "lookup did not open")
        XCTAssertTrue(app.staticTexts["第 1 卦"].exists, "blank slate should read 乾")
        // Break the top three lines: 乾 → 泰 (#11).
        app.buttons["line.4"].tap()
        app.buttons["line.5"].tap()
        app.buttons["line.6"].tap()
        XCTAssertTrue(app.staticTexts["第 11 卦"].waitForExistence(timeout: 3), "乾 with top three broken should be 泰")
        // 初九 动 → 变卦 升 (#46).
        app.buttons["changing.1"].tap()
        XCTAssertTrue(app.staticTexts["升"].waitForExistence(timeout: 3), "泰 初九动 should show 变卦 升")
        snap("03-lookup")
        app.buttons["读本卦 泰"].tap()
        XCTAssertTrue(app.navigationBars["第 11 卦"].waitForExistence(timeout: 5), "读本卦 did not open the detail")
        swipeBackFromLeftEdge()
        XCTAssertTrue(app.buttons["line.1"].waitForExistence(timeout: 5), "swipe did not return to lookup")
    }
}
