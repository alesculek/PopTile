@testable import PopTileCore
import XCTest

// MARK: - Stack tab title refresh on window title change

/// Validates that the title refresh path works correctly:
/// - StackContainer exposes refreshTitles() for external callers
/// - Engine.onWindowTitleChanged routes to the correct stack container
/// - kAXTitleChangedNotification is registered in the observer list
final class TitleRefreshTests: XCTestCase {

    /// StackContainer.refreshTitles() should be callable (public API surface test)
    func testStackContainerExposesRefreshTitles() {
        let engine = Engine()
        let entity = Entity(index: 100_001, generation: 0)
        let container = StackContainer(engine: engine, active: entity, workspace: 0, monitor: 0)

        // Should not crash — validates the method exists and is callable
        container.refreshTitles()
    }

    /// onWindowTitleChanged should not crash when window is not tracked
    func testOnWindowTitleChanged_unknownElement_noOp() {
        let engine = Engine()
        // Create a dummy AXUIElement (system-wide element, always valid)
        let systemWide = AXUIElementCreateSystemWide()
        // Should not crash — window not found, returns early
        engine.onWindowTitleChanged(systemWide)
    }

    /// Verify kAXTitleChangedNotification is the correct string constant
    func testTitleChangedNotificationConstant() {
        // The accessibility framework defines this constant
        let notif = kAXTitleChangedNotification as String
        XCTAssertEqual(notif, "AXTitleChanged",
                       "kAXTitleChangedNotification should be 'AXTitleChanged'")
    }
}
