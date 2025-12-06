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
                VStack(spacing: 24) {
                    // Header Section
                    headerView
                    
                    // Dashboard Widgets (Summary Cards)
                    summaryCardsSection

                    // Credit Card Spending
                    if !viewModel.cardSpending.isEmpty {
                        CardSpendingCarousel(cardSpendings: viewModel.cardSpending)
                    }

                    // Analytics / Charts
                    if !viewModel.pieData.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            DarkSectionHeader(title: "Gastos por Categoria")
                            
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
                    }

                    // Recent Transactions
                    transactionsSection
                }
                .padding()
                .padding(.bottom, 80)
            }
            .refreshable {
                await viewModel.loadSummary()
            }

            // Floating Action Button
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

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Visão Geral")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.textSecondary)
                
                HStack(spacing: 8) {
                    Text(viewModel.currentMonth.displayString)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                    
                    if viewModel.isOffline {
                        Image(systemName: "wifi.slash")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    
                    if viewModel.pendingSyncCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("\(viewModel.pendingSyncCount)")
                        }
                        .font(.caption2)
                        .foregroundColor(AppColors.accentOrange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.accentOrange.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }
            
            Spacer()
            
            // Month Navigation
            HStack(spacing: 4) {
                Button(action: {
                    Task { await viewModel.goToPreviousMonth() }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                }
                
                Button(action: {
                    Task { await viewModel.goToNextMonth() }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                }
                
                if viewModel.currentMonth != .current {
                    Button(action: {
                        Task { await viewModel.goToToday() }
                    }) {
                        Text("Hoje")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.accentBlue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppColors.accentBlue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .padding(.leading, 8)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var summaryCardsSection: some View {
        HStack(spacing: 12) {
            SummaryCard(
                title: "Receitas",
                value: CurrencyUtils.format(viewModel.totalIncome),
                color: AppColors.income,
                icon: "arrow.down"
            )

            SummaryCard(
                title: "Gastos",
                value: CurrencyUtils.format(viewModel.totalExpense),
                color: AppColors.expense,
                icon: "arrow.up"
            )

            SummaryCard(
                title: "Saldo",
                value: CurrencyUtils.format(viewModel.balance),
                color: viewModel.balance >= 0 ? AppColors.accentBlue : AppColors.accentOrange,
                icon: "wallet.pass"
            )
        }
    }
    
    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            DarkSectionHeader(
                title: "Transações",
                actionText: viewModel.filteredTransactions.isEmpty ? nil : "Ver todas",
                action: { /* Navigate to full list if needed */ }
            )
            
            if viewModel.filteredTransactions.isEmpty {
                DarkEmptyState(
                    icon: "list.bullet.clipboard",
                    title: "Nenhuma transação",
                    subtitle: "Suas transações deste mês aparecerão aqui"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredTransactions) { transaction in
                        TransactionRowCard(transaction: transaction)
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteTransaction(transaction.id)
                                    }
                                } label: {
                                    Label("Excluir", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }
}

#Preview {
    MonthlySummaryView()
}
