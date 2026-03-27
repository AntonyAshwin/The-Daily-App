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
    let pointsEarned: Int
}

class TaskViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var userProfile: UserProfile = UserProfile() {
        didSet {
            saveData()
        }
    }
    
    @Published var shieldUsedThisRound = false
    
    private let tasksKey = "tasks"
    private let userProfileKey = "userProfile"
    private let levelKey = "level" // legacy migration key
    private let streakKey = "streak" // legacy migration key
    private let pointsKey = "dailyPoints" // legacy migration key
    private let profileNameKey = "profileName" // legacy migration key
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
        recalculateStreak()
    }

    var todayTasks: [Task] {
        let today = Date()
        return tasks.filter { isTaskApplicable($0, on: today) }
    }

    var recurringTasks: [Task] {
        tasks
            .filter { $0.isEveryday || !$0.recurringDays.isEmpty }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var totalPoints: Int {
        tasks.reduce(0) { $0 + $1.pointsHistory.values.reduce(0, +) }
    }
    
    var canBuyShield: Bool {
        totalPoints >= 150 && userProfile.streakShields < userProfile.shieldCapacity
    }
    
    var shieldsDisplay: String {
        "\(userProfile.streakShields)/\(userProfile.shieldCapacity)"
    }
    
    var nextUpgradeCost: Int {
        userProfile.shieldCapacity == 1 ? 600 : (userProfile.shieldCapacity == 2 ? 1400 : 0)
    }
    
    var canUpgradeCapacity: Bool {
        (userProfile.shieldCapacity == 1 && totalPoints >= 600) ||
        (userProfile.shieldCapacity == 2 && totalPoints >= 1400)
    }
    
    func addTask(_ title: String, isEveryday: Bool = false, recurringDays: Set<Int> = [], points: Int = 1) {
        var newTask = Task(title: title)
        newTask.points = points
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
            let key = dateKey(for: Date())
            tasks[index].completionHistory[key] = tasks[index].isCompleted
            if tasks[index].isCompleted {
                tasks[index].pointsHistory[key] = tasks[index].points
            } else {
                tasks[index].pointsHistory.removeValue(forKey: key)
            }
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
                isCompleted: task.completionHistory[key] ?? false,
                pointsEarned: task.pointsHistory[key] ?? 0
            )
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func currentStreakDates(endingAt endDate: Date = Date()) -> [Date] {
        let calendar = Calendar.current
        let endDay = calendar.startOfDay(for: endDate)

        // Grace mode: if today is not perfect yet, show streak up to yesterday.
        let effectiveEndDay: Date
        if isPerfectDay(endDay) {
            effectiveEndDay = endDay
        } else {
            effectiveEndDay = calendar.date(byAdding: .day, value: -1, to: endDay) ?? endDay
        }

        return consecutivePerfectDates(endingAt: effectiveEndDay)
    }
    
    func historicalStreakDates() -> [Date] {
        // Return all dates where at least one task earned points (visible in history)
        let dateFormatter = self.dateFormatter
        var streakDates = Set<String>()
        
        for task in tasks {
            for (dateStr, _) in task.pointsHistory {
                streakDates.insert(dateStr)
            }
        }
        
        return streakDates
            .compactMap { dateFormatter.date(from: $0) }
            .sorted()
    }
    
    func shieldUsedDates() -> [Date] {
        // Return dates where shield was used
        return userProfile.shieldUsedDates
            .compactMap { dateFormatter.date(from: $0) }
            .sorted()
    }
    
    func updateStreakAndPoints() {
        let key = dateKey(for: Date())

        // Daily points = sum of snapshot points for today's completed tasks
        userProfile.dailyPoints = todayTasks.reduce(0) { sum, task in
            sum + (task.pointsHistory[key] ?? 0)
        }

        // Level up every 100 total points
        userProfile.level = 1 + (totalPoints / 100)

        // Keep streak aligned with true consecutive perfect days.
        recalculateStreak()

        saveData()
    }
    
    func getProgressPercentage() -> Double {
        let applicableTasks = todayTasks
        guard !applicableTasks.isEmpty else { return 0 }
        let completed = applicableTasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(applicableTasks.count)
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
    
    func buyShield() -> Bool {
        let cost = 150
        guard totalPoints >= cost && userProfile.streakShields < userProfile.shieldCapacity else {
            return false
        }
        
        // Deduct points by removing from pointsHistory
        var remainingCost = cost
        for index in tasks.indices {
            var daysToRemove: [String] = []
            for (date, points) in tasks[index].pointsHistory {
                if remainingCost <= 0 { break }
                if points <= remainingCost {
                    remainingCost -= points
                    daysToRemove.append(date)
                } else {
                    daysToRemove.append(date)
                    remainingCost = 0
                }
            }
            for date in daysToRemove {
                tasks[index].pointsHistory.removeValue(forKey: date)
            }
            if remainingCost <= 0 { break }
        }
        
        userProfile.streakShields += 1
        updateStreakAndPoints()
        return true
    }
    
    func upgradeCapacity() -> Bool {
        if userProfile.shieldCapacity == 1 && totalPoints >= 600 {
            // Deduct 600 points
            var cost = 600
            for index in tasks.indices {
                var daysToRemove: [String] = []
                for (date, points) in tasks[index].pointsHistory {
                    if cost <= 0 { break }
                    if points <= cost {
                        cost -= points
                        daysToRemove.append(date)
                    } else {
                        daysToRemove.append(date)
                        cost = 0
                    }
                }
                for date in daysToRemove {
                    tasks[index].pointsHistory.removeValue(forKey: date)
                }
                if cost <= 0 { break }
            }
            
            userProfile.shieldCapacity = 2
            updateStreakAndPoints()
            return true
        }
        
        if userProfile.shieldCapacity == 2 && totalPoints >= 1400 {
            // Deduct 1400 points
            var cost = 1400
            for index in tasks.indices {
                var daysToRemove: [String] = []
                for (date, points) in tasks[index].pointsHistory {
                    if cost <= 0 { break }
                    if points <= cost {
                        cost -= points
                        daysToRemove.append(date)
                    } else {
                        daysToRemove.append(date)
                        cost = 0
                    }
                }
                for date in daysToRemove {
                    tasks[index].pointsHistory.removeValue(forKey: date)
                }
                if cost <= 0 { break }
            }
            
            userProfile.shieldCapacity = 3
            updateStreakAndPoints()
            return true
        }
        
        return false
    }
    
    private func saveData() {
        UserDefaults.standard.set(try? JSONEncoder().encode(tasks), forKey: tasksKey)
        UserDefaults.standard.set(try? JSONEncoder().encode(userProfile), forKey: userProfileKey)
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: tasksKey) {
            if let decodedTasks = try? JSONDecoder().decode([Task].self, from: data) {
                tasks = decodedTasks
            }
        }

        if let profileData = UserDefaults.standard.data(forKey: userProfileKey),
           let decodedProfile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
            userProfile = decodedProfile
        } else {
            // Migrate data from legacy flat keys.
            var migratedProfile = UserProfile()
            let legacyLevel = UserDefaults.standard.integer(forKey: levelKey)
            migratedProfile.level = legacyLevel == 0 ? 1 : legacyLevel
            migratedProfile.streak = UserDefaults.standard.integer(forKey: streakKey)
            migratedProfile.dailyPoints = UserDefaults.standard.integer(forKey: pointsKey)
            migratedProfile.name = UserDefaults.standard.string(forKey: profileNameKey) ?? "My Name"
            userProfile = migratedProfile
            saveData()
        }
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
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let createdDay = calendar.startOfDay(for: task.createdAt)

        // A task should never be shown before it exists.
        guard day >= createdDay else {
            return false
        }

        if task.isEveryday {
            return true
        }

        if !task.recurringDays.isEmpty {
            let weekday = calendar.component(.weekday, from: date) - 1 // 0-6 Sun-Sat
            return task.recurringDays.contains(weekday)
        }

        return calendar.isDate(task.createdAt, inSameDayAs: date)
    }

    private func isPerfectDay(_ date: Date) -> Bool {
        let applicableTasks = tasks.filter { isTaskApplicable($0, on: date) }
        guard !applicableTasks.isEmpty else { return false }

        let key = dateKey(for: date)
        return applicableTasks.allSatisfy { task in
            task.completionHistory[key] ?? false
        }
    }

    private func recalculateStreak() {
        let newStreakCount = currentStreakDates().count
        let previousStreakCount = userProfile.streak
        
        // Check if streak would reset (new count < previous count)
        if newStreakCount < previousStreakCount && previousStreakCount > 0 {
            // Streak would reset - try to consume a shield
            if userProfile.streakShields > 0 {
                userProfile.streakShields -= 1
                shieldUsedThisRound = true
                // Keep previous streak by not updating it
                return
            }
        }
        
        // No shield available or streak didn't reset, update normally
        userProfile.streak = newStreakCount
        shieldUsedThisRound = false
    }

    private func consecutivePerfectDates(endingAt endDate: Date) -> [Date] {
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

    private func dateKey(for date: Date) -> String {
        dateFormatter.string(from: Calendar.current.startOfDay(for: date))
    }
}
