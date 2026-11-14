import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var emailError: String? {
        guard !email.isEmpty, !AuthValidator.isValidEmail(trimmedEmail) else { return nil }
        return "Enter a valid email address."
    }

    private var isFormValid: Bool {
        AuthValidator.isValidEmail(trimmedEmail) && !password.isEmpty
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                    Text("Welcome back")
                        .font(.title2.bold())
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(submit)
            } footer: {
                if let emailError {
                    Text(emailError).foregroundStyle(.red)
                }
            }

            Section {
                Button(action: submit) {
                    HStack {
                        Spacer()
                        if auth.isLoading {
                            ProgressView()
                        } else {
                            Text("Sign In").bold()
                        }
                        Spacer()
                    }
                }
                .disabled(!isFormValid || auth.isLoading)
            }

            Section {
                NavigationLink("Don't have an account? Sign Up") {
                    SignUpView()
                }
                .disabled(auth.isLoading)
            }
        }
        .navigationTitle("Sign In")
        .authErrorAlert(auth)
    }

    private func submit() {
        guard isFormValid, !auth.isLoading else { return }
        focusedField = nil
        Task { await auth.signIn(email: trimmedEmail, password: password) }
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
    .environment(AuthViewModel())
}
