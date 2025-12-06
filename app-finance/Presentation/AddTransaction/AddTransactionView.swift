import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = AddTransactionViewModel()
    @FocusState private var isAmountFocused: Bool

    let onTransactionAdded: () -> Void

    var body: some View {
        ZStack {
            // Background
            DarkBackground(blurColor1: AppColors.blurGreen, blurColor2: AppColors.blurBlue)

            // Content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Text("Cancelar")
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Text("Nova Transação")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)

                        // Indicador offline
                        if viewModel.isOffline {
                            Image(systemName: "wifi.slash")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    Spacer()

                    Button(action: {
                        Task {
                            if let userId = authManager.userId {
                                await viewModel.saveTransaction(
                                    userId: userId,
                                    onSuccess: {
                                        onTransactionAdded()
                                        dismiss()
                                    }
                                )
                            }
                        }
                    }) {
                        Text("Salvar")
                            .fontWeight(.semibold)
                            .foregroundColor(viewModel.isLoading ? AppColors.textTertiary : AppColors.accentBlue)
                    }
                    .disabled(viewModel.isLoading)
                }
                .padding()

                ScrollView {
                    VStack(spacing: 24) {
                        // Tipo
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tipo de transação")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            DarkSegmentedPicker(
                                selection: $viewModel.type,
                                options: [
                                    (.expense, "Gasto"),
                                    (.income, "Receita")
                                ]
                            )
                        }

                        // Valor
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Valor")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            HStack(spacing: 8) {
                                Text("R$")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.textSecondary)

                                TextField("0,00", text: $viewModel.amount)
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(viewModel.type == .expense ? AppColors.accentRed : AppColors.accentGreen)
                                    .keyboardType(.decimalPad)
                                    .focused($isAmountFocused)
                            }
                            .padding(16)
                            .background(AppColors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.cardBorder, lineWidth: 1)
                            )
                            .cornerRadius(16)
                        }

                        // Data
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Data")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(AppColors.textSecondary)

                                DatePicker("", selection: $viewModel.date, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .environment(\.locale, Locale(identifier: "pt_BR"))
                                    .labelsHidden()
                                    .colorScheme(.dark)

                                Spacer()
                            }
                            .padding(16)
                            .background(AppColors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.cardBorder, lineWidth: 1)
                            )
                            .cornerRadius(16)
                        }

                        // Descrição
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Descrição")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            DarkTextField(
                                icon: "text.alignleft",
                                placeholder: "Ex: Supermercado, Uber, etc.",
                                text: $viewModel.description,
                                autocapitalization: .sentences
                            )
                        }

                        // AI Note / Offline Note (somente para gastos)
                        if viewModel.type == .expense {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(
                                            colors: viewModel.isOffline ? [.gray, .gray.opacity(0.7)] : [.purple, .blue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .frame(width: 36, height: 36)

                                    Image(systemName: viewModel.isOffline ? "arrow.triangle.2.circlepath" : "sparkles")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(viewModel.isOffline ? "Salvamento Local" : "Categorização Inteligente")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColors.textPrimary)

                                    Text(viewModel.isOffline
                                         ? "Será categorizado pela IA quando online"
                                         : "A IA vai categorizar automaticamente seu gasto")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }

                                Spacer()
                            }
                            .padding(16)
                            .background(
                                LinearGradient(
                                    colors: viewModel.isOffline
                                        ? [.gray.opacity(0.1), .gray.opacity(0.05)]
                                        : [.purple.opacity(0.1), .blue.opacity(0.1)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: viewModel.isOffline
                                                ? [.gray.opacity(0.3), .gray.opacity(0.2)]
                                                : [.purple.opacity(0.3), .blue.opacity(0.3)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .cornerRadius(16)
                        }
                    }
                    .padding()
                    .onTapGesture { isAmountFocused = false; hideKeyboard() }
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onTapGesture { isAmountFocused = false; hideKeyboard() }
        .disabled(viewModel.isLoading)
        .overlay {
            if viewModel.isLoading {
                DarkLoadingOverlay(message: "Salvando...")
            }
        }
        .alert("Erro", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .onAppear {
            // Auto-foca no campo de valor com pequeno delay para garantir que a view está pronta
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAmountFocused = true
            }
        }
    }
}
