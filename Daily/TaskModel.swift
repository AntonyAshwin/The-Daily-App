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
    var streak: Int = 0
    var dailyPoints: Int = 0
}

struct Task: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
    var createdAt = Date()
    var recurringDays: [Int] = [] // 0-6 for Sun-Sat, empty = no recurrence
    var isEveryday: Bool = false
    var completionHistory: [String: Bool] = [:] // yyyy-MM-dd -> completion state
    
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

