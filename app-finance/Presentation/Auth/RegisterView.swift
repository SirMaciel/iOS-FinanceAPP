import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingVerification = false
    @State private var pendingUserId: String?

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
                    .fill(Color.purple.opacity(0.3))
                    .frame(width: 400, height: 400)
                    .blur(radius: 100)
                    .offset(x: geo.size.width - 200, y: -150)

                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 350, height: 350)
                    .blur(radius: 100)
                    .offset(x: -100, y: geo.size.height - 300)
            }
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        // App Icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.purple, Color.blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 72, height: 72)
                                .rotationEffect(.degrees(-6))
                                .shadow(color: .blue.opacity(0.4), radius: 20, y: 10)

                            Text("$")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 40)

                        Text("Comece sua jornada")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Crie sua conta em segundos.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.bottom, 32)

                    // Form
                    VStack(spacing: 16) {
                        // Nome completo
                        CustomTextField(
                            icon: "person",
                            placeholder: "Nome completo",
                            text: $name
                        )

                        // Email
                        CustomTextField(
                            icon: "envelope",
                            placeholder: "Seu e-mail",
                            text: $email,
                            keyboardType: .emailAddress
                        )

                        // Senha
                        CustomSecureField(
                            icon: "lock",
                            placeholder: "Sua senha",
                            text: $password,
                            showPassword: $showPassword
                        )

                        // Confirmar senha
                        CustomSecureField(
                            icon: "lock.shield",
                            placeholder: "Confirme sua senha",
                            text: $confirmPassword,
                            showPassword: $showConfirmPassword
                        )

                        // Validações
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

                        // Botão Criar Conta
                        Button(action: register) {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Text("Criar Conta")
                                        .fontWeight(.semibold)
                                    Image(systemName: "arrow.right")
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

                    // Termos
                    Text("Ao criar uma conta, você concorda com nossos Termos de Uso e Política de Privacidade")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 24)

                    // Back to login
                    HStack(spacing: 4) {
                        Text("Já tem uma conta?")
                            .foregroundColor(.white.opacity(0.5))
                        Button("Entrar") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
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
                    .foregroundColor(.white.opacity(0.8))
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
        .foregroundColor(isValid ? .green : .red.opacity(0.8))
    }
}

#Preview {
    NavigationStack {
        RegisterView()
            .environmentObject(AuthManager())
    }
}
