import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    let initialEmail: String

    @State private var email: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showResetCode = false
    @State private var showEmailHint: Bool

    init(initialEmail: String = "") {
        self.initialEmail = initialEmail
        _email = State(initialValue: initialEmail)
        _showEmailHint = State(initialValue: initialEmail.isEmpty)
    }

    var body: some View {
        ZStack {
            // Background
            DarkBackground()

            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(AppColors.primaryGradient)
                        .frame(width: 80, height: 80)
                        .shadow(color: AppColors.accentBlue.opacity(0.4), radius: 20, y: 10)

                    Image(systemName: "key.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 32)
                
                // Title
                VStack(spacing: 12) {
                    Text("Recuperar senha")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)

                    Text("Digite seu email para receber um link de recuperação")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 40)

                // Email Input
                VStack(alignment: .leading, spacing: 8) {
                    if showEmailHint && email.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14))
                            Text("Digite seu email cadastrado")
                                .font(.caption)
                        }
                        .foregroundColor(AppColors.accentBlue)
                        .padding(.horizontal, 4)
                    }

                    DarkTextField(
                        icon: "envelope",
                        placeholder: "Seu e-mail",
                        text: $email,
                        keyboardType: .emailAddress
                    )

                    if let error = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 14))
                            Text(error)
                                .font(.caption)
                        }
                        .foregroundColor(AppColors.accentRed)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)

                // Send Button
                DarkButton(
                    title: "Enviar link",
                    icon: "paperplane.fill",
                    isLoading: isLoading,
                    isDisabled: !isEmailValid
                ) {
                    sendResetEmail()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Spacer()

                // Back Button
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 14))
                        Text("Voltar para login")
                    }
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                }
                .padding(.bottom, 40)
            }
            .onTapGesture { hideKeyboard() }
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
        .navigationDestination(isPresented: $showResetCode) {
            ResetPasswordCodeView(email: email)
        }
    }

    private var isEmailValid: Bool {
        !email.isEmpty && email.contains("@") && email.contains(".")
    }

    private func sendResetEmail() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authManager.sendPasswordReset(email: email)
                showResetCode = true
            } catch AuthError.userNotFound {
                errorMessage = "Email não encontrado"
            } catch {
                errorMessage = "Erro ao enviar. Tente novamente."
            }
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView(initialEmail: "")
            .environmentObject(AuthManager())
    }
}
