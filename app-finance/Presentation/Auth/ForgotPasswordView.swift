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
                    .fill(Color.orange.opacity(0.25))
                    .frame(width: 350, height: 350)
                    .blur(radius: 100)
                    .offset(x: geo.size.width / 2 - 175, y: -100)

                Circle()
                    .fill(Color.purple.opacity(0.25))
                    .frame(width: 300, height: 300)
                    .blur(radius: 100)
                    .offset(x: -50, y: geo.size.height - 250)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.3), Color.purple.opacity(0.3)],
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
                                    colors: [Color.orange, Color.pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: .orange.opacity(0.4), radius: 20, y: 10)

                        Image(systemName: "key.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 32)

                // Title
                VStack(spacing: 12) {
                    Text("Recuperar senha")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Digite seu email para receber um link de recuperação")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
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
                        .foregroundColor(.blue.opacity(0.8))
                        .padding(.horizontal, 4)
                    }

                    CustomTextField(
                        icon: "envelope",
                        placeholder: "Seu e-mail",
                        text: $email,
                        keyboardType: .emailAddress
                    )

                    if let error = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 12))
                            Text(error)
                                .font(.caption)
                        }
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)

                // Send Button
                Button(action: sendResetEmail) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("Enviar link")
                                .fontWeight(.semibold)
                            Image(systemName: "paperplane.fill")
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
                .disabled(!isEmailValid || isLoading)
                .opacity(isEmailValid ? 1 : 0.6)
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
                    .foregroundColor(.white.opacity(0.5))
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
                    .foregroundColor(.white.opacity(0.8))
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
