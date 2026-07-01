import XCTest
@testable import Macmd

final class PaneColumnTests: SandboxTestCase {

    func test_startsWithSingleTab() {
        let col = PaneColumn(directory: root)
        XCTAssertEqual(col.tabs.count, 1)
        XCTAssertEqual(col.activeTab, 0)
        XCTAssertEqual(col.current.directory, root)
    }

    func test_newTab_addsAndActivates() {
        let sub = makeDir("sub")
        let col = PaneColumn(directory: root)
        col.newTab(from: sub)
        XCTAssertEqual(col.tabs.count, 2)
        XCTAssertEqual(col.activeTab, 1)
        XCTAssertEqual(col.current.directory, sub)
    }

    func test_nextTab_wrapsAround() {
        let col = PaneColumn(directory: root)
        col.newTab(from: makeDir("a"))
        col.newTab(from: makeDir("b")) // tabs: [root, a, b], active=2
        col.nextTab()
        XCTAssertEqual(col.activeTab, 0)
        col.nextTab()
        XCTAssertEqual(col.activeTab, 1)
    }

    func test_nextTab_singleTabIsNoop() {
        let col = PaneColumn(directory: root)
        col.nextTab()
        XCTAssertEqual(col.activeTab, 0)
    }

    func test_selectTab_boundsChecked() {
        let col = PaneColumn(directory: root)
        col.newTab(from: makeDir("a"))
        col.selectTab(0)
        XCTAssertEqual(col.activeTab, 0)
        col.selectTab(99) // out of range -> ignored
        XCTAssertEqual(col.activeTab, 0)
    }

    func test_closeCurrentTab_keepsAtLeastOne() {
        let col = PaneColumn(directory: root)
        col.closeCurrentTab() // only one tab -> no-op
        XCTAssertEqual(col.tabs.count, 1)
    }

    func test_closeTab_adjustsActiveIndex() {
        let col = PaneColumn(directory: root)
        col.newTab(from: makeDir("a"))
        col.newTab(from: makeDir("b")) // [root, a, b], active=2

        col.closeTab(at: 0)            // removing a tab before active shifts active down
        XCTAssertEqual(col.tabs.count, 2)
        XCTAssertEqual(col.activeTab, 1)
        XCTAssertEqual(col.current.directory.lastPathComponent, "b")

        col.closeTab(at: 1)            // remove active (last) -> clamps
        XCTAssertEqual(col.tabs.count, 1)
        XCTAssertEqual(col.activeTab, 0)
    }
}
