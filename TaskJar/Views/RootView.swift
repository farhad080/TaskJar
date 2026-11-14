import SwiftUI

/// Switches between the auth flow and the main app based on Firebase auth state.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var auth = AuthViewModel()
    @State private var taskViewModel = TaskViewModel()

    var body: some View {
        Group {
            if auth.isSignedIn {
                MainTabView()
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
        // Reconnect a listener that an error ended while the app was in the background.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { taskViewModel.retryIfNeeded() }
        }
        // One alert for auth errors across Login, Sign Up and Sign Out. Attaching it in each
        // screen made SwiftUI try to present the same alert twice while SignUpView was pushed.
        .authErrorAlert(auth)
        .environment(auth)
        .environment(taskViewModel)
    }
}

#Preview {
    RootView()
}
