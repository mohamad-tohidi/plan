import SwiftUI

/// The board: a clean 2-week × N-project grid on a hay background.
///
/// The grid is a fixed-width "sheet" (centered on the hay background) inside
/// a vertical scroll view. The sheet itself avoids `ScrollView` so it can
/// also be rendered offscreen for visual verification.
struct BoardView: View {
    @Environment(Store.self) private var store
    @State private var actions = BoardActions()

    var body: some View {
        ScrollView(.vertical) {
            BoardSheet(actions: actions)
                .frame(width: BoardSheet.boardWidth)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Style.hay)
        .focusedSceneValue(\.boardActions, actions)
        .onAppear { VimInput.shared.attach(actions) }
    }
}

/// The fixed-width grid sheet: header, rows, footer — no scrolling.
struct BoardSheet: View {
    let actions: BoardActions

    @Environment(Store.self) private var store

    // Column metrics (pts).
    static let cornerWidth: CGFloat = 180
    static let cellWidth: CGFloat = 430
    static let sidePadding: CGFloat = 20
    /// Total board width: padding + corner + hairline + 2 × cell + hairline + padding.
    static let boardWidth: CGFloat =
        sidePadding + cornerWidth + 1 + cellWidth + 1 + cellWidth + sidePadding

    var body: some View {
        VStack(spacing: 0) {
            header
            Hairline()
            if let prompt = actions.prompt {
                PromptBar(prompt: prompt)
                Hairline()
            }
            VStack(spacing: 0) {
                ForEach(Array(store.projects.enumerated()), id: \.element.id) { index, project in
                    if index > 0 { Hairline() }
                    projectRow(project)
                }
                if !store.projects.isEmpty { Hairline() }
                addProjectRow
            }
            footer
        }
        .onAppear {
            actions.store = store
            actions.saveNow = { store.save() }
            actions.ensureCursor()
            actions.repairCursor()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            cornerHeader
                .frame(width: Self.cornerWidth, alignment: .leading)
            Hairline(vertical: true)
            weekHeader(for: 0)
                .frame(width: Self.cellWidth, alignment: .center)
            Hairline(vertical: true)
            weekHeader(for: 1)
                .frame(width: Self.cellWidth, alignment: .center)
        }
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var cornerHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Sprint Board")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Style.text)
            let counts = store.overallCounts
            Text("\(counts.done) of \(counts.total) tasks done")
                .font(.system(size: 11))
                .foregroundColor(Style.secondary)
        }
        .padding(.top, 2)
    }

    private func weekHeader(for index: Int) -> some View {
        let week = store.weeks.indices.contains(index) ? store.weeks[index] : nil
        return Group {
            if let week {
                VStack(spacing: 3) {
                    Text(week.title.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .kerning(1.2)
                        .foregroundColor(Style.text)
                    let counts = store.counts(for: week)
                    Text("\(counts.done)/\(counts.total) done")
                        .font(.system(size: 11))
                        .foregroundColor(Style.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Rows

    private func projectRow(_ project: Project) -> some View {
        HStack(spacing: 0) {
            ProjectLabelView(
                project: project,
                autoEdit: actions.pendingRenameProjectID == project.id,
                onAutoEditDone: { actions.pendingRenameProjectID = nil },
                onRemove: { actions.prompt = .removeProject(project) }
            )
            .frame(width: Self.cornerWidth, alignment: .leading)
            .frame(maxHeight: .infinity)
            Hairline(vertical: true)
            cell(project, weekIndex: 0)
            Hairline(vertical: true)
            cell(project, weekIndex: 1)
        }
        .frame(minHeight: 150)
    }

    private func cell(_ project: Project, weekIndex: Int) -> some View {
        CellView(
            actions: actions,
            project: project,
            weekIndex: weekIndex,
            width: Self.cellWidth
        )
    }

    private func week(_ index: Int) -> Week? {
        store.weeks.indices.contains(index) ? store.weeks[index] : nil
    }

    private var addProjectRow: some View {
        HStack(spacing: 0) {
            Button {
                store.addProject()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .semibold))
                    Text("Add project")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(Style.secondary)
                .padding(.vertical, 8)
                .padding(.trailing, 12)
            }
            .buttonStyle(.plain)
            .frame(width: Self.cornerWidth, alignment: .leading)
            Spacer(minLength: 0)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                vimHint("a", "add")
                hintDot
                vimHint("e", "edit")
                hintDot
                vimHint("x", "done")
                hintDot
                vimHint("d", "cut")
                hintDot
                vimHint("p", "paste")
            }
            HStack(spacing: 8) {
                vimHint("j k h l", "move")
                hintDot
                vimHint("r", "rename")
                hintDot
                vimHint("A", "project")
                hintDot
                vimHint("D", "remove")
                hintDot
                vimHint("s", "save")
                hintDot
                vimHint("R", "reset")
                hintDot
                vimHint("esc", "exit")
            }
            Text("click = done · double-click = edit · drag = move")
                .font(.system(size: 10))
                .foregroundColor(Style.secondary.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
        .padding(.horizontal, 4)
    }

    private func vimHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundColor(Style.text)
            Text(label)
                .font(.system(size: 10.5))
                .foregroundColor(Style.secondary)
        }
    }

    private var hintDot: some View {
        Text("·")
            .font(.system(size: 9))
            .foregroundColor(Style.secondary.opacity(0.55))
    }
}

/// The project (row) label. Double-click the name — or hover and hit the
/// pencil — to rename in place. `autoEdit` opens the editor (vim `r`).
struct ProjectLabelView: View {
    let project: Project
    var autoEdit: Bool = false
    var onAutoEditDone: () -> Void = {}
    var onRemove: () -> Void

    @Environment(Store.self) private var store
    @State private var editing = false
    @State private var hovered = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            if editing {
                TextField("Project name", text: $draft)
                    .font(.system(size: 13, weight: .semibold))
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit { commit() }
                    .onExitCommand { cancel() }
                    .onAppear {
                        draft = project.title
                        focused = true
                    }
            } else {
                Text(project.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Style.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .onTapGesture(count: 2) {
                        beginEdit()
                    }
            }

            Spacer(minLength: 4)

            if hovered && !editing {
                Button {
                    beginEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Style.secondary)
                }
                .buttonStyle(.plain)
                .help("Rename project")

                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Style.red)
                }
                .buttonStyle(.plain)
                .help("Remove project")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.leading, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                hovered = hovering
            }
        }
        .onAppear {
            if autoEdit { beginEdit() }
        }
        .onChange(of: autoEdit) { _, newValue in
            if newValue { beginEdit() }
        }
        .help("Double-click to rename")
    }

    private func beginEdit() {
        draft = project.title
        editing = true
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { store.renameProject(project.id, to: trimmed) }
        editing = false
        onAutoEditDone()
    }

    private func cancel() {
        editing = false
        onAutoEditDone()
    }
}

