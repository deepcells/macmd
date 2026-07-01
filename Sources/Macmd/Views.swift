import SwiftUI
import AppKit

// MARK: - Root

struct ContentView: View {
    @Bindable var app: AppModel
    @State private var keyboard = KeyboardMonitor()

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView(app: app)
            Divider()
            HStack(spacing: 0) {
                PaneView(app: app, column: app.leftColumn, side: .left)
                Divider()
                PaneView(app: app, column: app.rightColumn, side: .right)
            }
            Divider()
            StatusBar(app: app)
        }
        .onAppear { keyboard.start(app: app) }
        .onDisappear { keyboard.stop() }
        .sheet(item: $app.pendingPrompt) { req in
            PromptSheet(request: req)
        }
    }
}

// MARK: - Pane

struct PaneView: View {
    let app: AppModel
    let column: PaneColumn
    let side: PaneSide

    private var isActive: Bool { app.active == side }
    private var pane: PaneModel { column.current }

    var body: some View {
        // Hoist observed reads into PaneView's own tracking scope so the list
        // re-renders when the model changes (reads nested inside ScrollViewReader's
        // closure are not reliably tracked by the enclosing view).
        let pane = column.current
        let items = pane.entries
        let cursor = pane.cursorIndex
        let selection = pane.selection
        let filter = pane.filterText
        let currentDir = pane.directory
        let editing = pane.editingURL

        return VStack(spacing: 0) {
            if column.tabs.count > 1 {
                TabBar(app: app, column: column, side: side)
                Divider()
            }
            PathBar(pane: pane, isActive: isActive)
            HeaderRow(pane: pane)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { idx, entry in
                            FileRow(
                                entry: entry,
                                isCursor: idx == cursor && isActive,
                                isCursorInactive: idx == cursor && !isActive,
                                isSelected: selection.contains(entry.url),
                                isEditing: entry.url == editing,
                                onCommit: { pane.commitRename(to: $0) },
                                onCancel: { pane.cancelRename() }
                            )
                            .onTapGesture(count: 2) {
                                app.active = side
                                pane.cursorIndex = idx
                                pane.openCursor()
                            }
                            .onTapGesture(count: 1) {
                                // Slow second click on the already-selected row → inline rename (Finder-style).
                                if isActive, cursor == idx, pane.editingURL == nil {
                                    pane.beginRename(entry.url)
                                } else {
                                    app.active = side
                                    pane.cursorIndex = idx
                                }
                            }
                        }
                    }
                    .id("\(pane.id.uuidString):\(currentDir.path)") // rebuild on tab switch or directory change
                }
                .onChange(of: cursor) { _, i in
                    if items.indices.contains(i) { proxy.scrollTo(items[i].id, anchor: .center) }
                }
            }
            if !filter.isEmpty {
                FilterBar(text: filter, count: items.count)
            }
        }
        .background(isActive ? Color(nsColor: .textBackgroundColor) : Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(isActive ? Color.accentColor : Color.clear)
                .frame(height: 2)
        }
        // Keyboard is handled app-wide by KeyboardMonitor (routes to app.activePane).
    }
}

// MARK: - Tab bar

struct TabBar: View {
    let app: AppModel
    let column: PaneColumn
    let side: PaneSide

