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
        let transactionsTotal = transactions
            .filter { $0.type == .expense && $0.syncStatusEnum != .pendingDelete }
            .reduce(0) { $0 + $1.amountDouble }
        return transactionsTotal + totalFixedBills
    }

    var totalFixedBills: Double {
        activeFixedBillsForMonth.reduce(0) { $0 + $1.amountDouble }
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

    var pieData: [PieCategoryData] {
        let expenseTransactions = transactions.filter {
            $0.type == .expense && $0.syncStatusEnum != .pendingDelete
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

    var filteredTransactions: [TransactionItemViewModel] {
        let filtered = transactions
            .filter { $0.syncStatusEnum != .pendingDelete }
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
                needsUserReview: tx.needsUserReview,
                isPendingSync: tx.isPendingSync,
                locationName: tx.locationName,
                latitude: tx.latitude,
                longitude: tx.longitude
            )
        }
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

        // 2. Sincronizar em background se online
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
    let needsUserReview: Bool
    var isPendingSync: Bool = false
    // Location
    var locationName: String?
    var latitude: Double?
    var longitude: Double?
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
