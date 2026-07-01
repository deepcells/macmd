import XCTest
@testable import Macmd

final class PaneModelTests: SandboxTestCase {

    func test_init_listsDirectory_dirsFirst() {
        makeDir("zdir")
        makeDir("adir")
        makeFile("a.txt")
        makeFile("b.txt")

        let pane = PaneModel(directory: root)
        // dirs first (sorted), then files (sorted)
        XCTAssertEqual(names(pane.entries), ["adir", "zdir", "a.txt", "b.txt"])
        XCTAssertEqual(pane.cursorIndex, 0)
    }

    func test_naturalSortOrder() {
        makeFile("file2.txt")
        makeFile("file10.txt")
        makeFile("file1.txt")
        let pane = PaneModel(directory: root)
        XCTAssertEqual(names(pane.entries), ["file1.txt", "file2.txt", "file10.txt"])
    }

    func test_enterDirectory_refreshesEntriesAndPushesHistory() {
        let sub = makeDir("sub")
        makeFile("inside.txt", in: sub)
        makeFile("outside.txt")

        let pane = PaneModel(directory: root)
        XCTAssertTrue(names(pane.entries).contains("outside.txt"))

        pane.enterDirectory(sub)
        XCTAssertEqual(pane.directory, sub)
        XCTAssertEqual(names(pane.entries), ["inside.txt"])       // list refreshed
        XCTAssertFalse(names(pane.entries).contains("outside.txt"))
        XCTAssertTrue(pane.history.canBack)
    }

    func test_openCursor_entersDirectory() {
        let sub = makeDir("sub")
        makeFile("inside.txt", in: sub)
        let pane = PaneModel(directory: root)
        pane.cursorIndex = try! XCTUnwrap(pane.entries.firstIndex { $0.name == "sub" })
        pane.openCursor()
        XCTAssertEqual(pane.directory, sub)
    }

    func test_goUp_placesCursorOnChildFolder() {
        let sub = makeDir("sub")
        makeDir("other")
        makeFile("inside.txt", in: sub)

        let pane = PaneModel(directory: sub)
        pane.goUp()
        XCTAssertEqual(pane.directory, root)
        XCTAssertEqual(pane.cursorEntry?.name, "sub")
    }

    func test_backForwardNavigation() {
        let sub = makeDir("sub")
        let pane = PaneModel(directory: root)
        pane.enterDirectory(sub)
        XCTAssertEqual(pane.directory, sub)

        pane.goBack()
        XCTAssertEqual(pane.directory, root)

        pane.goForward()
        XCTAssertEqual(pane.directory, sub)
    }

    func test_enterDirectoryClearsSelectionAndFilter() {
        let sub = makeDir("sub")
        makeFile("a.txt")
        let pane = PaneModel(directory: root)
        pane.selection.insert(pane.entries[0].url)
        pane.appendFilter("a")
        XCTAssertFalse(pane.selection.isEmpty)

        pane.enterDirectory(sub)
        XCTAssertTrue(pane.selection.isEmpty)
        XCTAssertEqual(pane.filterText, "")
    }

    func test_moveCursor_clampsToBounds() {
        makeFile("a.txt"); makeFile("b.txt"); makeFile("c.txt")
        let pane = PaneModel(directory: root)

        pane.moveCursor(-5)
        XCTAssertEqual(pane.cursorIndex, 0)

        pane.moveCursor(100)
        XCTAssertEqual(pane.cursorIndex, pane.entries.count - 1)

        pane.cursorTop()
        XCTAssertEqual(pane.cursorIndex, 0)
        pane.cursorBottom()
        XCTAssertEqual(pane.cursorIndex, pane.entries.count - 1)
    }

    func test_toggleSelect_addsAndAdvancesCursor() {
        makeFile("a.txt"); makeFile("b.txt")
        let pane = PaneModel(directory: root)
        let first = pane.entries[0].url

        pane.toggleSelectAtCursor()
        XCTAssertTrue(pane.selection.contains(first))
        XCTAssertEqual(pane.cursorIndex, 1) // advanced

        pane.cursorIndex = 0
        pane.toggleSelectAtCursor() // toggle off
        XCTAssertFalse(pane.selection.contains(first))
    }

    func test_selectAll() {
        makeDir("d"); makeFile("a.txt"); makeFile("b.txt")
        let pane = PaneModel(directory: root)
        pane.selectAll()
        XCTAssertEqual(pane.selection.count, pane.entries.count)
    }

    func test_actionTargets_prefersSelectionThenCursor() {
        makeFile("a.txt"); makeFile("b.txt")
        let pane = PaneModel(directory: root)

        // no selection -> cursor row
        XCTAssertEqual(pane.actionTargets, [pane.entries[0].url])

        // with selection -> selection
        pane.selection = [pane.entries[1].url]
        XCTAssertEqual(pane.actionTargets, [pane.entries[1].url])
    }

