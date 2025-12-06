import SwiftUI

struct NewPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    let email: String
    let resetToken: String

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.14),
                    Color(red: 0.12, green: 0.13, blue: 0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Blur circles background
            GeometryReader { geo in
                Circle()
                    .fill(Color.green.opacity(0.25))
                    .frame(width: 350, height: 350)
                    .blur(radius: 100)
                    .offset(x: geo.size.width / 2 - 175, y: -100)

                Circle()
                    .fill(Color.teal.opacity(0.25))
                    .frame(width: 300, height: 300)
                    .blur(radius: 100)
                    .offset(x: -50, y: geo.size.height - 250)
            }
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)

                    // Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.3), Color.teal.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .blur(radius: 20)

                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.green, Color.teal],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: .green.opacity(0.4), radius: 20, y: 10)

                            Image(systemName: "lock.rotation")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 32)

                    // Title
                    VStack(spacing: 12) {
                        Text("Nova senha")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Crie uma nova senha para sua conta")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.bottom, 40)

                    // Password Fields
                    VStack(spacing: 16) {
                        CustomSecureField(
                            icon: "lock",
                            placeholder: "Nova senha",
                            text: $password,
                            showPassword: $showPassword
                        )

                        CustomSecureField(
                            icon: "lock.shield",
                            placeholder: "Confirme a nova senha",
                            text: $confirmPassword,
                            showPassword: $showConfirmPassword
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
                        Button(action: resetPassword) {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Text("Redefinir senha")
                                        .fontWeight(.semibold)
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: .white.opacity(0.2), radius: 20, y: 10)
                        }
                        .disabled(!isFormValid || isLoading)
                        .opacity(isFormValid ? 1 : 0.6)
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
                    .foregroundColor(.white.opacity(0.8))
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
