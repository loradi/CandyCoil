import XCTest
final class CandyCoilUITests: XCTestCase {
    func testPlayPauseAndReturnToLobby() {
        let app = XCUIApplication()
        app.launch()
        let play = app.buttons["play"]
        XCTAssertTrue(play.waitForExistence(timeout: 10))
        if !play.isHittable { app.swipeUp() }
        play.tap()
        let pause = app.buttons["PAUSE"]
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        pause.tap()
        XCTAssertTrue(app.buttons["KEEP PLAYING"].waitForExistence(timeout: 5))
        app.buttons["KEEP PLAYING"].tap()
        pause.tap()
        app.buttons["Back to home"].tap()
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Candy Coil lobby"; shot.lifetime = .keepAlways; add(shot)
    }
}