    func test_filter_prefixMatchNarrowsAndRestores() {
        makeFile("apple.txt")
        makeFile("apricot.txt")
        makeFile("banana.txt")
        let pane = PaneModel(directory: root)
        XCTAssertEqual(pane.entries.count, 3)

        pane.appendFilter("ap") // prefix "ap"
        XCTAssertEqual(Set(names(pane.entries)), ["apple.txt", "apricot.txt"])

        pane.backspaceFilter() // "a" — prefix, banana excluded (starts with b)
        XCTAssertEqual(Set(names(pane.entries)), ["apple.txt", "apricot.txt"])

        pane.clearFilter()
        XCTAssertEqual(pane.entries.count, 3)
    }

    func test_filter_isPrefixNotSubstring() {
        makeFile("readme.txt")
        makeFile("me.txt")
        let pane = PaneModel(directory: root)
        pane.appendFilter("me") // only "me.txt" starts with "me"; "readme.txt" contains but doesn't start
        XCTAssertEqual(names(pane.entries), ["me.txt"])
    }

    func test_toggleHidden() {
        makeFile("visible.txt")
        makeFile(".secret")
        let pane = PaneModel(directory: root)
        XCTAssertFalse(names(pane.entries).contains(".secret"))

        pane.toggleHidden()
        XCTAssertTrue(names(pane.entries).contains(".secret"))

        pane.toggleHidden()
        XCTAssertFalse(names(pane.entries).contains(".secret"))
    }

    func test_setSort_togglesDirectionAndKeepsDirsFirst() {
        makeDir("adir"); makeDir("bdir")
        makeFile("a.txt"); makeFile("b.txt")
        let pane = PaneModel(directory: root)

        // default name ascending
        XCTAssertEqual(names(pane.entries), ["adir", "bdir", "a.txt", "b.txt"])

        pane.setSort(.name) // same field -> toggle to descending
        XCTAssertFalse(pane.sortAscending)
        // dirs still grouped first, but in descending order within groups
        XCTAssertEqual(names(pane.entries), ["bdir", "adir", "b.txt", "a.txt"])

        pane.setSort(.size) // new field -> ascending, dirs first
        XCTAssertTrue(pane.sortAscending)
        XCTAssertTrue(pane.entries[0].isDirectory)
        XCTAssertTrue(pane.entries[1].isDirectory)
    }

    func test_rename_commitMovesCursorToRenamedItem() {
        makeFile("a.txt"); makeFile("m.txt"); makeFile("z.txt")
        let pane = PaneModel(directory: root)
        let target = pane.entries.first { $0.name == "m.txt" }!.url

        pane.beginRename(target)
        XCTAssertEqual(pane.editingURL, target)

        XCTAssertTrue(pane.commitRename(to: "n.txt"))
        XCTAssertNil(pane.editingURL)
        XCTAssertTrue(names(pane.entries).contains("n.txt"))
        XCTAssertFalse(names(pane.entries).contains("m.txt"))
        XCTAssertEqual(pane.cursorEntry?.name, "n.txt") // cursor follows renamed item
    }

    func test_rename_emptyOrUnchangedNameIsNoop() {
        makeFile("keep.txt")
        let pane = PaneModel(directory: root)
        let target = pane.entries[0].url

        pane.beginRename(target)
        XCTAssertFalse(pane.commitRename(to: "   ")) // empty
        XCTAssertTrue(names(pane.entries).contains("keep.txt"))

        pane.beginRename(target)
        XCTAssertFalse(pane.commitRename(to: "keep.txt")) // unchanged
        XCTAssertTrue(names(pane.entries).contains("keep.txt"))
    }

    func test_rename_cancelLeavesFileUntouched() {
        makeFile("orig.txt")
        let pane = PaneModel(directory: root)
        pane.beginRename(pane.entries[0].url)
        pane.cancelRename()
        XCTAssertNil(pane.editingURL)
        XCTAssertTrue(names(pane.entries).contains("orig.txt"))
    }

    func test_reload_picksUpNewFileAndKeepsCursor() {
        makeFile("a.txt"); makeFile("b.txt")
        let pane = PaneModel(directory: root)
        pane.cursorIndex = 1
        let cursorURL = pane.cursorEntry?.url

        makeFile("c.txt") // appears alphabetically after b
        pane.reload()
        XCTAssertTrue(names(pane.entries).contains("c.txt"))
        XCTAssertEqual(pane.cursorEntry?.url, cursorURL) // cursor stays on same item
    }
}
