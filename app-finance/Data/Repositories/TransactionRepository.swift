import Foundation
import SwiftData
import Combine
import CoreLocation
import MapKit

// MARK: - Transaction Repository (Local-First)

@MainActor
final class TransactionRepository: ObservableObject {
    static let shared = TransactionRepository()

    @Published private(set) var isLoading = false

    private let context: ModelContext
    private let syncManager = SyncManager.shared

    private init() {
        self.context = SwiftDataStack.shared.context
    }

    // MARK: - Read Operations (Local First)

    /// Busca transações do mês - SEMPRE do local primeiro
    func getTransactions(month: String, userId: String) -> [Transaction] {
        // Parse month string (yyyy-MM)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"

        guard let startDate = formatter.date(from: month) else {
            return []
        }

        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        guard let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) else {
            return []
        }

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate {
                $0.userId == userId &&
                $0.date >= startDate &&
                $0.date < endDate &&
                $0.syncStatus != "pendingDelete"
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ [Repo] Erro ao buscar transações: \(error)")
            return []
        }
    }

    /// Busca transações e tenta sincronizar em background
    func getTransactionsWithSync(month: String, userId: String) async -> [Transaction] {
        // 1. Retornar dados locais imediatamente
        let localData = getTransactions(month: month, userId: userId)

        // 2. Sincronizar em background se conectado
        if NetworkMonitor.shared.isConnected {
            Task {
                await syncManager.syncAll()
            }
        }

        return localData
    }

    // MARK: - Write Operations (Local First)

    /// Criar transação - salva local primeiro, sync depois
    func createTransaction(
        userId: String,
        type: TransactionType,
        amount: Decimal,
        date: Date,
        description: String,
        categoryId: String? = nil,
        creditCardId: String? = nil,
        locationName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        cityName: String? = nil,
        installments: Int? = nil,
        startingInstallment: Int? = nil,
        notes: String? = nil
    ) -> Transaction {
        let transaction = Transaction(
            userId: userId,
            categoryId: categoryId,
            creditCardId: creditCardId,
            type: type,
            amount: amount,
            date: date,
            description: description,
            syncStatus: .pending,
            locationName: locationName,
            latitude: latitude,
            longitude: longitude,
            cityName: cityName,
            installments: installments,
            startingInstallment: startingInstallment,
            notes: notes
        )

        context.insert(transaction)

        do {
            try context.save()
            print("💾 [Repo] Transação salva localmente: \(description)")

            // Tentar sync em background
            Task {
                await syncManager.syncAll()
            }
        } catch {
            print("❌ [Repo] Erro ao salvar transação: \(error)")
        }

        return transaction
    }

    /// Atualizar categoria da transação
    func updateCategory(transaction: Transaction, categoryId: String) {
        transaction.categoryId = categoryId
        transaction.markAsModified()

        do {
            try context.save()
            print("💾 [Repo] Categoria atualizada localmente")

            Task {
                await syncManager.syncAll()
            }
        } catch {
            print("❌ [Repo] Erro ao atualizar categoria: \(error)")
        }
    }

    /// Atualizar transação completa
    func updateTransaction(
        _ transaction: Transaction,
        description: String? = nil,
        amount: Decimal? = nil,
        date: Date? = nil,
        type: TransactionType? = nil,
        categoryId: String? = nil,
        locationName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        cityName: String? = nil,
        notes: String? = nil
    ) {
        if let description = description { transaction.desc = description }
        if let amount = amount { transaction.amount = amount }
        if let date = date { transaction.date = date }
        if let type = type { transaction.type = type }
        if let categoryId = categoryId { transaction.categoryId = categoryId }
        if locationName != nil { transaction.locationName = locationName }
        if latitude != nil { transaction.latitude = latitude }
        if longitude != nil { transaction.longitude = longitude }
        if cityName != nil { transaction.cityName = cityName }
        if notes != nil { transaction.notes = notes }

        transaction.markAsModified()

        do {
            try context.save()
            print("💾 [Repo] Transação atualizada localmente: \(transaction.desc)")

            Task {
                await syncManager.syncAll()
            }
        } catch {
            print("❌ [Repo] Erro ao atualizar transação: \(error)")
        }
    }

    /// Buscar transação por ID
    func getTransaction(id: String) -> Transaction? {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }

    /// Deletar transação (soft delete para sync)
    func deleteTransaction(_ transaction: Transaction) {
        if transaction.serverId != nil {
            // Marcar para deletar no servidor
            transaction.markForDeletion()
        } else {
            // Se nunca foi sincronizado, deletar direto
            context.delete(transaction)
        }

        do {
            try context.save()
            print("💾 [Repo] Transação marcada para deleção")

            Task {
                await syncManager.syncAll()
            }
        } catch {
            print("❌ [Repo] Erro ao deletar transação: \(error)")
        }
    }

    // MARK: - Credit Card Transactions

    /// Busca todas transações de cartão de crédito do usuário
    func getCreditCardTransactions(userId: String) -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate {
                $0.userId == userId &&
                $0.creditCardId != nil &&
                $0.syncStatus != "pendingDelete"
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ [Repo] Erro ao buscar transações de cartão: \(error)")
            return []
        }
    }

    /// Busca transações de um cartão específico
    func getTransactionsForCard(cardId: String, userId: String) -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate {
                $0.userId == userId &&
                $0.creditCardId == cardId &&
                $0.syncStatus != "pendingDelete"
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ [Repo] Erro ao buscar transações do cartão: \(error)")
            return []
        }
    }

    /// Busca todas transações parceladas do usuário (para exibir em qualquer mês)
    func getInstallmentTransactions(userId: String) -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate {
                $0.userId == userId &&
                $0.installments != nil &&
                $0.syncStatus != "pendingDelete"
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            let transactions = try context.fetch(descriptor)
            // Filtrar apenas transações com mais de 1 parcela
            return transactions.filter { ($0.installments ?? 0) > 1 }
        } catch {
            print("❌ [Repo] Erro ao buscar transações parceladas: \(error)")
            return []
        }
    }

    // MARK: - Batch Operations

    /// Buscar todas transações pendentes de sync
    func getPendingTransactions() -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.syncStatus != "synced" }
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    /// Contar transações pendentes
    func getPendingCount() -> Int {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.syncStatus != "synced" }
        )

        return (try? context.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Migration

    /// Migra transações existentes para preencher cityName a partir das coordenadas
    func migrateCityNames() async {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate {
                $0.latitude != nil && $0.longitude != nil && $0.cityName == nil
            }
        )

        guard let transactions = try? context.fetch(descriptor), !transactions.isEmpty else {
            print("✅ [Repo] Nenhuma transação para migrar cityName")
            return
        }

        print("🔄 [Repo] Migrando cityName para \(transactions.count) transações...")

        for transaction in transactions {
            guard let lat = transaction.latitude, let lon = transaction.longitude else { continue }

            if let cityName = await reverseGeocodeCity(latitude: lat, longitude: lon) {
                transaction.cityName = cityName
                print("📍 [Repo] Cidade extraída: \(cityName) para \(transaction.desc)")
            }
            // Aguardar um pouco entre requisições para não exceder rate limits
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        }

        do {
            try context.save()
            print("✅ [Repo] Migração de cityName concluída")
        } catch {
            print("❌ [Repo] Erro ao salvar migração: \(error)")
        }
    }

    // MARK: - Geocoding Helper

    /// Extrai o nome da cidade a partir das coordenadas via geocodificação reversa (iOS 26+)
    private func reverseGeocodeCity(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)

        guard let request = MKReverseGeocodingRequest(location: location) else {
            print("❌ [Repo] Coordenadas inválidas para geocodificação")
            return nil
        }

        do {
            let mapItems = try await request.mapItems
            if let mapItem = mapItems.first {
                // iOS 26: usar addressRepresentations ao invés de placemark (deprecated)
                if let cityWithContext = mapItem.addressRepresentations?.cityWithContext {
                    // cityWithContext retorna algo como "São Paulo, SP" - extrair só a cidade
                    let components = cityWithContext.components(separatedBy: ",")
                    return components.first?.trimmingCharacters(in: .whitespaces)
                }
                // Fallback: usar regionName
                return mapItem.addressRepresentations?.regionName
            }
        } catch {
            print("❌ [Repo] Erro ao geocodificar: \(error)")
        }
        return nil
    }
}
