import XCTest
@testable import Macmd

final class CommandRunnerTests: SandboxTestCase {

    private func index(of name: String, in pane: PaneModel) -> Int {
        pane.entries.firstIndex { $0.name == name } ?? -1
    }

    func test_switchPane_togglesActive() {
        let app = AppModel(leftDir: makeDir("l"), rightDir: makeDir("r"))
        XCTAssertEqual(app.active, .left)
        CommandRunner.run(.switchPane, app: app)
        XCTAssertEqual(app.active, .right)
        CommandRunner.run(.switchPane, app: app)
        XCTAssertEqual(app.active, .left)
    }

    func test_cursorCommands_moveWithinActivePane() {
        let l = makeDir("l")
        makeFile("a.txt", in: l); makeFile("b.txt", in: l); makeFile("c.txt", in: l)
        let app = AppModel(leftDir: l, rightDir: makeDir("r"))

        CommandRunner.run(.cursorDown, app: app)
        XCTAssertEqual(app.left.cursorIndex, 1)
        CommandRunner.run(.cursorBottom, app: app)
        XCTAssertEqual(app.left.cursorIndex, app.left.entries.count - 1)
        CommandRunner.run(.cursorTop, app: app)
        XCTAssertEqual(app.left.cursorIndex, 0)
    }

    func test_copyToOther_copiesActiveTargetsToInactivePane() {
        let l = makeDir("l"), r = makeDir("r")
        makeFile("f.txt", in: l)
        let app = AppModel(leftDir: l, rightDir: r)

        CommandRunner.run(.copyToOther, app: app)
        XCTAssertTrue(exists(r.appendingPathComponent("f.txt")))
        XCTAssertTrue(exists(l.appendingPathComponent("f.txt")))       // original stays
        XCTAssertTrue(names(app.right.entries).contains("f.txt"))       // inactive reloaded
    }

    func test_copyToOther_multiSelection() {
        let l = makeDir("l"), r = makeDir("r")
        makeFile("a.txt", in: l); makeFile("b.txt", in: l); makeFile("c.txt", in: l)
        let app = AppModel(leftDir: l, rightDir: r)
        app.left.selection = [
            l.appendingPathComponent("a.txt"),
            l.appendingPathComponent("c.txt"),
        ]
        CommandRunner.run(.copyToOther, app: app)
        XCTAssertTrue(exists(r.appendingPathComponent("a.txt")))
        XCTAssertTrue(exists(r.appendingPathComponent("c.txt")))
        XCTAssertFalse(exists(r.appendingPathComponent("b.txt")))
        XCTAssertTrue(app.left.selection.isEmpty)                       // cleared after op
    }

    func test_moveToOther_relocatesAndReloadsBothPanes() {
        let l = makeDir("l"), r = makeDir("r")
        makeFile("m.txt", in: l)
        let app = AppModel(leftDir: l, rightDir: r)

        CommandRunner.run(.moveToOther, app: app)
        XCTAssertFalse(exists(l.appendingPathComponent("m.txt")))
        XCTAssertTrue(exists(r.appendingPathComponent("m.txt")))
        XCTAssertFalse(names(app.left.entries).contains("m.txt"))       // active reloaded
        XCTAssertTrue(names(app.right.entries).contains("m.txt"))       // inactive reloaded
    }

    func test_delete_movesTargetToTrash() {
        let l = makeDir("l")
        let file = makeFile("d.txt", in: l)
        let app = AppModel(leftDir: l, rightDir: makeDir("r"))

        CommandRunner.run(.delete, app: app)
        XCTAssertFalse(exists(file))
        XCTAssertFalse(names(app.left.entries).contains("d.txt"))
    }

    func test_permanentDelete_removesTarget() {
        let l = makeDir("l")
        let file = makeFile("p.txt", in: l)
        let app = AppModel(leftDir: l, rightDir: makeDir("r"))

        CommandRunner.run(.permanentDelete, app: app)
        XCTAssertFalse(exists(file))
    }

    func test_newFolder_promptCreatesFolderAndReloads() throws {
        let l = makeDir("l")
        let app = AppModel(leftDir: l, rightDir: makeDir("r"))

        CommandRunner.run(.newFolder, app: app)
        let prompt = try XCTUnwrap(app.pendingPrompt)
        prompt.action("Made")

        XCTAssertTrue(exists(l.appendingPathComponent("Made")))
        XCTAssertTrue(names(app.left.entries).contains("Made"))
    }

    func test_newFolder_emptyNameDoesNothing() throws {
        let l = makeDir("l")
        let app = AppModel(leftDir: l, rightDir: makeDir("r"))
        CommandRunner.run(.newFolder, app: app)
        let prompt = try XCTUnwrap(app.pendingPrompt)
        prompt.action("   ") // whitespace only
        XCTAssertEqual(app.left.entries.count, 0)
    }

