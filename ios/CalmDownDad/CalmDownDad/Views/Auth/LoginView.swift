import SwiftUI

struct LoginView: View {
    @ObservedObject var authService = AuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var showConfirmation = false
    @State private var confirmationEmail = ""

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.pink.opacity(0.2))
                            .frame(width: 100, height: 100)

                        Image(systemName: "face.smiling.inverse")
                            .font(.system(size: 50))
                            .foregroundColor(AppTheme.pink)
                    }

                    Text(L10n.appName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.pink)

                    Text(L10n.smartParentingAssistant)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                // Login form
                VStack(spacing: 16) {
                    // Email field
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.email)
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)

                        TextField("", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .foregroundColor(AppTheme.textPrimary)
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                    }

                    // Password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.password)
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)

                        SecureField("", text: $password)
                            .textContentType(.password)
                            .foregroundColor(AppTheme.textPrimary)
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                    }

                    // Error message
                    if let error = authService.error {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    // Login button
                    Button {
                        Task {
                            do {
                                try await authService.signIn(email: email, password: password)
                            } catch AuthError.confirmationRequired {
                                confirmationEmail = email
                                showConfirmation = true
                            } catch {
                                authService.error = error as? AuthError ?? .networkError(error.localizedDescription)
                            }
                        }
                    } label: {
                        HStack {
                            if authService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(L10n.login)
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canLogin ? AppTheme.pink : AppTheme.textSecondary)
                        .cornerRadius(12)
                    }
                    .disabled(!canLogin || authService.isLoading)
                }
                .padding(.horizontal)

                // Sign up link
                Button {
                    showSignUp = true
                } label: {
                    HStack {
                        Text(L10n.noAccount)
                            .foregroundColor(AppTheme.textSecondary)
                        Text(L10n.signUp)
                            .foregroundColor(AppTheme.pink)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }

                Spacer()
            }
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
        }
        .sheet(isPresented: $showConfirmation) {
            ConfirmationView(email: confirmationEmail)
        }
    }

    private var canLogin: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }
}

// MARK: - Sign Up View

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService = AuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text(L10n.createAccount)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.textPrimary)

                            Text(L10n.signUpSubtitle)
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(.top, 20)

                        // Form
                        VStack(spacing: 16) {
                            // Email
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.email)
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)

                                TextField("", text: $email)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .foregroundColor(AppTheme.textPrimary)
                                    .padding()
                                    .background(AppTheme.cardBackground)
                                    .cornerRadius(12)
                            }

                            // Password
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.password)
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)

                                SecureField("", text: $password)
                                    .textContentType(.newPassword)
                                    .foregroundColor(AppTheme.textPrimary)
                                    .padding()
                                    .background(AppTheme.cardBackground)
                                    .cornerRadius(12)

                                Text(L10n.passwordRequirements)
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.textSecondary)
                            }

                            // Confirm password
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.confirmPassword)
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)

                                SecureField("", text: $confirmPassword)
                                    .textContentType(.newPassword)
                                    .foregroundColor(AppTheme.textPrimary)
                                    .padding()
                                    .background(AppTheme.cardBackground)
                                    .cornerRadius(12)

                                if !confirmPassword.isEmpty && password != confirmPassword {
                                    Text(L10n.passwordsDoNotMatch)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }

                            // Error message
                            if let error = authService.error {
                                Text(error.localizedDescription)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }

                            // Sign up button
                            Button {
                                Task {
                                    do {
                                        try await authService.signUp(email: email, password: password)
                                        showConfirmation = true
                                    } catch AuthError.confirmationRequired {
                                        showConfirmation = true
                                    } catch {
                                        authService.error = error as? AuthError ?? .networkError(error.localizedDescription)
                                    }
                                }
                            } label: {
                                HStack {
                                    if authService.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text(L10n.signUp)
                                    }
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(canSignUp ? AppTheme.pink : AppTheme.textSecondary)
                                .cornerRadius(12)
                            }
                            .disabled(!canSignUp || authService.isLoading)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.pink)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .sheet(isPresented: $showConfirmation) {
            ConfirmationView(email: email, onConfirmed: {
                dismiss()
            })
        }
    }

    private var canSignUp: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 8 &&
        password == confirmPassword
    }
}

// MARK: - Confirmation View

struct ConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService = AuthService.shared
    let email: String
    var onConfirmed: (() -> Void)?

    @State private var code = ""
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "envelope.badge")
                            .font(.system(size: 50))
                            .foregroundColor(AppTheme.pink)

                        Text(L10n.checkYourEmail)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.textPrimary)

                        Text(L10n.confirmationCodeSent(email: email))
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    // Code input
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.verificationCode)
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)

                        TextField("", text: $code)
                            .keyboardType(.numberPad)
                            .foregroundColor(AppTheme.textPrimary)
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // Error message
                    if let error = authService.error {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    // Confirm button
                    Button {
                        Task {
                            do {
                                try await authService.confirmSignUp(email: email, code: code)
                                showSuccess = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    onConfirmed?()
                                    dismiss()
                                }
                            } catch {
                                authService.error = error as? AuthError ?? .networkError(error.localizedDescription)
                            }
                        }
                    } label: {
                        HStack {
                            if authService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else if showSuccess {
                                Image(systemName: "checkmark")
                                Text(L10n.confirmed)
                            } else {
                                Text(L10n.confirm)
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(showSuccess ? .green : (code.count >= 6 ? AppTheme.pink : AppTheme.textSecondary))
                        .cornerRadius(12)
                    }
                    .disabled(code.count < 6 || authService.isLoading || showSuccess)
                    .padding(.horizontal)

                    // Resend code
                    Button {
                        Task {
                            try? await authService.resendConfirmationCode(email: email)
                        }
                    } label: {
                        Text(L10n.resendCode)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.pink)
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.pink)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

#Preview {
    LoginView()
}
