import SwiftUI

struct MonthlySummaryView: View {
    @StateObject private var viewModel = MonthlySummaryViewModel()
    @State private var showingAddTransaction = false

    var body: some View {
        ZStack {
            // Background
            DarkBackground()

            // Content
            ScrollView {
                VStack(spacing: 20) {
                    // Cabeçalho de mês
                    monthHeader

                    // Cards de resumo
                    summaryCards

                    // Gastos do Cartão
                    if !viewModel.cardSpending.isEmpty {
                        CardSpendingCarousel(cardSpendings: viewModel.cardSpending)
                    }

                    // Gráfico de pizza
                    if !viewModel.pieData.isEmpty {
                        PieChartView(
                            data: viewModel.pieData,
                            selectedCategoryId: viewModel.selectedCategoryId,
                            onTap: { categoryId in
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                viewModel.selectCategory(categoryId)
                            }
                        )
                    }

                    // Lista de transações
                    TransactionListView(
                        transactions: viewModel.filteredTransactions,
                        selectedCategoryInfo: viewModel.selectedCategoryInfo,
                        onClearFilter: {
                            viewModel.clearFilter()
                        },
                        onDelete: { transactionId in
                            Task {
                                await viewModel.deleteTransaction(transactionId)
                            }
                        }
                    )
                }
                .padding()
                .padding(.bottom, 80)
            }
            .refreshable {
                await viewModel.loadSummary()
            }

            // Botão flutuante
            VStack {
                Spacer()
                FloatingAddButton {
                    showingAddTransaction = true
                }
                .padding(.bottom, 20)
            }
        }
        .task {
            await viewModel.loadSummary()
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView(onTransactionAdded: {
                Task {
                    await viewModel.loadSummary()
                }
            })
        }
        .overlay {
            if viewModel.isLoading && viewModel.transactions.isEmpty {
                DarkLoadingOverlay()
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
    }

    private var monthHeader: some View {
        HStack {
            Button(action: {
                Task {
                    await viewModel.goToPreviousMonth()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(AppColors.cardBackground)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        )

                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                }
            }

            Spacer()

            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Text(viewModel.currentMonth.displayString)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    // Indicador offline
                    if viewModel.isOffline {
                        Image(systemName: "wifi.slash")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    // Indicador de sync pendente
                    if viewModel.pendingSyncCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption2)
                            Text("\(viewModel.pendingSyncCount)")
                                .font(.caption2)
                        }
                        .foregroundColor(AppColors.accentOrange)
                    }
                }

                if viewModel.currentMonth != .current {
                    Button(action: {
                        Task {
                            await viewModel.goToToday()
                        }
                    }) {
                        Text("Ir para hoje")
                            .font(.caption)
                            .foregroundColor(AppColors.accentBlue)
                    }
                }
            }

            Spacer()

            Button(action: {
                Task {
                    await viewModel.goToNextMonth()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(AppColors.cardBackground)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        )

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                }
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .cornerRadius(16)
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            SummaryCard(
                title: "Receitas",
                value: CurrencyUtils.format(viewModel.totalIncome),
                color: AppColors.accentGreen,
                icon: "arrow.down.circle.fill"
            )

            SummaryCard(
                title: "Gastos",
                value: CurrencyUtils.format(viewModel.totalExpense),
                color: AppColors.accentRed,
                icon: "arrow.up.circle.fill"
            )

            SummaryCard(
                title: "Saldo",
                value: CurrencyUtils.format(viewModel.balance),
                color: viewModel.balance >= 0 ? AppColors.accentBlue : AppColors.accentOrange,
                icon: "wallet.pass.fill"
            )
        }
    }
}

#Preview {
    MonthlySummaryView()
}