    func test_rename_beginsInlineEditThenCommits() throws {
        let l = makeDir("l")
        makeFile("old.txt", in: l)
        let app = AppModel(leftDir: l, rightDir: makeDir("r"))

        CommandRunner.run(.rename, app: app) // begins inline editing on the cursor row
        XCTAssertEqual(app.left.editingURL, l.appendingPathComponent("old.txt"))

        app.left.commitRename(to: "new.txt")
        XCTAssertNil(app.left.editingURL)
        XCTAssertFalse(exists(l.appendingPathComponent("old.txt")))
        XCTAssertTrue(exists(l.appendingPathComponent("new.txt")))
        XCTAssertTrue(names(app.left.entries).contains("new.txt"))
    }

    func test_focusLeftRightPaneCommands() {
        let app = AppModel(leftDir: makeDir("l"), rightDir: makeDir("r"))
        app.active = .right
        CommandRunner.run(.focusLeftPane, app: app)
        XCTAssertEqual(app.active, .left)
        CommandRunner.run(.focusRightPane, app: app)
        XCTAssertEqual(app.active, .right)
    }

    func test_newTab_opensTabFromActivePaneDirectory() {
        let l = makeDir("l")
        let sub = makeDir("sub", in: l)
        let app = AppModel(leftDir: l, rightDir: makeDir("r"))
        app.active = .left
        app.left.enterDirectory(sub)

        CommandRunner.run(.newTab, app: app)
        XCTAssertEqual(app.leftColumn.tabs.count, 2)
        XCTAssertEqual(app.activePane.directory, sub) // new tab rooted at current path
        // the other column is untouched
        XCTAssertEqual(app.rightColumn.tabs.count, 1)
    }

    func test_nextTab_cyclesActiveColumnOnly() {
        let app = AppModel(leftDir: makeDir("l"), rightDir: makeDir("r"))
        app.active = .left
        CommandRunner.run(.newTab, app: app) // left has 2 tabs, active=1
        CommandRunner.run(.nextTab, app: app)
        XCTAssertEqual(app.leftColumn.activeTab, 0)
        XCTAssertEqual(app.rightColumn.tabs.count, 1)
    }

    func test_closeTab_command() {
        let app = AppModel(leftDir: makeDir("l"), rightDir: makeDir("r"))
        app.active = .left
        CommandRunner.run(.newTab, app: app)
        XCTAssertEqual(app.leftColumn.tabs.count, 2)
        CommandRunner.run(.closeTab, app: app)
        XCTAssertEqual(app.leftColumn.tabs.count, 1)
    }

    func test_addBookmark_recordsActiveDirectory() {
        let l = makeDir("l")
        let app = AppModel(leftDir: l, rightDir: makeDir("r"))
        CommandRunner.run(.addBookmark, app: app)
        XCTAssertTrue(app.bookmarks.contains(l))
    }

    func test_clipboardCopyThenPaste_copiesAcrossPanes() {
        let l = makeDir("l"), r = makeDir("r")
        // Tricky name with a space + non-ASCII to catch file-reference-URL name mangling.
        let name = "重要 报告.txt"
        makeFile(name, in: l)
        let app = AppModel(leftDir: l, rightDir: r)

        app.active = .left
        CommandRunner.run(.clipboardCopy, app: app)

        app.active = .right
        CommandRunner.run(.clipboardPaste, app: app)

        XCTAssertTrue(exists(r.appendingPathComponent(name)), "pasted file should keep its real name")
        XCTAssertTrue(names(app.right.entries).contains(name))
    }

    func test_toggleHidden_command() {
        let l = makeDir("l")
        makeFile(".hidden", in: l)
        makeFile("shown.txt", in: l)
        let app = AppModel(leftDir: l, rightDir: makeDir("r"))
        XCTAssertFalse(names(app.left.entries).contains(".hidden"))
        CommandRunner.run(.toggleHidden, app: app)
        XCTAssertTrue(names(app.left.entries).contains(".hidden"))
    }

    func test_sortCommands_setField() {
        let l = makeDir("l")
        makeFile("a.txt", in: l)
        let app = AppModel(leftDir: l, rightDir: makeDir("r"))
        CommandRunner.run(.sortSize, app: app)
        XCTAssertEqual(app.left.sortField, .size)
        CommandRunner.run(.sortModified, app: app)
        XCTAssertEqual(app.left.sortField, .modified)
        CommandRunner.run(.sortName, app: app)
        XCTAssertEqual(app.left.sortField, .name)
    }

    func test_selectAll_command() {
        let l = makeDir("l")
        makeFile("a.txt", in: l); makeFile("b.txt", in: l)
        let app = AppModel(leftDir: l, rightDir: makeDir("r"))
        CommandRunner.run(.selectAll, app: app)
        XCTAssertEqual(app.left.selection.count, 2)
    }

    func test_navigationCommands_backForwardUp() {
        let l = makeDir("l")
        let sub = makeDir("sub", in: l)
        let app = AppModel(leftDir: l, rightDir: makeDir("r"))

        app.left.enterDirectory(sub)
        XCTAssertEqual(app.left.directory, sub)

        CommandRunner.run(.back, app: app)      // back to parent
        XCTAssertEqual(app.left.directory, l)

        CommandRunner.run(.forward, app: app)   // redo into sub
        XCTAssertEqual(app.left.directory, sub)

        CommandRunner.run(.goUp, app: app)      // up one level
        XCTAssertEqual(app.left.directory, l)
    }
}
