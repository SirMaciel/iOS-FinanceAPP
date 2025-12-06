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

    private let transactionRepo = TransactionRepository.shared
    private let categoryRepo = CategoryRepository.shared
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
        transactions
            .filter { $0.type == .expense && $0.syncStatusEnum != .pendingDelete }
            .reduce(0) { $0 + $1.amountDouble }
    }

    var balance: Double {
        totalIncome - totalExpense
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
                isPendingSync: tx.isPendingSync
            )
        }
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
}
