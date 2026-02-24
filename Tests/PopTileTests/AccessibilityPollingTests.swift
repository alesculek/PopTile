@testable import PopTileCore
import XCTest

// MARK: - Accessibility permission polling

final class AccessibilityPollingTests: XCTestCase {

    func testEngineStartsWithoutCrashWhenAccessibilityGranted() {
        // When accessibility is already granted (as in test environment),
        // start() should proceed directly to startEngine() without polling
        let engine = Engine()
        // start() will either start immediately or begin polling —
        // neither should crash
        engine.start()
        engine.stop()
    }

    func testEngineStopCleansUpPollingTimer() {
        let engine = Engine()
        engine.start()
        engine.stop()
        // Calling stop multiple times should not crash
        engine.stop()
    }
}
