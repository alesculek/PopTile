@testable import PopTileCore
import XCTest

final class SettingsTests: XCTestCase {

    private var settings: Settings!

    override func setUp() {
        super.setUp()
        settings = Settings()
        // Reset to defaults for test isolation
        UserDefaults.standard.removeObject(forKey: "tilingDisplayMode")
        UserDefaults.standard.removeObject(forKey: "maxTilesPerMonitor")
        UserDefaults.standard.removeObject(forKey: "gapOuter")
        UserDefaults.standard.removeObject(forKey: "gapInner")
    }

    // MARK: - Display mode

    func testDefaultDisplayMode() {
        XCTAssertEqual(settings.tilingDisplayMode, "all")
    }

    func testSetDisplayMode() {
        settings.tilingDisplayMode = "main"
        XCTAssertEqual(settings.tilingDisplayMode, "main")
        settings.tilingDisplayMode = "external"
        XCTAssertEqual(settings.tilingDisplayMode, "external")
        settings.tilingDisplayMode = "all"
        XCTAssertEqual(settings.tilingDisplayMode, "all")
    }

    func testShouldTileMonitorAllMode() {
        settings.tilingDisplayMode = "all"
        // In "all" mode, all valid monitor indices should be tiled
        // (may fail if no screens are connected, but at least index 0 should work)
        if !NSScreen.screens.isEmpty {
            XCTAssertTrue(settings.shouldTileMonitor(0))
        }
    }

    func testShouldTileMonitorInvalidIndex() {
        XCTAssertFalse(settings.shouldTileMonitor(999))
    }

    // MARK: - Gap defaults

    func testDefaultGapOuter() {
        XCTAssertEqual(settings.gapOuter, 4)
    }

    func testDefaultGapInner() {
        XCTAssertEqual(settings.gapInner, 4)
    }

    func testSetGap() {
        settings.gapOuter = 8
        XCTAssertEqual(settings.gapOuter, 8)
        settings.gapInner = 12
        XCTAssertEqual(settings.gapInner, 12)
    }

    // MARK: - Float exceptions

    func testShouldFloatSystemPreferences() {
        XCTAssertTrue(settings.shouldFloat(bundleId: "com.apple.systempreferences"))
    }

    func testShouldNotFloatUnknownApp() {
        XCTAssertFalse(settings.shouldFloat(bundleId: "com.example.myapp"))
    }

    func testShouldNotFloatNil() {
        XCTAssertFalse(settings.shouldFloat(bundleId: nil))
    }

    // MARK: - Float exception management

    func testAddFloatException() {
        let bundleId = "com.test.floatme"
        settings.addFloatException(bundleId)
        XCTAssertTrue(settings.shouldFloat(bundleId: bundleId))
        // Cleanup
        settings.removeFloatException(bundleId)
    }

    func testRemoveFloatException() {
        let bundleId = "com.test.removeme"
        settings.addFloatException(bundleId)
        XCTAssertTrue(settings.shouldFloat(bundleId: bundleId))
        settings.removeFloatException(bundleId)
        XCTAssertFalse(settings.shouldFloat(bundleId: bundleId))
    }

    func testAddFloatExceptionNoDuplicates() {
        let bundleId = "com.test.nodup"
        let countBefore = settings.floatExceptions.count
        settings.addFloatException(bundleId)
        settings.addFloatException(bundleId)  // duplicate
        XCTAssertEqual(settings.floatExceptions.filter { $0 == bundleId }.count, 1)
        // Cleanup
        settings.removeFloatException(bundleId)
    }

    func testDefaultFloatExceptionsIncludeCalculator() {
        XCTAssertTrue(settings.shouldFloat(bundleId: "com.apple.Calculator"))
    }

    func testDefaultFloatExceptionsIncludeDictionary() {
        XCTAssertTrue(settings.shouldFloat(bundleId: "com.apple.Dictionary"))
    }

    func testDefaultFloatExceptionsExcludeSafari() {
        // Safari was removed from defaults — full-size apps should tile
        XCTAssertFalse(settings.shouldFloat(bundleId: "com.apple.Safari"))
    }

    func testDefaultFloatExceptionsExcludePreview() {
        XCTAssertFalse(settings.shouldFloat(bundleId: "com.apple.Preview"))
    }

    // MARK: - Smart gaps default

    func testDefaultSmartGaps() {
        XCTAssertTrue(settings.smartGaps)
    }

    // MARK: - Stacking with mouse default

    func testDefaultStackingWithMouse() {
        XCTAssertTrue(settings.stackingWithMouse)
    }
}
