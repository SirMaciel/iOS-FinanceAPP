import Foundation
import Combine
import SwiftUI
import SwiftData

@MainActor
class MonthlySummaryViewModel: ObservableObject {
    @Published var currentMonth: MonthRef = .current
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedCategoryId: String?
    @Published var isOffline = false
    @Published var pendingSyncCount = 0

    // Local data
    @Published private(set) var transactions: [Transaction] = []
    @Published private(set) var installmentTransactions: [Transaction] = []  // Todas transações parceladas
    @Published private(set) var categories: [Category] = []
    @Published private(set) var fixedBills: [FixedBill] = []

    private let transactionRepo = TransactionRepository.shared
    private let categoryRepo = CategoryRepository.shared
    private let fixedBillRepo = FixedBillRepository.shared
    private let syncManager = SyncManager.shared
    private let networkMonitor = NetworkMonitor.shared

    private var cancellables = Set<AnyCancellable>()
    private var userId: String {
        UserDefaults.standard.string(forKey: "user_id") ?? ""
    }

    init() {
        setupObservers()
    }

    private func setupObservers() {
        // Observar mudanças de rede
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.isOffline = !connected
            }
            .store(in: &cancellables)

        // Observar sync completo para recarregar
        NotificationCenter.default.publisher(for: .syncCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadFromLocal()
                self?.updatePendingCount()
            }
            .store(in: &cancellables)

