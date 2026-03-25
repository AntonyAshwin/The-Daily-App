//
//  TaskModel.swift
//  Daily
//
//  Created by Ashwin, Antony on 25/03/26.
//

import Foundation

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

