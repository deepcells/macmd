# Macmd

A native macOS **dual-pane file manager** in the spirit of Total Commander —
keyboard-driven, orthodox-file-manager style.

## Features

- **Dual-pane** layout; `←` / `→` switch panes
- **Multi-tab per pane**: `⌘T` opens a tab at the current path, `Tab` cycles tabs
- **Keyboard navigation**: `↑↓` move cursor, `↵` enter, `⌫` / `⌘↑` go up
- **Multi-select** (`Space`) and **type-ahead prefix filter**
- **File ops**: `F5`/`⌘C` copy, `F6` move, `⌘⌫` trash (`⌥⌘⌫` permanent), `F7` new folder, `F2` / click-name inline rename
- **Column sorting**, hidden-file toggle (`⌘.`), back/forward history, bookmarks (`⌘D`)

Shortcuts are Mac-native first (`⌘C`/`⌘V`/`⌘⌫`), with Total Commander F-keys as aliases.

## Architecture

Layered, UI-agnostic core so the logic is unit-testable:

- `FileSystemService` — list / copy / move / trash / rename (Foundation)
- `PaneModel` — one directory view (entries, cursor, selection, sort, filter, history, inline rename)
- `PaneColumn` — a pane's tab set
- `Command` + `KeyMap` + `CommandRunner` — key bindings decoupled from actions
- SwiftUI shell (`ContentView` / `PaneView` / `TabBar` / …)

## Build & run

```sh
swift build
swift run          # or: open Macmd.app after packaging
```

## Test

```sh
swift test
```

Requires macOS 14+ and a Swift 6 toolchain.
# macmd
