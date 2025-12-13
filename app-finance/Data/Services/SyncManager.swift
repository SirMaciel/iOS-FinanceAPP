import Foundation
import SwiftData
import Combine
import UIKit

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
    private let creditCardsAPI = CreditCardsAPI.shared
    private let fixedBillsAPI = FixedBillsAPI.shared

    /// Timer para sync periódico (multi-device)
    private var periodicSyncTimer: Timer?

    /// Intervalo de sync periódico (30 segundos)
    private let periodicSyncInterval: TimeInterval = 30

    private init() {
        print("🔄 [Sync] SyncManager inicializado")
        setupNetworkObserver()
        setupAppLifecycleObserver()
        loadLastSyncDate()
        startPeriodicSync()
    }

    nonisolated func cleanup() {
        Task { @MainActor in
            periodicSyncTimer?.invalidate()
            periodicSyncTimer = nil
        }
    }

    // MARK: - Setup

    private func setupNetworkObserver() {
        // Sync imediato quando conectar (reduzido de 2s para 0.5s)
        NotificationCenter.default.publisher(for: .networkBecameAvailable)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                print("🔄 [Sync] Rede disponível - iniciando sync imediato")
                Task {
                    await self?.syncAll()
                }
            }
            .store(in: &cancellables)
    }

    private func setupAppLifecycleObserver() {
        // Sync quando app volta ao foreground
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                print("🔄 [Sync] App voltou ao foreground - sincronizando")
                Task {
                    await self?.syncAll()
                }
            }
            .store(in: &cancellables)

        // Sync quando app se torna ativo
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.startPeriodicSync()
            }
            .store(in: &cancellables)

        // Parar sync periódico quando app vai para background
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.stopPeriodicSync()
            }
            .store(in: &cancellables)
    }

    // MARK: - Periodic Sync (Multi-device)

    private func startPeriodicSync() {
        stopPeriodicSync()

        periodicSyncTimer = Timer.scheduledTimer(withTimeInterval: periodicSyncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard NetworkMonitor.shared.isConnected else { return }
                print("🔄 [Sync] Sync periódico (multi-device)")
                await self?.syncAll()
            }
        }
        print("🔄 [Sync] Sync periódico iniciado (cada \(Int(periodicSyncInterval))s)")
    }

    private func stopPeriodicSync() {
        periodicSyncTimer?.invalidate()
        periodicSyncTimer = nil
        print("🔄 [Sync] Sync periódico parado")
    }

    /// Força sync imediato (chamado manualmente ou por repositories)
    func syncNow() async {
        print("🔄 [Sync] Sync forçado solicitado")
        await syncAll()
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
        print("🔄 [Sync] syncAll() chamado")

        guard !isSyncing else {
            print("🔄 [Sync] Já sincronizando, ignorando...")
            return
        }

        let isConnected = NetworkMonitor.shared.isConnected
        print("🔄 [Sync] Network conectado: \(isConnected)")

        guard isConnected else {
            print("🔄 [Sync] Sem conexão, sync adiado")
            return
        }

        isSyncing = true
        syncError = nil
        print("🔄 [Sync] Iniciando sincronização completa...")

        var hasErrors = false

        // 1. Sync categorias primeiro (transações dependem delas)
        print("🔄 [Sync] 1/4 Sincronizando categorias...")
        do {
            try await syncCategories()
            print("✅ [Sync] Categorias sincronizadas")
        } catch {
            print("❌ [Sync] Erro em categorias: \(error)")
            hasErrors = true
        }

        // 2. Sync cartões de crédito (transações podem referenciar)
        print("🔄 [Sync] 2/4 Sincronizando cartões...")
        do {
            try await syncCreditCards()
            print("✅ [Sync] Cartões sincronizados")
        } catch {
            print("⚠️ [Sync] Cartões ignorados (endpoint não disponível)")
            // Não marcar como erro crítico - endpoint pode não existir ainda
        }

        // 3. Sync contas fixas
        print("🔄 [Sync] 3/4 Sincronizando contas fixas...")
        do {
            try await syncFixedBills()
            print("✅ [Sync] Contas fixas sincronizadas")
        } catch {
            print("❌ [Sync] Erro em contas fixas: \(error)")
            hasErrors = true
        }

        // 4. Sync transações (depende de categorias e cartões)
        print("🔄 [Sync] 4/4 Sincronizando transações...")
        do {
            try await syncTransactions()
            print("✅ [Sync] Transações sincronizadas")
        } catch {
            print("❌ [Sync] Erro em transações: \(error)")
            hasErrors = true
        }

        saveLastSyncDate()
        await updatePendingCount()

        if hasErrors {
            print("⚠️ [Sync] Sincronização concluída com alguns erros")
            syncError = "Alguns itens não foram sincronizados"
        } else {
            print("✅ [Sync] Sincronização completa!")
        }
        NotificationCenter.default.post(name: .syncCompleted, object: nil)

        isSyncing = false
        print("🔄 [Sync] Sync finalizado, isSyncing = false")
    }

    func updatePendingCount() async {
        let context = SwiftDataStack.shared.context

        let transactionDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.syncStatus != "synced" }
        )
        let categoryDescriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.syncStatus != "synced" }
        )
        let creditCardDescriptor = FetchDescriptor<CreditCard>(
            predicate: #Predicate { $0.syncStatus != "synced" }
        )
        let fixedBillDescriptor = FetchDescriptor<FixedBill>(
            predicate: #Predicate { $0.syncStatus != "synced" }
        )

        let transactionCount = (try? context.fetchCount(transactionDescriptor)) ?? 0
        let categoryCount = (try? context.fetchCount(categoryDescriptor)) ?? 0
        let creditCardCount = (try? context.fetchCount(creditCardDescriptor)) ?? 0
        let fixedBillCount = (try? context.fetchCount(fixedBillDescriptor)) ?? 0

        pendingChangesCount = transactionCount + categoryCount + creditCardCount + fixedBillCount
    }

    // MARK: - Categories Sync

    private func syncCategories() async throws {
        let context = SwiftDataStack.shared.context

        // 1. PULL FIRST - Baixar dados do servidor antes de enviar
        try await pullCategories(context: context)

        // 2. Corrigir categorias que existem localmente mas não foram sincronizadas
        try await fixUnsyncedCategories(context: context)

        // 3. Push local changes to server
        try await pushPendingCategories(context: context)

        try context.save()

        // Notificar que categorias foram atualizadas
        NotificationCenter.default.post(name: .categoriesUpdated, object: nil)
    }

    private func fixUnsyncedCategories(context: ModelContext) async throws {
        // Encontrar categorias marcadas como synced mas sem serverId
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.syncStatus == "synced" && $0.serverId == nil }
        )
        let unsyncedCategories = try context.fetch(descriptor)

        for category in unsyncedCategories {
            category.syncStatusEnum = .pending
            print("🔧 [Sync] Categoria '\(category.name)' marcada para sync (sem serverId)")
        }

        if !unsyncedCategories.isEmpty {
            try context.save()
        }
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
                        // Tentar criar no servidor
                        do {
                            let response = try await categoriesAPI.create(
                                name: category.name,
                                colorHex: category.colorHex,
                                iconName: category.iconName,
                                displayOrder: category.displayOrder
                            )
                            category.markAsSynced(serverId: response.id)
                            print("📤 [Sync] Categoria criada: \(category.name)")
                        } catch {
                            // Se falhou (possivelmente duplicata), tentar buscar no servidor
                            let serverCategories = try await categoriesAPI.getAll()
                            let normalizedName = category.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            if let existing = serverCategories.first(where: {
                                $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedName
                            }) {
                                category.markAsSynced(serverId: existing.id)
                                print("🔗 [Sync] Categoria vinculada ao servidor: \(category.name)")
                            } else {
                                throw error
                            }
                        }
                    } else {
                        // Atualizar no servidor
                        _ = try await categoriesAPI.update(
                            id: category.serverId!,
                            name: category.name,
                            colorHex: category.colorHex,
                            iconName: category.iconName,
                            isActive: category.isActive,
                            displayOrder: category.displayOrder
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

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for serverCat in serverCategories {
            // Parse server updatedAt
            let serverUpdatedAt: Date? = serverCat.updatedAt.flatMap { dateFormatter.date(from: $0) }

            if let existing = localByServerId[serverCat.id]?.first {
                // Comparar timestamps para resolver conflito
                if existing.syncStatusEnum == .synced {
                    // Sempre atualiza se synced (servidor é fonte da verdade)
                    existing.name = serverCat.name
                    existing.colorHex = serverCat.colorHex
                    existing.iconName = serverCat.iconName
                    existing.isActive = serverCat.isActive
                    if let serverOrder = serverCat.displayOrder {
                        existing.displayOrder = serverOrder
                    }
                    if let serverDate = serverUpdatedAt {
                        existing.updatedAt = serverDate
                    }
                } else if existing.syncStatusEnum == .pending {
                    // Local tem mudanças pendentes - comparar timestamps
                    if let serverDate = serverUpdatedAt, serverDate > existing.updatedAt {
                        // Servidor é mais novo - descartar mudanças locais
                        existing.name = serverCat.name
                        existing.colorHex = serverCat.colorHex
                        existing.iconName = serverCat.iconName
                        existing.isActive = serverCat.isActive
                        if let serverOrder = serverCat.displayOrder {
                            existing.displayOrder = serverOrder
                        }
                        existing.updatedAt = serverDate
                        existing.syncStatusEnum = .synced
                        print("⚠️ [Sync] Categoria atualizada pelo servidor (mais recente): \(serverCat.name)")
                    }
                    // Se local é mais novo, mantém pending para push
                }
            } else {
                // Verificar se existe categoria local com mesmo nome (merge com default)
                // Usar comparação case-insensitive e trim para maior robustez
                let serverNameNormalized = serverCat.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if let localDefault = localCategories.first(where: {
                    $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == serverNameNormalized && $0.serverId == nil
                }) {
                    // Fazer merge: atualizar a categoria local com serverId
                    localDefault.serverId = serverCat.id
                    localDefault.colorHex = serverCat.colorHex
                    localDefault.iconName = serverCat.iconName
                    localDefault.isActive = serverCat.isActive
                    localDefault.syncStatusEnum = .synced
                    if let serverOrder = serverCat.displayOrder {
                        localDefault.displayOrder = serverOrder
                    }
                    if let serverDate = serverUpdatedAt {
                        localDefault.updatedAt = serverDate
                    }
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
                        displayOrder: serverCat.displayOrder ?? (maxOrder + 1),
                        createdAt: Date(),
                        updatedAt: serverUpdatedAt ?? Date(),
                        syncStatus: .synced
                    )
                    context.insert(newCategory)
                    print("📥 [Sync] Categoria baixada: \(serverCat.name)")
                }
            }
        }

        // Deletar categorias locais que foram removidas do servidor
        let serverIds = Set(serverCategories.map { $0.id })
        let localWithServerId = localCategories.filter { $0.serverId != nil && $0.syncStatusEnum == .synced }

        for localCat in localWithServerId {
            if let serverId = localCat.serverId, !serverIds.contains(serverId) {
                context.delete(localCat)
                print("🗑️ [Sync] Categoria removida (deletada no servidor): \(localCat.name)")
            }
        }
    }

    // MARK: - Credit Cards Sync

    private func syncCreditCards() async throws {
        let context = SwiftDataStack.shared.context

        // 1. PULL FIRST - Baixar dados do servidor antes de enviar
        try await pullCreditCards(context: context)

        // 2. Corrigir cartões que existem localmente mas não foram sincronizados
        try await fixUnsyncedCreditCards(context: context)

        // 3. Push local changes to server
        try await pushPendingCreditCards(context: context)

        try context.save()

        // Notificar que cartões foram atualizados
        NotificationCenter.default.post(name: .creditCardsUpdated, object: nil)
    }

    private func fixUnsyncedCreditCards(context: ModelContext) async throws {
        // Encontrar cartões marcados como synced mas sem serverId
        let descriptor = FetchDescriptor<CreditCard>(
            predicate: #Predicate { $0.syncStatus == "synced" && $0.serverId == nil }
        )
        let unsyncedCards = try context.fetch(descriptor)

        for card in unsyncedCards {
            card.syncStatusEnum = .pending
            print("🔧 [Sync] Cartão '\(card.cardName)' marcado para sync (sem serverId)")
        }

        if !unsyncedCards.isEmpty {
            try context.save()
        }
    }

    private func pushPendingCreditCards(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<CreditCard>(
            predicate: #Predicate { $0.syncStatus != "synced" }
        )
        let pendingCards = try context.fetch(descriptor)

        for card in pendingCards {
            do {
                switch card.syncStatusEnum {
                case .pending:
                    if card.serverId == nil {
                        // Criar no servidor
                        let response = try await creditCardsAPI.create(from: card)
                        card.markAsSynced(serverId: response.id)
                        print("📤 [Sync] Cartão criado: \(card.cardName)")
                    } else {
                        // Atualizar no servidor
                        _ = try await creditCardsAPI.update(from: card)
                        card.syncStatusEnum = .synced
                        card.lastSyncAttempt = Date()
                        print("📤 [Sync] Cartão atualizado: \(card.cardName)")
                    }

                case .pendingDelete:
                    if let serverId = card.serverId {
                        try await creditCardsAPI.delete(id: serverId)
                        print("📤 [Sync] Cartão deletado: \(card.cardName)")
                    }
                    context.delete(card)

                case .synced:
                    break
                }
            } catch {
                card.syncError = error.localizedDescription
                card.lastSyncAttempt = Date()
                print("❌ [Sync] Erro cartão \(card.cardName): \(error)")
            }
        }
    }

    private func pullCreditCards(context: ModelContext) async throws {
        let serverCards = try await creditCardsAPI.getAll()

        let descriptor = FetchDescriptor<CreditCard>()
        let localCards = try context.fetch(descriptor)
        let localByServerId = Dictionary(grouping: localCards.filter { $0.serverId != nil }, by: { $0.serverId! })

        for serverCard in serverCards {
            if let existing = localByServerId[serverCard.id]?.first {
                // Atualizar se local não tiver mudanças pendentes
                if existing.syncStatusEnum == .synced {
                    existing.cardName = serverCard.cardName
                    existing.holderName = serverCard.holderName
                    existing.lastFourDigits = serverCard.lastFourDigits
                    existing.brand = serverCard.brand
                    existing.cardType = serverCard.cardType
                    existing.bank = serverCard.bank
                    existing.paymentDay = serverCard.paymentDay
                    existing.closingDay = serverCard.closingDay
                    existing.limitAmount = Decimal(serverCard.limitAmount)
                    existing.isActive = serverCard.isActive
                    existing.displayOrder = serverCard.displayOrder
                }
            } else {
                // Verificar duplicatas por nome
                let isDuplicate = localCards.contains {
                    $0.cardName == serverCard.cardName && $0.serverId == nil
                }

                if !isDuplicate {
                    // Criar localmente
                    let newCard = CreditCard(
                        serverId: serverCard.id,
                        userId: serverCard.userId,
                        cardName: serverCard.cardName,
                        holderName: serverCard.holderName,
                        lastFourDigits: serverCard.lastFourDigits,
                        brand: CardBrand(rawValue: serverCard.brand) ?? .other,
                        cardType: CardType(rawValue: serverCard.cardType) ?? .standard,
                        bank: Bank(rawValue: serverCard.bank) ?? .other,
                        paymentDay: serverCard.paymentDay,
                        closingDay: serverCard.closingDay,
                        limitAmount: Decimal(serverCard.limitAmount),
                        isActive: serverCard.isActive,
                        displayOrder: serverCard.displayOrder,
                        syncStatus: .synced
                    )
                    context.insert(newCard)
                    print("📥 [Sync] Cartão baixado: \(serverCard.cardName)")
                }
            }
        }

        // Deletar cartões locais que foram removidos do servidor
        let serverIds = Set(serverCards.map { $0.id })
        let localWithServerId = localCards.filter { $0.serverId != nil && $0.syncStatusEnum == .synced }

        for localCard in localWithServerId {
            if let serverId = localCard.serverId, !serverIds.contains(serverId) {
                context.delete(localCard)
                print("🗑️ [Sync] Cartão removido (deletado no servidor): \(localCard.cardName)")
            }
        }
    }

    // MARK: - Fixed Bills Sync

    private func syncFixedBills() async throws {
        let context = SwiftDataStack.shared.context

        // 1. PULL FIRST - Baixar dados do servidor antes de enviar
        try await pullFixedBills(context: context)

        // 2. Push local changes to server
        try await pushPendingFixedBills(context: context)

        try context.save()

        // Notificar que contas fixas foram atualizadas
        NotificationCenter.default.post(name: .fixedBillsUpdated, object: nil)
    }

    private func pushPendingFixedBills(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<FixedBill>(
            predicate: #Predicate { $0.syncStatus != "synced" }
        )
        let pendingBills = try context.fetch(descriptor)

        for bill in pendingBills {
            do {
                switch bill.syncStatusEnum {
                case .pending:
                    if bill.serverId == nil {
                        // Criar no servidor
                        let response = try await fixedBillsAPI.create(from: bill)
                        bill.markAsSynced(serverId: response.id)
                        print("📤 [Sync] Conta fixa criada: \(bill.name)")
                    } else {
                        // Atualizar no servidor
                        _ = try await fixedBillsAPI.update(from: bill)
                        bill.syncStatusEnum = .synced
                        bill.lastSyncAttempt = Date()
                        print("📤 [Sync] Conta fixa atualizada: \(bill.name)")
                    }

                case .pendingDelete:
                    if let serverId = bill.serverId {
                        try await fixedBillsAPI.delete(id: serverId)
                        print("📤 [Sync] Conta fixa deletada: \(bill.name)")
                    }
                    context.delete(bill)

                case .synced:
                    break
                }
            } catch {
                bill.syncError = error.localizedDescription
                bill.lastSyncAttempt = Date()
                print("❌ [Sync] Erro conta fixa \(bill.name): \(error)")
            }
        }
    }

    private func pullFixedBills(context: ModelContext) async throws {
        let serverBills = try await fixedBillsAPI.getAll()

        let descriptor = FetchDescriptor<FixedBill>()
        let localBills = try context.fetch(descriptor)
        let localByServerId = Dictionary(grouping: localBills.filter { $0.serverId != nil }, by: { $0.serverId! })

        for serverBill in serverBills {
            if let existing = localByServerId[serverBill.id]?.first {
                // Atualizar se local não tiver mudanças pendentes
                if existing.syncStatusEnum == .synced {
                    existing.name = serverBill.name
                    existing.amount = Decimal(serverBill.amount)
                    existing.dueDay = serverBill.dueDay
                    existing.category = mapFixedBillCategory(serverBill.category)
                    existing.isActive = serverBill.isActive
                    existing.notes = serverBill.notes
                    existing.customCategoryName = serverBill.customCategoryName
                    existing.customCategoryIcon = serverBill.customCategoryIcon
                    existing.customCategoryColorHex = serverBill.customCategoryColorHex
                    existing.totalInstallments = serverBill.totalInstallments
                    existing.paidInstallments = serverBill.paidInstallments
                }
            } else {
                // Verificar duplicatas
                let isDuplicate = localBills.contains {
                    $0.name == serverBill.name && $0.serverId == nil
                }

                if !isDuplicate {
                    // Criar localmente
                    let newBill = FixedBill(
                        serverId: serverBill.id,
                        userId: serverBill.userId,
                        name: serverBill.name,
                        amount: Decimal(serverBill.amount),
                        dueDay: serverBill.dueDay,
                        category: mapFixedBillCategory(serverBill.category),
                        isActive: serverBill.isActive,
                        notes: serverBill.notes,
                        syncStatus: .synced,
                        customCategoryName: serverBill.customCategoryName,
                        customCategoryIcon: serverBill.customCategoryIcon,
                        customCategoryColorHex: serverBill.customCategoryColorHex,
                        totalInstallments: serverBill.totalInstallments,
                        paidInstallments: serverBill.paidInstallments
                    )
                    context.insert(newBill)
                    print("📥 [Sync] Conta fixa baixada: \(serverBill.name)")
                }
            }
        }

        // Deletar contas fixas locais que foram removidas do servidor
        let serverIds = Set(serverBills.map { $0.id })
        let localWithServerId = localBills.filter { $0.serverId != nil && $0.syncStatusEnum == .synced }

        for localBill in localWithServerId {
            if let serverId = localBill.serverId, !serverIds.contains(serverId) {
                context.delete(localBill)
                print("🗑️ [Sync] Conta fixa removida (deletada no servidor): \(localBill.name)")
            }
        }
    }

    private func mapFixedBillCategory(_ serverCategory: String) -> FixedBillCategory {
        let normalized = serverCategory.lowercased()
        switch normalized {
        case "housing", "moradia": return .housing
        case "utilities", "utilidades": return .utilities
        case "health", "saúde", "saude": return .health
        case "education", "educação", "educacao": return .education
        case "transport", "transporte": return .transport
        case "entertainment", "entretenimento": return .entertainment
        case "subscription", "assinatura": return .subscription
        case "insurance", "seguro": return .insurance
        case "financing", "financiamento": return .financing
        case "loan", "empréstimo", "emprestimo": return .loan
        case "custom", "personalizada": return .custom
        default: return .other
        }
    }

    // MARK: - Transactions Sync

    private func syncTransactions() async throws {
        let context = SwiftDataStack.shared.context

        // 1. PULL FIRST - Baixar dados do servidor antes de enviar
        try await pullTransactions(context: context)

        // 2. Push local changes
        try await pushPendingTransactions(context: context)

        try context.save()

        // Notificar que transações foram atualizadas
        NotificationCenter.default.post(name: .transactionsUpdated, object: nil)
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
                        // Resolver categoryId para serverId (APENAS se categoria foi sincronizada)
                        var serverCategoryId: String? = nil
                        if let localCatId = transaction.categoryId {
                            let catDescriptor = FetchDescriptor<Category>(
                                predicate: #Predicate { $0.id == localCatId || $0.serverId == localCatId }
                            )
                            if let category = try? context.fetch(catDescriptor).first {
                                // Só usar serverId se existir, nunca enviar ID local
                                serverCategoryId = category.serverId
                            }
                        }

                        // Resolver creditCardId para serverId (APENAS se cartão foi sincronizado)
                        var serverCreditCardId: String? = nil
                        if let localCardId = transaction.creditCardId {
                            let cardDescriptor = FetchDescriptor<CreditCard>(
                                predicate: #Predicate { $0.id == localCardId || $0.serverId == localCardId }
                            )
                            if let card = try? context.fetch(cardDescriptor).first {
                                // Só usar serverId se existir, nunca enviar ID local
                                serverCreditCardId = card.serverId
                            }
                        }

                        // Criar no servidor com todos os campos
                        let response = try await transactionsAPI.create(
                            type: transaction.type,
                            amount: transaction.amount,
                            date: transaction.date,
                            description: transaction.desc,
                            categoryId: serverCategoryId,
                            creditCardId: serverCreditCardId,
                            locationName: transaction.locationName,
                            latitude: transaction.latitude,
                            longitude: transaction.longitude,
                            cityName: transaction.cityName,
                            installments: transaction.installments,
                            startingInstallment: transaction.startingInstallment,
                            notes: transaction.notes,
                            paymentMethod: transaction.paymentMethod
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
                        // Atualizar todos os campos no servidor
                        var serverCategoryId: String? = nil
                        if let localCatId = transaction.categoryId {
                            let catDescriptor = FetchDescriptor<Category>(
                                predicate: #Predicate { $0.id == localCatId }
                            )
                            if let category = try? context.fetch(catDescriptor).first {
                                // Só usar serverId se existir, nunca enviar ID local
                                serverCategoryId = category.serverId
                            }
                        }

                        var serverCreditCardId: String? = nil
                        if let localCardId = transaction.creditCardId {
                            let cardDescriptor = FetchDescriptor<CreditCard>(
                                predicate: #Predicate { $0.id == localCardId }
                            )
                            if let card = try? context.fetch(cardDescriptor).first {
                                // Só usar serverId se existir, nunca enviar ID local
                                serverCreditCardId = card.serverId
                            }
                        }

                        let dateString = ISO8601DateFormatter().string(from: transaction.date).prefix(10)
                        _ = try await transactionsAPI.update(
                            id: transaction.serverId!,
                            type: transaction.type.rawValue,
                            amount: NSDecimalNumber(decimal: transaction.amount).doubleValue,
                            date: String(dateString),
                            description: transaction.desc,
                            categoryId: serverCategoryId,
                            creditCardId: serverCreditCardId,
                            locationName: transaction.locationName,
                            latitude: transaction.latitude,
                            longitude: transaction.longitude,
                            cityName: transaction.cityName,
                            installments: transaction.installments,
                            startingInstallment: transaction.startingInstallment,
                            notes: transaction.notes,
                            paymentMethod: transaction.paymentMethod
                        )
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
        // Buscar todas as transações
        let serverTransactions = try await transactionsAPI.getAll()

        let descriptor = FetchDescriptor<Transaction>()
        let localTransactions = try context.fetch(descriptor)
        let localByServerId = Dictionary(grouping: localTransactions.filter { $0.serverId != nil }, by: { $0.serverId! })

        // Buscar todas as categorias e cartões para mapping
        let allCatsDescriptor = FetchDescriptor<Category>()
        let allCategories = try context.fetch(allCatsDescriptor)
        let catByServerId = Dictionary(grouping: allCategories.filter { $0.serverId != nil }, by: { $0.serverId! })

        let allCardsDescriptor = FetchDescriptor<CreditCard>()
        let allCards = try context.fetch(allCardsDescriptor)
        let cardByServerId = Dictionary(grouping: allCards.filter { $0.serverId != nil }, by: { $0.serverId! })

        for serverTx in serverTransactions {
            if let existing = localByServerId[serverTx.id]?.first {
                // Atualizar se local não tiver mudanças pendentes
                if existing.syncStatusEnum == .synced {
                    // Atualizar campos principais
                    existing.desc = serverTx.description
                    existing.amount = Decimal(serverTx.amount)

                    // Atualizar data
                    let dateFormatter = ISO8601DateFormatter()
                    dateFormatter.formatOptions = [.withFullDate]
                    if let serverDate = dateFormatter.date(from: serverTx.date) {
                        existing.date = serverDate
                    }

                    // Atualizar tipo
                    existing.type = TransactionType(rawValue: serverTx.type) ?? .expense

                    // Mapear categoryId do servidor para local
                    if let serverCatId = serverTx.categoryId,
                       let localCat = catByServerId[serverCatId]?.first {
                        existing.categoryId = localCat.id
                    } else {
                        existing.categoryId = serverTx.categoryId
                    }

                    // Mapear creditCardId do servidor para local
                    if let serverCardId = serverTx.creditCardId,
                       let localCard = cardByServerId[serverCardId]?.first {
                        existing.creditCardId = localCard.id
                    } else {
                        existing.creditCardId = serverTx.creditCardId
                    }

                    existing.aiConfidence = serverTx.aiConfidence
                    existing.aiJustification = serverTx.aiJustification
                    existing.needsUserReview = serverTx.needsUserReview ?? false
                    existing.locationName = serverTx.locationName
                    existing.latitude = serverTx.latitude
                    existing.longitude = serverTx.longitude
                    existing.cityName = serverTx.cityName
                    existing.installments = serverTx.installments
                    existing.startingInstallment = serverTx.startingInstallment
                    existing.notes = serverTx.notes
                    existing.paymentMethod = serverTx.paymentMethod

                    print("🔄 [Sync] Transação atualizada do servidor: \(serverTx.description)")
                }
            } else {
                // Verificar duplicatas
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

                    // Mapear categoryId do servidor para local
                    var localCategoryId: String? = serverTx.categoryId
                    if let serverCatId = serverTx.categoryId,
                       let localCat = catByServerId[serverCatId]?.first {
                        localCategoryId = localCat.id
                    }

                    // Mapear creditCardId do servidor para local
                    var localCreditCardId: String? = serverTx.creditCardId
                    if let serverCardId = serverTx.creditCardId,
                       let localCard = cardByServerId[serverCardId]?.first {
                        localCreditCardId = localCard.id
                    }

                    let newTransaction = Transaction(
                        serverId: serverTx.id,
                        userId: serverTx.userId ?? "",
                        categoryId: localCategoryId,
                        creditCardId: localCreditCardId,
                        type: TransactionType(rawValue: serverTx.type) ?? .expense,
                        amount: Decimal(serverTx.amount),
                        date: date,
                        description: serverTx.description,
                        aiConfidence: serverTx.aiConfidence,
                        aiJustification: serverTx.aiJustification,
                        needsUserReview: serverTx.needsUserReview ?? false,
                        syncStatus: .synced,
                        locationName: serverTx.locationName,
                        latitude: serverTx.latitude,
                        longitude: serverTx.longitude,
                        cityName: serverTx.cityName,
                        installments: serverTx.installments,
                        startingInstallment: serverTx.startingInstallment,
                        notes: serverTx.notes,
                        paymentMethod: serverTx.paymentMethod
                    )
                    context.insert(newTransaction)
                    print("📥 [Sync] Transação baixada: \(serverTx.description)")
                }
            }
        }

        // Deletar transações locais que foram removidas do servidor
        let serverIds = Set(serverTransactions.map { $0.id })
        let localWithServerId = localTransactions.filter { $0.serverId != nil && $0.syncStatusEnum == .synced }

        for localTx in localWithServerId {
            if let serverId = localTx.serverId, !serverIds.contains(serverId) {
                context.delete(localTx)
                print("🗑️ [Sync] Transação removida (deletada no servidor): \(localTx.desc)")
            }
        }
    }
}
