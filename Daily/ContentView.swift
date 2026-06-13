import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "checkmark.circle")
                }
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
            ConfigureTasksView()
                .tabItem {
                    Label("Configure", systemImage: "gearshape")
                }
        }
    }
}
