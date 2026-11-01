import XCTest

@MainActor
final class GamekeeperUITests: XCTestCase {
  private func launchGame() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["GAMEKEEPER_TEST_STORE"] = UUID().uuidString
    app.launchArguments = ["-idleDelay", "5"]
    app.launch()
    XCTAssertTrue(app.buttons["Set up a game"].waitForExistence(timeout: 10))
    app.buttons["Set up a game"].tap()
    app.buttons["jerseyPickerHome"].tap()
    XCTAssertTrue(app.buttons["Light blue"].waitForExistence(timeout: 3))
    let dropdown = XCTAttachment(screenshot: app.screenshot())
    dropdown.name = "Colored jersey dropdown"
    dropdown.lifetime = .keepAlways
    add(dropdown)
    app.buttons["Light blue"].tap()
    app.buttons["jerseyPickerAway"].tap()
    app.buttons["Gold"].tap()
    let colors = XCTAttachment(screenshot: app.screenshot())
    colors.name = "Selected jersey colors"
    colors.lifetime = .keepAlways
    add(colors)
    app.buttons["Create"].tap()
    XCTAssertTrue(app.buttons["Start first half"].waitForExistence(timeout: 5))
    app.buttons["Start first half"].tap()
    return app
  }

  func testGoalEntryAndRelaunch() {
    let app = launchGame()
    XCTAssertTrue(app.buttons["goalHome"].isHittable)
    XCTAssertTrue(app.buttons["cardAway"].isHittable)
    XCTAssertTrue(app.buttons["blankScreen"].isHittable)
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Live game on iPhone 12 mini"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    app.buttons["goalHome"].tap()
    app.buttons["1"].tap()
    app.buttons["2"].tap()
    app.buttons["saveEvent"].tap()
    XCTAssertTrue(app.staticTexts["scoreHome"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["scoreHome"].label, "1")
    app.terminate()
    app.launch()
    XCTAssertTrue(app.staticTexts["scoreHome"].waitForExistence(timeout: 10))
    XCTAssertEqual(app.staticTexts["scoreHome"].label, "1")
    app.buttons["Record"].tap()
    XCTAssertTrue(app.staticTexts["Player #12"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Home: Home · Light blue"].exists)
    XCTAssertTrue(app.staticTexts["Away: Away · Gold"].exists)
  }

  func testBlankTapOnlyRevealsAndEntryStaysVisible() {
    let app = launchGame()
    let goal = app.buttons["goalHome"]
    let frame = goal.frame
    let point = app.coordinate(withNormalizedOffset: .zero)
      .withOffset(CGVector(dx: frame.midX, dy: frame.midY))
    app.buttons["blankScreen"].tap()
    let reveal = app.descendants(matching: .any).matching(identifier: "revealScreen").firstMatch
    XCTAssertTrue(reveal.waitForExistence(timeout: 3))
    point.tap()
    XCTAssertTrue(app.buttons["goalHome"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["saveEvent"].exists)
    XCTAssertEqual(app.staticTexts["scoreHome"].label, "0")
    app.buttons["goalHome"].tap()
    XCTAssertTrue(app.buttons["saveEvent"].waitForExistence(timeout: 3))
    XCTAssertFalse(reveal.waitForExistence(timeout: 6))
    XCTAssertTrue(app.buttons["saveEvent"].isHittable)
    app.buttons["Cancel"].tap()
    XCTAssertEqual(app.staticTexts["scoreHome"].label, "0")
    XCTAssertTrue(reveal.waitForExistence(timeout: 8))
  }
}
