import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var showingRegister = false
    @State private var showingForgotPassword = false
    @State private var showingVerification = false
    @State private var verificationUserId: String?
    @State private var verificationEmail: String?
    @State private var isLoading = false
    @State private var isSocialLoading = false
    @State private var errorMessage: String?
    @State private var animate = false
    @StateObject private var appleSignIn = AppleSignInService()

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                DarkBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header Section
                        VStack(spacing: 24) {
                            // Logo
                            ZStack {
                                Circle()
                                    .fill(AppColors.primaryGradient)
                                    .frame(width: 80, height: 80)
                                    .shadow(color: AppColors.accentPurple.opacity(0.4), radius: 20, y: 10)

                                Image(systemName: "dollarsign")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 60)

                            VStack(spacing: 8) {
                                Text("Bem-vindo de volta")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.textPrimary)

                                Text("Gerencie suas finanças com inteligência.")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .padding(.bottom, 48)

                        // Form
                        VStack(spacing: 20) {
                            DarkTextField(
                                icon: "envelope",
                                placeholder: "Seu e-mail",
                                text: $email,
                                keyboardType: .emailAddress
                            )

                            VStack(alignment: .trailing, spacing: 8) {
                                DarkSecureField(
                                    icon: "lock",
                                    placeholder: "Sua senha",
                                    text: $password
                                )

                                Button("Esqueceu a senha?") {
                                    showingForgotPassword = true
                                }
                                .font(.caption)
                                .foregroundColor(AppColors.accentBlue)
                            }

                            if let error = errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(AppColors.accentRed)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            DarkButton(
                                title: "Entrar",
                                icon: "arrow.right",
                                isLoading: isLoading,
                                isDisabled: !isFormValid
                            ) {
                                login()
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 24)

                        // Divider
                        HStack {
                            Rectangle()
                                .fill(AppColors.cardBorder)
                                .frame(height: 1)
                            Text("ou continue com")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                                .padding(.horizontal, 8)
                            Rectangle()
                                .fill(AppColors.cardBorder)
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 32)

                        // Social Login
                        VStack(spacing: 16) {
                            DarkButton(
                                title: "Continuar com Apple",
                                icon: "apple.logo",
                                style: .secondary,
                                isLoading: isSocialLoading
                            ) {
                                loginWithApple()
                            }
                        }
                        .padding(.horizontal, 24)

                        // Sign Up Link
                        HStack(spacing: 4) {
                            Text("Não tem uma conta?")
                                .foregroundColor(AppColors.textSecondary)
                            Button("Cadastre-se") {
                                showingRegister = true
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentBlue)
                        }
                        .font(.subheadline)
                        .padding(.top, 32)
                        .padding(.bottom, 40)
                    }
                    .onTapGesture { hideKeyboard() }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .onTapGesture { hideKeyboard() }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showingRegister) {
                RegisterView()
            }
            .navigationDestination(isPresented: $showingForgotPassword) {
                ForgotPasswordView(initialEmail: email)
            }
            .navigationDestination(isPresented: $showingVerification) {
                if let userId = verificationUserId, let userEmail = verificationEmail {
                    EmailVerificationView(email: userEmail, userId: userId)
                }
            }
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty && email.contains("@") && password.count >= 6
    }

    private func login() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await authManager.login(email: email, password: password)

                switch result {
                case .success:
                    break
                case .requiresVerification(let userId, let userEmail):
                    verificationUserId = userId
                    verificationEmail = userEmail
                    showingVerification = true
                }
            } catch {
                errorMessage = "Email ou senha incorretos"
            }
            isLoading = false
        }
    }

    private func loginWithApple() {
        isSocialLoading = true
        errorMessage = nil

        appleSignIn.signIn { result in
            Task { @MainActor in
                switch result {
                case .success(let appleResult):
                    do {
                        var fullName: String? = nil
                        if let nameComponents = appleResult.fullName {
                            let givenName = nameComponents.givenName ?? ""
                            let familyName = nameComponents.familyName ?? ""
                            fullName = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
                            if fullName?.isEmpty == true { fullName = nil }
                        }

                        try await authManager.loginWithApple(
                            identityToken: appleResult.identityToken,
                            authorizationCode: appleResult.authorizationCode,
                            appleUserId: appleResult.userId,
                            email: appleResult.email,
                            fullName: fullName
                        )
                    } catch {
                        errorMessage = "Erro ao fazer login com Apple"
                    }

                case .failure(let error):
                    if (error as NSError).code != 1001 { // Cancelled by user
                        errorMessage = "Erro ao fazer login com Apple"
                    }
                }
                isSocialLoading = false
            }
        }
    }
}
