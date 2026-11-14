import SwiftUI

/// Signed-in home: the Jar and the full task list.
struct MainTabView: View {
    @Environment(TaskViewModel.self) private var taskViewModel

    /// Named `AppTab` rather than `Tab` to avoid clashing with SwiftUI's own `Tab` type (iOS 18 SDK).
    private enum AppTab: Hashable { case jar, allTasks }

    @State private var selection: AppTab = .jar

    var body: some View {
        TabView(selection: $selection) {
            JarView()
                .tabItem { Label("Jar", systemImage: "sparkles") }
                .tag(AppTab.jar)

            TaskListView()
                .tabItem { Label("All Tasks", systemImage: "checklist") }
                .tag(AppTab.allTasks)
        }
        // Lives above the tabs so Firestore errors show whichever tab is open.
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { taskViewModel.errorMessage != nil },
                set: { if !$0 { taskViewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(taskViewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    MainTabView()
        .environment(AuthViewModel())
        .environment(TaskViewModel())
}
