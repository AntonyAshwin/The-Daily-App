import SwiftUI
import SwiftData

@main
struct DailyApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([RecurringTask.self, DailyEntry.self, UserProfile.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, allowsSave: true)
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // Schema migration failed — delete the old store and start fresh
            if let storeURL = URL.applicationSupportDirectory.appending(path: "default.store", directoryHint: .notDirectory) as URL? {
                try? FileManager.default.removeItem(at: storeURL)
                // Also remove companion files
                for ext in ["store-shm", "store-wal"] {
                    let companion = storeURL.deletingLastPathComponent().appending(path: "default.\(ext)")
                    try? FileManager.default.removeItem(at: companion)
                }
            }
            container = try! ModelContainer(for: schema, configurations: config)
        }

        // Ensure a UserProfile always exists so points are never lost
        let context = container.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<UserProfile>())) ?? 0
        if count == 0 {
            context.insert(UserProfile())
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
