//
//  TaskViewModel.swift
//  Daily
//
//  Created by Ashwin, Antony on 25/03/26.
//

import SwiftUI
import Combine
import AVFoundation

// MARK: - Display struct for today's task list

struct TodayTaskDisplay: Identifiable {
    let entry: DailyTaskEntry
    let task: RecurringTask
    var id: UUID { entry.id }
    var title: String { task.title }
    var points: Int { task.points }
    var isCompleted: Bool { entry.isDone }
    var recurrenceText: String { task.recurrenceText }
}

// MARK: - History item (unchanged shape, consumed by HistoryView)

struct HistoryTaskItem: Identifiable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let pointsEarned: Int
}

// MARK: - ViewModel

class TaskViewModel: ObservableObject {
    private var audioPlayer: AVAudioPlayer?

    @Published var recurringTasks: [RecurringTask] = []
    @Published var dailyEntries: [DailyTaskEntry] = []
    @Published var userProfile: UserProfile = UserProfile() {
        didSet { saveData() }
    }
    @Published var shieldUsedThisRound = false

    // Persistence keys
    private let recurringTasksKey = "recurringTasks_v2"
    private let dailyEntriesKey   = "dailyTaskEntries_v2"
    private let userProfileKey    = "userProfile"
    private let migrationV2Key    = "migration_v2_completed"
    private let recoverySeedKey   = "recoverySeed_2026_03_28_applied"

    // Legacy keys (profile migration only)
    private let levelKey       = "level"
    private let streakKey      = "streak"
    private let pointsKey      = "dailyPoints"
    private let profileNameKey = "profileName"

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init() {
        loadData()
        migrateV2IfNeeded()
        applyRecoverySeedIfNeeded()
        backfillAllTasks()
        updateStreakAndPoints(allowLevelUpRewards: false)
    }

    // MARK: - Computed properties

