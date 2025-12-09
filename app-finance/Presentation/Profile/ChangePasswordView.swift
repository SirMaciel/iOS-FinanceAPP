import SwiftUI

enum ChangePasswordStep {
    case requestCode
    case verifyCode
    case newPassword
}

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    @State private var step: ChangePasswordStep = .requestCode
    @State private var code = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var changeToken: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                Spacer()

                // Icon
                iconSection

                // Title
                titleSection

                // Content based on step
                contentSection

                Spacer()

                // Back button
                backButton
            }
            .onTapGesture { hideKeyboard() }
        }
        .onTapGesture { hideKeyboard() }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { handleBack() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Voltar")
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .alert("Senha alterada!", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Sua senha foi alterada com sucesso.")
        }
        .task {
            // Fetch profile to ensure we have the email
            if authManager.userEmail == nil {
                try? await authManager.fetchProfile()
            }
        }
    }

    // MARK: - Icon Section

    private var iconSection: some View {
        ZStack {
            Circle()
                .fill(AppColors.primaryGradient)
                .frame(width: 80, height: 80)
                .shadow(color: AppColors.accentBlue.opacity(0.4), radius: 20, y: 10)

            Image(systemName: iconName)
                .font(.system(size: 32))
                .foregroundColor(.white)
        }
        .padding(.bottom, 32)
    }

    private var iconName: String {
        switch step {
        case .requestCode:
            return "lock.shield"
        case .verifyCode:
            return "envelope.badge.shield.half.filled"
        case .newPassword:
            return "lock.rotation"
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(spacing: 12) {
            Text(titleText)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)

            Text(subtitleText)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if step == .verifyCode, let email = authManager.userEmail {
                Text(email)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.accentBlue)
            }
        }
        .padding(.bottom, 40)
    }

    private var titleText: String {
        switch step {
        case .requestCode:
            return "Alterar senha"
        case .verifyCode:
            return "Digite o codigo"
        case .newPassword:
            return "Nova senha"
        }
    }

    private var subtitleText: String {
        switch step {
        case .requestCode:
            return "Enviaremos um codigo de verificacao para seu email"
        case .verifyCode:
            return "Enviamos um codigo de 6 digitos para"
        case .newPassword:
            return "Crie uma nova senha para sua conta"
        }
    }

    // MARK: - Content Section

    @ViewBuilder
    private var contentSection: some View {
        VStack(spacing: 20) {
            switch step {
            case .requestCode:
                requestCodeContent
            case .verifyCode:
                verifyCodeContent
            case .newPassword:
                newPasswordContent
            }
        }
        .padding(.horizontal, 24)
    }

    private var requestCodeContent: some View {
        VStack(spacing: 16) {
            if let error = errorMessage {
                errorView(error)
            }

            AppButton(
                title: "Enviar codigo",
                icon: "paperplane.fill",
                isLoading: isLoading
            ) {
                requestCode()
            }
        }
    }

    private var verifyCodeContent: some View {
        VStack(spacing: 20) {
            ResetCodeInputView(code: $code, isCodeFocused: $isCodeFocused)
                .onAppear { isCodeFocused = true }

            if let error = errorMessage {
                errorView(error)
            }

            AppButton(
                title: "Verificar",
                icon: "checkmark",
                isLoading: isLoading,
                isDisabled: code.count != 6
            ) {
                verifyCode()
            }
            .padding(.top, 12)
        }
    }

    private var newPasswordContent: some View {
        VStack(spacing: 16) {
            AppSecureField(
                icon: "lock",
                placeholder: "Nova senha",
                text: $password
            )

            AppSecureField(
                icon: "lock.shield",
                placeholder: "Confirme a nova senha",
                text: $confirmPassword
            )

            VStack(alignment: .leading, spacing: 8) {
                if !password.isEmpty && password.count < 6 {
                    ValidationBadge(text: "Minimo 6 caracteres", isValid: false)
                }

                if !confirmPassword.isEmpty && password != confirmPassword {
                    ValidationBadge(text: "As senhas nao conferem", isValid: false)
                }

                if let error = errorMessage {
                    ValidationBadge(text: error, isValid: false)
                }
            }
            .padding(.vertical, 4)

            AppButton(
                title: "Alterar senha",
                icon: "checkmark.circle.fill",
                isLoading: isLoading,
                isDisabled: !isPasswordFormValid
            ) {
                changePassword()
            }
            .padding(.top, 8)
        }
    }

    private var isPasswordFormValid: Bool {
        password.count >= 6 && password == confirmPassword
    }

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14))
            Text(message)
                .font(.caption)
        }
        .foregroundColor(AppColors.accentRed)
    }

    // MARK: - Back Button

    private var backButton: some View {
        Button(action: { handleBack() }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 14))
                Text(step == .requestCode ? "Voltar para perfil" : "Voltar")
            }
            .font(.subheadline)
            .foregroundColor(AppColors.textSecondary)
        }
        .padding(.bottom, 40)
    }

    // MARK: - Actions

    private func handleBack() {
        switch step {
        case .requestCode:
            dismiss()
        case .verifyCode:
            step = .requestCode
            code = ""
            errorMessage = nil
        case .newPassword:
            step = .verifyCode
            password = ""
            confirmPassword = ""
            errorMessage = nil
        }
    }

    private func requestCode() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authManager.requestPasswordChange()
                withAnimation {
                    step = .verifyCode
                }
            } catch {
                errorMessage = "Erro ao enviar codigo. Tente novamente."
            }
            isLoading = false
        }
    }

    private func verifyCode() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let token = try await authManager.verifyPasswordChangeCode(code: code)
                changeToken = token
                withAnimation {
                    step = .newPassword
                }
            } catch AuthError.invalidCode {
                errorMessage = "Codigo invalido. Tente novamente."
                code = ""
            } catch AuthError.codeExpired {
                errorMessage = "Codigo expirado. Solicite um novo."
                code = ""
            } catch {
                errorMessage = "Erro ao verificar. Tente novamente."
            }
            isLoading = false
        }
    }

    private func changePassword() {
        guard let token = changeToken else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authManager.changePassword(token: token, newPassword: password)
                showSuccess = true
            } catch {
                errorMessage = "Erro ao alterar senha. Tente novamente."
            }
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        ChangePasswordView()
            .environmentObject(AuthManager())
    }
}
