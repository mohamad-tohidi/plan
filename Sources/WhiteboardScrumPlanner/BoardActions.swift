import SwiftUI
import AppKit
import Observation

/// The board's modal "vim" state: the cursor (selected cell + selected task),
/// the cut/paste clipboard, pending auto-edit requests, and the single-key
/// command handler. Menu ⌘-shortcuts target this object via @FocusedValue.
@MainActor
@Observable
final class BoardActions {
    weak var store: Store?

    // Cursor.
    var selectedKey: GridKey?
    var selectedTaskID: UUID?

    // Cut/paste clipboard (vim `d` / `p`).
    var clipboardCard: TaskCard?

    // Ask the UI to open an editor automatically (vim `a`, `e`, `r`).
    var pendingEditTaskID: UUID?
    var pendingRenameProjectID: UUID?

    // A pending vim-style "are you sure?" prompt (y / n / esc).
    enum Prompt {
        case removeProject(Project)
        case resetBoard
    }
    var prompt: Prompt?

    // Menubar actions.
    var saveNow: () -> Void = {}

    var isActive: Bool { store != nil }

    // MARK: - Cursor

    func focus(_ key: GridKey) {
        selectedKey = key
        selectedTaskID = store?.tasks(for: key).first?.id
    }

    func selectTask(_ id: UUID, in key: GridKey) {
        selectedKey = key
        selectedTaskID = id
    }

    func ensureCursor() {
        guard selectedKey == nil, let store,
              let project = store.projects.first,
              let week = store.weeks.first else { return }
        focus(GridKey(projectID: project.id, weekID: week.id))
    }

    func repairCursor() {
        guard let store else {
            selectedKey = nil
            selectedTaskID = nil
            return
        }
        if let key = selectedKey,
           store.projects.contains(where: { $0.id == key.projectID }),
           store.weeks.contains(where: { $0.id == key.weekID }) {
            let cards = store.tasks(for: key)
            if let id = selectedTaskID, !cards.contains(where: { $0.id == id }) {
                selectedTaskID = cards.first?.id
            }
            return
        }
        if let week = store.weeks.first, let project = store.projects.first {
            focus(GridKey(projectID: project.id, weekID: week.id))
        } else {
            selectedKey = nil
            selectedTaskID = nil
        }
    }

    // MARK: - Movement  (h l j k)

    func cursorLeft() { shiftWeek(by: -1) }
    func cursorRight() { shiftWeek(by: 1) }

    private func shiftWeek(by delta: Int) {
        guard let store, let key = selectedKey else { ensureCursor(); return }
        guard let idx = store.weeks.firstIndex(where: { $0.id == key.weekID }) else { return }
        let newIdx = max(0, min(store.weeks.count - 1, idx + delta))
        guard newIdx != idx else { return }
        focus(GridKey(projectID: key.projectID, weekID: store.weeks[newIdx].id))
    }

    func cursorDown() {
        guard let store, let key = selectedKey else { ensureCursor(); return }
        let cards = store.tasks(for: key)
        if let taskID = selectedTaskID,
           let idx = cards.firstIndex(where: { $0.id == taskID }),
           idx + 1 < cards.count {
            selectedTaskID = cards[idx + 1].id
            return
        }
        guard let row = store.projects.firstIndex(where: { $0.id == key.projectID }),
              row + 1 < store.projects.count else { return }
        focus(GridKey(projectID: store.projects[row + 1].id, weekID: key.weekID))
    }

    func cursorUp() {
        guard let store, let key = selectedKey else { ensureCursor(); return }
        let cards = store.tasks(for: key)
        if let taskID = selectedTaskID,
           let idx = cards.firstIndex(where: { $0.id == taskID }),
           idx > 0 {
            selectedTaskID = cards[idx - 1].id
            return
        }
        guard let row = store.projects.firstIndex(where: { $0.id == key.projectID }),
              row > 0 else { return }
        focus(GridKey(projectID: store.projects[row - 1].id, weekID: key.weekID))
    }

    // MARK: - Tasks  (a e x d p)

    func addTaskAtCursor() {
        ensureCursor()
        guard let store, let key = selectedKey else { return }
        let card = store.addTask(to: key)
        selectedTaskID = card.id
        pendingEditTaskID = card.id
    }

    func editTaskAtCursor() {
        guard let store, let key = selectedKey else { return }
        let cards = store.tasks(for: key)
        let target = selectedTaskID.flatMap { id in cards.first(where: { $0.id == id }) } ?? cards.first
        guard let target else { return }
        selectedTaskID = target.id
        pendingEditTaskID = target.id
    }

