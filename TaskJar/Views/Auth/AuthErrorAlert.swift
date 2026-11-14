import SwiftUI

private struct AuthErrorAlert: ViewModifier {
    @Bindable var auth: AuthViewModel

    func body(content: Content) -> some View {
        content.alert(
            "Something went wrong",
            isPresented: Binding(
                get: { auth.errorMessage != nil },
                set: { if !$0 { auth.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(auth.errorMessage ?? "")
        }
    }
}

extension View {
    /// Presents `auth.errorMessage` as an alert and clears it on dismiss.
    func authErrorAlert(_ auth: AuthViewModel) -> some View {
        modifier(AuthErrorAlert(auth: auth))
    }
}