    var sortedTodayDisplays: [TodayTaskDisplay] {
        let key = dateKey(for: Date())
        return dailyEntries
            .filter { $0.date == key }
            .compactMap { entry -> TodayTaskDisplay? in
                guard let task = recurringTasks.first(where: { $0.id == entry.taskID }),
                      task.isActive else { return nil }
                return TodayTaskDisplay(entry: entry, task: task)
            }
            .sorted {
                if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }

    var recurringTaskDefinitions: [RecurringTask] {
        recurringTasks
            .filter { $0.isActive && ($0.isEveryday || !$0.recurringDays.isEmpty) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var totalPoints: Int {
        let taskPoints = dailyEntries.reduce(0) { $0 + $1.pointsEarned }
        let rewardBonus = userProfile.rewardBonusRPByDate.values.reduce(0, +)
        return max(0, taskPoints + rewardBonus - userProfile.totalSpentRP)
    }

    var rewardAssets: [RewardAsset] { RewardAsset.catalog }

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

    var canBuyShield: Bool {
        let cost = shieldCost()
        return totalPoints >= cost && userProfile.streakShields < userProfile.shieldCapacity
    }

    var shieldsDisplay: String { "\(userProfile.streakShields)/\(userProfile.shieldCapacity)" }

    var shieldCostDisplay: Int { shieldCost() }

    var nextUpgradeCost: Int {
        userProfile.shieldCapacity == 1 ? 600 : (userProfile.shieldCapacity == 2 ? 1400 : 0)
    }

    var canUpgradeCapacity: Bool {
        (userProfile.shieldCapacity == 1 && totalPoints >= 600) ||
        (userProfile.shieldCapacity == 2 && totalPoints >= 1400)
    }

    // MARK: - Task management

    func addTask(_ title: String, isEveryday: Bool = false, recurringDays: Set<Int> = [], points: Int = 1) {
        var newTask = RecurringTask(title: title)
        newTask.points = points
        newTask.isEveryday = isEveryday
        newTask.recurringDays = isEveryday ? Array(0...6) : Array(recurringDays)
        recurringTasks.append(newTask)
        backfill(task: newTask, upTo: Date())
        saveData()
    }

    func deleteTask(at index: Int) {
        guard recurringTasks.indices.contains(index) else { return }
        recurringTasks[index].deletedAt = Date()
        updateStreakAndPoints()
        saveData()
    }

    func updateTask(_ task: RecurringTask) {
        if let index = recurringTasks.firstIndex(where: { $0.id == task.id }) {
            recurringTasks[index] = task
            backfill(task: task, upTo: Date())
            updateStreakAndPoints()
            saveData()
        }
    }

    func toggleTask(_ entry: DailyTaskEntry) {
        guard let idx = dailyEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        guard let task = recurringTasks.first(where: { $0.id == entry.taskID }) else { return }

        dailyEntries[idx].isDone.toggle()

        if dailyEntries[idx].isDone {
            let earnedRP = scaledTaskRP(task.points)
            let earnedXP = scaledXP(fromTaskRP: earnedRP)
            dailyEntries[idx].pointsEarned = earnedRP
            dailyEntries[idx].xpEarned = earnedXP

            let todayKey = dateKey(for: Date())
            let allDone = dailyEntries
                .filter { $0.date == todayKey && $0.id != entry.id }
                .allSatisfy { $0.isDone }
            if allDone { playAllCompleteSound() } else { playTaskCompleteSound() }
            applyTaskCompletionReward(for: task)
        } else {
            dailyEntries[idx].pointsEarned = 0
            dailyEntries[idx].xpEarned = 0
        }

        updateStreakAndPoints()
        saveData()
    }

    // MARK: - Shop

    func isAssetOwned(_ asset: RewardAsset) -> Bool {
        userProfile.ownedRewardAssets.contains(asset.id)
    }

    func canPurchaseAsset(_ asset: RewardAsset) -> Bool {
        !isAssetOwned(asset) && userProfile.level >= asset.unlockLevel && totalPoints >= asset.price
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

    func buyShield() -> Bool {
        let cost = shieldCost()
        guard totalPoints >= cost && userProfile.streakShields < userProfile.shieldCapacity else { return false }
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

    // MARK: - History & Analytics

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

    func tasksForDate(_ date: Date) -> [HistoryTaskItem] {
        let key = dateKey(for: date)
        return dailyEntries
            .filter { $0.date == key }
            .compactMap { entry -> HistoryTaskItem? in
                guard let task = recurringTasks.first(where: { $0.id == entry.taskID }) else { return nil }
                return HistoryTaskItem(
                    id: entry.id,
                    title: task.title,
                    isCompleted: entry.isDone,
                    pointsEarned: entry.pointsEarned
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func getProgressPercentage() -> Double {
        let displays = sortedTodayDisplays
        guard !displays.isEmpty else { return 0 }
        let completed = displays.filter { $0.isCompleted }.count
        return Double(completed) / Double(displays.count)
    }

    func getProgressColor() -> Color {
        let progress = getProgressPercentage()
        if progress <= 0.25 {
            return Color(red: 1.0, green: 0.27, blue: 0.41)
        } else if progress <= 0.5 {
            return Color(red: 1.0, green: 0.65, blue: 0.2)
        } else if progress <= 0.75 {
            return Color(red: 1.0, green: 0.92, blue: 0.23)
        } else {
            return Color(red: 0.0, green: 0.816, blue: 0.518)
        }
    }

    func currentStreakDates(endingAt endDate: Date = Date()) -> [Date] {
        let calendar = Calendar.current
        let endDay = calendar.startOfDay(for: endDate)
        let effectiveEndDay: Date
        if isPerfectDay(endDay) {
            effectiveEndDay = endDay
        } else {
            effectiveEndDay = calendar.date(byAdding: .day, value: -1, to: endDay) ?? endDay
        }
        return consecutivePerfectDates(endingAt: effectiveEndDay)
    }

    func historicalStreakDates() -> [Date] {
        let datesWithPoints = Set(dailyEntries.filter { $0.pointsEarned > 0 }.map { $0.date })
        return datesWithPoints
            .compactMap { dateFormatter.date(from: $0) }
            .sorted()
    }

    func shieldUsedDates() -> [Date] {
        return userProfile.shieldUsedDates
            .compactMap { dateFormatter.date(from: $0) }
            .sorted()
    }

    func updateStreakAndPoints(allowLevelUpRewards: Bool = true) {
        let key = dateKey(for: Date())
        let previousLevel = userProfile.level

        userProfile.dailyPoints = dailyEntries
            .filter { $0.date == key }
            .reduce(0) { $0 + $1.pointsEarned }

        userProfile.totalXP = totalEarnedXP()
        userProfile.level = 1 + (userProfile.totalXP / 100)

        if allowLevelUpRewards {
            let levelsGained = max(0, userProfile.level - previousLevel)
            for _ in 0..<levelsGained { applyLevelUpReward() }
        }

        recalculateStreak()
        saveData()
    }

    // MARK: - Persistence

    private func saveData() {
        UserDefaults.standard.set(try? JSONEncoder().encode(recurringTasks), forKey: recurringTasksKey)
        UserDefaults.standard.set(try? JSONEncoder().encode(dailyEntries),   forKey: dailyEntriesKey)
        UserDefaults.standard.set(try? JSONEncoder().encode(userProfile),    forKey: userProfileKey)
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: recurringTasksKey),
           let decoded = try? JSONDecoder().decode([RecurringTask].self, from: data) {
            recurringTasks = decoded
        }
        if let data = UserDefaults.standard.data(forKey: dailyEntriesKey),
           let decoded = try? JSONDecoder().decode([DailyTaskEntry].self, from: data) {
            dailyEntries = decoded
        }
        if let data = UserDefaults.standard.data(forKey: userProfileKey),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            userProfile = decoded
        } else {
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

    // MARK: - Migration from old Task model

    private struct LegacyTask: Codable {
        var id: UUID = UUID()
        var title: String
        var createdAt: Date = Date()
        var deletedAt: Date? = nil
        var recurringDays: [Int] = []
        var isEveryday: Bool = false
        var points: Int = 1
        var completionHistory: [String: Bool] = [:]
        var pointsHistory: [String: Int] = [:]
        var xpHistory: [String: Int] = [:]
    }

    private func migrateV2IfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationV2Key) else { return }

        defer { UserDefaults.standard.set(true, forKey: migrationV2Key) }

        guard let data = UserDefaults.standard.data(forKey: "tasks"),
              let oldTasks = try? JSONDecoder().decode([LegacyTask].self, from: data),
              !oldTasks.isEmpty else {
            return
        }

        var newTasks: [RecurringTask] = []
        var newEntries: [DailyTaskEntry] = []

        for old in oldTasks {
            var newTask = RecurringTask(title: old.title)
            newTask.id = old.id
            newTask.createdAt = old.createdAt
            newTask.deletedAt = old.deletedAt
            newTask.recurringDays = old.recurringDays
            newTask.isEveryday = old.isEveryday
            newTask.points = old.points
            newTasks.append(newTask)

            for (dateStr, isCompleted) in old.completionHistory {
                let earnedRP = old.pointsHistory[dateStr] ?? 0
                let earnedXP = old.xpHistory[dateStr] ?? (earnedRP * 2)
                let entry = DailyTaskEntry(
                    taskID: old.id,
                    date: dateStr,
                    isDone: isCompleted,
                    pointsEarned: earnedRP,
                    xpEarned: earnedXP
                )
                newEntries.append(entry)
            }
        }

        recurringTasks = newTasks
        dailyEntries = newEntries
        saveData()
    }

    // MARK: - Backfill

    private func isTaskApplicable(_ task: RecurringTask, on date: Date) -> Bool {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let createdDay = calendar.startOfDay(for: task.createdAt)
        guard day >= createdDay else { return false }

        if let deletedAt = task.deletedAt {
            let deletedDay = calendar.startOfDay(for: deletedAt)
            if day > deletedDay { return false }
        }

        if task.isEveryday { return true }

        if !task.recurringDays.isEmpty {
            let weekday = calendar.component(.weekday, from: date) - 1
            return task.recurringDays.contains(weekday)
        }

        return calendar.isDate(task.createdAt, inSameDayAs: date)
    }

    private func backfill(task: RecurringTask, upTo today: Date) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)

        let existingDates = Set(
            dailyEntries
                .filter { $0.taskID == task.id }
                .map { $0.date }
        )

        var cursor = calendar.startOfDay(for: task.createdAt)

        while cursor <= todayStart {
            if isTaskApplicable(task, on: cursor) {
                let key = dateFormatter.string(from: cursor)
                if !existingDates.contains(key) {
                    dailyEntries.append(DailyTaskEntry(taskID: task.id, date: key))
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
    }

    private func backfillAllTasks() {
        let today = Date()
        for task in recurringTasks {
            backfill(task: task, upTo: today)
        }
        saveData()
    }

    // MARK: - Recovery seed

    private func applyRecoverySeedIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: recoverySeedKey) else { return }
        guard recurringTasks.isEmpty else { return }
        guard userProfile.totalXP == 0 && userProfile.rewardBonusRPByDate.isEmpty else { return }

        var components = DateComponents()
        components.year = 2026; components.month = 3; components.day = 28
        guard let recoveryDate = Calendar.current.date(from: components) else { return }

        let key = dateKey(for: recoveryDate)
        var recoveredTask = RecurringTask(title: "Recovered Progress (28 Mar)")
        recoveredTask.createdAt = recoveryDate
        recoveredTask.isEveryday = false
        recoveredTask.recurringDays = []

        let entry = DailyTaskEntry(
            taskID: recoveredTask.id,
            date: key,
            isDone: true,
            pointsEarned: 46,
            xpEarned: 92
        )

        recurringTasks = [recoveredTask]
        dailyEntries = [entry]
        userProfile.level = 1
        userProfile.totalXP = 92
        userProfile.dailyPoints = 0

        UserDefaults.standard.set(true, forKey: recoverySeedKey)
        saveData()
    }

    // MARK: - Streak

    private func isPerfectDay(_ date: Date) -> Bool {
        let key = dateKey(for: date)
        let entriesForDay = dailyEntries.filter { $0.date == key }
        guard !entriesForDay.isEmpty else { return false }
        return entriesForDay.allSatisfy { $0.isDone }
    }

    private func consecutivePerfectDates(endingAt endDate: Date) -> [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []
        var cursor = calendar.startOfDay(for: endDate)

        while isPerfectDay(cursor) {
            dates.append(cursor)
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return dates.reversed()
    }

    private func recalculateStreak() {
        let newStreakCount = currentStreakDates().count
        let previousStreakCount = userProfile.streak

        if newStreakCount < previousStreakCount && previousStreakCount > 0 {
            if userProfile.streakShields > 0 {
                userProfile.streakShields -= 1
                shieldUsedThisRound = true
                let key = dateKey(for: Date())
                if !userProfile.shieldUsedDates.contains(key) {
                    userProfile.shieldUsedDates.append(key)
                }
                return
            }
        }

        userProfile.streak = newStreakCount
        shieldUsedThisRound = false
    }

    // MARK: - RP / XP helpers

    private func totalEarnedXP() -> Int {
        dailyEntries.reduce(0) { $0 + $1.xpEarned }
    }

    private func shieldCost() -> Int {
        switch userProfile.streakShields {
        case 0: return 150
        case 1: return 250
        case 2: return 400
        default: return 0
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

    // MARK: - Rewards

    private func applyTaskCompletionReward(for task: RecurringTask) {
        let triggerChance = min(1.0, 0.05 * userProfile.rewardChanceMultiplier)
        guard Double.random(in: 0...1) <= triggerChance else { return }

        let rawTaskBonus = max(Int.random(in: 3...10), task.points)
        let taskBonus = scaledRewardRP(rawTaskBonus)
        if Double.random(in: 0...1) <= 0.80 {
            grantBonusRP(taskBonus)
        } else {
            grantShieldOrFallbackRP(fallbackRP: taskBonus)
        }
    }

    private func applyLevelUpReward() {
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

    // MARK: - Audio

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

    // MARK: - Date key

    private func dateKey(for date: Date) -> String {
        dateFormatter.string(from: Calendar.current.startOfDay(for: date))
    }
}
