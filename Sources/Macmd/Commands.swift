import SwiftUI
import AppKit

// MARK: - Command set

enum Command {
    case cursorUp, cursorDown, cursorTop, cursorBottom, pageUp, pageDown
    case open, goUp, switchPane, focusLeftPane, focusRightPane, toggleSelect, selectAll
    case copyToOther, moveToOther, delete, permanentDelete, newFolder, rename
    case clipboardCopy, clipboardPaste
    case back, forward, toggleHidden, addBookmark, clearFilter, reload
    case sortName, sortSize, sortModified
    case newTab, nextTab, closeTab
}

// MARK: - Key map (Mac-native primary, F-keys auxiliary → same commands)

enum KeyMap {
    static func command(for press: KeyPress) -> Command? {
        let m = press.modifiers
        // Candidate scalars from BOTH the resolved key and typed characters —
        // physical keys (e.g. Backspace) don't always report the same scalar.
        let scalars = Set(
            [press.key.character.unicodeScalars.first?.value,
             press.characters.unicodeScalars.first?.value].compactMap { $0 }
        )
        return resolve(scalars: scalars,
                       command: m.contains(.command),
                       option: m.contains(.option),
                       shift: m.contains(.shift),
                       chars: press.characters.lowercased())
    }

    static func command(for event: NSEvent) -> Command? {
        let m = event.modifierFlags
        let scalars = Set(
            [event.charactersIgnoringModifiers?.unicodeScalars.first?.value,
             event.characters?.unicodeScalars.first?.value].compactMap { $0 }
        )
        return resolve(scalars: scalars,
                       command: m.contains(.command),
                       option: m.contains(.option),
                       shift: m.contains(.shift),
                       chars: (event.charactersIgnoringModifiers ?? "").lowercased())
    }

    /// Shared resolution used by both the SwiftUI and AppKit key paths.
    static func resolve(scalars: Set<UInt32>, command cmd: Bool, option opt: Bool,
                        shift: Bool, chars: String) -> Command? {
        func key(_ v: UInt32) -> Bool { scalars.contains(v) }

        // Function keys (NSFxFunctionKey private-use range).
        if key(0xF705) { return .rename }                          // F2
        if key(0xF708) { return .copyToOther }                     // F5
        if key(0xF709) { return .moveToOther }                     // F6
        if key(0xF70A) { return .newFolder }                       // F7
        if key(0xF70B) { return opt ? .permanentDelete : .delete } // F8

        // Backspace / Delete key (0x08 = BS, 0x7F = DEL — depends on hardware).
        if key(0x08) || key(0x7F) {
            return cmd ? (opt ? .permanentDelete : .delete) : .goUp
        }

        // Arrows & navigation.
        if key(0xF700) { return cmd ? .goUp : .cursorUp }          // Up (⌘↑ = up level)
        if key(0xF701) { return .cursorDown }                      // Down
        if key(0xF702) { return .focusLeftPane }                   // Left  → left pane
        if key(0xF703) { return .focusRightPane }                  // Right → right pane
        if key(0x0D) || key(0x03) { return .open }                 // Return / Enter
        if key(0x09) { return .nextTab }                           // Tab → cycle tabs
        if key(0x20) { return .toggleSelect }                      // Space
        if key(0xF729) { return .cursorTop }                       // Home
        if key(0xF72B) { return .cursorBottom }                    // End
        if key(0xF72C) { return .pageUp }                          // Page Up
        if key(0xF72D) { return .pageDown }                        // Page Down
        if key(0x1B) { return .clearFilter }                       // Esc

        // Command-modified shortcuts.
        if cmd {
            switch chars {
            case "c": return .clipboardCopy
            case "v": return .clipboardPaste
            case "t": return .newTab
            case "n" where shift: return .newFolder
            case "a": return .selectAll
            case "d": return .addBookmark
            case "[": return .back
            case "]": return .forward
            case ".": return .toggleHidden
            case "r": return .reload
            case "1": return .sortName
            case "2": return .sortSize
            case "3": return .sortModified
            default: return nil
            }
        }
        return nil
    }
}

// MARK: - Command runner (all mutation goes through here)

