import Foundation

// MARK: - Data model

struct FileEntry: Identifiable, Hashable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modified: Date
    let ext: String
    let isHidden: Bool
    let isSymlink: Bool

    var id: URL { url }
}

enum SortField {
    case name, size, modified
}

// MARK: - History (per pane back / forward)

final class HistoryStack {
    private var back: [URL] = []
    private var forward: [URL] = []

    var canBack: Bool { !back.isEmpty }
    var canForward: Bool { !forward.isEmpty }

    func visit(_ url: URL, from old: URL) {
        guard url != old else { return }
        back.append(old)
        forward.removeAll()
    }

    func goBack(current: URL) -> URL? {
        guard let u = back.popLast() else { return nil }
        forward.append(current)
        return u
    }

    func goForward(current: URL) -> URL? {
        guard let u = forward.popLast() else { return nil }
        back.append(current)
        return u
    }
}

// MARK: - File system service (UI-agnostic, synchronous for MVP)

enum FileSystemService {

    static func list(_ dir: URL, showHidden: Bool) -> [FileEntry] {
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey, .fileSizeKey, .contentModificationDateKey,
            .isHiddenKey, .isSymbolicLinkKey,
        ]
        let opts: FileManager.DirectoryEnumerationOptions = showHidden ? [] : [.skipsHiddenFiles]
        guard let urls = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: Array(keys),
            options: opts
        ) else { return [] }

        var out: [FileEntry] = []
        out.reserveCapacity(urls.count)
        for u in urls {
            let rv = try? u.resourceValues(forKeys: keys)
            let isDir = rv?.isDirectory ?? false
            let entry = FileEntry(
                url: u,
                name: u.lastPathComponent,
                isDirectory: isDir,
                size: Int64(rv?.fileSize ?? 0),
                modified: rv?.contentModificationDate ?? Date(timeIntervalSince1970: 0),
                ext: isDir ? "" : u.pathExtension.lowercased(),
                isHidden: rv?.isHidden ?? false,
                isSymlink: rv?.isSymbolicLink ?? false
            )
            out.append(entry)
        }
        return out
    }

    /// Produce a non-colliding destination URL inside `dstDir` for `name`.
    static func uniqueDestination(_ dstDir: URL, name: String) -> URL {
        let fm = FileManager.default
        var candidate = dstDir.appendingPathComponent(name)
        if !fm.fileExists(atPath: candidate.path) { return candidate }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var i = 2
        while true {
            let newName = ext.isEmpty ? "\(base) \(i)" : "\(base) \(i).\(ext)"
            candidate = dstDir.appendingPathComponent(newName)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            i += 1
        }
    }

    /// Returns a list of failure messages (empty == full success).
    static func copy(_ items: [URL], to dstDir: URL) -> [String] {
        run(items) { src in
            try FileManager.default.copyItem(at: src, to: uniqueDestination(dstDir, name: src.lastPathComponent))
        }
    }

    static func move(_ items: [URL], to dstDir: URL) -> [String] {
        run(items) { src in
            try FileManager.default.moveItem(at: src, to: uniqueDestination(dstDir, name: src.lastPathComponent))
        }
    }

    static func trash(_ items: [URL]) -> [String] {
        run(items) { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }
    }

    static func remove(_ items: [URL]) -> [String] {
        run(items) { try FileManager.default.removeItem(at: $0) }
    }

    static func makeFolder(in dir: URL, name: String) -> String? {
        let target = uniqueDestination(dir, name: name)
        do {
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
            return nil
        } catch { return error.localizedDescription }
    }

    static func rename(_ url: URL, to newName: String) -> String? {
        let dst = url.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try FileManager.default.moveItem(at: url, to: dst)
            return nil
        } catch { return error.localizedDescription }
    }

    /// Run `op` per item, collecting failures instead of aborting the batch.
    private static func run(_ items: [URL], _ op: (URL) throws -> Void) -> [String] {
        var failures: [String] = []
        for u in items {
            do { try op(u) }
            catch { failures.append("\(u.lastPathComponent): \(error.localizedDescription)") }
        }
        return failures
    }
}
