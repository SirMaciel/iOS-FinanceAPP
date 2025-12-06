import SwiftUI

struct EmailVerificationView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    let email: String
    let userId: String

    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var resendCooldown = 0
    @State private var timer: Timer?
    @FocusState private var isCodeFocused: Bool

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
                    .fill(Color.blue.opacity(0.25))
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
                                colors: [Color.green.opacity(0.3), Color.blue.opacity(0.3)],
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

                        Image(systemName: "envelope.badge")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 32)

                // Title
                VStack(spacing: 12) {
                    Text("Verifique seu email")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Enviamos um código de 6 dígitos para")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))

                    Text(email)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                .padding(.bottom, 40)

                // Code Input
                VStack(spacing: 20) {
                    DarkCodeInputView(code: $code)
                        .focused($isCodeFocused)

                    if let error = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 12))
                            Text(error)
                                .font(.caption)
                        }
                        .foregroundColor(.red.opacity(0.8))
                    }
                }
                .padding(.horizontal, 24)

                // Verify Button
                Button(action: verify) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("Verificar")
                                .fontWeight(.semibold)
                            Image(systemName: "checkmark")
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
                .disabled(code.count != 6 || isLoading)
                .opacity(code.count == 6 ? 1 : 0.6)
                .padding(.horizontal, 24)
                .padding(.top, 32)

                // Resend Code
                VStack(spacing: 8) {
                    Text("Não recebeu o código?")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))

                    if resendCooldown > 0 {
                        Text("Reenviar em \(resendCooldown)s")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.3))
                    } else {
                        Button("Reenviar código") {
                            resendCode()
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    }
                }
                .padding(.top, 24)

                Spacer()

                // Back Button
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 14))
                        Text("Usar outro email")
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
        .onAppear {
            isCodeFocused = true
            startResendCooldown()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func verify() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authManager.verifyEmail(userId: userId, code: code)
            } catch AuthError.invalidCode {
                errorMessage = "Código inválido. Tente novamente."
                code = ""
            } catch AuthError.codeExpired {
                errorMessage = "Código expirado. Solicite um novo."
                code = ""
            } catch {
                errorMessage = "Erro ao verificar. Tente novamente."
            }
            isLoading = false
        }
    }

    private func resendCode() {
        Task {
            do {
                try await authManager.resendVerificationCode(userId: userId)
                startResendCooldown()
            } catch {
                errorMessage = "Erro ao reenviar código"
            }
        }
    }

    private func startResendCooldown() {
        resendCooldown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if resendCooldown > 0 {
                resendCooldown -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
}

// MARK: - Dark Code Input View

struct DarkCodeInputView: View {
    @Binding var code: String
    let codeLength = 6

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<codeLength, id: \.self) { index in
                DarkCodeDigitBox(
                    digit: digit(at: index),
                    isFocused: index == code.count
                )
            }
        }
        .background(
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .opacity(0.01)
                .onChange(of: code) { _, newValue in
                    code = String(newValue.filter { $0.isNumber }.prefix(codeLength))
                }
        )
    }

    private func digit(at index: Int) -> String {
        guard index < code.count else { return "" }
        return String(code[code.index(code.startIndex, offsetBy: index)])
    }
}

struct DarkCodeDigitBox: View {
    let digit: String
    let isFocused: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isFocused ? Color.blue.opacity(0.6) : Color.white.opacity(0.1),
                            lineWidth: isFocused ? 2 : 1
                        )
                )

            if digit.isEmpty && isFocused {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.blue)
                    .frame(width: 2, height: 24)
            } else {
                Text(digit)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .frame(width: 50, height: 60)
    }
}

#Preview {
    NavigationStack {
        EmailVerificationView(email: "teste@exemplo.com", userId: "123")
            .environmentObject(AuthManager())
    }
}
