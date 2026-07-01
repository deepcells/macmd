import SwiftUI
import AppKit
import Observation

@main
struct CmdToolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(app: model)
                .frame(minWidth: 940, minHeight: 580)
        }
        .windowStyle(.titleBar)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }
}

enum PaneSide { case left, right }

@Observable
final class AppModel {
    let leftColumn: PaneColumn
    let rightColumn: PaneColumn
    var active: PaneSide = .left
    var bookmarks: [URL] = []
    var status: String = ""
    var pendingPrompt: PromptRequest?

    // Current tab of each column.
    var left: PaneModel { leftColumn.current }
    var right: PaneModel { rightColumn.current }

    var activeColumn: PaneColumn { active == .left ? leftColumn : rightColumn }
    var inactiveColumn: PaneColumn { active == .left ? rightColumn : leftColumn }
    var activePane: PaneModel { activeColumn.current }
    var inactivePane: PaneModel { inactiveColumn.current }

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let desktop = home.appendingPathComponent("Desktop", isDirectory: true)
        let rightDir = FileManager.default.fileExists(atPath: desktop.path) ? desktop : home
        leftColumn = PaneColumn(directory: home)
        rightColumn = PaneColumn(directory: rightDir)
        loadBookmarks()
    }

    /// Directed initializer, primarily for tests.
    init(leftDir: URL, rightDir: URL) {
        leftColumn = PaneColumn(directory: leftDir)
        rightColumn = PaneColumn(directory: rightDir)
    }

    func toggleActive() { active = (active == .left ? .right : .left) }

    // MARK: - Bookmarks (persisted paths)

    func addBookmark(_ url: URL) {
        guard !bookmarks.contains(url) else { return }
        bookmarks.append(url)
        UserDefaults.standard.set(bookmarks.map(\.path), forKey: "cmdtool.bookmarks")
    }

    private func loadBookmarks() {
        if let paths = UserDefaults.standard.stringArray(forKey: "cmdtool.bookmarks") {
            bookmarks = paths.map { URL(fileURLWithPath: $0) }
        }
    }

    struct PromptRequest: Identifiable {
        let id = UUID()
        let title: String
        let initial: String
        let action: (String) -> Void
    }
}
