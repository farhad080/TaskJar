import SwiftUI
import FirebaseCore

@main
struct TaskJarApp: App {
    init() {
        // Reads GoogleService-Info.plist from the app bundle.
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            TaskListView()
        }
    }
}
