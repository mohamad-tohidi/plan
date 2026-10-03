import Foundation
import Observation

/// The single source of truth for the board. Persists to a JSON file in
/// Application Support on every mutation (debounced slightly while typing).
///
/// The board is always a fixed 2-week × N-project grid.
@MainActor
@Observable
final class Store {
    var projects: [Project] = []
    var weeks: [Week] = []
    var tasks: [String: [TaskCard]] = [:]

    /// Session-only signal: which card should play its done-celebration.
    var celebrationTaskID: UUID?

    private var saveTask: Task<Void, Never>?

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("WhiteboardScrumPlanner", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("board.json")
    }

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let state = try? JSONDecoder().decode(BoardState.self, from: data) {
            projects = state.projects
            weeks = state.weeks
            tasks = state.tasks
            // Always keep exactly two weeks.
            if weeks.count != 2 || projects.isEmpty { installSampleData() }
        } else {
            installSampleData()
        }
    }

    // MARK: - Sample board (first run only)

    func installSampleData() {
        weeks = [Week(title: "Week 1"), Week(title: "Week 2")]
        projects = [
            Project(title: "Mobile App"),
            Project(title: "Backend API"),
            Project(title: "Design"),
        ]

        func mk(_ text: String, done: Bool = false) -> TaskCard { TaskCard(text: text, isDone: done) }
        let key: (Project, Week) -> String = { self.keyString($0.id, $1.id) }
        let w1 = weeks[0], w2 = weeks[1]

        tasks = [
            key(projects[0], w1): [mk("Map the onboarding flow"), mk("Wireframe the home screen", done: true)],
            key(projects[0], w2): [mk("Build the home screen UI")],
            key(projects[1], w1): [mk("Auth endpoints"), mk("CI pipeline", done: true)],
            key(projects[1], w2): [mk("Payments integration"), mk("Load testing")],
            key(projects[2], w1): [mk("Color & type tokens", done: true)],
            key(projects[2], w2): [mk("Icon set")],
        ]
        save()
    }

    // MARK: - Query helpers

    /// Stable string key: "<projectID>|<weekID>".
    func keyString(_ key: GridKey) -> String {
        key.projectID.uuidString + "|" + key.weekID.uuidString
    }

    func keyString(_ projectID: UUID, _ weekID: UUID) -> String {
        projectID.uuidString + "|" + weekID.uuidString
    }

    func tasks(for key: GridKey) -> [TaskCard] { tasks[keyString(key)] ?? [] }

    func counts(for week: Week) -> (done: Int, total: Int) {
        var done = 0, total = 0
        for (k, arr) in tasks where k.hasSuffix(week.id.uuidString) {
            total += arr.count
            done += arr.filter { $0.isDone }.count
        }
        return (done, total)
    }

    var overallCounts: (done: Int, total: Int) {
        var done = 0, total = 0
        for arr in tasks.values {
            total += arr.count
            done += arr.filter { $0.isDone }.count
        }
        return (done, total)
    }

    // MARK: - Projects (rows)

    @discardableResult
    func addProject() -> Project {
        let project = Project(title: "Project \(projects.count + 1)")
        projects.append(project)
        save()
        return project
    }

    func removeProject(_ id: UUID) {
        projects.removeAll { $0.id == id }
        tasks = tasks.filter { !$0.key.hasPrefix(id.uuidString) }
        save()
    }

    func renameProject(_ id: UUID, to title: String) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        projects[index].title = trimmed
        save()
    }

    // MARK: - Task cards

    @discardableResult
    func addTask(to key: GridKey) -> TaskCard {
        let card = TaskCard(text: "New task")
        tasks[keyString(key), default: []].append(card)
        save()
        return card
    }

    func renameTask(_ id: UUID, to text: String) {
        guard let (key, index) = locate(id) else { return }
        tasks[key]?[index].text = text
        scheduleSave()
    }

    func toggleTask(_ id: UUID) {
        guard let (key, index) = locate(id) else { return }
        tasks[key]?[index].isDone.toggle()
        save()
    }

    func removeTask(_ id: UUID) {
        guard let (key, index) = locate(id) else { return }
        tasks[key]?.remove(at: index)
        if tasks[key]?.isEmpty == true { tasks[key] = nil }
        save()
    }

    func moveTask(_ id: UUID, to target: GridKey) {
        guard let (from, index) = locate(id), from != keyString(target) else { return }
        guard let card = tasks[from]?.remove(at: index) else { return }
        if tasks[from]?.isEmpty == true { tasks[from] = nil }
        tasks[keyString(target), default: []].append(card)
        save()
    }

    /// Re-inserts a card (vim `p` after `d`).
    func insertTask(_ card: TaskCard, at key: GridKey) {
        tasks[keyString(key), default: []].append(card)
        save()
    }

    /// Flags a card so its view plays the done-celebration (used by the
    /// vim `x` command — mouse clicks celebrate locally).
    func celebrate(_ cardID: UUID) {
        celebrationTaskID = cardID
    }

    private func locate(_ id: UUID) -> (String, Int)? {
        for (key, arr) in tasks {
            if let i = arr.firstIndex(where: { $0.id == id }) { return (key, i) }
        }
        return nil
    }

    // MARK: - Persistence

    func save() {
        saveTask?.cancel()
        do {
            let state = BoardState(projects: projects, weeks: weeks, tasks: tasks)
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("WhiteboardScrumPlanner save failed: \(error)")
        }
    }

    /// Debounced save used while the user is typing in a card.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }
}