//
//  ContentView.swift
//  Daily
//
//  Created by Ashwin, Antony on 25/03/26.
//

import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var viewModel = TaskViewModel()
    @State private var showAddTask = false
    @State private var editingTask: Task? = nil
    @State private var selectedHistoryDate = Date()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            homeView
                .tag(0)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            HistoryView(viewModel: viewModel, selectedDate: $selectedHistoryDate)
                .tag(1)
                .tabItem {
                    Label("History", systemImage: "calendar")
                }

            RecurringTasksView(
                viewModel: viewModel,
                onEdit: { task in
                    editingTask = task
                    showAddTask = true
                },
                onDelete: { task in
                    if let index = viewModel.tasks.firstIndex(where: { $0.id == task.id }) {
                        viewModel.deleteTask(at: index)
                    }
                }
            )
                .tag(2)
                .tabItem {
                    Label("Recurring", systemImage: "repeat")
                }

            ProfileView(viewModel: viewModel)
                .tag(3)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }

            ShopView(viewModel: viewModel)
                .tag(4)
                .tabItem {
                    Label("Shop", systemImage: "bag.fill")
                }
        }
        .onChange(of: selectedTab) { _ in
            Haptics.pageChange()
        }
        .sheet(isPresented: $showAddTask, onDismiss: {
            editingTask = nil
        }) {
            AddTaskSheet(isPresented: $showAddTask, editingTask: $editingTask, onAdd: { title, isEveryday, selectedDays, points in
                viewModel.addTask(title, isEveryday: isEveryday, recurringDays: selectedDays, points: points)
            }, onUpdate: { updatedTask in
                viewModel.updateTask(updatedTask)
            })
        }
    }

    private var homeView: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with Stats
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        // Level
                        VStack(spacing: 4) {
                            Text("Level")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(viewModel.userProfile.level)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        
                        // Streak
                        VStack(spacing: 4) {
                            Text("Streak")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                Text("\(viewModel.userProfile.streak)")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        // Daily RP
                        VStack(spacing: 4) {
                            Text("RP")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(viewModel.totalPoints)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.yellow)
                        }
                        
                        Spacer()
                        
                        // Add Button
                        Button(action: { showAddTask = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    // Progress Bar
                    VStack(spacing: 8) {
                        HStack {
                            Text("Progress")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(viewModel.getProgressPercentage() * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 8)
                                    .foregroundColor(Color(UIColor.systemGray6))
                                
                                // Progress
                                RoundedRectangle(cornerRadius: 8)
                                    .foregroundColor(viewModel.getProgressColor())
                                    .frame(width: geometry.size.width * CGFloat(viewModel.getProgressPercentage()))
                                    .animation(.easeInOut(duration: 0.3), value: viewModel.getProgressPercentage())
                            }
                        }
                        .frame(height: 12)
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 12)
                }
                .background(Color(UIColor.secondarySystemBackground))
                
                // Tasks List
                if viewModel.todayTasks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No tasks yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Tap the + button to add your first task")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List {
                        ForEach(viewModel.sortedTodayTasks) { task in
                            TaskRow(task: task, onTap: {
                                viewModel.toggleTask(task)
                                if let updatedTask = viewModel.tasks.first(where: { $0.id == task.id }) {
                                    Haptics.taskProgress(isCompleted: updatedTask.isCompleted)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                                        viewModel.objectWillChange.send()
                                    }
                                }
                            }, onEdit: {
                                editingTask = task
                                showAddTask = true
                            }, onDelete: {
                                if let index = viewModel.tasks.firstIndex(where: { $0.id == task.id }) {
                                    viewModel.deleteTask(at: index)
                                }
                            })
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
                
                Spacer()
            }
        }
    }
}

struct HistoryView: View {
    @ObservedObject var viewModel: TaskViewModel
    @Binding var selectedDate: Date
    @State private var displayedMonth = Calendar.current.startOfMonth(for: Date())

    private var items: [HistoryTaskItem] {
        viewModel.tasksForDate(selectedDate)
    }

    private var streakDates: Set<Date> {
        Set(viewModel.currentStreakDates())
    }
    
    private var historicalStreakDates: Set<Date> {
        Set(viewModel.historicalStreakDates())
    }
    
