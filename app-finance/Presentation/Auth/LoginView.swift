import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
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
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 400, height: 400)
                        .blur(radius: 100)
                        .offset(x: -100, y: -200)

                    Circle()
                        .fill(Color.purple.opacity(0.3))
                        .frame(width: 350, height: 350)
                        .blur(radius: 100)
                        .offset(x: geo.size.width - 150, y: geo.size.height - 200)
                }
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header Section
                        VStack(spacing: 16) {
                            // App Icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue, Color.purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 72, height: 72)
                                    .rotationEffect(.degrees(6))
                                    .shadow(color: .purple.opacity(0.4), radius: 20, y: 10)

                                Text("$")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 60)

                            Text("Bem-vindo de volta")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text("Gerencie suas finanças com inteligência.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.bottom, 40)

                        // Form
                        VStack(spacing: 16) {
                            // Email Field
                            CustomTextField(
                                icon: "envelope",
                                placeholder: "Seu e-mail",
                                text: $email,
                                keyboardType: .emailAddress
                            )

                            // Password Field
                            CustomSecureField(
                                icon: "lock",
                                placeholder: "Sua senha",
                                text: $password,
                                showPassword: $showPassword
                            )

                            // Forgot Password
                            HStack {
                                Spacer()
                                Button("Esqueceu a senha?") {
                                    showingForgotPassword = true
                                }
                                .font(.caption)
                                .foregroundColor(.blue.opacity(0.8))
                            }

                            // Error Message
                            if let error = errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.vertical, 8)
                            }

                            // Login Button
                            Button(action: login) {
                                HStack(spacing: 8) {
                                    if isLoading {
                                        ProgressView()
                                            .tint(.black)
                                    } else {
                                        Text("Entrar")
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

                        // Divider
                        HStack {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 1)
                            Text("ou continue com")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.horizontal, 8)
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 32)

                        // Social Login Buttons
                        HStack(spacing: 16) {
                            SocialLoginButton(icon: "apple.logo", title: "Apple", isLoading: isSocialLoading) {
                                loginWithApple()
                            }
                            SocialLoginButton(icon: "g.circle.fill", title: "Google", isLoading: false) {
                                loginWithGoogle()
                            }
                        }
                        .padding(.horizontal, 24)
                        .disabled(isSocialLoading)

                        // Sign Up Link
                        HStack(spacing: 4) {
                            Text("Não tem uma conta?")
                                .foregroundColor(.white.opacity(0.5))
                            Button("Cadastre-se") {
                                showingRegister = true
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
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
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animate = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .passwordResetSuccess)) { _ in
            showingForgotPassword = false
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
                    // Login successful, authManager already handled it
                    break
                case .requiresVerification(let userId, let userEmail):
                    // Navigate to verification screen
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

    private func loginWithGoogle() {
        // TODO: Implementar Google Sign In
        // Requer GoogleSignIn SDK via SPM ou CocoaPods
        errorMessage = "Login com Google ainda não disponível"
    }
}

// MARK: - Custom Components

struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 24)

            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.3)))
                .foregroundColor(.white)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color.black.opacity(0.2))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .cornerRadius(16)
    }
}

struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 24)

            Group {
                if showPassword {
                    TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.3)))
                } else {
                    SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.3)))
                }
            }
            .foregroundColor(.white)
            .autocapitalization(.none)
            .autocorrectionDisabled()

            Button(action: { showPassword.toggle() }) {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color.black.opacity(0.2))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .cornerRadius(16)
    }
}

struct SocialLoginButton: View {
    let icon: String
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .cornerRadius(14)
        }
        .disabled(isLoading)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
