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

                    Image(systemName: "envelope.badge.shield.half.filled")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 32)

                // Title
                VStack(spacing: 12) {
                    Text("Digite o código")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)

                    Text("Enviamos um código de 6 dígitos para")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)

                    Text(email)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.accentBlue)
                }
                .padding(.bottom, 40)

                // Code Input
                VStack(spacing: 20) {
                    ResetCodeInputView(code: $code, isCodeFocused: $isCodeFocused)

                    if let error = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 14))
                            Text(error)
                                .font(.caption)
                        }
                        .foregroundColor(AppColors.accentRed)
                    }
                }
                .padding(.horizontal, 24)

                // Verify Button
                DarkButton(
                    title: "Verificar",
                    icon: "checkmark",
                    isLoading: isLoading,
                    isDisabled: code.count != 6
                ) {
                    verifyCode()
                }
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
    var isCodeFocused: FocusState<Bool>.Binding
    
    let codeLength = 6

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<codeLength, id: \.self) { index in
                ResetCodeDigitBox(
                    digit: digit(at: index),
                    isFocused: index == code.count || (index == codeLength - 1 && code.count == codeLength)
                )
            }
        }
        .background(
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused(isCodeFocused)
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
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isFocused ? AppColors.accentBlue.opacity(0.8) : AppColors.cardBorder,
                            lineWidth: isFocused ? 2 : 1
                        )
                )

            if digit.isEmpty && isFocused {
                RoundedRectangle(cornerRadius: 1)
                    .fill(AppColors.accentBlue)
                    .frame(width: 2, height: 24)
            } else {
                Text(digit)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
            }
        }
        .frame(width: 48, height: 60)
    }
}

#Preview {
    NavigationStack {
        ResetPasswordCodeView(email: "teste@exemplo.com")
            .environmentObject(AuthManager())
    }
}
