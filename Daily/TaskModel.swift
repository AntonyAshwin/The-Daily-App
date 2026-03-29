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
}

struct Task: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
    var createdAt = Date()
    var deletedAt: Date? = nil
    var recurringDays: [Int] = [] // 0-6 for Sun-Sat, empty = no recurrence
    var isEveryday: Bool = false
    var completionHistory: [String: Bool] = [:] // yyyy-MM-dd -> completion state
    var points: Int = 1
    var pointsHistory: [String: Int] = [:] // yyyy-MM-dd -> points earned that day
    var xpHistory: [String: Int] = [:] // yyyy-MM-dd -> xp earned that day
    
    var recurrenceText: String {
        if isEveryday {
            return "Everyday"
        } else if recurringDays.isEmpty {
            return "Once"
        } else {
            let days = ["S", "M", "T", "W", "T", "F", "S"]
            let selectedDays = recurringDays
                .sorted()
                .map { days[$0] }
                .joined(separator: "")
            return selectedDays
        }
    }
}