    func toggleDoneAtCursor() {
        guard let store, let key = selectedKey else { return }
        let cards = store.tasks(for: key)
        let target = selectedTaskID.flatMap { id in cards.first(where: { $0.id == id }) } ?? cards.first
        guard let target else { return }
        selectedTaskID = target.id
        let becomesDone = !target.isDone
        withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
            store.toggleTask(target.id)
        }
        if becomesDone { store.celebrate(target.id) }
    }

    func cutTaskAtCursor() {
        guard let store, let key = selectedKey, let taskID = selectedTaskID,
              let card = store.tasks(for: key).first(where: { $0.id == taskID }) else { return }
        clipboardCard = card
        store.removeTask(taskID)
        selectedTaskID = store.tasks(for: key).first?.id
    }

    func pasteAtCursor() {
        guard let store, let card = clipboardCard, let key = selectedKey else { return }
        store.insertTask(card, at: key)
        selectedTaskID = card.id
    }

    // MARK: - Projects  (r A D)

    func renameProjectAtCursor() {
        guard let key = selectedKey else { return }
        pendingRenameProjectID = key.projectID
    }

    func addProject() {
        guard let store else { return }
        let project = store.addProject()
        if let week = store.weeks.first {
            focus(GridKey(projectID: project.id, weekID: week.id))
        }
    }

    func deleteProjectAtCursor() {
        guard let store, let key = selectedKey,
              let project = store.projects.first(where: { $0.id == key.projectID }) else { return }
        prompt = .removeProject(project)
    }

    // MARK: - Confirmation prompt (y / n / esc)

    func confirmPrompt() {
        guard let prompt else { return }
        self.prompt = nil
        switch prompt {
        case .removeProject(let project):
            store?.removeProject(project.id)
        case .resetBoard:
            store?.installSampleData()
        }
        repairCursor()
    }

    func cancelPrompt() {
        prompt = nil
    }

    // MARK: - Single-key command handler (normal mode)

    /// Returns true if the key was consumed. Called by the global key monitor
    /// only when no text field is being edited (i.e. not in insert mode).
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Escape: dismiss a pending prompt (text fields handle their own Esc).
        if event.keyCode == 53 {
            guard prompt != nil else { return false }
            cancelPrompt()
            return true
        }

        guard let characters = event.charactersIgnoringModifiers, characters.count == 1,
              let character = characters.lowercased().first else { return false }

        let modifiers = event.modifierFlags.intersection([.command, .option, .control])
        guard modifiers.isEmpty else { return false }
        let shift = event.modifierFlags.contains(.shift)

        // While a prompt is up, only y / n / esc act; everything else is
        // consumed so the board can't change underneath the question.
        if let prompt {
            switch character {
            case "y": confirmPrompt()
            case "n": cancelPrompt()
            default: break
            }
            return true
        }

        switch (character, shift) {
        case ("h", false): cursorLeft()
        case ("l", false): cursorRight()
        case ("j", false): cursorDown()
        case ("k", false): cursorUp()

        case ("a", false): addTaskAtCursor()
        case ("e", false): editTaskAtCursor()
        case ("x", false): toggleDoneAtCursor()
        case ("d", false): cutTaskAtCursor()
        case ("p", false): pasteAtCursor()

        case ("r", false): renameProjectAtCursor()
        case ("s", false): saveNow()

        case ("a", true): addProject()
        case ("d", true): deleteProjectAtCursor()
        case ("r", true): prompt = .resetBoard

        default: return false
        }
        return true
    }

    /// Called by editors once they close, so auto-opened editors don't reopen.
    func clearPendingEdits() {
        pendingEditTaskID = nil
        pendingRenameProjectID = nil
    }
}

/// Installs the app-wide key monitor that turns the board into a vim-like
/// modal editor: single keys act when no text field is focused (normal mode),
/// and everything is passed through while a field is being edited (insert
/// mode). `Esc` inside a field exits insert mode via the field's own handler.
@MainActor
final class VimInput {
    static let shared = VimInput()

    private var monitor: Any?
    private var installed = false
    weak var actions: BoardActions?

    private init() {}

    func install() {
        guard !installed else { return }
        installed = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  NSApp.keyWindow != nil,
                  let actions = self.actions,
                  actions.isActive else { return event }

            // Insert mode: a text field owns the keys.
            if NSApp.keyWindow?.firstResponder is NSTextView {
                return event
            }

            // Normal mode.
            return actions.handleKeyEvent(event) ? nil : event
        }
    }

    /// Wire the current board's actions into the monitor (called on appear).
    func attach(_ actions: BoardActions) {
        self.actions = actions
    }
}
private struct BoardActionsKey: FocusedValueKey {
    typealias Value = BoardActions
}

extension FocusedValues {
    var boardActions: BoardActions? {
        get { self[BoardActionsKey.self] }
        set { self[BoardActionsKey.self] = newValue }
    }
}

struct BoardCommands: Commands {
    @FocusedValue(\.boardActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Task") { actions?.addTaskAtCursor() }
                .keyboardShortcut("n", modifiers: [.command])
        }

        CommandMenu("Board") {
            Button("Save Now") { actions?.saveNow() }
                .keyboardShortcut("s", modifiers: [.command])
            Divider()
            Button("Reset Demo Board") { actions?.prompt = .resetBoard }
        }
    }
}
