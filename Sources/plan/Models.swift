import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// A single sticky-note style task on the board.
struct TaskCard: Identifiable, Codable, Hashable, Transferable {
    let id: UUID
    var text: String
    var isDone: Bool

    init(id: UUID = UUID(), text: String, isDone: Bool = false) {
        self.id = id
        self.text = text
        self.isDone = isDone
    }

    /// Enables drag-and-drop of cards between grid cells.
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

/// A row on the board.
struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String

    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }
}

/// A column on the board.
struct Week: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String

    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }
}

/// Identifies a single board cell: the intersection of one project and one week.
struct GridKey: Hashable, Codable {
    var projectID: UUID
    var weekID: UUID
}

/// Everything we persist to disk (JSON).
/// Tasks are keyed by "<projectID>|<weekID>" for clean, stable serialization.
struct BoardState: Codable {
    var projects: [Project]
    var weeks: [Week]
    var tasks: [String: [TaskCard]]
}