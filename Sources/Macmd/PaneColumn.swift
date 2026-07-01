import Foundation
import Observation

/// A single pane (left or right) that can hold multiple tabs, each an independent
/// directory view (its own cursor, selection, history, sort, filter).
@Observable
final class PaneColumn {
    private(set) var tabs: [PaneModel]
    var activeTab: Int = 0

    init(directory: URL) {
        tabs = [PaneModel(directory: directory)]
    }

    var current: PaneModel { tabs[activeTab] }

    /// Open a new tab rooted at `url` and make it active.
    func newTab(from url: URL) {
        tabs.append(PaneModel(directory: url))
        activeTab = tabs.count - 1
    }

    /// Cycle to the next tab (wraps around). No-op with a single tab.
    func nextTab() {
        guard tabs.count > 1 else { return }
        activeTab = (activeTab + 1) % tabs.count
    }

    func selectTab(_ index: Int) {
        if tabs.indices.contains(index) { activeTab = index }
    }

    /// Close the active tab. Always keeps at least one tab.
    func closeCurrentTab() { closeTab(at: activeTab) }

    func closeTab(at index: Int) {
        guard tabs.count > 1, tabs.indices.contains(index) else { return }
        tabs.remove(at: index)
        if activeTab >= tabs.count { activeTab = tabs.count - 1 }
        else if index < activeTab { activeTab -= 1 }
    }
}
