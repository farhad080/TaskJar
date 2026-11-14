import Foundation
import Observation
import FirebaseAuth

@MainActor
@Observable
final class AuthViewModel {
    /// The signed-in Firebase user, or `nil` when signed out. Kept in sync by the auth state listener.
    private(set) var user: User?
    /// True while a sign-in / sign-up request is in flight.
    private(set) var isLoading = false
    /// Set when an auth operation fails; views present it as an alert.
    var errorMessage: String?

    var isSignedIn: Bool { user != nil }

    @ObservationIgnored
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        user = Auth.auth().currentUser
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            // Firebase delivers auth state callbacks on the main thread.
            MainActor.assumeIsolated {
                self?.user = user
            }
        }
    }

    deinit {
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
    }

    // MARK: - Actions

    func signUp(email: String, password: String) async {
        await perform {
            _ = try await Auth.auth().createUser(withEmail: email, password: password)
        }
    }

    func signIn(email: String, password: String) async {
        await perform {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    // MARK: - Helpers

    private func perform(_ operation: () async throws -> Void) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await operation()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private static func message(for error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: nsError.code) else {
            return error.localizedDescription
        }

        switch code {
        case .invalidEmail:
            return "That email address looks invalid."
        case .emailAlreadyInUse:
            return "An account with this email already exists."
        case .weakPassword:
            return "Password is too weak. Use at least 6 characters."
        case .wrongPassword, .invalidCredential, .userNotFound:
            return "Incorrect email or password."
        case .userDisabled:
            return "This account has been disabled."
        case .networkError:
            return "Network error. Check your connection and try again."
        case .tooManyRequests:
            return "Too many attempts. Please wait a moment and try again."
        default:
            return error.localizedDescription
        }
    }
}

// MARK: - Validation

enum AuthValidator {
    static let minimumPasswordLength = 6

    static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    static func isValidPassword(_ password: String) -> Bool {
        password.count >= minimumPasswordLength
    }
}
