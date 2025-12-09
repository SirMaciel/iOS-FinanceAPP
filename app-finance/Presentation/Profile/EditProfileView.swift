import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    @State private var name: String = ""
    @State private var lastName: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar
                        avatarSection

                        // Form
                        formSection

                        // Error message
                        if let error = errorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 14))
                                Text(error)
                                    .font(.caption)
                            }
                            .foregroundColor(AppColors.accentRed)
                        }

                        // Save Button
                        AppButton(
                            title: "Salvar alteracoes",
                            icon: "checkmark",
                            isLoading: isLoading,
                            isDisabled: !isFormValid
                        ) {
                            saveProfile()
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Editar perfil")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .onAppear {
            name = authManager.userName ?? ""
            lastName = authManager.userLastName ?? ""
        }
        .alert("Perfil atualizado", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Suas informacoes foram atualizadas com sucesso.")
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Text(name.prefix(1).uppercased())
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("Foto de perfil")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.top, 20)
    }

    private var formSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Nome")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textSecondary)

                AppTextField(
                    icon: "person",
                    placeholder: "Seu nome",
                    text: $name,
                    autocapitalization: .words
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Sobrenome")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textSecondary)

                AppTextField(
                    icon: "person",
                    placeholder: "Seu sobrenome",
                    text: $lastName,
                    autocapitalization: .words
                )
            }
        }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func saveProfile() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authManager.updateProfile(
                    name: name.trimmingCharacters(in: .whitespaces),
                    lastName: lastName.trimmingCharacters(in: .whitespaces)
                )
                showSuccess = true
            } catch {
                errorMessage = "Erro ao salvar. Tente novamente."
            }
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileView()
            .environmentObject(AuthManager())
    }
}