/// The inline vim-style confirmation prompt: press `y` to confirm, `n` or
/// `esc` to cancel (handled by the global key monitor).
struct PromptBar: View {
    let prompt: BoardActions.Prompt

    var body: some View {
        HStack(spacing: 12) {
            Text(question)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Style.text)
                .lineLimit(2)

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                hint("y", "yes")
                dot
                hint("n", "no")
                dot
                hint("esc", "cancel")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Style.cardWhite)
                .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeOut(duration: 0.15), value: question)
    }

    private var question: String {
        switch prompt {
        case .removeProject(let project):
            return "Remove project “\(project.title)”? All its tasks will be deleted."
        case .resetBoard:
            return "Reset the demo board? This replaces the current board."
        }
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(Style.focus)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Style.secondary)
        }
    }

    private var dot: some View {
        Text("·")
            .font(.system(size: 9))
            .foregroundColor(Style.secondary.opacity(0.55))
    }
}

/// One cell of the grid: holds the week's cards for one project and accepts
/// drops from other cells. The `+ Add task` button only appears on hover.
struct CellView: View {
    let actions: BoardActions
    let project: Project
    let weekIndex: Int
    var width: CGFloat

    @Environment(Store.self) private var store
    @State private var isTargeted = false
    @State private var hovered = false
    @State private var autoEditID: UUID?

    private var week: Week? {
        store.weeks.indices.contains(weekIndex) ? store.weeks[weekIndex] : nil
    }

    private var key: GridKey? {
        week.map { GridKey(projectID: project.id, weekID: $0.id) }
    }

    private var cards: [TaskCard] {
        key.flatMap { store.tasks(for: $0) } ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(cards) { card in
                TaskCardView(
                    card: card,
                    isSelected: actions.selectedTaskID == card.id,
                    autoEdit: card.id == autoEditID || card.id == actions.pendingEditTaskID,
                    onSelect: {
                        if let key { actions.selectTask(card.id, in: key) }
                    },
                    onAutoEditDone: {
                        autoEditID = nil
                        actions.clearPendingEdits()
                    }
                )
            }
            Spacer(minLength: 0)
            if hovered {
                addButton
                    .transition(.opacity)
            }
        }
        .padding(12)
        .frame(width: width, alignment: .top)
        .frame(minHeight: 150)
        .background(cellFill)
        .contentShape(Rectangle())
        .onTapGesture {
            if let key { actions.focus(key) }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                hovered = hovering
            }
        }
        .dropDestination(for: TaskCard.self) { items, _ in
            guard let card = items.first, let key else { return false }
            store.moveTask(card.id, to: key)
            return true
        } isTargeted: { isTargeted = $0 }
        .animation(.easeOut(duration: 0.15), value: isTargeted)
    }

    private var cellFill: some View {
        isTargeted
            ? Style.hayDeep.opacity(0.55)
            : (isCellSelected ? Style.line.opacity(0.55) : Color.clear)
    }

    private var isCellSelected: Bool {
        key.map { actions.selectedKey == $0 } ?? false
    }

    private var addButton: some View {
        Button {
            guard let key else { return }
            let card = store.addTask(to: key)
            autoEditID = card.id
            actions.selectTask(card.id, in: key)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .semibold))
                Text("Add task")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(Style.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Style.line.opacity(0.5), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .help("Add a task to this week")
    }
}