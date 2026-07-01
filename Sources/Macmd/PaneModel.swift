import Foundation
import Observation
import AppKit

@Observable
final class PaneModel {
    let id = UUID()
    private(set) var directory: URL
    private var allEntries: [FileEntry] = []   // raw disk listing (already hidden-filtered)
    private(set) var entries: [FileEntry] = []  // visible: filtered + sorted
    var selection: Set<URL> = []
    var cursorIndex: Int = 0
    private(set) var sortField: SortField = .name
    private(set) var sortAscending: Bool = true
    private(set) var filterText: String = ""
    private(set) var showHidden: Bool = false
    var editingURL: URL?   // entry currently being renamed inline
    let history = HistoryStack()

    init(directory: URL) {
        self.directory = directory
        loadDirectory(directory)
    }

    var cursorEntry: FileEntry? {
        entries.indices.contains(cursorIndex) ? entries[cursorIndex] : nil
    }

    /// Targets for a file operation: the multi-selection if any, else the cursor row.
    var actionTargets: [URL] {
        if !selection.isEmpty { return Array(selection) }
        if let c = cursorEntry { return [c.url] }
        return []
    }

    // MARK: - Loading

    func loadDirectory(_ url: URL, cursorOn: URL? = nil) {
        directory = url
        selection.removeAll()
        filterText = ""
        allEntries = FileSystemService.list(url, showHidden: showHidden)
        applyFilterAndSort()
        if let cursorOn, let idx = entries.firstIndex(where: { $0.url == cursorOn }) {
            cursorIndex = idx
        } else {
            cursorIndex = 0
        }
    }

    func reload() {
        let keep = cursorEntry?.url
        allEntries = FileSystemService.list(directory, showHidden: showHidden)
        applyFilterAndSort(keep: keep)
    }

    private func applyFilterAndSort(keep: URL? = nil) {
        let keepURL = keep ?? cursorEntry?.url
        var list = allEntries
        if !filterText.isEmpty {
            // Prefix match (type-ahead), matching Total Commander / Finder convention.
            let f = filterText.lowercased()
            list = list.filter { $0.name.lowercased().hasPrefix(f) }
        }
        list.sort { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory } // dirs first (OFM style)
            let ascendingResult: Bool
            switch sortField {
            case .name:
                ascendingResult = a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .size:
                ascendingResult = a.size < b.size
            case .modified:
                ascendingResult = a.modified < b.modified
            }
            return sortAscending ? ascendingResult : !ascendingResult
        }
        entries = list
        if let keepURL, let idx = entries.firstIndex(where: { $0.url == keepURL }) {
            cursorIndex = idx
        } else {
            cursorIndex = min(cursorIndex, max(0, entries.count - 1))
        }
    }

    // MARK: - Navigation

    func enterDirectory(_ url: URL) {
        history.visit(url, from: directory)
        loadDirectory(url)
    }

    func openCursor() {
        guard let e = cursorEntry else { return }
        if e.isDirectory {
            enterDirectory(e.url)
        } else {
            NSWorkspace.shared.open(e.url)
        }
    }

    func goUp() {
        let cameFrom = directory
        let parent = directory.deletingLastPathComponent()
        guard parent != directory else { return }
        history.visit(parent, from: directory)
        loadDirectory(parent, cursorOn: cameFrom)
    }

    func goBack() {
        if let u = history.goBack(current: directory) { loadDirectory(u) }
    }

    func goForward() {
        if let u = history.goForward(current: directory) { loadDirectory(u) }
    }

    // MARK: - Cursor & selection

    func moveCursor(_ delta: Int) {
        guard !entries.isEmpty else { return }
        cursorIndex = max(0, min(entries.count - 1, cursorIndex + delta))
    }

    func cursorTop() { cursorIndex = 0 }
    func cursorBottom() { cursorIndex = max(0, entries.count - 1) }

    func toggleSelectAtCursor() {
        guard let e = cursorEntry else { return }
        if selection.contains(e.url) { selection.remove(e.url) } else { selection.insert(e.url) }
        moveCursor(1) // OFM: advance after toggling
    }

    func selectAll() { selection = Set(entries.map(\.url)) }
    func clearSelection() { selection.removeAll() }

    // MARK: - Filter (type-to-search)

    func appendFilter(_ s: String) { filterText += s; applyFilterAndSort() }
    func backspaceFilter() { if !filterText.isEmpty { filterText.removeLast(); applyFilterAndSort() } }
    func clearFilter() { if !filterText.isEmpty { filterText = ""; applyFilterAndSort() } }

    // MARK: - View options

    func toggleHidden() {
        showHidden.toggle()
        reload()
    }

    func setSort(_ f: SortField) {
        if sortField == f { sortAscending.toggle() } else { sortField = f; sortAscending = true }
        applyFilterAndSort()
    }

    // MARK: - Inline rename

    func beginRename(_ url: URL) { editingURL = url }
    func cancelRename() { editingURL = nil }

    /// Commit the in-progress rename. Returns true if a rename actually happened.
    @discardableResult
    func commitRename(to newName: String) -> Bool {
        guard let url = editingURL else { return false }
        editingURL = nil
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != url.lastPathComponent else { return false }
        guard FileSystemService.rename(url, to: trimmed) == nil else { return false }
        let newURL = url.deletingLastPathComponent().appendingPathComponent(trimmed)
        reload()
        if let idx = entries.firstIndex(where: { $0.url == newURL }) { cursorIndex = idx }
        return true
    }
}
