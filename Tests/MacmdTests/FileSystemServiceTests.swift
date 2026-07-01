import XCTest
@testable import Macmd

final class FileSystemServiceTests: SandboxTestCase {

    func test_list_skipsHiddenByDefault_includesWhenRequested() {
        makeFile("visible.txt")
        makeFile(".hidden")
        makeDir("sub")

        let shown = FileSystemService.list(root, showHidden: false)
        XCTAssertTrue(names(shown).contains("visible.txt"))
        XCTAssertTrue(names(shown).contains("sub"))
        XCTAssertFalse(names(shown).contains(".hidden"))

        let all = FileSystemService.list(root, showHidden: true)
        XCTAssertTrue(names(all).contains(".hidden"))
    }

    func test_list_marksDirectoriesAndSizes() {
        makeDir("folder")
        makeFile("file.txt", contents: "hello")

        let entries = FileSystemService.list(root, showHidden: false)
        let folder = try! XCTUnwrap(entries.first { $0.name == "folder" })
        let file = try! XCTUnwrap(entries.first { $0.name == "file.txt" })
        XCTAssertTrue(folder.isDirectory)
        XCTAssertFalse(file.isDirectory)
        XCTAssertEqual(file.size, 5) // "hello"
        XCTAssertEqual(file.ext, "txt")
    }

    func test_list_missingDirectory_returnsEmpty() {
        let missing = root.appendingPathComponent("nope")
        XCTAssertEqual(FileSystemService.list(missing, showHidden: false).count, 0)
    }

    func test_uniqueDestination_withExtension() {
        makeFile("a.txt")
        let dst1 = FileSystemService.uniqueDestination(root, name: "a.txt")
        XCTAssertEqual(dst1.lastPathComponent, "a 2.txt")

        makeFile("a 2.txt")
        let dst2 = FileSystemService.uniqueDestination(root, name: "a.txt")
        XCTAssertEqual(dst2.lastPathComponent, "a 3.txt")
    }

    func test_uniqueDestination_withoutExtension() {
        makeDir("folder")
        let dst = FileSystemService.uniqueDestination(root, name: "folder")
        XCTAssertEqual(dst.lastPathComponent, "folder 2")
    }

    func test_copy_toEmptyDestination() {
        let src = makeDir("src")
        let dst = makeDir("dst")
        makeFile("f.txt", in: src)

        let fails = FileSystemService.copy([src.appendingPathComponent("f.txt")], to: dst)
        XCTAssertTrue(fails.isEmpty)
        XCTAssertTrue(exists(dst.appendingPathComponent("f.txt")))
        XCTAssertTrue(exists(src.appendingPathComponent("f.txt"))) // original stays
    }

    func test_copy_collisionCreatesUniqueName() {
        let dst = makeDir("dst")
        let file = makeFile("dup.txt", in: dst)

        let fails = FileSystemService.copy([file], to: dst)
        XCTAssertTrue(fails.isEmpty)
        XCTAssertTrue(exists(dst.appendingPathComponent("dup.txt")))
        XCTAssertTrue(exists(dst.appendingPathComponent("dup 2.txt")))
    }

    func test_copy_missingSourceReportsFailure() {
        let dst = makeDir("dst")
        let fails = FileSystemService.copy([root.appendingPathComponent("ghost.txt")], to: dst)
        XCTAssertEqual(fails.count, 1)
    }

    func test_copy_batchContinuesAfterFailure() {
        let src = makeDir("src")
        let dst = makeDir("dst")
        let good = makeFile("good.txt", in: src)
        let ghost = src.appendingPathComponent("ghost.txt")

        let fails = FileSystemService.copy([ghost, good], to: dst)
        XCTAssertEqual(fails.count, 1) // only the ghost failed
        XCTAssertTrue(exists(dst.appendingPathComponent("good.txt"))) // good one still copied
    }

    func test_move_relocatesFile() {
        let src = makeDir("src")
        let dst = makeDir("dst")
        let file = makeFile("m.txt", in: src)

        let fails = FileSystemService.move([file], to: dst)
        XCTAssertTrue(fails.isEmpty)
        XCTAssertFalse(exists(file))
        XCTAssertTrue(exists(dst.appendingPathComponent("m.txt")))
    }

    func test_trash_removesFromOriginalLocation() {
        let file = makeFile("trash-me.txt")
        let fails = FileSystemService.trash([file])
        XCTAssertTrue(fails.isEmpty)
        XCTAssertFalse(exists(file))
    }

    func test_remove_deletesPermanently() {
        let file = makeFile("gone.txt")
        let fails = FileSystemService.remove([file])
        XCTAssertTrue(fails.isEmpty)
        XCTAssertFalse(exists(file))
    }

    func test_makeFolder_createsAndDeduplicates() {
        XCTAssertNil(FileSystemService.makeFolder(in: root, name: "New"))
        XCTAssertTrue(exists(root.appendingPathComponent("New")))

        XCTAssertNil(FileSystemService.makeFolder(in: root, name: "New"))
        XCTAssertTrue(exists(root.appendingPathComponent("New 2")))
    }

    func test_rename_changesName() {
        let file = makeFile("old.txt")
        let err = FileSystemService.rename(file, to: "new.txt")
        XCTAssertNil(err)
        XCTAssertFalse(exists(file))
        XCTAssertTrue(exists(root.appendingPathComponent("new.txt")))
    }
}