    private var shieldUsedDates: Set<Date> {
        Set(viewModel.shieldUsedDates())
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                StreakCalendarView(
                    displayedMonth: $displayedMonth,
                    selectedDate: $selectedDate,
                    streakDates: streakDates,
                    historicalStreakDates: historicalStreakDates,
                    shieldUsedDates: shieldUsedDates
                )
                .padding(.horizontal, 12)

                Text("Streak: \(streakDates.count) day\(streakDates.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 16)

                Text(selectedDate, style: .date)
                    .font(.headline)
                    .padding(.horizontal, 16)

                if items.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("No tasks for this date")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(items) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(item.isCompleted ? Color(red: 0.0, green: 0.816, blue: 0.518) : Color(red: 1.0, green: 0.27, blue: 0.41))
                            Text(item.title)
                                .foregroundColor(.primary)
                            Spacer()
                            if item.pointsEarned > 0 {
                                Text("+\(item.pointsEarned)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            }
                            Text(item.isCompleted ? "Completed" : "Incomplete")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("History")
            .onAppear {
                displayedMonth = Calendar.current.startOfMonth(for: selectedDate)
            }
        }
    }
}

struct RecurringTasksView: View {
    @ObservedObject var viewModel: TaskViewModel
    let onEdit: (Task) -> Void
    let onDelete: (Task) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.recurringTasks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "repeat")
                            .font(.system(size: 42))
                            .foregroundColor(.secondary)
                        Text("No recurring tasks")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Create everyday or weekday tasks to manage them here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List {
                        ForEach(viewModel.recurringTasks) { task in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.title)
                                        .foregroundColor(.primary)
                                    Text(task.recurrenceText)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(task.points) pt\(task.points == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onEdit(task)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    onDelete(task)
                                } label: {
                                    Image(systemName: "trash.fill")
                                }

                                Button {
                                    onEdit(task)
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Recurring")
        }
    }
}

struct StreakCalendarView: View {
    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date
    let streakDates: Set<Date>
    let historicalStreakDates: Set<Date>
    let shieldUsedDates: Set<Date>

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    if let previous = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
                        displayedMonth = calendar.startOfMonth(for: previous)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                }

                Spacer()

                Text(monthTitle)
                    .font(.headline)

                Spacer()

                Button {
                    if let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
                        displayedMonth = calendar.startOfMonth(for: next)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 6)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdaySymbols, id: \ .self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(dayCells.indices, id: \ .self) { index in
                    if let date = dayCells[index] {
                        DayCellView(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isCurrentStreak: isCurrentStreakDate(date),
                            isHistoricalStreak: isHistoricalStreakDate(date),
                            isShieldUsed: isShieldUsedDate(date),
                            hasLeftStreak: hasAdjacentStreak(date, offset: -1),
                            hasRightStreak: hasAdjacentStreak(date, offset: 1)
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    } else {
                        Color.clear
                            .frame(height: 36)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var dayCells: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }

        let firstDay = calendar.startOfMonth(for: displayedMonth)
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leadingEmpty = firstWeekday - 1

        var cells: [Date?] = Array(repeating: nil, count: leadingEmpty)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                cells.append(date)
            }
        }

        return cells
    }

    private func isCurrentStreakDate(_ date: Date) -> Bool {
        streakDates.contains(calendar.startOfDay(for: date))
    }
    
    private func isHistoricalStreakDate(_ date: Date) -> Bool {
        historicalStreakDates.contains(calendar.startOfDay(for: date))
    }
    
    private func isShieldUsedDate(_ date: Date) -> Bool {
        shieldUsedDates.contains(calendar.startOfDay(for: date))
    }

    private func hasAdjacentStreak(_ date: Date, offset: Int) -> Bool {
        guard let adjacent = calendar.date(byAdding: .day, value: offset, to: date) else {
            return false
        }

        guard calendar.isDate(adjacent, equalTo: date, toGranularity: .month) else {
            return false
        }

        return isHistoricalStreakDate(adjacent)
    }
}

