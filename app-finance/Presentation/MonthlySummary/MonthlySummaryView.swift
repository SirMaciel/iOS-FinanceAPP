import SwiftUI
import MapKit

enum ChartMode {
    case complete       // Categorias + Gastos Fixos + Parcelamentos
    case transactionsOnly  // Apenas categorias das transações

    var title: String {
        switch self {
        case .complete: return "Todos"
        case .transactionsOnly: return "Transações"
        }
    }
}

struct MonthlySummaryView: View {
    @StateObject private var viewModel = MonthlySummaryViewModel()
    @State private var showingAddTransaction = false
    @State private var showingProfile = false
    @State private var showingFixedBills = false
    @State private var showingAllTransactions = false
    @State private var showingAllInstallments = false
    @State private var selectedTransaction: TransactionItemViewModel?
    @State private var selectedFixedBill: FixedBill?
    @State private var selectedInstallment: InstallmentItemViewModel?
    @State private var chartMode: ChartMode = .transactionsOnly

    var body: some View {
        ZStack {
            // Background
            AppBackground()

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
                    chartSection

                    // Recent Transactions
                    transactionsSection

                    // Fixed Bills
                    fixedBillsSection

                    // Parcelamentos
                    parcelamentosSection
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
        .sheet(isPresented: $showingAllInstallments) {
            InstallmentsListView(
                initialMonth: viewModel.currentMonth,
                onDelete: { transactionId in
                    Task {
                        await viewModel.deleteInstallment(transactionId)
                    }
                },
                onUpdate: { transactionId, description, amount, categoryId in
                    Task {
                        await viewModel.updateInstallment(
                            transactionId: transactionId,
                            description: description,
                            amount: amount,
                            categoryId: categoryId
                        )
                    }
                }
            )
            .onDisappear {
                Task {
                    await viewModel.loadSummary()
                }
            }
        }
        .sheet(isPresented: $showingAllTransactions) {
            AllTransactionsView()
                .onDisappear {
                    // Reload data when returning from AllTransactionsView
                    Task {
                        await viewModel.loadSummary()
                    }
                }
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailSheet(
                transaction: transaction,
                onDelete: {
                    Task {
                        await viewModel.deleteTransaction(transaction.id)
                    }
                    selectedTransaction = nil
                },
                onEdit: { desc, amount, date, type, categoryId, notes, paymentMethod in
                    Task {
                        await viewModel.updateTransaction(
                            transactionId: transaction.id,
                            description: desc,
                            amount: amount,
                            date: date,
                            type: type,
                            categoryId: categoryId,
                            notes: notes,
                            paymentMethod: paymentMethod
                        )
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
        .sheet(item: $selectedInstallment) { installment in
            SummaryInstallmentDetailSheet(
                installment: installment,
                categories: viewModel.categories,
                onDelete: {
                    Task {
                        await viewModel.deleteTransaction(installment.transactionId)
                    }
                    selectedInstallment = nil
                },
                onUpdate: { transactionId, description, totalAmount, categoryId in
                    Task {
                        await viewModel.updateTransaction(
                            transactionId: transactionId,
                            description: description,
                            amount: totalAmount,
                            date: Date(),
                            type: .expense,
                            categoryId: categoryId,
                            notes: nil
                        )
                    }
                    selectedInstallment = nil
                }
            )
        }
        .overlay {
            if viewModel.isLoading && viewModel.transactions.isEmpty {
                ZStack {
                    AppBackground().opacity(0.8)
                    ProgressView()
                }
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
                        .background(AppColors.bgTertiary)
                        .clipShape(Circle())
                }
                
                Button(action: {
                    Task { await viewModel.goToNextMonth() }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(AppColors.bgTertiary)
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

    private var chartSection: some View {
        let currentData = chartMode == .complete
            ? viewModel.pieDataComplete
            : viewModel.pieDataTransactions

        return Group {
            if !currentData.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    // Header com toggle
                    HStack {
                        Text("Gastos por Categoria")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                chartMode = chartMode == .complete ? .transactionsOnly : .complete
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(chartMode.title)
                                    .font(.caption)
                                    .fontWeight(.medium)

                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .rotationEffect(.degrees(90))
                            }
                            .foregroundColor(AppColors.accentBlue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppColors.accentBlue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }

                    PieChartView(
                        data: currentData,
                        selectedCategoryId: viewModel.selectedCategoryId,
                        onTap: { categoryId in
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            viewModel.selectCategory(categoryId)
                        }
                    )
                }
            }
        }
    }

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Transações",
                actionText: viewModel.filteredTransactions.isEmpty ? nil : "Ver todas",
                action: { showingAllTransactions = true }
            )

            if viewModel.filteredTransactions.isEmpty {
                AppEmptyState(
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
            SectionHeader(
                title: "Contas Fixas",
                actionText: viewModel.activeFixedBillsForMonth.isEmpty ? nil : "Ver todas",
                action: { showingFixedBills = true }
            )

            if viewModel.activeFixedBillsForMonth.isEmpty {
                AppEmptyState(
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

    private var parcelamentosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Parcelamentos",
                actionText: viewModel.installmentsForMonth.isEmpty ? nil : "Ver todos",
                action: { showingAllInstallments = true }
            )

            if viewModel.installmentsForMonth.isEmpty {
                AppEmptyState(
                    icon: "creditcard.and.123",
                    title: "Nenhum parcelamento",
                    subtitle: "Seus parcelamentos deste mês aparecerão aqui"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(viewModel.installmentsForMonth.prefix(5))) { installment in
                        Button {
                            selectedInstallment = installment
                        } label: {
                            InstallmentSummaryRow(installment: installment)
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

// MARK: - Installment Summary Row

struct InstallmentSummaryRow: View {
    let installment: InstallmentItemViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(installment.categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: installment.categoryIcon)
                    .font(.system(size: 18))
                    .foregroundColor(installment.categoryColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(installment.description)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "creditcard")
                            .font(.caption2)
                        Text("\(installment.currentInstallment)/\(installment.totalInstallments)")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(6)
                }

                Text(installment.categoryName ?? "Sem categoria")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyUtils.format(installment.installmentAmount))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)

                Text("Total: \(CurrencyUtils.format(installment.totalAmount))")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Installments List View

struct InstallmentsListView: View {
    @Environment(\.dismiss) private var dismiss
    let initialMonth: MonthRef
    var onDelete: ((String) -> Void)? = nil
    var onUpdate: ((String, String, Decimal, String?) -> Void)? = nil

    @State private var currentMonth: MonthRef
    @State private var selectedInstallment: InstallmentItemViewModel?
    @State private var installmentTransactions: [Transaction] = []
    @State private var categories: [Category] = []
    @State private var creditCards: [CreditCard] = []
    @State private var showAddInstallment = false

    private let transactionRepo = TransactionRepository.shared
    private let categoryRepo = CategoryRepository.shared
    private let creditCardRepo = CreditCardRepository.shared

    private var userId: String {
        UserDefaults.standard.string(forKey: "user_id") ?? ""
    }

    init(initialMonth: MonthRef, onDelete: ((String) -> Void)? = nil, onUpdate: ((String, String, Decimal, String?) -> Void)? = nil) {
        self.initialMonth = initialMonth
        self.onDelete = onDelete
        self.onUpdate = onUpdate
        _currentMonth = State(initialValue: initialMonth)
    }

    /// Calcula os parcelamentos para o mês atual
    private var installmentsForMonth: [InstallmentItemViewModel] {
        let calendar = Calendar.current
        let currentYear = currentMonth.year
        let currentMonthNum = currentMonth.month

        let validInstallments = installmentTransactions.filter {
            $0.syncStatusEnum != .pendingDelete
        }

        var items: [InstallmentItemViewModel] = []

        for transaction in validInstallments {
            guard let totalInstallments = transaction.installments else { continue }
            let startingInstallment = transaction.startingInstallment ?? 1

            let txYear = calendar.component(.year, from: transaction.date)
            let txMonth = calendar.component(.month, from: transaction.date)
            let monthsSinceTransaction = (currentYear - txYear) * 12 + (currentMonthNum - txMonth)

            let installmentNumber = startingInstallment + monthsSinceTransaction

            if installmentNumber >= 1 && installmentNumber <= totalInstallments {
                let category = categories.first { $0.id == transaction.categoryId || $0.serverId == transaction.categoryId }

                let totalAmount = transaction.amountDouble
                let installmentAmount = totalAmount / Double(totalInstallments)

                items.append(InstallmentItemViewModel(
                    id: "\(transaction.id)-\(installmentNumber)",
                    transactionId: transaction.id,
                    description: transaction.desc,
                    installmentAmount: installmentAmount,
                    totalAmount: totalAmount,
                    currentInstallment: installmentNumber,
                    totalInstallments: totalInstallments,
                    creditCardId: transaction.creditCardId,
                    categoryName: category?.name,
                    categoryColor: category?.color ?? AppColors.textSecondary,
                    categoryIcon: category?.iconName ?? "tag.fill"
                ))
            }
        }

        return items.sorted { $0.description < $1.description }
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Header com navegação de mês
                headerSection

                // Summary
                if !installmentsForMonth.isEmpty {
                    summarySection
                }

                // Lista de parcelamentos
                if installmentsForMonth.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        AppEmptyState(
                            icon: "creditcard.and.123",
                            title: "Nenhum parcelamento",
                            subtitle: "Nenhum parcelamento ativo para \(currentMonth.displayString)"
                        )
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(installmentsForMonth) { installment in
                                Button {
                                    selectedInstallment = installment
                                } label: {
                                    InstallmentSummaryRow(installment: installment)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .onAppear {
            loadData()
        }
        .sheet(item: $selectedInstallment) { installment in
            SummaryInstallmentDetailSheet(
                installment: installment,
                categories: categories,
                onDelete: {
                    onDelete?(installment.transactionId)
                    selectedInstallment = nil
                    loadData()
                },
                onUpdate: { transactionId, description, amount, categoryId in
                    onUpdate?(transactionId, description, amount, categoryId)
                    selectedInstallment = nil
                    loadData()
                }
            )
        }
        .sheet(isPresented: $showAddInstallment) {
            AddExistingInstallmentSheet(
                creditCards: creditCards,
                onSave: { cardId, description, totalAmount, totalInstallments, startingInstallment, date, categoryId in
                    addInstallment(
                        cardId: cardId,
                        description: description,
                        totalAmount: totalAmount,
                        totalInstallments: totalInstallments,
                        startingInstallment: startingInstallment,
                        date: date,
                        categoryId: categoryId
                    )
                }
            )
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(AppColors.bgSecondary)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Parcelamentos")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Button {
                    showAddInstallment = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(AppColors.accentBlue)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top)

            // Month navigation
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        currentMonth = currentMonth.addingMonths(-1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(AppColors.bgSecondary)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 4) {
                    Text(currentMonth.displayString)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Text("\(installmentsForMonth.count) parcelamento\(installmentsForMonth.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        currentMonth = currentMonth.addingMonths(1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(AppColors.bgSecondary)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total do mês")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                Text(CurrencyUtils.format(installmentsForMonth.reduce(0) { $0 + $1.installmentAmount }))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.expense)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Valor total")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                Text(CurrencyUtils.format(installmentsForMonth.reduce(0) { $0 + $1.totalAmount }))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding()
        .background(AppColors.bgSecondary)
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Load Data

    private func loadData() {
        installmentTransactions = transactionRepo.getInstallmentTransactions(userId: userId)
        categories = categoryRepo.getCategories(userId: userId)
        creditCards = creditCardRepo.getCreditCards(userId: userId)
    }

    // MARK: - Add Installment

    private func addInstallment(
        cardId: String,
        description: String,
        totalAmount: Decimal,
        totalInstallments: Int,
        startingInstallment: Int,
        date: Date,
        categoryId: String?
    ) {
        _ = transactionRepo.createTransaction(
            userId: userId,
            type: .expense,
            amount: totalAmount,
            date: date,
            description: description,
            categoryId: categoryId,
            creditCardId: cardId,
            locationName: nil,
            latitude: nil,
            longitude: nil,
            cityName: nil,
            installments: totalInstallments,
            startingInstallment: startingInstallment,
            notes: nil
        )
        loadData()
    }
}

// MARK: - Summary Installment Detail Sheet (com Edição)

struct SummaryInstallmentDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let installment: InstallmentItemViewModel
    let categories: [Category]
    let onDelete: () -> Void
    var onUpdate: ((String, String, Decimal, String?) -> Void)? = nil

    @State private var showingDeleteConfirmation = false
    @State private var showingEditSheet = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(AppColors.bgSecondary)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Parcelamento")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    // Edit button
                    if onUpdate != nil {
                        Button { showingEditSheet = true } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.accentBlue)
                                .frame(width: 36, height: 36)
                                .background(AppColors.accentBlue.opacity(0.1))
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(width: 36, height: 36)
                    }
                }
                .padding()

                ScrollView {
                    VStack(spacing: 24) {
                        // Main Info Card
                        VStack(spacing: 20) {
                            // Icon and Name
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(installment.categoryColor.opacity(0.15))
                                        .frame(width: 64, height: 64)

                                    Image(systemName: installment.categoryIcon)
                                        .font(.system(size: 28))
                                        .foregroundColor(installment.categoryColor)
                                }

                                Text(installment.description)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.textPrimary)
                                    .multilineTextAlignment(.center)

                                // Installment badge
                                HStack(spacing: 6) {
                                    Image(systemName: "creditcard.fill")
                                        .font(.caption)
                                    Text("Parcela \(installment.currentInstallment) de \(installment.totalInstallments)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(8)
                            }

                            Divider()
                                .background(AppColors.cardBorder)

                            // Amounts
                            VStack(spacing: 16) {
                                // Installment amount
                                HStack {
                                    Text("Valor da parcela")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.textSecondary)
                                    Spacer()
                                    Text(CurrencyUtils.format(installment.installmentAmount))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.expense)
                                }

                                // Total amount
                                HStack {
                                    Text("Valor total da compra")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.textSecondary)
                                    Spacer()
                                    Text(CurrencyUtils.format(installment.totalAmount))
                                        .font(.headline)
                                        .foregroundColor(AppColors.textPrimary)
                                }

                                Divider()
                                    .background(AppColors.cardBorder)

                                // Remaining
                                let remaining = installment.totalInstallments - installment.currentInstallment
                                HStack {
                                    Text("Parcelas restantes")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.textSecondary)
                                    Spacer()
                                    Text("\(remaining)")
                                        .font(.headline)
                                        .foregroundColor(remaining > 0 ? AppColors.accentOrange : .green)
                                }

                                if remaining > 0 {
                                    HStack {
                                        Text("Valor restante")
                                            .font(.subheadline)
                                            .foregroundColor(AppColors.textSecondary)
                                        Spacer()
                                        Text(CurrencyUtils.format(installment.installmentAmount * Double(remaining)))
                                            .font(.headline)
                                            .foregroundColor(AppColors.accentOrange)
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(AppColors.bgSecondary)
                        .cornerRadius(16)

                        // Category info
                        if let categoryName = installment.categoryName {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Categoria")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.textSecondary)

                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(installment.categoryColor.opacity(0.15))
                                            .frame(width: 40, height: 40)

                                        Image(systemName: installment.categoryIcon)
                                            .font(.system(size: 16))
                                            .foregroundColor(installment.categoryColor)
                                    }

                                    Text(categoryName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColors.textPrimary)

                                    Spacer()
                                }
                                .padding(16)
                                .background(AppColors.bgSecondary)
                                .cornerRadius(12)
                            }
                        }

                        // Progress visualization
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Progresso")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            VStack(spacing: 8) {
                                // Progress bar
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(AppColors.bgTertiary)
                                            .frame(height: 8)

                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(installment.categoryColor)
                                            .frame(width: geometry.size.width * CGFloat(installment.currentInstallment) / CGFloat(installment.totalInstallments), height: 8)
                                    }
                                }
                                .frame(height: 8)

                                HStack {
                                    Text("\(installment.currentInstallment)/\(installment.totalInstallments) parcelas pagas")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)

                                    Spacer()

                                    let percentage = Int((Double(installment.currentInstallment) / Double(installment.totalInstallments)) * 100)
                                    Text("\(percentage)%")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(installment.categoryColor)
                                }
                            }
                            .padding(16)
                            .background(AppColors.bgSecondary)
                            .cornerRadius(12)
                        }

                        // Delete button
                        Button {
                            showingDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Excluir Parcelamento")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.expense)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.expense.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            SummaryEditInstallmentSheet(
                installment: installment,
                categories: categories,
                onSave: { description, amount, categoryId in
                    onUpdate?(installment.transactionId, description, amount, categoryId)
                    dismiss()
                }
            )
        }
        .alert("Excluir Parcelamento", isPresented: $showingDeleteConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir", role: .destructive) {
                dismiss()
                onDelete()
            }
        } message: {
            Text("Tem certeza que deseja excluir este parcelamento? Todas as parcelas serão removidas.")
        }
    }
}

// MARK: - Summary Edit Installment Sheet

struct SummaryEditInstallmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let installment: InstallmentItemViewModel
    let categories: [Category]
    let onSave: (String, Decimal, String?) -> Void

