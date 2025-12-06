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



                        // Forma de Pagamento (apenas para gastos)
                        if viewModel.type == .expense {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Forma de Pagamento")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.textSecondary)

                                paymentMethodPicker
                            }
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
            // Carregar cartões de crédito
            if let userId = authManager.userId {
                viewModel.loadCreditCards(userId: userId)
            }

            // Auto-foca no campo de valor com pequeno delay para garantir que a view está pronta
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAmountFocused = true
            }
        }
    }

    // MARK: - Payment Method Picker

    private var paymentMethodPicker: some View {
        Menu {
            // Opções básicas: Dinheiro, Pix, Débito
            Button(action: {
                viewModel.paymentMethod = .cash
                viewModel.selectedCreditCard = nil
            }) {
                HStack {
                    Image(systemName: PaymentMethod.cash.icon)
                    Text(PaymentMethod.cash.rawValue)
                    if viewModel.paymentMethod == .cash {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Button(action: {
                viewModel.paymentMethod = .pix
                viewModel.selectedCreditCard = nil
            }) {
                HStack {
                    Image(systemName: PaymentMethod.pix.icon)
                    Text(PaymentMethod.pix.rawValue)
                    if viewModel.paymentMethod == .pix {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Button(action: {
                viewModel.paymentMethod = .debit
                viewModel.selectedCreditCard = nil
            }) {
                HStack {
                    Image(systemName: PaymentMethod.debit.icon)
                    Text(PaymentMethod.debit.rawValue)
                    if viewModel.paymentMethod == .debit {
                        Image(systemName: "checkmark")
                    }
                }
            }

            // Cartões de Crédito (se houver)
            if !viewModel.creditCards.isEmpty {
                Divider()

                // Seção de Cartões de Crédito
                ForEach(viewModel.creditCards, id: \.id) { card in
                    Button(action: {
                        viewModel.paymentMethod = .credit
                        viewModel.selectedCreditCard = card
                    }) {
                        HStack {
                            Image(systemName: "creditcard.fill")
                                .foregroundColor(cardColor(for: card))
                            Text(card.cardName)
                            if viewModel.paymentMethod == .credit && viewModel.selectedCreditCard?.id == card.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack {
                // Ícone baseado no método selecionado
                if viewModel.paymentMethod == .credit, let card = viewModel.selectedCreditCard {
                    miniCardIcon(for: card)
                    Text(card.cardName)
                        .foregroundColor(AppColors.textPrimary)
                } else {
                    Image(systemName: viewModel.paymentMethod.icon)
                        .foregroundColor(paymentMethodColor)
                    Text(viewModel.paymentMethod.rawValue)
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(16)
            .background(AppColors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .cornerRadius(16)
        }
    }

    private var paymentMethodColor: Color {
        switch viewModel.paymentMethod {
        case .cash: return .green
        case .pix: return .cyan
        case .debit: return .orange
        case .credit: return .purple
        }
    }

    private func miniCardIcon(for card: CreditCard) -> some View {
        let cardColors: [Color] = {
            if let match = AvailableBankCards.cards(forBank: card.bankEnum).first(where: { $0.tier == card.cardTypeEnum }) {
                if let color = Color(hex: match.cardColor) {
                    return [color.opacity(0.9), color]
                }
            }
            return card.cardTypeEnum.gradientColors
        }()

        return RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: cardColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 28, height: 18)
            .overlay(
                RoundedRectangle(cornerRadius: 1)
                    .fill(LinearGradient(colors: [.yellow.opacity(0.8), .orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 6, height: 4)
                    .offset(x: -6, y: 2)
            )
    }

    private func cardColor(for card: CreditCard) -> Color {
        if let match = AvailableBankCards.cards(forBank: card.bankEnum).first(where: { $0.tier == card.cardTypeEnum }) {
            if let color = Color(hex: match.cardColor) {
                return color
            }
        }
        return card.cardTypeEnum.gradientColors.first ?? .purple
    }
}
