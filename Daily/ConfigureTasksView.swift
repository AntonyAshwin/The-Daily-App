import SwiftUI
import SwiftData

struct ConfigureTasksView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RecurringTask.name) private var allTasks: [RecurringTask]
    @Query private var allEntries: [DailyEntry]
    @Query private var profiles: [UserProfile]

    @State private var showAddSheet = false
    @State private var taskToEdit: RecurringTask? = nil

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var todayKey: String { Self.dateFormatter.string(from: Date()) }

    private var activeTasks: [RecurringTask] {
        allTasks.filter { $0.deletedAt == nil && !$0.isOneOff }
    }

    var body: some View {
        NavigationStack {
            Group {
                if activeTasks.isEmpty {
                    ContentUnavailableView(
                        "No tasks configured",
                        systemImage: "list.bullet",
                        description: Text("Tap + to add your first recurring task.")
                    )
                } else {
                    List {
                        ForEach(activeTasks) { task in
                            TaskConfigRowView(task: task)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        softDelete(task)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        taskToEdit = task
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                }
            }
            .navigationTitle("Configure Tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddEditTaskView(existingTask: nil)
            }
            .sheet(item: $taskToEdit) { task in
                AddEditTaskView(existingTask: task)
            }
        }
    }

    private func softDelete(_ task: RecurringTask) {
        // Remove today's entry if it exists (and deduct points if completed)
        if let todayEntry = allEntries.first(where: { $0.taskID == task.id && $0.date == todayKey }) {
            if todayEntry.isCompleted, let profile = profiles.first {
                profile.totalPoints = max(0, profile.totalPoints - todayEntry.pointsEarned)
            }
            context.delete(todayEntry)
        }
        task.deletedAt = Date()
    }
}

// MARK: - Row

private struct TaskConfigRowView: View {
    let task: RecurringTask

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.name)
                .font(.body)
            HStack {
                Text(task.recurrenceSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(task.points) pt\(task.points == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add / Edit Sheet

struct AddEditTaskView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let existingTask: RecurringTask?

    @State private var name: String = ""
    @State private var points: Int = 1
    @State private var isEveryday: Bool = false
    @State private var selectedDays: Set<Int> = []

    private let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Name") {
                    TextField("e.g. Morning run", text: $name)
                }

                Section("Points (1–5)") {
                    Stepper(value: $points, in: 1...5) {
                        HStack {
                            Text("Points")
                            Spacer()
                            Text("\(points)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Recurrence") {
                    Toggle("Every Day", isOn: $isEveryday)
                        .onChange(of: isEveryday) { _, newVal in
                            if newVal { selectedDays = Set(0...6) }
                        }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(0..<7, id: \.self) { index in
                            DayToggleButton(
                                label: dayLabels[index],
                                isSelected: selectedDays.contains(index),
                                isDisabled: isEveryday
                            ) {
                                if selectedDays.contains(index) {
                                    selectedDays.remove(index)
                                } else {
                                    selectedDays.insert(index)
                                }
                                if selectedDays.count < 7 { isEveryday = false }
                                if selectedDays.count == 7 { isEveryday = true }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(existingTask == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (!isEveryday && selectedDays.isEmpty))
                        .fontWeight(.semibold)
                }
            }
            .onAppear { prefill() }
        }
    }

    private func prefill() {
        guard let task = existingTask else { return }
        name = task.name
        points = task.points
        isEveryday = task.isEveryday
        selectedDays = Set(task.recurrenceDays)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let days = isEveryday ? Array(0...6) : Array(selectedDays)

        if let task = existingTask {
            task.name = trimmed
            task.points = points
            task.isEveryday = isEveryday
            task.recurrenceDays = days
        } else {
            let task = RecurringTask(
                name: trimmed,
                recurrenceDays: days,
                isEveryday: isEveryday,
                points: points
            )
            context.insert(task)
        }
        dismiss()
    }
}

// MARK: - Day Toggle Button

private struct DayToggleButton: View {
    let label: String
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption2)
                .fontWeight(isSelected ? .semibold : .regular)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5), in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled && !isSelected ? 0.4 : 1)
    }
}
