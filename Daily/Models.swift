import Foundation
import SwiftData

@Model
final class RecurringTask {
    var id: UUID
    var name: String
    /// Weekday indices: 0 = Sunday … 6 = Saturday
    var recurrenceDays: [Int]
    var isEveryday: Bool
    /// 1–5
    var points: Int
    var createdAt: Date
    var deletedAt: Date?

    /// True for tasks created ad-hoc for a single day from the Today view.
    /// These are never shown in Configure and are never backfilled.
    var isOneOff: Bool

    init(name: String, recurrenceDays: [Int], isEveryday: Bool, points: Int, isOneOff: Bool = false) {
        self.id = UUID()
        self.name = name
        self.recurrenceDays = recurrenceDays
        self.isEveryday = isEveryday
        self.points = points
        self.isOneOff = isOneOff
        self.createdAt = Date()
        self.deletedAt = nil
    }

    var recurrenceSummary: String {
        if isEveryday { return "Every day" }
        if recurrenceDays.isEmpty { return "No days set" }
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return recurrenceDays.sorted().map { names[$0] }.joined(separator: ", ")
    }

    func appliesOn(weekday: Int) -> Bool {
        if isEveryday { return true }
        return recurrenceDays.contains(weekday)
    }
}

@Model
final class DailyEntry {
    var id: UUID
    var taskID: UUID
    /// "yyyy-MM-dd"
    var date: String
    var isCompleted: Bool
    var pointsEarned: Int

    init(taskID: UUID, date: String) {
        self.id = UUID()
        self.taskID = taskID
        self.date = date
        self.isCompleted = false
        self.pointsEarned = 0
    }
}

@Model
final class UserProfile {
    var name: String
    var totalPoints: Int

    init(name: String = "My Name") {
        self.name = name
        self.totalPoints = 0
    }
}
