import XCTest
import Foundation
@testable import Macmd

/// Base case that provides an isolated temp sandbox directory per test.
class SandboxTestCase: XCTestCase {
    var root: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("macmd-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        // Canonicalize via realpath (/var -> /private/var) so URLs match what
        // FileManager.contentsOfDirectory returns for entries.
        root = Self.canonical(base)
    }

    /// Resolve a path the same way the file system does (realpath), matching the
    /// namespace of URLs returned by contentsOfDirectory.
    static func canonical(_ url: URL) -> URL {
        guard let r = realpath(url.path, nil) else { return url }
        defer { free(r) }
        return URL(fileURLWithPath: String(cString: r))
    }

    override func tearDownWithError() throws {
        if let root, FileManager.default.fileExists(atPath: root.path) {
            try? FileManager.default.removeItem(at: root)
        }
        try super.tearDownWithError()
    }

    // MARK: - Fixture helpers

    @discardableResult
    func makeDir(_ path: String, in base: URL? = nil) -> URL {
        let url = (base ?? root).appendingPathComponent(path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    func makeFile(_ path: String, contents: String = "x", in base: URL? = nil) -> URL {
        let url = (base ?? root).appendingPathComponent(path)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: Data(contents.utf8))
        return url
    }

    func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func names(_ entries: [FileEntry]) -> [String] {
        entries.map(\.name)
    }
}
