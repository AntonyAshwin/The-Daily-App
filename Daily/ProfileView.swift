import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query private var allEntries: [DailyEntry]

    @State private var isEditingName = false
    @State private var draftName = ""
    @State private var displayedMonth = Calendar.current.startOfMonth(for: Date())

    private var profile: UserProfile {
        if let p = profiles.first { return p }
        let p = UserProfile()
        context.insert(p)
        return p
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var todayKey: String { Self.dateFormatter.string(from: Date()) }

    private var todayPoints: Int {
        allEntries.filter { $0.date == todayKey }.reduce(0) { $0 + $1.pointsEarned }
    }

    private var streak: Int { computeStreak() }

    /// All dates where every task was completed (for calendar highlighting)
    private var completedDays: Set<String> {
        let grouped = Dictionary(grouping: allEntries, by: { $0.date })
        return Set(grouped.compactMap { date, entries -> String? in
            entries.isEmpty ? nil : (entries.allSatisfy { $0.isCompleted } ? date : nil)
        })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: Name
                    nameSection

                    // MARK: Stats
                    statsSection

                    // MARK: Calendar
                    calendarSection
                }
                .padding()
            }
            .navigationTitle("Profile")
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        HStack {
            if isEditingName {
                TextField("Name", text: $draftName)
                    .textFieldStyle(.roundedBorder)
                    .font(.title2)
                Button {
                    profile.name = draftName.trimmingCharacters(in: .whitespaces).isEmpty
                        ? profile.name : draftName
                    isEditingName = false
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                }
            } else {
                Text(profile.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                Button {
                    draftName = profile.name
                    isEditingName = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 0) {
            StatCell(label: "Today", value: "\(todayPoints) pts")
            Divider().frame(height: 40)
            StatCell(label: "Total", value: "\(profile.totalPoints) pts")
            Divider().frame(height: 40)
            StatCell(label: "Streak", value: "\(streak) \(streak == 1 ? "day" : "days")")
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        VStack(spacing: 12) {
            // Month navigation
            HStack {
                Button {
                    if let prev = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) {
                        displayedMonth = Calendar.current.startOfMonth(for: prev)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(monthTitle(displayedMonth))
                    .font(.headline)

                Spacer()

                Button {
                    if let next = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) {
                        displayedMonth = Calendar.current.startOfMonth(for: next)
                    }
                }
                label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(Calendar.current.isDate(displayedMonth, equalTo: Calendar.current.startOfMonth(for: Date()), toGranularity: .month))
            }

            // Day-of-week headers
            let dayHeaders = ["S", "M", "T", "W", "T", "F", "S"]
            HStack(spacing: 0) {
                ForEach(dayHeaders.indices, id: \.self) { i in
                    Text(dayHeaders[i])
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            let days = calendarDays(for: displayedMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(days.indices, id: \.self) { i in
                    if let date = days[i] {
                        let key = Self.dateFormatter.string(from: date)
                        let isCompleted = completedDays.contains(key)
                        let isToday = Calendar.current.isDateInToday(date)
                        CalendarDayCell(
                            day: Calendar.current.component(.day, from: date),
                            isCompleted: isCompleted,
                            isToday: isToday
                        )
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Streak Logic

    private func computeStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var cursor = calendar.startOfDay(for: Date())

        // Check if today is fully complete
        let todayEntries = allEntries.filter { $0.date == todayKey }
        let todayDone = !todayEntries.isEmpty && todayEntries.allSatisfy { $0.isCompleted }
        if !todayDone {
            // Start from yesterday
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        // Walk back counting consecutive fully-completed days
        for _ in 0..<365 {
            let key = Self.dateFormatter.string(from: cursor)
            let entries = allEntries.filter { $0.date == key }
            if entries.isEmpty { break }
            if entries.allSatisfy({ $0.isCompleted }) {
                streak += 1
                cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            } else {
                break
            }
        }
        return streak
    }

    // MARK: - Calendar Helpers

    private func calendarDays(for month: Date) -> [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let firstDay = calendar.startOfMonth(for: month)
        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in 0..<range.count {
            if let date = calendar.date(byAdding: .day, value: day, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }

    private func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
}

// MARK: - Stat Cell

private struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Calendar Day Cell

private struct CalendarDayCell: View {
    let day: Int
    let isCompleted: Bool
    let isToday: Bool

    var body: some View {
        Text("\(day)")
            .font(.caption)
            .fontWeight(isToday ? .bold : .regular)
            .frame(width: 32, height: 32)
            .background {
                if isCompleted {
                    Circle().fill(Color.green.opacity(0.75))
                } else if isToday {
                    Circle().strokeBorder(Color.accentColor, lineWidth: 1.5)
                }
            }
            .foregroundStyle(isCompleted ? .white : (isToday ? .accentColor : .primary))
    }
}

// MARK: - Calendar extension

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
