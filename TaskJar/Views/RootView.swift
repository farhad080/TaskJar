import SwiftUI

/// Switches between the auth flow and the main app based on Firebase auth state.
struct RootView: View {
    @State private var auth = AuthViewModel()
    @State private var taskViewModel = TaskViewModel()

    var body: some View {
        Group {
            if auth.isSignedIn {
                TaskListView()
                    .transition(.opacity)
            } else {
                NavigationStack {
                    LoginView()
                }
                .transition(.opacity)
            }
        }
        .animation(.default, value: auth.isSignedIn)
        // Start the tasks listener for the signed-in user; remove it on sign out
        // (also covers sessions ending without the Sign Out button, e.g. a revoked token).
        .onChange(of: auth.user?.uid, initial: true) { _, uid in
            if let uid {
                taskViewModel.startListening(uid: uid)
            } else {
                taskViewModel.stopListening()
            }
        }
        .environment(auth)
        .environment(taskViewModel)
    }
}

#Preview {
    RootView()
}
