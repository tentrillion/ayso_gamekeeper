import XCTest

@MainActor
final class GamekeeperUITests: XCTestCase {
  private func launchGame(location: String? = nil, idleDelay: String = "5") -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["GAMEKEEPER_TEST_STORE"] = UUID().uuidString
    app.launchArguments = ["-idleDelay", idleDelay]
    app.launch()
    XCTAssertTrue(app.buttons["newGame"].waitForExistence(timeout: 10))
    app.buttons["newGame"].tap()
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
    if let location {
      let field = app.textFields["gameLocation"]
      field.tap()
      field.typeText(location)
    }
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
    let record = XCTAttachment(screenshot: app.screenshot())
    record.name = "Colored shirts in game record"
    record.lifetime = .keepAlways
    add(record)
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

  func testEndGameReturnsToLibraryAndAllowsAnotherGame() {
    let app = launchGame(location: "Practice Field", idleDelay: "0")
    app.buttons["goalHome"].tap()
    app.buttons["1"].tap()
    app.buttons["2"].tap()
    app.buttons["saveEvent"].tap()
    app.buttons["backToGames"].tap()
    XCTAssertTrue(app.buttons["resumeGame"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["newGame"].isEnabled)
    app.buttons["resumeGame"].tap()
    XCTAssertEqual(app.staticTexts["scoreHome"].label, "1")

    app.buttons["End half"].tap()
    app.buttons.matching(identifier: "confirmEndPeriod").firstMatch.tap()
    XCTAssertTrue(app.buttons["Start second half"].waitForExistence(timeout: 3))
    app.buttons["Start second half"].tap()
    let clockFrame = app.staticTexts["gameClock"].frame
    let outsideConfirmation = app.coordinate(withNormalizedOffset: .zero)
      .withOffset(CGVector(dx: clockFrame.midX, dy: clockFrame.midY))
    app.buttons["End game"].tap()
    outsideConfirmation.tap()
    XCTAssertTrue(app.buttons["goalHome"].exists)
    app.buttons["End game"].tap()
    app.buttons.matching(identifier: "confirmEndPeriod").firstMatch.tap()

    XCTAssertTrue(app.staticTexts["previousGames"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["newGame"].isEnabled)
    XCTAssertTrue(app.staticTexts["Practice Field"].exists)
    XCTAssertFalse(app.staticTexts["gameDate"].label.isEmpty)
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Previous games after final whistle"
    screenshot.lifetime = .keepAlways
    add(screenshot)

    for _ in 0..<2 {
      app.buttons["previousGame"].tap()
      XCTAssertTrue(
        app.staticTexts["Full time"].waitForExistence(timeout: 3)
          || app.staticTexts["FULL TIME"].exists)
      XCTAssertEqual(app.staticTexts["scoreHome"].label, "1")
      app.buttons["Record"].tap()
      XCTAssertTrue(app.staticTexts["Player #12"].waitForExistence(timeout: 3))
      XCTAssertTrue(app.staticTexts["Practice Field"].exists)
      app.buttons["Done"].tap()
      app.buttons["backToGames"].tap()
      XCTAssertTrue(app.buttons["newGame"].waitForExistence(timeout: 3))
    }
    app.buttons["newGame"].tap()
    app.buttons["Create"].tap()
    XCTAssertTrue(app.buttons["Start first half"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["scoreHome"].label, "0")
    app.buttons["backToGames"].tap()
    XCTAssertEqual(app.buttons.matching(identifier: "previousGame").count, 1)
    app.terminate()
    app.launch()
    XCTAssertTrue(app.buttons["Start first half"].waitForExistence(timeout: 10))
    app.buttons["backToGames"].tap()
    XCTAssertEqual(app.buttons.matching(identifier: "previousGame").count, 1)
    XCTAssertTrue(app.staticTexts["Practice Field"].exists)
  }
}
