import SwiftUI

struct MonthlySummaryView: View {
    @StateObject private var viewModel = MonthlySummaryViewModel()
    @State private var showingAddTransaction = false
    @State private var showingProfile = false
    @State private var showingFixedBills = false
    @State private var showingAllTransactions = false
    @State private var selectedTransaction: TransactionItemViewModel?
    @State private var selectedFixedBill: FixedBill?

    var body: some View {
        ZStack {
            // Background
            DarkBackground()

            // Content
            VStack(spacing: 0) {
                // Profile Header
                ProfileHeader(onProfileTap: { showingProfile = true })

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

                    // Divider
                    Rectangle()
                        .fill(AppColors.cardBorder)
                        .frame(height: 1)
                        .padding(.vertical, 8)

                    // Fixed Bills
                    fixedBillsSection
                }
                .padding()
                .padding(.bottom, 80)
            }
                .refreshable {
                    await viewModel.loadSummary()
                }
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
        .sheet(isPresented: $showingProfile) {
            NavigationStack {
                ProfileView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: { showingProfile = false }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingFixedBills) {
            FixedBillsView()
        }
        .sheet(isPresented: $showingAllTransactions) {
            TransactionsView(
                transactions: viewModel.filteredTransactions,
                currentMonth: viewModel.currentMonth,
                onDelete: { transactionId in
                    Task {
                        await viewModel.deleteTransaction(transactionId)
                    }
                }
            )
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailSheet(
                transaction: transaction,
                onDelete: {
                    Task {
                        await viewModel.deleteTransaction(transaction.id)
                    }
                    selectedTransaction = nil
                }
            )
        }
        .sheet(item: $selectedFixedBill) { bill in
            AddFixedBillView(editingBill: bill, onSave: {
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
                action: { showingAllTransactions = true }
            )

            if viewModel.filteredTransactions.isEmpty {
                DarkEmptyState(
                    icon: "list.bullet.clipboard",
                    title: "Nenhuma transação",
                    subtitle: "Suas transações deste mês aparecerão aqui"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(viewModel.filteredTransactions.prefix(5))) { transaction in
                        Button {
                            selectedTransaction = transaction
                        } label: {
                            TransactionRowCard(transaction: transaction)
                        }
                        .buttonStyle(.plain)
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
                .animation(.none, value: viewModel.filteredTransactions.count)
            }
        }
    }

    private var fixedBillsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            DarkSectionHeader(
                title: "Contas Fixas",
                actionText: viewModel.activeFixedBillsForMonth.isEmpty ? nil : "Ver todas",
                action: { showingFixedBills = true }
            )

            if viewModel.activeFixedBillsForMonth.isEmpty {
                DarkEmptyState(
                    icon: "calendar.badge.clock",
                    title: "Nenhuma conta fixa",
                    subtitle: "Suas contas fixas deste mês aparecerão aqui"
                )
            } else {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.activeFixedBillsForMonth.prefix(5)) { bill in
                        Button {
                            selectedFixedBill = bill
                        } label: {
                            FixedBillSummaryRow(
                                bill: bill,
                                currentInstallment: viewModel.currentInstallment(for: bill),
                                currentMonth: viewModel.currentMonth
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Fixed Bill Summary Row

struct FixedBillSummaryRow: View {
    let bill: FixedBill
    let currentInstallment: Int?
    let currentMonth: MonthRef

    init(bill: FixedBill, currentInstallment: Int?, currentMonth: MonthRef = .current) {
        self.bill = bill
        self.currentInstallment = currentInstallment
        self.currentMonth = currentMonth
    }

    /// Data de vencimento formatada para o mês atual
    private var dueDateFormatted: String {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = currentMonth.year
        components.month = currentMonth.month
        components.day = min(bill.dueDay, 28) // Evitar problemas com meses curtos

        if let date = calendar.date(from: components) {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"
            return formatter.string(from: date)
        }
        return "\(bill.dueDay)/\(currentMonth.month)/\(currentMonth.year)"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(bill.displayCategoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: bill.displayCategoryIcon)
                    .font(.system(size: 18))
                    .foregroundColor(bill.displayCategoryColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(bill.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    if let current = currentInstallment,
                       let total = bill.totalInstallments {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text("\(current)/\(total)")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(6)
                    }
                }

                Text("\(bill.displayCategoryName) · \(dueDateFormatted)")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Amount
            HStack(spacing: 4) {
                Text(bill.formattedAmount)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary.opacity(0.5))
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Transaction Detail Sheet

struct TransactionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let transaction: TransactionItemViewModel
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            DarkBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(AppColors.cardBackground)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Detalhes")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    // Placeholder for balance
                    Color.clear
                        .frame(width: 36, height: 36)
                }
                .padding()

                ScrollView {
                    VStack(spacing: 24) {
                        // Amount Card
                        VStack(spacing: 8) {
                            Text(transaction.type == .income ? "Receita" : "Gasto")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)
                                .textCase(.uppercase)

                            Text(transaction.amountFormatted)
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(transaction.type == .income ? AppColors.income : AppColors.expense)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(AppColors.cardBackground)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        )

                        // Details
                        VStack(spacing: 16) {
                            detailRow(icon: "text.alignleft", title: "Descrição", value: transaction.description)

                            Divider().background(AppColors.cardBorder)

                            detailRow(icon: "calendar", title: "Data", value: transaction.dateFormatted)

                            if let categoryName = transaction.categoryName {
                                Divider().background(AppColors.cardBorder)

                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(transaction.categoryColor.opacity(0.15))
                                            .frame(width: 36, height: 36)

                                        Image(systemName: "tag.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(transaction.categoryColor)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Categoria")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textSecondary)

                                        Text(categoryName)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppColors.textPrimary)
                                    }

                                    Spacer()
                                }
                            }

                            // Location
                            if let locationName = transaction.locationName, !locationName.isEmpty {
                                Divider().background(AppColors.cardBorder)

                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.green.opacity(0.15))
                                            .frame(width: 36, height: 36)

                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.green)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Localização")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textSecondary)

                                        Text(locationName)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppColors.textPrimary)
                                    }

                                    Spacer()
                                }
                            }

                            if transaction.isPendingSync {
                                Divider().background(AppColors.cardBorder)

                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.caption)
                                        .foregroundColor(AppColors.accentOrange)

                                    Text("Aguardando sincronização")
                                        .font(.caption)
                                        .foregroundColor(AppColors.accentOrange)

                                    Spacer()
                                }
                                .padding(12)
                                .background(AppColors.accentOrange.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                        .padding(20)
                        .background(AppColors.cardBackground)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        )

                        // Delete Button
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                Text("Excluir Transação")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.expense)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColors.expense.opacity(0.1))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(AppColors.expense.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.accentBlue.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.accentBlue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
            }

            Spacer()
        }
    }
}

#Preview {
    MonthlySummaryView()
}
