import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingVerification = false
    @State private var pendingUserId: String?

    var body: some View {
        ZStack {
            // Background
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 24) {
                        // Logo
                        ZStack {
                            Circle()
                                .fill(AppColors.primaryGradient)
                                .frame(width: 80, height: 80)
                                .shadow(color: AppColors.accentPurple.opacity(0.4), radius: 20, y: 10)

                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 40)
                        
                        VStack(spacing: 8) {
                            Text("Comece sua jornada")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.textPrimary)

                            Text("Crie sua conta em segundos.")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(.bottom, 32)

                    // Form
                    VStack(spacing: 16) {
                        AppTextField(
                            icon: "person",
                            placeholder: "Nome completo",
                            text: $name
                        )

                        AppTextField(
                            icon: "envelope",
                            placeholder: "Seu e-mail",
                            text: $email,
                            keyboardType: .emailAddress
                        )

                        AppSecureField(
                            icon: "lock",
                            placeholder: "Sua senha",
                            text: $password
                        )

                        AppSecureField(
                            icon: "lock.shield",
                            placeholder: "Confirme sua senha",
                            text: $confirmPassword
                        )

                        // Validations
                        VStack(alignment: .leading, spacing: 8) {
                            if !password.isEmpty && password.count < 6 {
                                ValidationBadge(text: "Mínimo 6 caracteres", isValid: false)
                            }

                            if !confirmPassword.isEmpty && password != confirmPassword {
                                ValidationBadge(text: "As senhas não conferem", isValid: false)
                            }

                            if let error = errorMessage {
                                ValidationBadge(text: error, isValid: false)
                            }
                        }
                        .padding(.vertical, 4)

                        AppButton(
                            title: "Criar Conta",
                            icon: "arrow.right",
                            isLoading: isLoading,
                            isDisabled: !isFormValid
                        ) {
                            register()
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)

                    // Terms
                    Text("Ao criar uma conta, você concorda com nossos Termos de Uso e Política de Privacidade")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 24)

                    // Back to login
                    HStack(spacing: 4) {
                        Text("Já tem uma conta?")
                            .foregroundColor(AppColors.textSecondary)
                        Button("Entrar") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.accentBlue)
                    }
                    .font(.subheadline)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
                .onTapGesture { hideKeyboard() }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onTapGesture { hideKeyboard() }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Voltar")
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .navigationDestination(isPresented: $showingVerification) {
            if let userId = pendingUserId {
                EmailVerificationView(email: email, userId: userId)
            }
        }
    }

    private var isFormValid: Bool {
        !name.isEmpty &&
        !email.isEmpty && email.contains("@") &&
        password.count >= 6 &&
        password == confirmPassword
    }

    private func register() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let userId = try await authManager.register(
                    name: name,
                    email: email,
                    password: password
                )
                pendingUserId = userId
                showingVerification = true
            } catch AuthError.emailAlreadyExists {
                errorMessage = "Este email já está cadastrado"
            } catch {
                errorMessage = "Erro ao criar conta. Tente novamente."
            }
            isLoading = false
        }
    }
}

// MARK: - Supporting Views

struct ValidationBadge: View {
    let text: String
    var isValid: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 12))
            Text(text)
                .font(.caption)
        }
        .foregroundColor(isValid ? AppColors.accentGreen : AppColors.accentRed)
    }
}
