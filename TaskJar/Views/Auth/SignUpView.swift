import SwiftUI

struct SignUpView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @FocusState private var focusedField: Field?

    private enum Field { case email, password, confirmPassword }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var emailError: String? {
        guard !email.isEmpty, !AuthValidator.isValidEmail(trimmedEmail) else { return nil }
        return "Enter a valid email address."
    }

    private var passwordError: String? {
        guard !password.isEmpty, !AuthValidator.isValidPassword(password) else { return nil }
        return "Password must be at least \(AuthValidator.minimumPasswordLength) characters."
    }

    private var confirmError: String? {
        guard !confirmPassword.isEmpty, confirmPassword != password else { return nil }
        return "Passwords don't match."
    }

    private var isFormValid: Bool {
        AuthValidator.isValidEmail(trimmedEmail)
            && AuthValidator.isValidPassword(password)
            && password == confirmPassword
    }

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
            } footer: {
                if let emailError {
                    Text(emailError).foregroundStyle(.red)
                }
            }

            Section {
                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .confirmPassword }

                SecureField("Confirm Password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .confirmPassword)
                    .submitLabel(.go)
                    .onSubmit(submit)
            } footer: {
                if let message = passwordError ?? confirmError {
                    Text(message).foregroundStyle(.red)
                } else {
                    Text("At least \(AuthValidator.minimumPasswordLength) characters.")
                }
            }

            Section {
                Button(action: submit) {
                    HStack {
                        Spacer()
                        if auth.isLoading {
                            ProgressView()
                        } else {
                            Text("Create Account").bold()
                        }
                        Spacer()
                    }
                }
                .disabled(!isFormValid || auth.isLoading)
            }
        }
        .navigationTitle("Sign Up")
        .navigationBarBackButtonHidden(auth.isLoading)
        .authErrorAlert(auth)
    }

    private func submit() {
        guard isFormValid, !auth.isLoading else { return }
        focusedField = nil
        Task { await auth.signUp(email: trimmedEmail, password: password) }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
    }
    .environment(AuthViewModel())
}
