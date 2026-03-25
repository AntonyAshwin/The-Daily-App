//
//  TaskViewModel.swift
//  Daily
//
//  Created by Ashwin, Antony on 25/03/26.
//

import SwiftUI
import Combine

class TaskViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var level: Int = 1
    @Published var streak: Int = 0
    @Published var dailyPoints: Int = 0
    
    private let tasksKey = "tasks"
    private let levelKey = "level"
    private let streakKey = "streak"
    private let pointsKey = "dailyPoints"
    private let lastCheckKey = "lastCheckDate"
    
    init() {
        loadData()
        checkDailyReset()
    }
    
    func addTask(_ title: String, isEveryday: Bool = false, recurringDays: Set<Int> = []) {
        var newTask = Task(title: title)
        newTask.isEveryday = isEveryday
        newTask.recurringDays = isEveryday ? Array(0...6) : Array(recurringDays)
        tasks.append(newTask)
        saveData()
    }
    
    func deleteTask(at index: Int) {
        tasks.remove(at: index)
        updateStreakAndPoints()
        saveData()
    }
    
    func updateTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            updateStreakAndPoints()
            saveData()
        }
    }
    
    func toggleTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted.toggle()
            updateStreakAndPoints()
            saveData()
        }
    }
    
    func updateStreakAndPoints() {
        let completedCount = tasks.filter { $0.isCompleted }.count
        let totalCount = tasks.count
        
        if totalCount > 0 && completedCount == totalCount {
            if streak == 0 {
                streak = 1
            } else {
                streak += 1
            }
            dailyPoints += 50
        } else if completedCount < totalCount {
            streak = 0
        }
        
        // Award points per completed task
        dailyPoints = completedCount * 10
        
        // Level up every 100 points
        level = 1 + (dailyPoints / 100)
        
        saveData()
    }
    
    func getProgressPercentage() -> Double {
        guard !tasks.isEmpty else { return 0 }
        let completed = tasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(tasks.count)
    }
    
    func getProgressColor() -> Color {
        let progress = getProgressPercentage()
        
        if progress <= 0.25 {
            return Color(red: 1.0, green: 0.27, blue: 0.41) // Duolingo red
        } else if progress <= 0.5 {
            return Color(red: 1.0, green: 0.65, blue: 0.2) // Orange
        } else if progress <= 0.75 {
            return Color(red: 1.0, green: 0.92, blue: 0.23) // Yellow
        } else {
            return Color(red: 0.0, green: 0.816, blue: 0.518) // Duolingo green
        }
    }
    
    private func saveData() {
        UserDefaults.standard.set(try? JSONEncoder().encode(tasks), forKey: tasksKey)
        UserDefaults.standard.set(level, forKey: levelKey)
        UserDefaults.standard.set(streak, forKey: streakKey)
        UserDefaults.standard.set(dailyPoints, forKey: pointsKey)
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: tasksKey) {
            if let decodedTasks = try? JSONDecoder().decode([Task].self, from: data) {
                tasks = decodedTasks
            }
        }
        
        level = UserDefaults.standard.integer(forKey: levelKey)
        if level == 0 { level = 1 }
        
        streak = UserDefaults.standard.integer(forKey: streakKey)
        dailyPoints = UserDefaults.standard.integer(forKey: pointsKey)
    }
    
    private func checkDailyReset() {
        let lastCheckKey = "lastCheckDate"
        let today = Calendar.current.startOfDay(for: Date())
        
        if let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date {
            let lastCheckDate = Calendar.current.startOfDay(for: lastCheck)
            if today > lastCheckDate {
                // New day - reset recurring tasks
                let todayWeekday = Calendar.current.component(.weekday, from: Date()) - 1 // 0-6 Sun-Sat
                
                tasks = tasks.map { var task = $0
                    // Reset completion if it's a recurring task and today is one of its days
                    if !task.recurringDays.isEmpty {
                        if task.isEveryday || task.recurringDays.contains(todayWeekday) {
                            task.isCompleted = false
                        }
                    }
                    return task
                }
                dailyPoints = 0
                streak = 0
                saveData()
            }
        }
        UserDefaults.standard.set(Date(), forKey: lastCheckKey)
    }
}