    @State private var name: String
    @State private var amountText: String
    @State private var selectedCategory: Category?

    init(installment: InstallmentItemViewModel, categories: [Category], onSave: @escaping (String, Decimal, String?) -> Void) {
        self.installment = installment
        self.categories = categories
        self.onSave = onSave
        _name = State(initialValue: installment.description)
        _amountText = State(initialValue: String(format: "%.2f", installment.totalAmount).replacingOccurrences(of: ".", with: ","))
        _selectedCategory = State(initialValue: categories.first { $0.name == installment.categoryName })
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Text("Cancelar")
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    Text("Editar Parcelamento")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Button {
                        saveChanges()
                    } label: {
                        Text("Salvar")
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentBlue)
                    }
                    .disabled(name.isEmpty || amountText.isEmpty)
                }
                .padding()

                ScrollView {
                    VStack(spacing: 24) {
                        // Nome (primeiro)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nome")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            TextField("Nome do parcelamento", text: $name)
                                .font(.body)
                                .foregroundColor(AppColors.textPrimary)
                                .padding()
                                .background(AppColors.bgSecondary)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColors.cardBorder, lineWidth: 1)
                                )
                        }

                        // Valor total (segundo)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Valor total")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            HStack {
                                Text("R$")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.expense)

                                TextField("0,00", text: $amountText)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.expense)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.leading)
                                    .onChange(of: amountText) { _, newValue in
                                        amountText = formatCurrencyInput(newValue)
                                    }
                            }
                            .padding(20)
                            .background(AppColors.bgSecondary)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.cardBorder, lineWidth: 1)
                            )

                            // Info sobre parcelas
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                Text("O valor será dividido em \(installment.totalInstallments) parcelas")
                                    .font(.caption)
                            }
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.top, 4)
                        }

                        // Categoria (terceiro) - usando Menu como no padrão
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Categoria")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            Menu {
                                ForEach(categories) { category in
                                    Button(action: {
                                        selectedCategory = category
                                    }) {
                                        HStack {
                                            Image(systemName: category.iconName)
                                            Text(category.name)
                                            if selectedCategory?.id == category.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    if let category = selectedCategory {
                                        ZStack {
                                            Circle()
                                                .fill(category.color.opacity(0.2))
                                                .frame(width: 32, height: 32)

                                            Image(systemName: category.iconName)
                                                .font(.system(size: 14))
                                                .foregroundColor(category.color)
                                        }

                                        Text(category.name)
                                            .foregroundColor(AppColors.textPrimary)
                                    } else {
                                        ZStack {
                                            Circle()
                                                .fill(AppColors.textSecondary.opacity(0.2))
                                                .frame(width: 32, height: 32)

                                            Image(systemName: "tag")
                                                .font(.system(size: 14))
                                                .foregroundColor(AppColors.textSecondary)
                                        }

                                        Text("Selecionar categoria")
                                            .foregroundColor(AppColors.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .padding(16)
                                .background(AppColors.bgSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(AppColors.cardBorder, lineWidth: 1)
                                )
                                .cornerRadius(16)
                            }
                        }

                        // Info do parcelamento (não editável)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Informações do Parcelamento")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            VStack(spacing: 12) {
                                HStack {
                                    Text("Parcela atual")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.textSecondary)
                                    Spacer()
                                    Text("\(installment.currentInstallment) de \(installment.totalInstallments)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.textPrimary)
                                }

                                if let amount = parseAmount(amountText) {
                                    HStack {
                                        Text("Valor da parcela")
                                            .font(.subheadline)
                                            .foregroundColor(AppColors.textSecondary)
                                        Spacer()
                                        Text(CurrencyUtils.format(amount / Double(installment.totalInstallments)))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppColors.expense)
                                    }
                                }
                            }
                            .padding()
                            .background(AppColors.bgSecondary)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func saveChanges() {
        guard let amount = parseAmount(amountText) else { return }
        let decimalAmount = Decimal(amount)
        onSave(name, decimalAmount, selectedCategory?.id)
    }

    private func parseAmount(_ text: String) -> Double? {
        guard !text.isEmpty else { return nil }
        let cleanText = text
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleanText)
    }

    private func formatCurrencyInput(_ input: String) -> String {
        let digitsOnly = input.filter { $0.isNumber }
        guard !digitsOnly.isEmpty else { return "" }
        guard let cents = Int(digitsOnly) else { return "" }
        let reais = Double(cents) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: reais)) ?? ""
    }
}

