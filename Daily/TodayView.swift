import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query private var allEntries: [DailyEntry]
    @Query private var tasks: [RecurringTask]
    @Query private var profiles: [UserProfile]

    @State private var showAddOneOff = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var todayKey: String {
        Self.dateFormatter.string(from: Date())
    }

    private var todayEntries: [DailyEntry] {
        allEntries
            .filter { $0.date == todayKey }
            .sorted { nameFor($0) < nameFor($1) }
    }

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            Group {
                if todayEntries.isEmpty {
                    ContentUnavailableView(
                        "No tasks today",
                        systemImage: "tray",
                        description: Text("Tap + to add a task for today, or add recurring tasks in Configure.")
                    )
                } else {
                    List {
                        ForEach(todayEntries) { entry in
                            TodayRowView(
                                entry: entry,
                                taskName: nameFor(entry),
                                points: pointsFor(entry),
                                onToggle: { toggle(entry) }
                            )
                        }
                        .onDelete(perform: deleteEntries)
                    }
                }
            }
            .navigationTitle(formattedToday())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddOneOff = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddOneOff, onDismiss: { ensureTodayEntries() }) {
                AddOneOffTaskView(todayKey: todayKey)
            }
            .onAppear { ensureTodayEntries() }
            .onChange(of: tasks.count) { _, _ in ensureTodayEntries() }
        }
    }

    // MARK: - Helpers

    private func nameFor(_ entry: DailyEntry) -> String {
        tasks.first { $0.id == entry.taskID }?.name ?? "Unknown"
    }

    private func pointsFor(_ entry: DailyEntry) -> Int {
        tasks.first { $0.id == entry.taskID }?.points ?? 0
    }

    private func formattedToday() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }

    // MARK: - Ensure today's entries exist (recurring tasks only)

    private func ensureTodayEntries() {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date()) - 1 // 0=Sun

        let existingTaskIDs = Set(allEntries.filter { $0.date == todayKey }.map { $0.taskID })

        for task in tasks where task.deletedAt == nil && !task.isOneOff {
            guard task.appliesOn(weekday: weekday) else { continue }
            guard !existingTaskIDs.contains(task.id) else { continue }
            let entry = DailyEntry(taskID: task.id, date: todayKey)
            context.insert(entry)
        }
    }

    // MARK: - Toggle completion

    private func toggle(_ entry: DailyEntry) {
        let taskPoints = pointsFor(entry)
        if entry.isCompleted {
            if let p = profile { p.totalPoints = max(0, p.totalPoints - entry.pointsEarned) }
            entry.pointsEarned = 0
            entry.isCompleted = false
        } else {
            entry.isCompleted = true
            entry.pointsEarned = taskPoints
            if let p = profile { p.totalPoints += taskPoints }
        }
    }

    // MARK: - Delete

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            let entry = todayEntries[index]

            // Deduct points if the entry was completed
            if entry.isCompleted, let p = profile {
                p.totalPoints = max(0, p.totalPoints - entry.pointsEarned)
            }

            // For one-off tasks: also soft-delete the task since it has no other entries
            if let task = tasks.first(where: { $0.id == entry.taskID }), task.isOneOff {
                task.deletedAt = Date()
            }

            // Remove only today's entry — recurring tasks will reappear tomorrow
            context.delete(entry)
        }
    }
}

// MARK: - Add One-Off Task Sheet

struct AddOneOffTaskView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let todayKey: String

    @State private var name = ""
    @State private var points = 1

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Name") {
                    TextField("e.g. Call the dentist", text: $name)
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
            }
            .navigationTitle("Add Task for Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let task = RecurringTask(
            name: trimmed,
            recurrenceDays: [],
            isEveryday: false,
            points: points,
            isOneOff: true
        )
        context.insert(task)

        let entry = DailyEntry(taskID: task.id, date: todayKey)
        context.insert(entry)

        dismiss()
    }
}

// MARK: - Row View

private struct TodayRowView: View {
    let entry: DailyEntry
    let taskName: String
    let points: Int
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Image(systemName: entry.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(entry.isCompleted ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(taskName)
                    .strikethrough(entry.isCompleted, color: .secondary)
                    .foregroundStyle(entry.isCompleted ? .secondary : .primary)
            }

            Spacer()

            Text("\(points) pt\(points == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onToggle()
        }
    }
}
