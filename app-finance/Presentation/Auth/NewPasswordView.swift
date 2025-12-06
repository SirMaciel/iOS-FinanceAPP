import SwiftUI

struct NewPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    let email: String
    let resetToken: String

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        ZStack {
            // Background
            DarkBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)

                    // Icon
                    ZStack {
                        Circle()
                            .fill(AppColors.primaryGradient)
                            .frame(width: 80, height: 80)
                            .shadow(color: AppColors.accentBlue.opacity(0.4), radius: 20, y: 10)

                        Image(systemName: "lock.rotation")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 32)

                    // Title
                    VStack(spacing: 12) {
                        Text("Nova senha")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.textPrimary)

                        Text("Crie uma nova senha para sua conta")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.bottom, 40)

                    // Password Fields
                    VStack(spacing: 16) {
                        DarkSecureField(
                            icon: "lock",
                            placeholder: "Nova senha",
                            text: $password
                        )

                        DarkSecureField(
                            icon: "lock.shield",
                            placeholder: "Confirme a nova senha",
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

                        // Reset Button
                        DarkButton(
                            title: "Redefinir senha",
                            icon: "checkmark.circle.fill",
                            isLoading: isLoading,
                            isDisabled: !isFormValid
                        ) {
                            resetPassword()
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)
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
        .alert("Senha redefinida!", isPresented: $showSuccess) {
            Button("Fazer login") {
                // Pop to root (login)
                NotificationCenter.default.post(name: .passwordResetSuccess, object: nil)
            }
        } message: {
            Text("Sua senha foi alterada com sucesso. Faça login com sua nova senha.")
        }
    }

    private var isFormValid: Bool {
        password.count >= 6 && password == confirmPassword
    }

    private func resetPassword() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authManager.resetPassword(email: email, token: resetToken, newPassword: password)
                showSuccess = true
            } catch {
                errorMessage = "Erro ao redefinir senha. Tente novamente."
            }
            isLoading = false
        }
    }
}

// Notification for successful password reset
extension Notification.Name {
    static let passwordResetSuccess = Notification.Name("passwordResetSuccess")
}

#Preview {
    NavigationStack {
        NewPasswordView(email: "teste@exemplo.com", resetToken: "token123")
            .environmentObject(AuthManager())
    }
}