// MARK: - Installment Summary Detail Sheet (Legacy - mantido para compatibilidade)

struct InstallmentSummaryDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let installment: InstallmentItemViewModel
    let onDelete: () -> Void

    @State private var showingDeleteConfirmation = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(AppColors.bgSecondary)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Parcelamento")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    // Delete button
                    Button { showingDeleteConfirmation = true } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.expense)
                            .frame(width: 36, height: 36)
                            .background(AppColors.expense.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding()

                ScrollView {
                    VStack(spacing: 24) {
                        // Main Info Card
                        VStack(spacing: 20) {
                            // Icon and Name
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(installment.categoryColor.opacity(0.15))
                                        .frame(width: 64, height: 64)

                                    Image(systemName: installment.categoryIcon)
                                        .font(.system(size: 28))
                                        .foregroundColor(installment.categoryColor)
                                }

                                Text(installment.description)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.textPrimary)
                                    .multilineTextAlignment(.center)

                                // Installment badge
                                HStack(spacing: 6) {
                                    Image(systemName: "creditcard.fill")
                                        .font(.caption)
                                    Text("Parcela \(installment.currentInstallment) de \(installment.totalInstallments)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(8)
                            }

                            Divider()
                                .background(AppColors.cardBorder)

                            // Amounts
                            VStack(spacing: 16) {
                                // Installment amount
                                HStack {
                                    Text("Valor da parcela")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.textSecondary)
                                    Spacer()
                                    Text(CurrencyUtils.format(installment.installmentAmount))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.textPrimary)
                                }

                                // Total amount
                                HStack {
                                    Text("Valor total da compra")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.textSecondary)
                                    Spacer()
                                    Text(CurrencyUtils.format(installment.totalAmount))
                                        .font(.headline)
                                        .foregroundColor(AppColors.textSecondary)
                                }

                                // Remaining
                                let remaining = installment.totalInstallments - installment.currentInstallment
                                if remaining > 0 {
                                    HStack {
                                        Text("Parcelas restantes")
                                            .font(.subheadline)
                                            .foregroundColor(AppColors.textSecondary)
                                        Spacer()
                                        Text("\(remaining)")
                                            .font(.headline)
                                            .foregroundColor(AppColors.accentOrange)
                                    }

                                    HStack {
                                        Text("Valor restante")
                                            .font(.subheadline)
                                            .foregroundColor(AppColors.textSecondary)
                                        Spacer()
                                        Text(CurrencyUtils.format(installment.installmentAmount * Double(remaining)))
                                            .font(.headline)
                                            .foregroundColor(AppColors.accentOrange)
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(AppColors.bgSecondary)
                        .cornerRadius(16)

                        // Category info
                        if let categoryName = installment.categoryName {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Categoria")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.textSecondary)

                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(installment.categoryColor.opacity(0.15))
                                            .frame(width: 40, height: 40)

                                        Image(systemName: installment.categoryIcon)
                                            .font(.system(size: 16))
                                            .foregroundColor(installment.categoryColor)
                                    }

                                    Text(categoryName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColors.textPrimary)

                                    Spacer()
                                }
                                .padding(16)
                                .background(AppColors.bgSecondary)
                                .cornerRadius(12)
                            }
                        }

                        // Progress visualization
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Progresso")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            VStack(spacing: 8) {
                                // Progress bar
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(AppColors.bgTertiary)
                                            .frame(height: 8)

                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(installment.categoryColor)
                                            .frame(width: geometry.size.width * CGFloat(installment.currentInstallment) / CGFloat(installment.totalInstallments), height: 8)
                                    }
                                }
                                .frame(height: 8)

                                HStack {
                                    Text("\(installment.currentInstallment)/\(installment.totalInstallments) parcelas pagas")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)

                                    Spacer()

                                    let percentage = Int((Double(installment.currentInstallment) / Double(installment.totalInstallments)) * 100)
                                    Text("\(percentage)%")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(installment.categoryColor)
                                }
                            }
                            .padding(16)
                            .background(AppColors.bgSecondary)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
        }
        .alert("Excluir Parcelamento", isPresented: $showingDeleteConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir", role: .destructive) {
                dismiss()
                onDelete()
            }
        } message: {
            Text("Tem certeza que deseja excluir este parcelamento? Todas as parcelas serão removidas.")
        }
    }
}