struct DayCellView: View {
    let date: Date
    let isSelected: Bool
    let isCurrentStreak: Bool
    let isHistoricalStreak: Bool
    let isShieldUsed: Bool
    let hasLeftStreak: Bool
    let hasRightStreak: Bool

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            // Background for shield-used dates (blue)
            if isShieldUsed {
                UnevenRoundedRectangle(
                    cornerRadii: .init(
                        topLeading: hasLeftStreak ? 0 : 12,
                        bottomLeading: hasLeftStreak ? 0 : 12,
                        bottomTrailing: hasRightStreak ? 0 : 12,
                        topTrailing: hasRightStreak ? 0 : 12
                    )
                )
                .fill(Color.blue.opacity(0.35))
                .frame(height: 28)
            }
            // Background for historical streak (lighter orange)
            else if isHistoricalStreak && !isCurrentStreak {
                UnevenRoundedRectangle(
                    cornerRadii: .init(
                        topLeading: hasLeftStreak ? 0 : 12,
                        bottomLeading: hasLeftStreak ? 0 : 12,
                        bottomTrailing: hasRightStreak ? 0 : 12,
                        topTrailing: hasRightStreak ? 0 : 12
                    )
                )
                .fill(Color.orange.opacity(0.2))
                .frame(height: 28)
            }
            // Background for current streak (darker orange)
            else if isCurrentStreak {
                UnevenRoundedRectangle(
                    cornerRadii: .init(
                        topLeading: hasLeftStreak ? 0 : 12,
                        bottomLeading: hasLeftStreak ? 0 : 12,
                        bottomTrailing: hasRightStreak ? 0 : 12,
                        topTrailing: hasRightStreak ? 0 : 12
                    )
                )
                .fill(Color.orange.opacity(0.35))
                .frame(height: 28)
            }

            Text("\(calendar.component(.day, from: date))")
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 30, height: 30)
                .background(isSelected ? Color.orange : Color.clear)
                .clipShape(Circle())
        }
        .frame(height: 36)
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }
}

struct TaskRow: View {
    let task: Task
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button(action: onTap) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(task.isCompleted ? Color(red: 0.0, green: 0.816, blue: 0.518) : Color(red: 1.0, green: 0.27, blue: 0.41))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .foregroundColor(.primary)
                        .strikethrough(task.isCompleted, color: .gray)
                    
                    Text(task.recurrenceText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(task.points) pt\(task.points == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash.fill")
            }
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .tint(.blue)
        }
    }
}

struct AddTaskSheet: View {
    @Binding var isPresented: Bool
    @Binding var editingTask: Task?
    let onAdd: (String, Bool, Set<Int>, Int) -> Void
    let onUpdate: (Task) -> Void
    @State private var title = ""
    @State private var isEveryday = false
    @State private var selectedDays: Set<Int> = []
    @State private var points: Int = 1
    
    let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var isEditing: Bool {
        editingTask != nil
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("Task Title") {
                        TextField("Enter task", text: $title)
                    }
                    
                    Section("Recurrence") {
                        Toggle("Everyday", isOn: Binding(
                            get: { isEveryday },
                            set: { newValue in
                                isEveryday = newValue
                                if newValue {
                                    selectedDays = Set(0...6)
                                }
                            }
                        ))
                    }

                    Section("RP") {
                        Stepper("\(points) RP", value: $points, in: 1...100)
                    }
                }
                
                if !isEveryday {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        
                        HStack(spacing: 8) {
                            ForEach(0..<7, id: \.self) { index in
                                Button(action: {
                                    if selectedDays.contains(index) {
                                        selectedDays.remove(index)
                                    } else {
                                        selectedDays.insert(index)
                                    }
                                }) {
                                    Text(String(days[index].prefix(1)))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                        .background(selectedDays.contains(index) ? Color.blue : Color(UIColor.systemGray6))
                                        .foregroundColor(selectedDays.contains(index) ? .white : .primary)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .background(Color(UIColor.systemBackground))
                }
                
                Spacer()
            }
            .navigationTitle(isEditing ? "Edit Task" : "Add New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                        editingTask = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Add") {
                        if !title.trimmingCharacters(in: .whitespaces).isEmpty {
                            if isEditing, var updatedTask = editingTask {
                                updatedTask.title = title
                                updatedTask.isEveryday = isEveryday
                                updatedTask.recurringDays = isEveryday ? Array(0...6) : Array(selectedDays)
                                updatedTask.points = points
                                onUpdate(updatedTask)
                                isPresented = false
                                editingTask = nil
                            } else {
                                onAdd(title, isEveryday, isEveryday ? Set(0...6) : selectedDays, points)
                                title = ""
                                selectedDays = []
                                isEveryday = false
                                points = 1
                            }
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let task = editingTask {
                    title = task.title
                    isEveryday = task.isEveryday
                    selectedDays = Set(task.recurringDays)
                    points = task.points
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
