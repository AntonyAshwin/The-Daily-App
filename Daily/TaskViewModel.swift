//
//  TaskViewModel.swift
//  Daily
//
//  Created by Ashwin, Antony on 25/03/26.
//

import SwiftUI
import Combine
import AVFoundation

struct HistoryTaskItem: Identifiable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let pointsEarned: Int
}

class TaskViewModel: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
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
    private let recoverySeedKey = "recoverySeed_2026_03_28_applied"
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    init() {
        loadData()
        applyRecoverySeedIfNeeded()
        checkDailyReset()
        applyTaskStateForToday()
        updateStreakAndPoints(allowLevelUpRewards: false)
    }

    var todayTasks: [Task] {
        let today = Date()
        return tasks.filter { isTaskActive($0) && isTaskApplicable($0, on: today) }
    }

    var sortedTodayTasks: [Task] {
        todayTasks.sorted {
            if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    var recurringTasks: [Task] {
        tasks
            .filter { isTaskActive($0) && ($0.isEveryday || !$0.recurringDays.isEmpty) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var totalPoints: Int {
        let taskPoints = tasks.reduce(0) { $0 + $1.pointsHistory.values.reduce(0, +) }
        let rewardBonus = userProfile.rewardBonusRPByDate.values.reduce(0, +)
        return max(0, taskPoints + rewardBonus - userProfile.totalSpentRP)
    }

    var rewardAssets: [RewardAsset] {
        RewardAsset.catalog
    }

    var xpToNextLevel: Int {
        let remainder = userProfile.totalXP % 100
        return remainder == 0 ? 100 : (100 - remainder)
    }

    var rewardChanceBonusPercent: Int {
        Int(((userProfile.rewardChanceMultiplier - 1.0) * 100).rounded())
    }

    var taskRPBonusPercent: Int {
        Int(((userProfile.taskRPMultiplier - 1.0) * 100).rounded())
    }

    var xpBonusPercent: Int {
        Int(((userProfile.xpMultiplier - 1.0) * 100).rounded())
    }

    var activeBonusesSummary: String {
        let chance = "+\(rewardChanceBonusPercent)% reward chance"
        let taskRP = "+\(taskRPBonusPercent)% RP/task"
        let xp = "+\(xpBonusPercent)% XP"
        return [chance, taskRP, xp].joined(separator: ", ")
    }

    func isAssetOwned(_ asset: RewardAsset) -> Bool {
        userProfile.ownedRewardAssets.contains(asset.id)
    }

    func canPurchaseAsset(_ asset: RewardAsset) -> Bool {
        !isAssetOwned(asset)
        && userProfile.level >= asset.unlockLevel
        && totalPoints >= asset.price
    }

    func purchaseAsset(_ asset: RewardAsset) -> Bool {
        guard !isAssetOwned(asset) else { return false }
        guard userProfile.level >= asset.unlockLevel else { return false }
        guard totalPoints >= asset.price else { return false }
        guard spendRP(asset.price) else { return false }

        userProfile.ownedRewardAssets.append(asset.id)
        updateStreakAndPoints()
        return true
    }

    func rewardSummary(for date: Date) -> (bonusRP: Int, shields: Int) {
        let key = dateKey(for: date)
        return (
            bonusRP: userProfile.rewardBonusRPByDate[key] ?? 0,
            shields: userProfile.rewardShieldsByDate[key] ?? 0
        )
    }

    func basePointsForDate(_ date: Date) -> Int {
        tasksForDate(date).reduce(0) { $0 + $1.pointsEarned }
    }
    
    private func shieldCost() -> Int {
        switch userProfile.streakShields {
        case 0: return 150  // 1st shield
        case 1: return 250  // 2nd shield
        case 2: return 400  // 3rd shield
        default: return 0   // Can't buy more
        }
    }
    
    var canBuyShield: Bool {
        let cost = shieldCost()
        return totalPoints >= cost && userProfile.streakShields < userProfile.shieldCapacity
    }
    
    var shieldsDisplay: String {
        "\(userProfile.streakShields)/\(userProfile.shieldCapacity)"
    }
    
    var shieldCostDisplay: Int {
        shieldCost()
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
        guard tasks.indices.contains(index) else { return }
        tasks[index].deletedAt = Date()
        tasks[index].isCompleted = false
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
                let taskEarnedRP = scaledTaskRP(task.points)
                tasks[index].pointsHistory[key] = taskEarnedRP
                tasks[index].xpHistory[key] = scaledXP(fromTaskRP: taskEarnedRP)
                let allDone = todayTasks.filter { $0.id != task.id }.allSatisfy { $0.isCompleted }
                if allDone {
                    playAllCompleteSound()
                } else {
                    playTaskCompleteSound()
                }
                applyTaskCompletionReward(for: tasks[index])
            } else {
                tasks[index].pointsHistory.removeValue(forKey: key)
                tasks[index].xpHistory.removeValue(forKey: key)
            }
            updateStreakAndPoints()
            saveData()
        }
    }

    private func playTaskCompleteSound() {
        guard let url = Bundle.main.url(forResource: "taskComplete", withExtension: "mp3") else { return }
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.play()
    }

    private func playAllCompleteSound() {
        guard let url = Bundle.main.url(forResource: "Complete", withExtension: "mp3") else { return }
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.play()
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
    
    func updateStreakAndPoints(allowLevelUpRewards: Bool = true) {
        let key = dateKey(for: Date())
        let previousLevel = userProfile.level

        // Daily points = sum of snapshot points for today's completed tasks
        userProfile.dailyPoints = todayTasks.reduce(0) { sum, task in
            sum + (task.pointsHistory[key] ?? 0)
        }

        // XP = 2x RP for each completed task entry, independent from RP spend/deduction flows.
        userProfile.totalXP = totalEarnedXP()

        // Level up every 100 XP.
        userProfile.level = 1 + (userProfile.totalXP / 100)

        if allowLevelUpRewards {
            let levelsGained = max(0, userProfile.level - previousLevel)
            if levelsGained > 0 {
                for _ in 0..<levelsGained {
                    applyLevelUpReward()
                }
            }
        }

        // Keep streak aligned with true consecutive perfect days.
        recalculateStreak()

        saveData()
    }

    private func totalEarnedXP() -> Int {
        tasks.reduce(0) { total, task in
            let xpForTask = task.completionHistory.reduce(0) { partial, entry in
                guard entry.value else { return partial }
                if let storedXP = task.xpHistory[entry.key] {
                    return partial + storedXP
                }
                let fallbackRP = task.pointsHistory[entry.key] ?? task.points
                return partial + (fallbackRP * 2)
            }
            return total + xpForTask
        }
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
        let cost = shieldCost()
        guard totalPoints >= cost && userProfile.streakShields < userProfile.shieldCapacity else {
            return false
        }

        guard spendRP(cost) else { return false }
        
        userProfile.streakShields += 1
        updateStreakAndPoints()
        return true
    }
    
    func upgradeCapacity() -> Bool {
        if userProfile.shieldCapacity == 1 && totalPoints >= 600 {
            guard spendRP(600) else { return false }
            
            userProfile.shieldCapacity = 2
            updateStreakAndPoints()
            return true
        }
        
        if userProfile.shieldCapacity == 2 && totalPoints >= 1400 {
            guard spendRP(1400) else { return false }
            
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

    private func applyRecoverySeedIfNeeded() {
        // One-time safety net: restore a minimal snapshot only when data is empty.
        guard !UserDefaults.standard.bool(forKey: recoverySeedKey) else { return }
        guard tasks.isEmpty else { return }
        guard userProfile.totalXP == 0 && userProfile.rewardBonusRPByDate.isEmpty else { return }

        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 28
        let calendar = Calendar.current
        guard let recoveryDate = calendar.date(from: components) else { return }

        let key = dateKey(for: recoveryDate)

        var recoveredTask = Task(title: "Recovered Progress (28 Mar)")
        recoveredTask.createdAt = recoveryDate
        recoveredTask.isEveryday = false
        recoveredTask.recurringDays = []
        recoveredTask.completionHistory[key] = true
        recoveredTask.pointsHistory[key] = 46
        recoveredTask.xpHistory[key] = 92
        recoveredTask.isCompleted = false

        tasks = [recoveredTask]
        userProfile.level = 1
        userProfile.totalXP = 92
        userProfile.dailyPoints = 0

        UserDefaults.standard.set(true, forKey: recoverySeedKey)
        saveData()
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
        let deletedDay = task.deletedAt.map { calendar.startOfDay(for: $0) }

        // A task should never be shown before it exists.
        guard day >= createdDay else {
            return false
        }

        // Deleted tasks still exist for history up to their deletion day.
        if let deletedDay, day > deletedDay {
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

    private func isTaskActive(_ task: Task) -> Bool {
        task.deletedAt == nil
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

    private func applyTaskCompletionReward(for task: Task) {
        // 30% trigger chance on completion.
        let triggerChance = min(1.0, 0.30 * userProfile.rewardChanceMultiplier)
        guard Double.random(in: 0...1) <= triggerChance else { return }

        let rawTaskBonus = max(Int.random(in: 3...10), task.points)
        let taskBonus = scaledRewardRP(rawTaskBonus)
        if Double.random(in: 0...1) <= 0.95 {
            grantBonusRP(taskBonus)
        } else {
            grantShieldOrFallbackRP(fallbackRP: taskBonus)
        }
    }

    private func applyLevelUpReward() {
        // Guaranteed reward on each level gained.
        let levelUpBonus = scaledRewardRP(Int.random(in: 10...20))
        if Double.random(in: 0...1) <= 0.70 {
            grantBonusRP(levelUpBonus)
        } else {
            grantShieldOrFallbackRP(fallbackRP: levelUpBonus)
        }
    }

    private func grantBonusRP(_ points: Int) {
        guard points > 0 else { return }
        let key = dateKey(for: Date())
        userProfile.rewardBonusRPByDate[key, default: 0] += points
    }

    private func grantShieldOrFallbackRP(fallbackRP: Int) {
        if userProfile.streakShields < userProfile.shieldCapacity {
            userProfile.streakShields += 1
            let key = dateKey(for: Date())
            userProfile.rewardShieldsByDate[key, default: 0] += 1
        } else {
            grantBonusRP(fallbackRP)
        }
    }

    private func spendRP(_ amount: Int) -> Bool {
        guard amount > 0 else { return true }
        guard totalPoints >= amount else { return false }
        userProfile.totalSpentRP += amount
        return true
    }

    private func scaledTaskRP(_ baseRP: Int) -> Int {
        max(1, Int((Double(baseRP) * userProfile.taskRPMultiplier).rounded()))
    }

    private func scaledXP(fromTaskRP taskRP: Int) -> Int {
        max(1, Int((Double(taskRP * 2) * userProfile.xpMultiplier).rounded()))
    }

    private func scaledRewardRP(_ baseRP: Int) -> Int {
        max(1, Int((Double(baseRP) * userProfile.rewardRPMultiplier).rounded()))
    }
}
