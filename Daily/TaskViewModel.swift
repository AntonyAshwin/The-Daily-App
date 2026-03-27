//
//  TaskViewModel.swift
//  Daily
//
//  Created by Ashwin, Antony on 25/03/26.
//

import SwiftUI
import Combine

struct HistoryTaskItem: Identifiable {
    let id: UUID
    let title: String
    let isCompleted: Bool
}

class TaskViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var level: Int = 1
    @Published var streak: Int = 0
    @Published var dailyPoints: Int = 0
    @Published var profileName: String = "My Name" {
        didSet {
            saveData()
        }
    }
    
    private let tasksKey = "tasks"
    private let levelKey = "level"
    private let streakKey = "streak"
    private let pointsKey = "dailyPoints"
    private let profileNameKey = "profileName"
    private let lastCheckKey = "lastCheckDate"
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    init() {
        loadData()
        checkDailyReset()
        applyTaskStateForToday()
    }
    
    func addTask(_ title: String, isEveryday: Bool = false, recurringDays: Set<Int> = []) {
        var newTask = Task(title: title)
        newTask.isEveryday = isEveryday
        newTask.recurringDays = isEveryday ? Array(0...6) : Array(recurringDays)
        if isTaskApplicable(newTask, on: Date()) {
            newTask.completionHistory[dateKey(for: Date())] = false
        }
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
            tasks[index].completionHistory[dateKey(for: Date())] = tasks[index].isCompleted
            updateStreakAndPoints()
            saveData()
        }
    }

    func tasksForDate(_ date: Date) -> [HistoryTaskItem] {
        let key = dateKey(for: date)

        return tasks.compactMap { task in
            guard isTaskApplicable(task, on: date) else {
                return nil
            }

            return HistoryTaskItem(
                id: task.id,
                title: task.title,
                isCompleted: task.completionHistory[key] ?? false
            )
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func currentStreakDates(endingAt endDate: Date = Date()) -> [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []
        var cursor = calendar.startOfDay(for: endDate)

        while isPerfectDay(cursor) {
            dates.append(cursor)
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }

        return dates.reversed()
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
        UserDefaults.standard.set(profileName, forKey: profileNameKey)
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
        profileName = UserDefaults.standard.string(forKey: profileNameKey) ?? "My Name"
    }
    
    private func checkDailyReset() {
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
                            task.completionHistory[dateKey(for: today)] = false
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

    private func applyTaskStateForToday() {
        let today = Date()
        let key = dateKey(for: today)

        tasks = tasks.map { task in
            var updatedTask = task
            if isTaskApplicable(updatedTask, on: today) {
                updatedTask.isCompleted = updatedTask.completionHistory[key] ?? false
            } else {
                updatedTask.isCompleted = false
            }
            return updatedTask
        }
    }

    private func isTaskApplicable(_ task: Task, on date: Date) -> Bool {
        if task.isEveryday {
            return true
        }

        if !task.recurringDays.isEmpty {
            let weekday = Calendar.current.component(.weekday, from: date) - 1 // 0-6 Sun-Sat
            return task.recurringDays.contains(weekday)
        }

        return Calendar.current.isDate(task.createdAt, inSameDayAs: date)
    }

    private func isPerfectDay(_ date: Date) -> Bool {
        let applicableTasks = tasks.filter { isTaskApplicable($0, on: date) }
        guard !applicableTasks.isEmpty else { return false }

        let key = dateKey(for: date)
        return applicableTasks.allSatisfy { task in
            task.completionHistory[key] ?? false
        }
    }

    private func dateKey(for date: Date) -> String {
        dateFormatter.string(from: Calendar.current.startOfDay(for: date))
    }
}
