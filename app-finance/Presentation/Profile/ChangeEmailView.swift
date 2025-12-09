import SwiftUI

enum ChangeEmailStep {
    case requestCode        // Request verification on current email
    case verifyCurrentEmail // Verify code from current email
    case enterNewEmail      // Enter the new email
    case verifyNewEmail     // Verify code sent to new email
}

struct ChangeEmailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    @State private var step: ChangeEmailStep = .requestCode
    @State private var code = ""
    @State private var newEmail = ""
    @State private var emailChangeToken: String?
    @State private var newEmailToken: String?
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
        .alert("Email alterado!", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Seu email foi alterado para \(newEmail)")
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
                .fill(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .shadow(color: AppColors.accentPurple.opacity(0.4), radius: 20, y: 10)

            Image(systemName: iconName)
                .font(.system(size: 32))
                .foregroundColor(.white)
        }
        .padding(.bottom, 32)
    }

    private var iconName: String {
        switch step {
        case .requestCode:
            return "envelope.badge.shield.half.filled"
        case .verifyCurrentEmail:
            return "envelope.open"
        case .enterNewEmail:
            return "envelope.badge.person.crop"
        case .verifyNewEmail:
            return "checkmark.seal"
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

            if step == .verifyCurrentEmail, let email = authManager.userEmail {
                Text(email)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.accentBlue)
            }

            if step == .verifyNewEmail {
                Text(newEmail)
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
            return "Alterar email"
        case .verifyCurrentEmail:
            return "Verificar email atual"
        case .enterNewEmail:
            return "Novo email"
        case .verifyNewEmail:
            return "Verificar novo email"
        }
    }

    private var subtitleText: String {
        switch step {
        case .requestCode:
            return "Primeiro, precisamos verificar seu email atual"
        case .verifyCurrentEmail:
            return "Digite o codigo enviado para"
        case .enterNewEmail:
            return "Digite o novo email que deseja usar"
        case .verifyNewEmail:
            return "Digite o codigo enviado para"
        }
    }

    // MARK: - Content Section

    @ViewBuilder
    private var contentSection: some View {
        VStack(spacing: 20) {
            switch step {
            case .requestCode:
                requestCodeContent
            case .verifyCurrentEmail:
                verifyCurrentEmailContent
            case .enterNewEmail:
                enterNewEmailContent
            case .verifyNewEmail:
                verifyNewEmailContent
            }
        }
        .padding(.horizontal, 24)
    }

    private var requestCodeContent: some View {
        VStack(spacing: 16) {
            // Show current email
            HStack(spacing: 12) {
                Image(systemName: "envelope")
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 20)

                if let email = authManager.userEmail, !email.isEmpty {
                    Text(email)
                        .foregroundColor(AppColors.textPrimary)
                } else {
                    Text("Carregando...")
                        .foregroundColor(AppColors.textTertiary)
                }

                Spacer()
            }
            .padding()
            .frame(height: 56)
            .background(AppColors.bgTertiary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if let error = errorMessage {
                errorView(error)
            }

            AppButton(
                title: "Enviar codigo",
                icon: "paperplane.fill",
                isLoading: isLoading,
                isDisabled: authManager.userEmail == nil || authManager.userEmail?.isEmpty == true
            ) {
                requestCode()
            }
        }
    }

    private var verifyCurrentEmailContent: some View {
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
                verifyCurrentEmail()
            }
            .padding(.top, 12)
        }
    }

    private var enterNewEmailContent: some View {
        VStack(spacing: 16) {
            AppTextField(
                icon: "envelope",
                placeholder: "Novo email",
                text: $newEmail,
                keyboardType: .emailAddress
            )

            if let error = errorMessage {
                errorView(error)
            }

            AppButton(
                title: "Continuar",
                icon: "arrow.right",
                isLoading: isLoading,
                isDisabled: !isEmailValid
            ) {
                setNewEmail()
            }
            .padding(.top, 8)
        }
    }

    private var verifyNewEmailContent: some View {
        VStack(spacing: 20) {
            ResetCodeInputView(code: $code, isCodeFocused: $isCodeFocused)
                .onAppear { isCodeFocused = true }

            if let error = errorMessage {
                errorView(error)
            }

            AppButton(
                title: "Confirmar troca",
                icon: "checkmark.circle.fill",
                isLoading: isLoading,
                isDisabled: code.count != 6
            ) {
                verifyNewEmail()
            }
            .padding(.top, 12)
        }
    }

    private var isEmailValid: Bool {
        !newEmail.isEmpty && newEmail.contains("@") && newEmail.contains(".")
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
        case .verifyCurrentEmail:
            step = .requestCode
            code = ""
            errorMessage = nil
        case .enterNewEmail:
            step = .verifyCurrentEmail
            newEmail = ""
            errorMessage = nil
        case .verifyNewEmail:
            step = .enterNewEmail
            code = ""
            errorMessage = nil
        }
    }

    private func requestCode() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authManager.requestEmailChange()
                withAnimation {
                    step = .verifyCurrentEmail
                }
            } catch {
                errorMessage = "Erro ao enviar codigo. Tente novamente."
            }
            isLoading = false
        }
    }

    private func verifyCurrentEmail() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let token = try await authManager.verifyCurrentEmailCode(code: code)
                emailChangeToken = token
                code = ""
                withAnimation {
                    step = .enterNewEmail
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

    private func setNewEmail() {
        guard let token = emailChangeToken else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let newToken = try await authManager.setNewEmail(token: token, newEmail: newEmail)
                newEmailToken = newToken
                withAnimation {
                    step = .verifyNewEmail
                }
            } catch AuthError.emailAlreadyExists {
                errorMessage = "Este email ja esta em uso."
            } catch {
                errorMessage = "Erro ao definir novo email. Tente novamente."
            }
            isLoading = false
        }
    }

    private func verifyNewEmail() {
        guard let token = newEmailToken else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authManager.verifyNewEmailCode(token: token, code: code)
                showSuccess = true
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
}

#Preview {
    NavigationStack {
        ChangeEmailView()
            .environmentObject(AuthManager())
    }
}
