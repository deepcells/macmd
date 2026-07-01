import AppKit

/// App-wide keyDown handler. Routes keys to the active pane via CommandRunner,
/// bypassing SwiftUI focus (which is unreliable for a custom dual-pane view).
final class KeyboardMonitor {
    private var token: Any?
    private weak var app: AppModel?

    func start(app: AppModel) {
        self.app = app
        guard token == nil else { return }
        token = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self, let app = self.app else { return event }
            return self.handle(event, app: app)
        }
    }

    func stop() {
        if let token {
            NSEvent.removeMonitor(token)
            self.token = nil
        }
    }

    private func handle(_ event: NSEvent, app: AppModel) -> NSEvent? {
        // Don't intercept while a text field owns input (inline rename or a sheet).
        if let win = event.window {
            if win.sheetParent != nil { return event }        // event belongs to a sheet
            if win.attachedSheet != nil { return event }       // a sheet is up on this window
            if win.firstResponder is NSText { return event }   // editing a field editor
        }

        let pane = app.activePane
        let bareMods = event.modifierFlags.intersection([.command, .option, .control])
        let scalar = event.charactersIgnoringModifiers?.unicodeScalars.first?.value

        // Backspace edits the quick-filter when one is active.
        if (scalar == 0x08 || scalar == 0x7F), bareMods.isEmpty, !pane.filterText.isEmpty {
            pane.backspaceFilter()
            return nil
        }

        if let command = KeyMap.command(for: event) {
            CommandRunner.run(command, app: app)
            return nil
        }

        // Type-to-filter: a printable character with no command/control/option.
        if bareMods.isEmpty,
           let s = event.characters,
           let sc = s.unicodeScalars.first,
           sc.value >= 0x20, sc.value != 0x7F, !(0xF700...0xF8FF).contains(sc.value) {
            pane.appendFilter(s)
            return nil
        }

        return event
    }
}