        // Observar contagem de pendentes
        syncManager.$pendingChangesCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$pendingSyncCount)
    }

    // MARK: - Computed Properties

    var totalIncome: Double {
        transactions
            .filter { $0.type == .income && $0.syncStatusEnum != .pendingDelete }
            .reduce(0) { $0 + $1.amountDouble }
    }

    var totalExpense: Double {
        // Transações normais (excluindo parcelamentos que são calculados separadamente)
        let transactionsTotal = transactions
            .filter {
                $0.type == .expense &&
                $0.syncStatusEnum != .pendingDelete &&
                ($0.installments == nil || $0.installments! <= 1)
            }
            .reduce(0) { $0 + $1.amountDouble }
        return transactionsTotal + totalFixedBills + totalInstallmentsForMonth
    }

    var totalFixedBills: Double {
        activeFixedBillsForMonth.reduce(0) { $0 + $1.amountDouble }
    }

    /// Total dos parcelamentos do mês (valor da parcela, não valor total)
    var totalInstallmentsForMonth: Double {
        installmentsForMonth.reduce(0) { $0 + $1.installmentAmount }
    }

    /// Contas fixas ativas para o mês atual, excluindo financiamentos já terminados
    var activeFixedBillsForMonth: [FixedBill] {
        fixedBills.filter { bill in
            // Deve estar ativa
            guard bill.isActive else { return false }

            // Se não tem parcelas, sempre mostrar
            guard let totalInstallments = bill.totalInstallments, totalInstallments > 0 else {
                return true
            }

            // Calcular quantos meses se passaram desde a criação da conta
            let calendar = Calendar.current
            let billStartDate = bill.createdAt

            // Pegar o ano e mês do currentMonth
            let currentYear = currentMonth.year
            let currentMonthNum = currentMonth.month

            // Calcular diferença de meses
            let billYear = calendar.component(.year, from: billStartDate)
            let billMonth = calendar.component(.month, from: billStartDate)

            let monthsSinceCreation = (currentYear - billYear) * 12 + (currentMonthNum - billMonth)

            // Considerar parcelas já pagas antes de adicionar ao app
            let paidBefore = bill.paidInstallments ?? 0

            // Parcela atual = parcelas já pagas + meses desde criação + 1
            let currentInstallment = paidBefore + monthsSinceCreation + 1

            // Mostrar se ainda não terminou todas as parcelas
            return currentInstallment <= totalInstallments
        }
    }

    var balance: Double {
        totalIncome - totalExpense
    }

    /// Calcula a parcela atual de um financiamento baseado no mês selecionado
    func currentInstallment(for bill: FixedBill) -> Int? {
        guard let totalInstallments = bill.totalInstallments, totalInstallments > 0 else {
            return nil
        }

        let calendar = Calendar.current
        let billYear = calendar.component(.year, from: bill.createdAt)
        let billMonth = calendar.component(.month, from: bill.createdAt)

        let monthsSinceCreation = (currentMonth.year - billYear) * 12 + (currentMonth.month - billMonth)

        // Considerar parcelas já pagas antes de adicionar ao app
        let paidBefore = bill.paidInstallments ?? 0

        // Parcela atual = parcelas já pagas + meses desde criação + 1
        return min(paidBefore + monthsSinceCreation + 1, totalInstallments)
    }

    /// Gráfico de pizza para transações (sem parcelamentos)
    var pieDataTransactions: [PieCategoryData] {
        let expenseTransactions = transactions.filter {
            $0.type == .expense &&
            $0.syncStatusEnum != .pendingDelete &&
            ($0.installments == nil || $0.installments! <= 1)
        }
        let total = expenseTransactions.reduce(0) { $0 + $1.amountDouble }

        guard total > 0 else { return [] }

        var categoryTotals: [String: Double] = [:]
        for tx in expenseTransactions {
            let catId = tx.categoryId ?? "uncategorized"
            categoryTotals[catId, default: 0] += tx.amountDouble
        }

        return categoryTotals.compactMap { (catId, catTotal) -> PieCategoryData? in
            let category = categories.first { $0.id == catId || $0.serverId == catId }
            return PieCategoryData(
                categoryId: catId,
                name: category?.name ?? "Sem categoria",
                colorHex: category?.colorHex ?? "#999999",
                iconName: category?.iconName ?? "questionmark.circle",
                total: catTotal,
                percent: (catTotal / total) * 100
            )
        }.sorted { $0.total > $1.total }
    }

    /// Gráfico de pizza completo: todas as categorias (transações + gastos fixos + parcelamentos)
    var pieDataComplete: [PieCategoryData] {
        // Dicionário para agrupar todos os valores por categoria
        // Chave: categoryId ou nome da categoria de gasto fixo
        // Valor: (nome, colorHex, iconName, total)
        var categoryData: [String: (name: String, colorHex: String, iconName: String, total: Double)] = [:]

        // 1. Adicionar categorias das transações normais (sem parcelamentos)
        let expenseTransactions = transactions.filter {
            $0.type == .expense &&
            $0.syncStatusEnum != .pendingDelete &&
            ($0.installments == nil || $0.installments! <= 1)
        }

        for tx in expenseTransactions {
            let catId = tx.categoryId ?? "uncategorized"
            let category = categories.first { $0.id == catId || $0.serverId == catId }
            let name = category?.name ?? "Sem categoria"
            let colorHex = category?.colorHex ?? "#999999"
            let iconName = category?.iconName ?? "questionmark.circle"

            if var existing = categoryData[catId] {
                existing.total += tx.amountDouble
                categoryData[catId] = existing
            } else {
                categoryData[catId] = (name: name, colorHex: colorHex, iconName: iconName, total: tx.amountDouble)
            }
        }

        // 2. Adicionar categorias dos gastos fixos (agrupados por categoria do FixedBill)
        for bill in activeFixedBillsForMonth {
            let catKey = "fixedbill_\(bill.displayCategoryName)"
            let name = bill.displayCategoryName
            let colorHex = bill.displayCategoryColorHex
            let iconName = bill.displayCategoryIcon

            if var existing = categoryData[catKey] {
                existing.total += bill.amountDouble
                categoryData[catKey] = existing
            } else {
                categoryData[catKey] = (name: name, colorHex: colorHex, iconName: iconName, total: bill.amountDouble)
            }
        }

        // 3. Adicionar categorias dos parcelamentos (usando o categoryId original da transação)
        let calendar = Calendar.current
        let currentYear = currentMonth.year
        let currentMonthNum = currentMonth.month

        for transaction in installmentTransactions {
            guard transaction.syncStatusEnum != .pendingDelete,
                  let totalInstallments = transaction.installments,
                  totalInstallments > 1 else { continue }

            let startingInstallment = transaction.startingInstallment ?? 1
            let txYear = calendar.component(.year, from: transaction.date)
            let txMonth = calendar.component(.month, from: transaction.date)
            let monthsSinceTransaction = (currentYear - txYear) * 12 + (currentMonthNum - txMonth)
            let installmentNumber = startingInstallment + monthsSinceTransaction

            // Só incluir se a parcela está dentro do range
            guard installmentNumber >= 1 && installmentNumber <= totalInstallments else { continue }

            // Usar o mesmo categoryId das transações para agrupar corretamente
            let catId = transaction.categoryId ?? "uncategorized"
            let category = categories.first { $0.id == catId || $0.serverId == catId }
            let name = category?.name ?? "Sem categoria"
            let colorHex = category?.colorHex ?? "#999999"
            let iconName = category?.iconName ?? "questionmark.circle"

            let installmentAmount = transaction.amountDouble / Double(totalInstallments)

            if var existing = categoryData[catId] {
                existing.total += installmentAmount
                categoryData[catId] = existing
            } else {
                categoryData[catId] = (name: name, colorHex: colorHex, iconName: iconName, total: installmentAmount)
            }
        }

        // Calcular total
        let total = categoryData.values.reduce(0) { $0 + $1.total }
        guard total > 0 else { return [] }

        // Converter para array de PieCategoryData
        return categoryData.map { (catId, data) in
            PieCategoryData(
                categoryId: catId,
                name: data.name,
                colorHex: data.colorHex,
                iconName: data.iconName,
                total: data.total,
                percent: (data.total / total) * 100
            )
        }.sorted { $0.total > $1.total }
    }

    /// Mantém compatibilidade - usa transações por padrão
    var pieData: [PieCategoryData] {
        pieDataTransactions
    }

    var filteredTransactions: [TransactionItemViewModel] {
        let filtered = transactions
            .filter { $0.syncStatusEnum != .pendingDelete }
            // Exclude installment transactions (installments > 1)
            .filter { $0.installments == nil || $0.installments! <= 1 }
            .filter { selectedCategoryId == nil || $0.categoryId == selectedCategoryId }
            .sorted { $0.date > $1.date }

        return filtered.map { tx in
            let category = categories.first { $0.id == tx.categoryId || $0.serverId == tx.categoryId }

            return TransactionItemViewModel(
                id: tx.id,
                description: tx.desc,
                amount: tx.amountDouble,
                amountFormatted: CurrencyUtils.format(tx.amountDouble),
                date: tx.date,
                dateFormatted: tx.date.shortFormatted,
                type: tx.type,
                categoryName: category?.name,
                categoryColor: category?.color ?? .gray,
                categoryIcon: category?.iconName ?? "tag.fill",
                needsUserReview: tx.needsUserReview,
                isPendingSync: tx.isPendingSync,
                locationName: tx.locationName,
                latitude: tx.latitude,
                longitude: tx.longitude,
                cityName: tx.cityName,
                notes: tx.notes,
                categoryId: tx.categoryId
            )
        }
    }

    /// Parcelamentos do mês atual
    var installmentsForMonth: [InstallmentItemViewModel] {
        let calendar = Calendar.current
        let currentYear = currentMonth.year
        let currentMonthNum = currentMonth.month

        // Usar installmentTransactions que contém todas as transações parceladas (de qualquer mês)
        let validInstallments = installmentTransactions.filter {
            $0.syncStatusEnum != .pendingDelete
        }

        var items: [InstallmentItemViewModel] = []

        for transaction in validInstallments {
            guard let totalInstallments = transaction.installments else { continue }
            let startingInstallment = transaction.startingInstallment ?? 1

            // Calculate which installment is due this month
            let txYear = calendar.component(.year, from: transaction.date)
            let txMonth = calendar.component(.month, from: transaction.date)
            let monthsSinceTransaction = (currentYear - txYear) * 12 + (currentMonthNum - txMonth)

            let installmentNumber = startingInstallment + monthsSinceTransaction

            // Only include if this installment is within range
            if installmentNumber >= 1 && installmentNumber <= totalInstallments {
                let category = categories.first { $0.id == transaction.categoryId || $0.serverId == transaction.categoryId }

                // O amount armazenado é o valor TOTAL da compra
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



    var cardSpending: [CreditCardSpending] {
        // Group transactions by credit card
        let cardTransactions = transactions.filter {
            $0.type == .expense &&
            $0.creditCardId != nil &&
            $0.syncStatusEnum != .pendingDelete
        }

        let grouped = Dictionary(grouping: cardTransactions) { $0.creditCardId! }
        let creditCardRepo = CreditCardRepository.shared

        return grouped.compactMap { (cardId, txs) -> CreditCardSpending? in
            guard let card = creditCardRepo.getCreditCard(id: cardId) else { return nil }
            let total = txs.reduce(0) { $0 + $1.amountDouble }
            return CreditCardSpending(
                cardId: card.id,
                cardName: card.cardName,
                lastFourDigits: card.lastFourDigits,
                totalAmount: total,
                bank: card.bankEnum,
                cardType: card.cardTypeEnum,
                paymentDay: card.paymentDay,
                daysUntilPayment: card.daysUntilPayment,
                paymentStatusText: card.paymentStatusText,
                isPaymentDueSoon: card.isPaymentDueSoon,
                isPaymentOverdue: card.isPaymentOverdue
            )
        }.sorted { $0.totalAmount > $1.totalAmount }
    }

    var selectedCategoryInfo: (name: String, total: String)? {
        guard let categoryId = selectedCategoryId,
              let cat = pieData.first(where: { $0.categoryId == categoryId }) else {
            return nil
        }
        return (cat.name, CurrencyUtils.format(cat.total))
    }

    // MARK: - Load Data (Local First)

    func loadSummary() async {
        isLoading = true
        errorMessage = nil

        // 1. Carregar do local IMEDIATAMENTE
        loadFromLocal()

        // UI já atualizada com dados locais, agora sincroniza
        isLoading = false

        // 2. Migrar cityName para transações existentes (apenas uma vez)
        if !UserDefaults.standard.bool(forKey: "cityName_migration_done") {
            Task {
                await transactionRepo.migrateCityNames()
                UserDefaults.standard.set(true, forKey: "cityName_migration_done")
                loadFromLocal() // Recarregar após migração
            }
        }

        // 3. Sincronizar em background se online
        if networkMonitor.isConnected {
            Task {
                await syncManager.syncAll()
                // Recarregar após sync
                loadFromLocal()
            }
        }

        updatePendingCount()
    }

    private func loadFromLocal() {
        transactions = transactionRepo.getTransactions(
            month: currentMonth.apiString,
            userId: userId
        )
        categories = categoryRepo.getCategories(userId: userId)
        fixedBills = fixedBillRepo.getFixedBills(userId: userId)

        // Carregar todas transações parceladas (independente do mês)
        installmentTransactions = transactionRepo.getInstallmentTransactions(userId: userId)

        // Seed default categories se necessário
        if categories.isEmpty {
            categoryRepo.seedDefaultCategoriesIfNeeded(userId: userId)
            categories = categoryRepo.getCategories(userId: userId)
        }
    }

    private func updatePendingCount() {
        Task {
            await syncManager.updatePendingCount()
        }
    }

    // MARK: - Navigation

    func goToPreviousMonth() async {
        currentMonth = currentMonth.addingMonths(-1)
        selectedCategoryId = nil
        await loadSummary()
    }

    func goToNextMonth() async {
        currentMonth = currentMonth.addingMonths(1)
        selectedCategoryId = nil
        await loadSummary()
    }

    func goToToday() async {
        currentMonth = .current
        selectedCategoryId = nil
        await loadSummary()
    }

    // MARK: - Category Selection

    func selectCategory(_ categoryId: String) {
        if selectedCategoryId == categoryId {
            selectedCategoryId = nil
        } else {
            selectedCategoryId = categoryId
        }
    }

    func clearFilter() {
        selectedCategoryId = nil
    }

    // MARK: - Delete Transaction (Local First)

    func deleteTransaction(_ transactionId: String) async {
        // Encontrar transação
        guard let transaction = transactions.first(where: { $0.id == transactionId }) else {
            return
        }

        // Deletar localmente (marca para sync)
        transactionRepo.deleteTransaction(transaction)

        // Atualizar UI imediatamente
        loadFromLocal()
        updatePendingCount()
    }

    // MARK: - Update Transaction (Local First)

    func updateTransaction(
        transactionId: String,
        description: String,
        amount: Decimal,
        date: Date,
        type: TransactionType,
        categoryId: String?,
        notes: String? = nil
    ) async {
        // Encontrar transação
        guard let transaction = transactions.first(where: { $0.id == transactionId }) else {
            return
        }

        // Atualizar localmente
        transactionRepo.updateTransaction(
            transaction,
            description: description,
            amount: amount,
            date: date,
            type: type,
            categoryId: categoryId,
            notes: notes
        )

        // Atualizar UI imediatamente
        loadFromLocal()
        updatePendingCount()
    }

    // MARK: - Update Installment (Local First)

    func updateInstallment(
        transactionId: String,
        description: String,
        amount: Decimal,
        categoryId: String?
    ) async {
        // Encontrar transação nos parcelamentos
        guard let transaction = installmentTransactions.first(where: { $0.id == transactionId }) else {
            return
        }

        // Atualizar localmente (mantém data, tipo e parcelas originais)
        transactionRepo.updateTransaction(
            transaction,
            description: description,
            amount: amount,
            date: transaction.date,
            type: transaction.type,
            categoryId: categoryId,
            notes: transaction.notes
        )

        // Atualizar UI imediatamente
        loadFromLocal()
        updatePendingCount()
    }

    // MARK: - Delete Installment

    func deleteInstallment(_ transactionId: String) async {
        // Encontrar transação nos parcelamentos
        guard let transaction = installmentTransactions.first(where: { $0.id == transactionId }) else {
            return
        }

        // Deletar localmente (marca para sync)
        transactionRepo.deleteTransaction(transaction)

        // Atualizar UI imediatamente
        loadFromLocal()
        updatePendingCount()
    }

    // MARK: - Manual Sync

    func forceSync() async {
        guard networkMonitor.isConnected else {
            errorMessage = "Sem conexão com internet"
            return
        }

        isLoading = true
        await syncManager.syncAll()
        loadFromLocal()
        isLoading = false
    }
}

    // MARK: - Transaction Item ViewModel

struct TransactionItemViewModel: Identifiable {
    let id: String
    let description: String
    let amount: Double
    let amountFormatted: String
    let date: Date
    let dateFormatted: String
    let type: TransactionType
    let categoryName: String?
    let categoryColor: Color
    let categoryIcon: String
    let needsUserReview: Bool
    var isPendingSync: Bool = false
    // Location
    var locationName: String?
    var latitude: Double?
    var longitude: Double?
    var cityName: String?  // Cidade extraída das coordenadas
    // Notes/Observation
    var notes: String?
    // Category ID for filtering
    var categoryId: String?
}

struct CreditCardSpending: Identifiable {
    var id: String { cardId }
    let cardId: String
    let cardName: String
    let lastFourDigits: String
    let totalAmount: Double
    let bank: Bank
    let cardType: CardType
    let paymentDay: Int
    let daysUntilPayment: Int
    let paymentStatusText: String
    let isPaymentDueSoon: Bool
    let isPaymentOverdue: Bool
}

struct InstallmentItemViewModel: Identifiable {
    let id: String
    let transactionId: String
    let description: String
    let installmentAmount: Double  // Valor da parcela (total / numParcelas)
    let totalAmount: Double        // Valor total da compra
    let currentInstallment: Int
    let totalInstallments: Int
    let creditCardId: String?
    let categoryName: String?
    let categoryColor: Color
    let categoryIcon: String
}