enum CommandRunner {
    static func run(_ cmd: Command, app: AppModel) {
        let pane = app.activePane
        switch cmd {
        case .cursorUp: pane.moveCursor(-1)
        case .cursorDown: pane.moveCursor(1)
        case .cursorTop: pane.cursorTop()
        case .cursorBottom: pane.cursorBottom()
        case .pageUp: pane.moveCursor(-15)
        case .pageDown: pane.moveCursor(15)
        case .open: pane.openCursor()
        case .goUp: pane.goUp()
        case .switchPane: app.toggleActive()
        case .focusLeftPane: app.active = .left
        case .focusRightPane: app.active = .right
        case .newTab: app.activeColumn.newTab(from: pane.directory)
        case .nextTab: app.activeColumn.nextTab()
        case .closeTab: app.activeColumn.closeCurrentTab()
        case .toggleSelect: pane.toggleSelectAtCursor()
        case .selectAll: pane.selectAll()
        case .back: pane.goBack()
        case .forward: pane.goForward()
        case .toggleHidden: pane.toggleHidden()
        case .clearFilter: pane.clearFilter()
        case .reload: pane.reload()
        case .sortName: pane.setSort(.name)
        case .sortSize: pane.setSort(.size)
        case .sortModified: pane.setSort(.modified)

        case .addBookmark:
            app.addBookmark(pane.directory)
            app.status = "已加入书签:\(pane.directory.lastPathComponent)"

        case .copyToOther:
            let targets = pane.actionTargets
            guard !targets.isEmpty else { break }
            let fails = FileSystemService.copy(targets, to: app.inactivePane.directory)
            app.inactivePane.reload(); pane.clearSelection()
            app.status = report("已复制", targets.count, "到对面板", fails)

        case .moveToOther:
            let targets = pane.actionTargets
            guard !targets.isEmpty else { break }
            let fails = FileSystemService.move(targets, to: app.inactivePane.directory)
            pane.reload(); app.inactivePane.reload(); pane.clearSelection()
            app.status = report("已移动", targets.count, "到对面板", fails)

        case .delete:
            let targets = pane.actionTargets
            guard !targets.isEmpty else { break }
            let fails = FileSystemService.trash(targets)
            pane.reload(); pane.clearSelection()
            app.status = report("已移到废纸篓", targets.count, "", fails)

        case .permanentDelete:
            let targets = pane.actionTargets
            guard !targets.isEmpty else { break }
            let fails = FileSystemService.remove(targets)
            pane.reload(); pane.clearSelection()
            app.status = report("已永久删除", targets.count, "", fails)

        case .clipboardCopy:
            let targets = pane.actionTargets
            guard !targets.isEmpty else { break }
            let pb = NSPasteboard.general
            pb.clearContents()
            let writers: [NSPasteboardWriting] = targets.map { $0 as NSURL }
            pb.writeObjects(writers)
            app.status = "已复制 \(targets.count) 项到剪贴板(⌘V 粘贴)"

        case .clipboardPaste:
            let pb = NSPasteboard.general
            // Normalize to path-based URLs — the pasteboard may return file-reference
            // URLs (file:///.file/id=…) whose lastPathComponent is not the real name.
            let urls = ((pb.readObjects(forClasses: [NSURL.self]) as? [URL]) ?? [])
                .map { ($0 as NSURL).filePathURL ?? $0 }
            guard !urls.isEmpty else { app.status = "剪贴板没有文件"; break }
            let fails = FileSystemService.copy(urls, to: pane.directory)
            pane.reload()
            app.status = report("已粘贴", urls.count, "", fails)

        case .newFolder:
            app.pendingPrompt = AppModel.PromptRequest(title: "新建文件夹", initial: "新建文件夹") { name in
                let trimmed = name.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                _ = FileSystemService.makeFolder(in: pane.directory, name: trimmed)
                pane.reload()
            }

        case .rename:
            guard let e = pane.cursorEntry else { break }
            pane.beginRename(e.url) // inline edit in the row
        }
    }

    private static func report(_ verb: String, _ n: Int, _ suffix: String, _ fails: [String]) -> String {
        if fails.isEmpty { return "\(verb) \(n) 项\(suffix)" }
        return "\(verb)完成,\(fails.count) 项失败:\(fails.first ?? "")"
    }
}