// MARK: - Transaction Detail Sheet

struct TransactionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let transaction: TransactionItemViewModel
    let onDelete: () -> Void
    var onEdit: ((String, Decimal, Date, TransactionType, String?, String?, String?) -> Void)? = nil

    @State private var showingEditSheet = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(AppColors.bgSecondary)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Detalhes")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    // Edit button
                    if onEdit != nil {
                        Button { showingEditSheet = true } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.accentBlue)
                                .frame(width: 36, height: 36)
                                .background(AppColors.accentBlue.opacity(0.1))
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(width: 36, height: 36)
                    }
                }
                .padding()

                ScrollView {
                    VStack(spacing: 24) {
                        // Transaction Title
                        Text(transaction.description)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

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
                        .background(AppColors.bgSecondary)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        )

                        // Details
                        VStack(spacing: 16) {
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

                            // Payment Method
                            if let paymentMethod = transaction.paymentMethod, transaction.type == .expense {
                                Divider().background(AppColors.cardBorder)

                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(paymentMethodColor(paymentMethod).opacity(0.15))
                                            .frame(width: 36, height: 36)

                                        Image(systemName: paymentMethodIcon(paymentMethod))
                                            .font(.system(size: 14))
                                            .foregroundColor(paymentMethodColor(paymentMethod))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Meio de Pagamento")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textSecondary)

                                        Text(paymentMethodDisplayName(paymentMethod))
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

                                VStack(alignment: .leading, spacing: 12) {
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

                                    // Map Preview
                                    if let lat = transaction.latitude, let lon = transaction.longitude {
                                        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)

                                        Button {
                                            openInMaps(coordinate: coordinate, name: locationName)
                                        } label: {
                                            Map(initialPosition: .region(MKCoordinateRegion(
                                                center: coordinate,
                                                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                                            ))) {
                                                Marker(locationName, coordinate: coordinate)
                                                    .tint(.red)
                                            }
                                            .frame(height: 150)
                                            .cornerRadius(12)
                                            .disabled(true)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(AppColors.cardBorder, lineWidth: 1)
                                            )
                                            .overlay(
                                                VStack {
                                                    Spacer()
                                                    HStack {
                                                        Spacer()
                                                        HStack(spacing: 4) {
                                                            Image(systemName: "arrow.up.right.square")
                                                                .font(.caption)
                                                            Text("Abrir no Mapas")
                                                                .font(.caption)
                                                                .fontWeight(.medium)
                                                        }
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 6)
                                                        .background(Color.black.opacity(0.6))
                                                        .cornerRadius(8)
                                                        .padding(8)
                                                    }
                                                }
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            // Observação
                            if let notes = transaction.notes, !notes.isEmpty {
                                Divider().background(AppColors.cardBorder)

                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(AppColors.accentBlue.opacity(0.15))
                                            .frame(width: 36, height: 36)

                                        Image(systemName: "text.alignleft")
                                            .font(.system(size: 14))
                                            .foregroundColor(AppColors.accentBlue)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Observação")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textSecondary)

                                        Text(notes)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
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
                        .background(AppColors.bgSecondary)
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
        .sheet(isPresented: $showingEditSheet) {
            EditTransactionSheet(
                transaction: transaction,
                onSave: { desc, amount, date, type, categoryId, notes, paymentMethod in
                    onEdit?(desc, amount, date, type, categoryId, notes, paymentMethod)
                    showingEditSheet = false
                    dismiss()
                }
            )
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

    private func openInMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let mapItem: MKMapItem

        if #available(iOS 26.0, *) {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            mapItem = MKMapItem(location: location, address: nil)
        } else {
            let placemark = MKPlacemark(coordinate: coordinate)
            mapItem = MKMapItem(placemark: placemark)
        }

        mapItem.name = name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault
        ])
    }

    private func paymentMethodDisplayName(_ rawValue: String) -> String {
        switch rawValue {
        case PaymentMethod.cash.rawValue: return "Dinheiro"
        case PaymentMethod.pix.rawValue: return "Pix"
        case PaymentMethod.debit.rawValue: return "Débito"
        case PaymentMethod.credit.rawValue: return "Cartão de Crédito"
        default: return rawValue
        }
    }

    private func paymentMethodIcon(_ rawValue: String) -> String {
        switch rawValue {
        case PaymentMethod.cash.rawValue: return "banknote"
        case PaymentMethod.pix.rawValue: return "qrcode"
        case PaymentMethod.debit.rawValue: return "creditcard"
        case PaymentMethod.credit.rawValue: return "creditcard.fill"
        default: return "creditcard"
        }
    }

    private func paymentMethodColor(_ rawValue: String) -> Color {
        switch rawValue {
        case PaymentMethod.cash.rawValue: return .green
        case PaymentMethod.pix.rawValue: return .cyan
        case PaymentMethod.debit.rawValue: return .orange
        case PaymentMethod.credit.rawValue: return .purple
        default: return .purple
        }
    }
}

// MARK: - Edit Transaction Sheet

struct EditTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    let transaction: TransactionItemViewModel
    let onSave: (String, Decimal, Date, TransactionType, String?, String?, String?) -> Void

    @State private var name: String
    @State private var amountText: String
    @State private var date: Date
    @State private var type: TransactionType
    @State private var selectedCategory: Category?
    @State private var notes: String
    @State private var categories: [Category] = []
    @State private var paymentMethod: PaymentMethod
    @State private var selectedCreditCard: CreditCard?
    @State private var creditCards: [CreditCard] = []

    // Location states
    @State private var locationName: String
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var showLocationOptions: Bool = false
    @State private var isLoadingLocation: Bool = false
    @State private var showMapPicker: Bool = false

    // Category management
    @State private var showingCategoryManagement = false

    private let categoryRepo = CategoryRepository.shared
    private let creditCardRepo = CreditCardRepository.shared
    private let locationManager = LocationManager()

    init(transaction: TransactionItemViewModel, onSave: @escaping (String, Decimal, Date, TransactionType, String?, String?, String?) -> Void) {
        self.transaction = transaction
        self.onSave = onSave
        _name = State(initialValue: transaction.description)
        _amountText = State(initialValue: String(format: "%.2f", transaction.amount).replacingOccurrences(of: ".", with: ","))
        _date = State(initialValue: transaction.date)
        _type = State(initialValue: transaction.type)
        _notes = State(initialValue: transaction.notes ?? "")
        _locationName = State(initialValue: transaction.locationName ?? "")
        _latitude = State(initialValue: transaction.latitude)
        _longitude = State(initialValue: transaction.longitude)

        // Parse payment method from saved value
        if let savedMethod = transaction.paymentMethod {
            if savedMethod == PaymentMethod.cash.rawValue {
                _paymentMethod = State(initialValue: .cash)
            } else if savedMethod == PaymentMethod.pix.rawValue {
                _paymentMethod = State(initialValue: .pix)
            } else if savedMethod == PaymentMethod.debit.rawValue {
                _paymentMethod = State(initialValue: .debit)
            } else if savedMethod == PaymentMethod.credit.rawValue {
                _paymentMethod = State(initialValue: .credit)
            } else {
                _paymentMethod = State(initialValue: .cash)
            }
        } else {
            _paymentMethod = State(initialValue: .cash)
        }
    }

    private var amount: Decimal {
        let cleanText = amountText.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: cleanText) ?? 0
    }

    private var isValid: Bool {
        !name.isEmpty && amount > 0
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Text("Cancelar")
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    Text("Editar Transação")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Button {
                        onSave(name, amount, date, type, selectedCategory?.id, notes.isEmpty ? nil : notes, type == .expense ? paymentMethod.rawValue : nil)
                    } label: {
                        Text("Salvar")
                            .fontWeight(.semibold)
                            .foregroundColor(isValid ? AppColors.accentBlue : AppColors.textTertiary)
                    }
                    .disabled(!isValid)
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

                            HStack(spacing: 0) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        type = .expense
                                    }
                                } label: {
                                    Text("Despesa")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(type == .expense ? .white : AppColors.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                        .background(type == .expense ? AppColors.expense : Color.clear)
                                        .cornerRadius(10)
                                }

                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        type = .income
                                    }
                                } label: {
                                    Text("Receita")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(type == .income ? .white : AppColors.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                        .background(type == .income ? AppColors.income : Color.clear)
                                        .cornerRadius(10)
                                }
                            }
                            .padding(4)
                            .background(AppColors.bgTertiary)
                            .cornerRadius(14)
                        }
                        .padding(.horizontal)

                        // Nome (movido para cima do valor)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nome")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            AppTextField(
                                icon: "bag",
                                placeholder: type == .income ? "Ex: Salário, Freelance, etc." : "Ex: Supermercado, Uber, etc.",
                                text: $name,
                                autocapitalization: .sentences
                            )
                        }
                        .padding(.horizontal)

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
                                    .foregroundColor(type == .expense ? AppColors.expense : AppColors.income)

                                TextField("0,00", text: $amountText)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(type == .expense ? AppColors.expense : AppColors.income)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.leading)
                                    .onChange(of: amountText) { _, newValue in
                                        amountText = formatCurrencyInput(newValue)
                                    }
                            }
                            .padding(20)
                            .background(AppColors.bgSecondary)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.cardBorder, lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)

                        // Data
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Data")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 18))
                                    .foregroundColor(AppColors.accentBlue)

                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .environment(\.locale, Locale(identifier: "pt_BR"))
                                    .tint(AppColors.textPrimary)

                                Spacer()
                            }
                            .padding(16)
                            .background(AppColors.bgSecondary)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.cardBorder, lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)

                        // Meio de Pagamento (apenas para despesas)
                        if type == .expense {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Forma de Pagamento")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.textSecondary)

                                editPaymentMethodPicker
                            }
                            .padding(.horizontal)
                        }

                        // Localização
                        editLocationSection
                            .padding(.horizontal)

                        // Categoria (apenas para despesas)
                        if type == .expense {
                            editCategorySection
                                .padding(.horizontal)
                        }

                        // Observação (opcional)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Observação (opcional)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            AppTextField(
                                icon: "text.alignleft",
                                placeholder: "Detalhes adicionais...",
                                text: $notes,
                                autocapitalization: .sentences
                            )
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
        }
        .onAppear {
            loadCategories()
            loadCreditCards()
        }
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementSheet(
                categories: categories,
                onUpdate: { category, newName, colorHex in
                    categoryRepo.updateCategory(category, name: newName, colorHex: colorHex)
                    loadCategories()
                },
                onDelete: { category in
                    categoryRepo.deleteCategory(category)
                    loadCategories()
                }
            )
        }
        .sheet(isPresented: $showMapPicker) {
            EditLocationMapPickerSheet(
                initialLatitude: latitude,
                initialLongitude: longitude,
                onSelect: { lat, lon, name in
                    latitude = lat
                    longitude = lon
                    locationName = name
                }
            )
        }
    }

    // MARK: - Location Methods

    private func fetchCurrentLocation() async {
        isLoadingLocation = true

        if let result = await locationManager.fetchCurrentLocation() {
            let (location, placeName) = result
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            locationName = placeName ?? "Localização atual"
        }

        isLoadingLocation = false
    }

    // MARK: - Location Section

    private var editLocationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Localização (opcional)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)

            // Se tem localização salva
            if !locationName.isEmpty || latitude != nil {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.green)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(locationName.isEmpty ? "Localização salva" : locationName)
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Button(action: {
                            locationName = ""
                            latitude = nil
                            longitude = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .padding(16)

                    // Map preview when we have coordinates
                    if let lat = latitude, let lon = longitude {
                        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        let region = MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                        )

                        Map(initialPosition: .region(region), interactionModes: []) {
                            Marker(locationName.isEmpty ? "Localização" : locationName, coordinate: coordinate)
                                .tint(.green)
                        }
                        .frame(height: 120)
                        .clipShape(
                            .rect(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 16,
                                bottomTrailingRadius: 16,
                                topTrailingRadius: 0
                            )
                        )
                        .allowsHitTesting(false)
                    }
                }
                .background(AppColors.bgSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(16)
            } else {
                // Opções para adicionar localização
                HStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await fetchCurrentLocation()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if isLoadingLocation {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "location.fill")
                            }
                            Text("Usar atual")
                                .font(.subheadline)
                        }
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppColors.bgSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                    .disabled(isLoadingLocation)

                    Button(action: {
                        showMapPicker = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin")
                            Text("Inserir manualmente")
                                .font(.subheadline)
                        }
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppColors.bgSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: - Category Section

    private var editCategorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Categoria")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)

            Menu {
                // Existing categories
                ForEach(categories) { cat in
                    Button(action: {
                        selectedCategory = cat
                    }) {
                        HStack {
                            Image(systemName: cat.iconName)
                            Text(cat.name)
                            if selectedCategory?.id == cat.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Divider()

                // Manage categories option
                Button(action: {
                    showingCategoryManagement = true
                }) {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("Gerenciar categorias")
                    }
                }
            } label: {
                HStack {
                    if let category = selectedCategory {
                        ZStack {
                            Circle()
                                .fill(category.color.opacity(0.2))
                                .frame(width: 32, height: 32)

                            Image(systemName: category.iconName)
                                .font(.system(size: 14))
                                .foregroundColor(category.color)
                        }

                        Text(category.name)
                            .foregroundColor(AppColors.textPrimary)
                    } else {
                        ZStack {
                            Circle()
                                .fill(AppColors.textSecondary.opacity(0.2))
                                .frame(width: 32, height: 32)

                            Image(systemName: "tag")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Text("Selecionar categoria")
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(16)
                .background(AppColors.bgSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                )
                .cornerRadius(16)
            }
        }
    }

    private func loadCategories() {
        guard let userId = authManager.userId else { return }
        categories = categoryRepo.getCategories(userId: userId)

        // Find the category that matches the transaction's category name
        if let categoryName = transaction.categoryName {
            selectedCategory = categories.first { $0.name == categoryName }
        }
    }

    /// Formata entrada para moeda brasileira (apenas números, com vírgula para decimais)
    private func formatCurrencyInput(_ input: String) -> String {
        // Remove tudo que não é número
        let digitsOnly = input.filter { $0.isNumber }

        // Se vazio, retorna vazio
        guard !digitsOnly.isEmpty else { return "" }

        // Converte para centavos
        guard let cents = Int(digitsOnly) else { return "" }

        // Formata como moeda (divide por 100 para obter reais)
        let reais = Double(cents) / 100.0

        // Formata com separador de milhares e vírgula decimal
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        return formatter.string(from: NSNumber(value: reais)) ?? ""
    }

    private func loadCreditCards() {
        let userId = UserDefaults.standard.string(forKey: "user_id") ?? ""
        creditCards = creditCardRepo.getCreditCards(userId: userId)
    }

    private var editPaymentMethodColor: Color {
        switch paymentMethod {
        case .cash: return .green
        case .pix: return .cyan
        case .debit: return .orange
        case .credit: return .purple
        }
    }

    private func cardColor(for card: CreditCard) -> Color {
        if let match = AvailableBankCards.cards(forBank: card.bankEnum).first(where: { $0.tier == card.cardTypeEnum }) {
            if let color = Color(hex: match.cardColor) {
                return color
            }
        }
        return card.cardTypeEnum.gradientColors.first ?? .purple
    }

    private func miniCardIcon(for card: CreditCard) -> some View {
        let colors: [Color] = {
            if let match = AvailableBankCards.cards(forBank: card.bankEnum).first(where: { $0.tier == card.cardTypeEnum }) {
                if let color = Color(hex: match.cardColor) {
                    return [color, color.opacity(0.7)]
                }
            }
            return card.cardTypeEnum.gradientColors
        }()

        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 18)
                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)

            // Chip
            RoundedRectangle(cornerRadius: 1)
                .fill(LinearGradient(colors: [.yellow.opacity(0.8), .orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 5, height: 3.5)
                .offset(x: -7, y: 2)
        }
    }

    private var editPaymentMethodPicker: some View {
        Menu {
            // Opções básicas: Dinheiro, Pix, Débito
            Button(action: {
                paymentMethod = .cash
                selectedCreditCard = nil
            }) {
                HStack {
                    Image(systemName: PaymentMethod.cash.icon)
                    Text(PaymentMethod.cash.rawValue)
                    if paymentMethod == .cash {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Button(action: {
                paymentMethod = .pix
                selectedCreditCard = nil
            }) {
                HStack {
                    Image(systemName: PaymentMethod.pix.icon)
                    Text(PaymentMethod.pix.rawValue)
                    if paymentMethod == .pix {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Button(action: {
                paymentMethod = .debit
                selectedCreditCard = nil
            }) {
                HStack {
                    Image(systemName: PaymentMethod.debit.icon)
                    Text(PaymentMethod.debit.rawValue)
                    if paymentMethod == .debit {
                        Image(systemName: "checkmark")
                    }
                }
            }

            // Cartões de crédito
            if !creditCards.isEmpty {
                Divider()

                // Seção de Cartões de Crédito
                ForEach(creditCards, id: \.id) { card in
                    Button(action: {
                        paymentMethod = .credit
                        selectedCreditCard = card
                    }) {
                        HStack {
                            Image(systemName: "creditcard.fill")
                                .foregroundColor(cardColor(for: card))
                            Text(card.cardName)
                            if paymentMethod == .credit && selectedCreditCard?.id == card.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack {
                // Ícone baseado no método selecionado
                if paymentMethod == .credit, let card = selectedCreditCard {
                    miniCardIcon(for: card)
                    Text(card.cardName)
                        .foregroundColor(AppColors.textPrimary)
                } else {
                    Image(systemName: paymentMethod.icon)
                        .foregroundColor(editPaymentMethodColor)
                    Text(paymentMethod.rawValue)
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(16)
            .background(AppColors.bgSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .cornerRadius(16)
        }
    }
}

// MARK: - Edit Location Map Picker Sheet

struct EditLocationMapPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialLatitude: Double?
    let initialLongitude: Double?
    let onSelect: (Double, Double, String) -> Void

    @State private var mapCameraPosition: MapCameraPosition
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var isLoadingAddress = false
    @State private var addressPreview: String = ""
    @State private var hasUserInteracted = false
    @State private var geocodeTask: Task<Void, Never>?

    // Search
    @State private var searchQuery: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @FocusState private var isSearchFocused: Bool

    private let locationManager = LocationManager()

    init(initialLatitude: Double?, initialLongitude: Double?, onSelect: @escaping (Double, Double, String) -> Void) {
        self.initialLatitude = initialLatitude
        self.initialLongitude = initialLongitude
        self.onSelect = onSelect

        // Set initial position
        let center: CLLocationCoordinate2D
        if let lat = initialLatitude, let lon = initialLongitude {
            center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            // Default to São Paulo
            center = CLLocationCoordinate2D(latitude: -23.5505, longitude: -46.6333)
        }

        _mapCameraPosition = State(initialValue: .region(
            MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        ))
        _selectedCoordinate = State(initialValue: center)
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    Text("Escolher no Mapa")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Button("Confirmar") {
                        if let coord = selectedCoordinate {
                            let name = addressPreview.isEmpty ? "Local selecionado" : addressPreview
                            onSelect(coord.latitude, coord.longitude, name)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.accentBlue)
                }
                .padding()

                // Map with centered pin
                ZStack {
                    Map(position: $mapCameraPosition, interactionModes: [.pan, .zoom]) {
                    }
                    .onMapCameraChange(frequency: .onEnd) { context in
                        let newCoord = context.camera.centerCoordinate
                        selectedCoordinate = newCoord

                        if !hasUserInteracted {
                            hasUserInteracted = true
                        }

                        if hasUserInteracted {
                            reverseGeocodeCoordinate(newCoord)
                        }
                    }

                    // Center pin overlay
                    VStack(spacing: 0) {
                        Image(systemName: "mappin")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.green)

                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                }

                // Search bar and address preview
                VStack(spacing: 0) {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.textSecondary)

                        TextField("Buscar endereço...", text: $searchQuery)
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                            .focused($isSearchFocused)
                            .onSubmit {
                                performSearch()
                            }

                        if isSearching {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        } else if !searchQuery.isEmpty {
                            Button(action: {
                                searchQuery = ""
                                searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                    .padding()
                    .background(AppColors.bgSecondary)

                    // Current address indicator
                    if searchQuery.isEmpty && !addressPreview.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)

                            if isLoadingAddress {
                                Text("Buscando endereço...")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            } else {
                                Text(addressPreview)
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(AppColors.bgSecondary)
                    }

                    // Search results
                    if !searchResults.isEmpty {
                        Divider()
                            .background(AppColors.cardBorder)

                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(searchResults, id: \.self) { item in
                                    Button(action: {
                                        selectSearchResult(item)
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "mappin.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 20))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.name ?? "Local")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(AppColors.textPrimary)
                                                    .lineLimit(1)

                                                if let address = formatMapItemAddress(item), !address.isEmpty {
                                                    Text(address)
                                                        .font(.caption)
                                                        .foregroundColor(AppColors.textSecondary)
                                                        .lineLimit(1)
                                                }
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(AppColors.textTertiary)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
            }
        }
        .onAppear {
            // If we have initial coordinates, geocode them
            if let coord = selectedCoordinate {
                reverseGeocodeCoordinate(coord)
            }
        }
    }

    private func reverseGeocodeCoordinate(_ coordinate: CLLocationCoordinate2D) {
        geocodeTask?.cancel()

        geocodeTask = Task {
            isLoadingAddress = true

            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce

            guard !Task.isCancelled else { return }

            if let address = await locationManager.reverseGeocodeCoordinate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ) {
                addressPreview = address
            } else {
                addressPreview = "Local selecionado"
            }

            isLoadingAddress = false
        }
    }

    private func performSearch() {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        Task {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = searchQuery
            request.resultTypes = [.address, .pointOfInterest]

            let search = MKLocalSearch(request: request)
            do {
                let response = try await search.start()
                searchResults = response.mapItems
            } catch {
                searchResults = []
            }
            isSearching = false
        }
    }

    private func selectSearchResult(_ item: MKMapItem) {
        // iOS 26: usar item.location ao invés de item.placemark.location
        let coordinate = item.location.coordinate

        selectedCoordinate = coordinate
        addressPreview = item.name ?? formatMapItemAddress(item) ?? "Local selecionado"
        searchQuery = ""
        searchResults = []
        isSearchFocused = false

        withAnimation {
            mapCameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                )
            )
        }
    }

    private func formatMapItemAddress(_ mapItem: MKMapItem) -> String? {
        // iOS 26: usar address/addressRepresentations ao invés de placemark (deprecated)
        if let fullAddress = mapItem.address?.fullAddress, !fullAddress.isEmpty {
            return fullAddress
        }
        // Fallback: usar shortAddress
        return mapItem.address?.shortAddress
    }
}

#Preview {
    MonthlySummaryView()
}
