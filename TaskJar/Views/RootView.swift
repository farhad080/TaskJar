import SwiftUI

/// Switches between the auth flow and the main app based on Firebase auth state.
struct RootView: View {
    @State private var auth = AuthViewModel()

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
        .environment(auth)
    }
}

#Preview {
    RootView()
}
