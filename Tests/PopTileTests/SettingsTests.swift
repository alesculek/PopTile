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

    // MARK: - Smart gaps default

    func testDefaultSmartGaps() {
        XCTAssertTrue(settings.smartGaps)
    }

    // MARK: - Stacking with mouse default

    func testDefaultStackingWithMouse() {
        XCTAssertTrue(settings.stackingWithMouse)
    }
}
