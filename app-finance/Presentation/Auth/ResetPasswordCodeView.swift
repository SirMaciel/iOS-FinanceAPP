import SwiftUI

struct ResetPasswordCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    let email: String

    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showNewPassword = false
    @State private var resetToken: String?
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
                    .fill(Color.orange.opacity(0.25))
                    .frame(width: 350, height: 350)
                    .blur(radius: 100)
                    .offset(x: geo.size.width / 2 - 175, y: -100)

                Circle()
                    .fill(Color.pink.opacity(0.25))
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
                                colors: [Color.orange.opacity(0.3), Color.pink.opacity(0.3)],
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

                        Image(systemName: "envelope.badge.shield.half.filled")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 32)

                // Title
                VStack(spacing: 12) {
                    Text("Digite o código")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Enviamos um código de 6 dígitos para")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))

                    Text(email)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
                .padding(.bottom, 40)

                // Code Input
                VStack(spacing: 20) {
                    ResetCodeInputView(code: $code)
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
                Button(action: verifyCode) {
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

                Spacer()

                // Back Button
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 14))
                        Text("Voltar")
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
        }
        .navigationDestination(isPresented: $showNewPassword) {
            if let token = resetToken {
                NewPasswordView(email: email, resetToken: token)
            }
        }
    }

    private func verifyCode() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let token = try await authManager.verifyResetCode(email: email, code: code)
                resetToken = token
                showNewPassword = true
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
}

// MARK: - Reset Code Input View

struct ResetCodeInputView: View {
    @Binding var code: String
    let codeLength = 6

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<codeLength, id: \.self) { index in
                ResetCodeDigitBox(
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

struct ResetCodeDigitBox: View {
    let digit: String
    let isFocused: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isFocused ? Color.orange.opacity(0.6) : Color.white.opacity(0.1),
                            lineWidth: isFocused ? 2 : 1
                        )
                )

            if digit.isEmpty && isFocused {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.orange)
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
        ResetPasswordCodeView(email: "teste@exemplo.com")
            .environmentObject(AuthManager())
    }
}