    var body: some View {
        let tabs = column.tabs
        let active = column.activeTab
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(tabs.enumerated()), id: \.element.id) { idx, tab in
                    HStack(spacing: 5) {
                        Image(systemName: "folder").font(.system(size: 9))
                        Text(title(tab)).font(.caption).lineLimit(1)
                        Button { column.closeTab(at: idx) } label: {
                            Image(systemName: "xmark").font(.system(size: 8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(idx == active ? Color.accentColor.opacity(0.28) : Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .contentShape(Rectangle())
                    .onTapGesture { app.active = side; column.selectTab(idx) }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func title(_ tab: PaneModel) -> String {
        let name = tab.directory.lastPathComponent
        return name.isEmpty ? "/" : name
    }
}

// MARK: - Row

struct FileRow: View {
    let entry: FileEntry
    let isCursor: Bool
    let isCursorInactive: Bool
    let isSelected: Bool
    var isEditing: Bool = false
    var onCommit: (String) -> Void = { _ in }
    var onCancel: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .frame(width: 18)
                .foregroundStyle(entry.isDirectory ? Color.accentColor : Color.secondary)
            if isEditing {
                RenameField(initialName: entry.name, onCommit: onCommit, onCancel: onCancel)
            } else {
                Text(entry.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(isSelected ? Color.red : Color.primary)
            }
            Spacer(minLength: 8)
            Text(sizeText)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .trailing)
            Text(dateText)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(background)
        .contentShape(Rectangle())
    }

    private var background: Color {
        if isCursor { return Color.accentColor.opacity(0.35) }
        if isCursorInactive { return Color.secondary.opacity(0.16) }
        return .clear
    }

    private var iconName: String {
        if entry.isSymlink { return "arrowshape.turn.up.left" }
        if entry.isDirectory { return "folder.fill" }
        return "doc"
    }

    private var sizeText: String {
        entry.isDirectory ? "<DIR>" : ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file)
    }

    private var dateText: String { Self.formatter.string(from: entry.modified) }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()
}

// MARK: - Inline rename field

struct RenameField: View {
    let initialName: String
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    @State private var text: String = ""
    @State private var finished = false
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.roundedBorder)
            .font(.body)
            .focused($focused)
            .onAppear {
                text = initialName
                focused = true
            }
            .onSubmit { finish(commit: true) }        // Return commits
            .onExitCommand { finish(commit: false) }  // Esc cancels
            .onChange(of: focused) { _, isFocused in
                if !isFocused { finish(commit: true) } // click-away commits, Finder-style
            }
    }

    private func finish(commit: Bool) {
        guard !finished else { return }
        finished = true
        if commit { onCommit(text) } else { onCancel() }
    }
}

// MARK: - Chrome

struct PathBar: View {
    let pane: PaneModel
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder")
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
            Text(pane.directory.path)
                .lineLimit(1)
                .truncationMode(.head)
                .font(.callout)
            Spacer()
            Text("\(pane.entries.count) 项")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
    }
}

struct HeaderRow: View {
    let pane: PaneModel

    var body: some View {
        HStack(spacing: 8) {
            Button { pane.setSort(.name) } label: { label("名称", .name) }
                .buttonStyle(.plain)
                .padding(.leading, 26)
            Spacer()
            Button { pane.setSort(.size) } label: { label("大小", .size).frame(width: 88, alignment: .trailing) }
                .buttonStyle(.plain)
            Button { pane.setSort(.modified) } label: { label("修改时间", .modified).frame(width: 140, alignment: .trailing) }
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .font(.caption.bold())
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func label(_ title: String, _ field: SortField) -> some View {
        HStack(spacing: 2) {
            Text(title)
            if pane.sortField == field {
                Image(systemName: pane.sortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8))
            }
        }
    }
}

struct ToolbarView: View {
    let app: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Button { CommandRunner.run(.back, app: app) } label: { Image(systemName: "chevron.left") }
                .disabled(!app.activePane.history.canBack)
            Button { CommandRunner.run(.forward, app: app) } label: { Image(systemName: "chevron.right") }
                .disabled(!app.activePane.history.canForward)
            Button { CommandRunner.run(.goUp, app: app) } label: { Image(systemName: "arrow.up") }
            Divider().frame(height: 16)
            Menu {
                if app.bookmarks.isEmpty {
                    Text("暂无书签(⌘D 添加当前目录)")
                } else {
                    ForEach(app.bookmarks, id: \.self) { url in
                        Button(url.lastPathComponent) { app.activePane.enterDirectory(url) }
                    }
                }
            } label: {
                Label("书签", systemImage: "bookmark")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            Spacer()
            Text("Macmd · 双栏文件管理器")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .buttonStyle(.borderless)
    }
}

struct StatusBar: View {
    let app: AppModel

    var body: some View {
        HStack(spacing: 14) {
            // Left: shortcuts, always visible.
            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 12)
            // Right: transient status + selection count.
            if !app.activePane.selection.isEmpty {
                Text("已选 \(app.activePane.selection.count) 项")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if !app.status.isEmpty {
                Text(app.status)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var hint: String {
        "←→切换面板 · Tab切换标签 · ⌘T新标签 · ↑↓移动 · ↵进入 · ⌫/⌘↑上级 · 空格选择 · F5/⌘C复制 · F6移动 · ⌘⌫删除 · F7新建 · F2重命名 · ⌘.隐藏 · ⌘D书签 · 字母过滤"
    }
}

struct FilterBar: View {
    let text: String
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
            Text("过滤: \(text)").bold()
            Spacer()
            Text("\(count) 项匹配").foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.yellow.opacity(0.25))
    }
}

struct PromptSheet: View {
    let request: AppModel.PromptRequest
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(request.title).font(.headline)
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 340)
                .focused($focused)
                .onSubmit(commit)
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("确定", action: commit).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .onAppear { text = request.initial; focused = true }
    }

    private func commit() {
        request.action(text)
        dismiss()
    }
}
