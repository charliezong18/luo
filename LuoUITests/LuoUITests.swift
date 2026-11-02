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
        // 本卦 lines carry the 动爻 mark (cinnabar ring); 变卦 is static.
        let present = app.descendants(matching: .any)["pair.lines.present"]
        XCTAssertTrue(present.waitForExistence(timeout: 3), "本卦 line glyph not found")
        XCTAssertTrue(present.label.contains("动爻：初爻"), "本卦 should mark 初爻 动, got: \(present.label)")
        let resulting = app.descendants(matching: .any)["pair.lines.resulting"]
        XCTAssertTrue(resulting.exists, "变卦 line glyph not found")
        XCTAssertTrue(resulting.label.contains("无动爻"), "变卦 should be static, got: \(resulting.label)")
        snap("03-lookup")
        app.buttons["读本卦 泰"].tap()
        XCTAssertTrue(app.navigationBars["第 11 卦"].waitForExistence(timeout: 5), "读本卦 did not open the detail")
        swipeBackFromLeftEdge()
        XCTAssertTrue(app.buttons["line.1"].waitForExistence(timeout: 5), "swipe did not return to lookup")
    }

    /// Six real throws through the 掷 button → the 本卦/变卦 result renders with
    /// the line glyphs; the auto-saved Cast then opens in 卦例记录 detail.
    func testRitualResultAndCastLogDetailShowLineGlyphs() {
        app.buttons["六爻"].tap()
        let cast = app.buttons["掷"]
        XCTAssertTrue(cast.waitForExistence(timeout: 8), "六爻 did not open")
        for i in 1...6 {
            let ready = NSPredicate { _, _ in cast.exists && cast.isEnabled }
            let exp = expectation(for: ready, evaluatedWith: nil)
            wait(for: [exp], timeout: 30)
            XCTAssertTrue(cast.isEnabled, "掷 not ready for throw \(i)")
            cast.tap()
        }
        XCTAssertTrue(app.buttons["再掷"].waitForExistence(timeout: 30), "cast did not complete after 6 throws")
        let present = app.descendants(matching: .any)["pair.lines.present"]
        XCTAssertTrue(present.waitForExistence(timeout: 5), "result 本卦 line glyph not found")
        snap("04-ritual-result")

        swipeBackFromLeftEdge()
        XCTAssertTrue(app.buttons["卦例记录"].waitForExistence(timeout: 5))
        app.buttons["卦例记录"].tap()
        XCTAssertTrue(app.navigationBars["卦例记录"].waitForExistence(timeout: 5))
        let firstRow = app.cells.firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "auto-saved cast not in 卦例记录")
        firstRow.tap()
        XCTAssertTrue(app.navigationBars["卦记"].waitForExistence(timeout: 5), "卦记 detail did not open")
        XCTAssertTrue(app.descendants(matching: .any)["pair.lines.present"].waitForExistence(timeout: 5),
                      "卦记 本卦 line glyph not found")
        snap("05-castlog-detail")
    }
}
