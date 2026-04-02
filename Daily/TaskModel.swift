//
//  TaskModel.swift
//  Daily
//
//  Created by Ashwin, Antony on 25/03/26.
//

import Foundation

struct UserProfile: Codable {
    var name: String = "My Name"
    var level: Int = 1
    var totalXP: Int = 0
    var streak: Int = 0
    var dailyPoints: Int = 0
    var rewardBonusRPByDate: [String: Int] = [:] // yyyy-MM-dd -> bonus RP earned from rewards
    var rewardShieldsByDate: [String: Int] = [:] // yyyy-MM-dd -> shields granted from rewards
    var ownedRewardAssets: [String] = [] // Purchased reward asset ids
    var streakShields: Int = 0
    var shieldCapacity: Int = 1
    var shieldUsedDates: [String] = [] // yyyy-MM-dd dates where shield was used
    var totalSpentRP: Int = 0 // Cumulative RP spent on shop purchases; never modifies history
}

// MARK: - Recurring Task (template/definition)

struct RecurringTask: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var createdAt: Date = Date()
    var deletedAt: Date? = nil
    var recurringDays: [Int] = [] // 0=Sun…6=Sat; empty = one-time
    var isEveryday: Bool = false
    var points: Int = 1

    var isActive: Bool { deletedAt == nil }

    var recurrenceText: String {
        if isEveryday {
            return "Everyday"
        } else if recurringDays.isEmpty {
            return "Once"
        } else {
            let days = ["S", "M", "T", "W", "T", "F", "S"]
            return recurringDays
                .sorted()
                .map { days[$0] }
                .joined(separator: "")
        }
    }
}

// MARK: - Daily Task Entry (one row per task × calendar day)

struct DailyTaskEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var taskID: UUID        // FK → RecurringTask.id
    var date: String        // "yyyy-MM-dd"
    var isDone: Bool = false
    var pointsEarned: Int = 0
    var xpEarned: Int = 0
}
