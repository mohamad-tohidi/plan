import SwiftUI

/// A single clean white task card. Click to mark done (with a small
/// celebration), double-click to edit in place, drag to move between cells.
struct TaskCardView: View {
    let card: TaskCard
    var isSelected: Bool = false
    var autoEdit: Bool = false
    var onSelect: () -> Void = {}
    var onAutoEditDone: () -> Void = {}

    @Environment(Store.self) private var store
    @State private var editing = false
    @State private var hovered = false
    @State private var draft = ""
    @State private var celebrating = false
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if editing {
                editor
            } else {
                cardContent
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardSurface)
        .overlay(alignment: .topTrailing) {
            if hovered && !editing { hoverActions }
        }
        .overlay(alignment: .center) {
            if celebrating { DoneCelebration() }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(isSelected ? Style.focus : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .modifier(DraggableIf(enabled: !editing, card: card))
        .gesture(doubleTap.exclusively(before: singleTap))
        .contextMenu {
            Button("Edit") { beginEdit() }
            Divider()
            Button("Delete", role: .destructive) { store.removeTask(card.id) }
        }
        .onHover { hovered = $0 }
        .onAppear { if autoEdit { beginEdit() } }
        .onChange(of: autoEdit) { _, newValue in
            if newValue { beginEdit() }
        }
        .onChange(of: store.celebrationTaskID) { _, newValue in
            guard newValue == card.id else { return }
            celebrateDone()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(60))
                store.celebrationTaskID = nil
            }
        }
        .animation(.easeOut(duration: 0.12), value: hovered)
        .help("Click: done · Double-click: edit · Drag: move")
    }

    // MARK: - Card body

    private var cardContent: some View {
        HStack(alignment: .top, spacing: 9) {
            checkbox
            Text(card.text)
                .font(.system(size: 13.5))
                .foregroundColor(card.isDone ? Style.secondary : Style.text)
                .strikethrough(card.isDone, color: Style.red)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var checkbox: some View {
        ZStack {
            Image(systemName: "circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(card.isDone ? Style.red.opacity(0) : Style.secondary.opacity(0.85))
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(Style.red)
                .scaleEffect(card.isDone ? 1 : 0.3)
                .opacity(card.isDone ? 1 : 0)
        }
        .frame(width: 20, height: 20)
        .padding(.top, 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: card.isDone)
    }

    private var hoverActions: some View {
        HStack(spacing: 10) {
            Button { beginEdit() } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Style.secondary)
            }
            .buttonStyle(.plain)
            .help("Edit task")

            Button { store.removeTask(card.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(Style.red.opacity(0.85))
            }
            .buttonStyle(.plain)
            .help("Delete task")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
    }

    private var editor: some View {
        TextField("Task", text: $draft, axis: .vertical)
            .font(.system(size: 13.5))
            .textFieldStyle(.plain)
            .focused($focused)
            .lineLimit(1...8)
            .onSubmit { commit() }
            .onExitCommand { cancel() }
            .onAppear {
                draft = card.text
                focused = true
            }
    }

    private var cardSurface: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(Style.cardWhite)
            .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
    }

    // MARK: - Gestures & editing

    private var singleTap: some Gesture {
        TapGesture().onEnded {
            guard !editing else { return }
            onSelect()
            let wasDone = card.isDone
            withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                store.toggleTask(card.id)
            }
            if !wasDone { celebrateDone() }
        }
    }

    private var doubleTap: some Gesture {
        TapGesture(count: 2).onEnded {
            guard !editing else { return }
            beginEdit()
        }
    }

    private func beginEdit() {
        draft = card.text
        editing = true
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { store.renameTask(card.id, to: trimmed) }
        editing = false
        onAutoEditDone()
    }

    private func cancel() {
        editing = false
        onAutoEditDone()
    }

    /// A short, quiet confetti burst when a task gets done.
    private func celebrateDone() {
        celebrating = true
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            celebrating = false
        }
    }
}

/// Enables `.draggable` only while the card is not being edited.
private struct DraggableIf: ViewModifier {
    let enabled: Bool
    let card: TaskCard

    func body(content: Content) -> some View {
        if enabled {
            content.draggable(card) { TaskCardPreview(card: card) }
        } else {
            content
        }
    }
}

/// The small card shown while dragging.
struct TaskCardPreview: View {
    let card: TaskCard

    var body: some View {
        Text(card.text)
            .font(.system(size: 13))
            .foregroundColor(Style.text)
            .multilineTextAlignment(.leading)
            .padding(10)
            .frame(width: 170, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Style.cardWhite)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            )
    }
}

/// Tiny radial burst of warm dots — the "celebration" when a task is done.
struct DoneCelebration: View {
    @State private var animating = false

    private let colors: [Color] = [
        Style.red,
        .orange,
        Color(hue: 0.11, saturation: 0.95, brightness: 0.95),
        Color(hue: 0.38, saturation: 0.75, brightness: 0.75),
        Style.red,
        Color(hue: 0.11, saturation: 0.95, brightness: 0.95),
    ]

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) / 8 * 2 * .pi
                let distance = 24 + Double(i % 3) * 5
                Circle()
                    .fill(colors[i % colors.count])
                    .frame(width: CGFloat(4 + i % 3), height: CGFloat(4 + i % 3))
                    .offset(
                        x: CGFloat(cos(angle) * (animating ? distance : 0)),
                        y: CGFloat(sin(angle) * (animating ? distance : 0))
                    )
                    .opacity(animating ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.55).delay(0.03)) { animating = true }
        }
    }
}