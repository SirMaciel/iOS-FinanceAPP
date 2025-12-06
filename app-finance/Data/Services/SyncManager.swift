import Foundation
import SwiftData
import Combine

// MARK: - Sync Manager

@MainActor
final class SyncManager: ObservableObject {
    static let shared = SyncManager()

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var pendingChangesCount = 0
    @Published private(set) var syncError: String?

    private var cancellables = Set<AnyCancellable>()
    private let transactionsAPI = TransactionsAPI.shared
    private let categoriesAPI = CategoriesAPI.shared

    private init() {
        setupNetworkObserver()
        loadLastSyncDate()
    }

    // MARK: - Setup

    private func setupNetworkObserver() {
        NotificationCenter.default.publisher(for: .networkBecameAvailable)
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.syncAll()
                }
            }
            .store(in: &cancellables)
    }

    private func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
    }

    private func saveLastSyncDate() {
        lastSyncDate = Date()
        UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
    }

    // MARK: - Public Methods

    func syncAll() async {
        guard !isSyncing else {
            print("🔄 [Sync] Já sincronizando...")
            return
        }

        guard NetworkMonitor.shared.isConnected else {
            print("🔄 [Sync] Sem conexão, sync adiado")
            return
        }

        isSyncing = true
        syncError = nil
        print("🔄 [Sync] Iniciando sincronização...")

        do {
            // 1. Sync categorias primeiro (transações dependem delas)
            try await syncCategories()

            // 2. Sync transações
            try await syncTransactions()

            saveLastSyncDate()
            await updatePendingCount()

            print("✅ [Sync] Sincronização completa!")
            NotificationCenter.default.post(name: .syncCompleted, object: nil)
        } catch {
            print("❌ [Sync] Erro: \(error.localizedDescription)")
            syncError = error.localizedDescription
            NotificationCenter.default.post(name: .syncFailed, object: error)
        }

        isSyncing = false
    }

    func updatePendingCount() async {
        let context = SwiftDataStack.shared.context

        let transactionDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.syncStatus != "synced" }
        )
        let categoryDescriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.syncStatus != "synced" }
        )

        let transactionCount = (try? context.fetchCount(transactionDescriptor)) ?? 0
        let categoryCount = (try? context.fetchCount(categoryDescriptor)) ?? 0

        pendingChangesCount = transactionCount + categoryCount
    }

    // MARK: - Categories Sync

    private func syncCategories() async throws {
        let context = SwiftDataStack.shared.context

        // 1. Push local changes to server
        try await pushPendingCategories(context: context)

        // 2. Pull server changes
        try await pullCategories(context: context)

        try context.save()
    }

    private func pushPendingCategories(context: ModelContext) async throws {
        // Buscar categorias pendentes
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.syncStatus != "synced" }
        )
        let pendingCategories = try context.fetch(descriptor)

        for category in pendingCategories {
            do {
                switch category.syncStatusEnum {
                case .pending:
                    if category.serverId == nil {
                        // Criar no servidor
                        let response = try await categoriesAPI.create(
                            name: category.name,
                            colorHex: category.colorHex,
                            iconName: category.iconName
                        )
                        category.markAsSynced(serverId: response.id)
                        print("📤 [Sync] Categoria criada: \(category.name)")
                    } else {
                        // Atualizar no servidor
                        _ = try await categoriesAPI.update(
                            id: category.serverId!,
                            name: category.name,
                            colorHex: category.colorHex,
                            iconName: category.iconName,
                            isActive: category.isActive
                        )
                        category.syncStatusEnum = .synced
                        category.lastSyncAttempt = Date()
                        print("📤 [Sync] Categoria atualizada: \(category.name)")
                    }

                case .pendingDelete:
                    if let serverId = category.serverId {
                        try await categoriesAPI.delete(id: serverId)
                        print("📤 [Sync] Categoria deletada: \(category.name)")
                    }
                    context.delete(category)

                case .synced:
                    break
                }
            } catch {
                category.syncError = error.localizedDescription
                category.lastSyncAttempt = Date()
                print("❌ [Sync] Erro categoria \(category.name): \(error)")
            }
        }
    }

    private func pullCategories(context: ModelContext) async throws {
        let serverCategories = try await categoriesAPI.getAll()

        // Buscar categorias locais
        let descriptor = FetchDescriptor<Category>()
        let localCategories = try context.fetch(descriptor)
        let localByServerId = Dictionary(grouping: localCategories.filter { $0.serverId != nil }, by: { $0.serverId! })

        for serverCat in serverCategories {
            if let existing = localByServerId[serverCat.id]?.first {
                // Atualizar se local não tiver mudanças pendentes
                // Preservar displayOrder (é propriedade local apenas)
                if existing.syncStatusEnum == .synced {
                    existing.name = serverCat.name
                    existing.colorHex = serverCat.colorHex
                    existing.iconName = serverCat.iconName
                    existing.isActive = serverCat.isActive
                    // displayOrder não é alterado - é local only
                }
            } else {
                // Verificar se existe categoria local com mesmo nome (merge com default)
                if let localDefault = localCategories.first(where: { $0.name == serverCat.name && $0.serverId == nil }) {
                    // Fazer merge: atualizar a categoria local com serverId
                    localDefault.serverId = serverCat.id
                    localDefault.colorHex = serverCat.colorHex
                    localDefault.iconName = serverCat.iconName
                    localDefault.isActive = serverCat.isActive
                    localDefault.syncStatusEnum = .synced
                    // Preservar displayOrder local
                    print("🔗 [Sync] Categoria mesclada: \(serverCat.name)")
                } else {
                    // Criar nova categoria localmente
                    let maxOrder = localCategories.map { $0.displayOrder }.max() ?? -1
                    let newCategory = Category(
                        serverId: serverCat.id,
                        userId: serverCat.userId,
                        name: serverCat.name,
                        colorHex: serverCat.colorHex,
                        iconName: serverCat.iconName,
                        isActive: serverCat.isActive,
                        displayOrder: maxOrder + 1,  // Adicionar no final da lista
                        syncStatus: .synced
                    )
                    context.insert(newCategory)
                    print("📥 [Sync] Categoria baixada: \(serverCat.name)")
                }
            }
        }
    }

    // MARK: - Transactions Sync

    private func syncTransactions() async throws {
        let context = SwiftDataStack.shared.context

        // 1. Push local changes
        try await pushPendingTransactions(context: context)

        // 2. Pull server changes (por mês atual)
        try await pullTransactions(context: context)

        try context.save()
    }

    private func pushPendingTransactions(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.syncStatus != "synced" }
        )
        let pendingTransactions = try context.fetch(descriptor)

        for transaction in pendingTransactions {
            do {
                switch transaction.syncStatusEnum {
                case .pending:
                    if transaction.serverId == nil {
                        // Criar no servidor
                        // Resolver categoryId para serverId se necessário
                        var serverCategoryId: String? = nil
                        if let localCatId = transaction.categoryId {
                            let catDescriptor = FetchDescriptor<Category>(
                                predicate: #Predicate { $0.id == localCatId || $0.serverId == localCatId }
                            )
                            if let category = try? context.fetch(catDescriptor).first {
                                serverCategoryId = category.serverId ?? category.id
                            }
                        }

                        let response = try await transactionsAPI.create(
                            type: transaction.type,
                            amount: transaction.amount,
                            date: transaction.date,
                            description: transaction.desc,
                            categoryId: serverCategoryId
                        )
                        transaction.markAsSynced(serverId: response.id)

                        // Atualizar dados da IA se retornados
                        if let aiConf = response.aiConfidence {
                            transaction.aiConfidence = aiConf
                        }
                        if let aiJust = response.aiJustification {
                            transaction.aiJustification = aiJust
                        }
                        if let needsReview = response.needsUserReview {
                            transaction.needsUserReview = needsReview
                        }
                        if let responseCat = response.category {
                            // Encontrar categoria local pelo serverId
                            let allCatsDescriptor = FetchDescriptor<Category>()
                            if let allCats = try? context.fetch(allCatsDescriptor),
                               let localCat = allCats.first(where: { $0.serverId == responseCat.id }) {
                                transaction.categoryId = localCat.id
                            }
                        }

                        print("📤 [Sync] Transação criada: \(transaction.desc)")
                    } else {
                        // Atualizar categoria no servidor
                        if let categoryId = transaction.categoryId {
                            let catDescriptor = FetchDescriptor<Category>(
                                predicate: #Predicate { $0.id == categoryId }
                            )
                            if let category = try? context.fetch(catDescriptor).first,
                               let serverCatId = category.serverId {
                                _ = try await transactionsAPI.updateCategory(
                                    transactionId: transaction.serverId!,
                                    categoryId: serverCatId
                                )
                            }
                        }
                        transaction.syncStatusEnum = .synced
                        transaction.lastSyncAttempt = Date()
                        print("📤 [Sync] Transação atualizada: \(transaction.desc)")
                    }

                case .pendingDelete:
                    if let serverId = transaction.serverId {
                        try await transactionsAPI.delete(transactionId: serverId)
                        print("📤 [Sync] Transação deletada: \(transaction.desc)")
                    }
                    context.delete(transaction)

                case .synced:
                    break
                }
            } catch {
                transaction.syncError = error.localizedDescription
                transaction.lastSyncAttempt = Date()
                print("❌ [Sync] Erro transação \(transaction.desc): \(error)")
            }
        }
    }

    private func pullTransactions(context: ModelContext) async throws {
        // Buscar transações do mês atual
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let currentMonth = formatter.string(from: Date())

        let serverTransactions = try await transactionsAPI.getByMonth(month: currentMonth)

        // Buscar transações locais sincronizadas
        let descriptor = FetchDescriptor<Transaction>()
        let localTransactions = try context.fetch(descriptor)
        let localByServerId = Dictionary(grouping: localTransactions.filter { $0.serverId != nil }, by: { $0.serverId! })

        for serverTx in serverTransactions {
            if let existing = localByServerId[serverTx.id]?.first {
                // Atualizar se local não tiver mudanças pendentes
                if existing.syncStatusEnum == .synced {
                    existing.categoryId = serverTx.categoryId
                    existing.aiConfidence = serverTx.aiConfidence
                    existing.aiJustification = serverTx.aiJustification
                    existing.needsUserReview = serverTx.needsUserReview ?? false
                }
            } else {
                // Verificar se não existe localmente (evitar duplicatas)
                let isDuplicate = localTransactions.contains {
                    $0.desc == serverTx.description &&
                    $0.amountDouble == serverTx.amount &&
                    $0.serverId == nil
                }

                if !isDuplicate {
                    // Criar localmente
                    let dateFormatter = ISO8601DateFormatter()
                    dateFormatter.formatOptions = [.withFullDate]
                    let date = dateFormatter.date(from: serverTx.date) ?? Date()

                    let newTransaction = Transaction(
                        serverId: serverTx.id,
                        userId: serverTx.userId ?? "",
                        categoryId: serverTx.categoryId,
                        type: TransactionType(rawValue: serverTx.type) ?? .expense,
                        amount: Decimal(serverTx.amount),
                        date: date,
                        description: serverTx.description,
                        aiConfidence: serverTx.aiConfidence,
                        aiJustification: serverTx.aiJustification,
                        needsUserReview: serverTx.needsUserReview ?? false,
                        syncStatus: .synced
                    )
                    context.insert(newTransaction)
                    print("📥 [Sync] Transação baixada: \(serverTx.description)")
                }
            }
        }
    }
}
