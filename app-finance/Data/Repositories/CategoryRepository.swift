import Foundation
import SwiftData
import Combine

// MARK: - Category Repository (Local-First)

@MainActor
final class CategoryRepository: ObservableObject {
    static let shared = CategoryRepository()

    @Published private(set) var isLoading = false

    private let context: ModelContext
    private let syncManager = SyncManager.shared

    private init() {
        self.context = SwiftDataStack.shared.context
    }

    // MARK: - Read Operations (Local First)

    /// Busca todas categorias ativas - SEMPRE do local primeiro
    func getCategories(userId: String) -> [Category] {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate {
                $0.userId == userId &&
                $0.isActive == true &&
                $0.syncStatus != "pendingDelete"
            },
            sortBy: [SortDescriptor(\.displayOrder), SortDescriptor(\.name)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ [Repo] Erro ao buscar categorias: \(error)")
            return []
        }
    }

    /// Busca categorias e sincroniza em background
    func getCategoriesWithSync(userId: String) async -> [Category] {
        // 1. Retornar dados locais imediatamente
        let localData = getCategories(userId: userId)

        // 2. Sincronizar em background
        if NetworkMonitor.shared.isConnected {
            Task {
                await syncManager.syncAll()
            }
        }

        return localData
    }

    /// Buscar categoria por ID
    func getCategory(id: String) -> Category? {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.id == id || $0.serverId == id }
        )

        return try? context.fetch(descriptor).first
    }

    /// Verificar se já existe categoria com o mesmo nome para o usuário
    func categoryExists(userId: String, name: String, excludingId: String? = nil) -> Bool {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let categories = getCategories(userId: userId)

        return categories.contains { category in
            let categoryName = category.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let isSameName = categoryName == normalizedName

            if let excludeId = excludingId {
                return isSameName && category.id != excludeId && category.serverId != excludeId
            }
            return isSameName
        }
    }

    // MARK: - Write Operations (Local First)

    /// Criar categoria - salva local primeiro
    /// Retorna nil se já existir uma categoria com o mesmo nome
    func createCategory(
        userId: String,
        name: String,
        colorHex: String,
        iconName: String = "tag"
    ) -> Category? {
        // Verificar se já existe categoria com esse nome
        if categoryExists(userId: userId, name: name) {
            print("⚠️ [Repo] Categoria com nome '\(name)' já existe")
            return nil
        }

        let category = Category(
            userId: userId,
            name: name,
            colorHex: colorHex,
            iconName: iconName,
            syncStatus: .pending
        )

        context.insert(category)

        do {
            try context.save()
            print("💾 [Repo] Categoria salva localmente: \(name)")

            Task {
                await syncManager.syncAll()
            }
        } catch {
            print("❌ [Repo] Erro ao salvar categoria: \(error)")
            return nil
        }

        return category
    }

    /// Atualizar categoria
    /// Retorna false se já existir outra categoria com o mesmo nome
    func updateCategory(
        _ category: Category,
        name: String? = nil,
        colorHex: String? = nil,
        iconName: String? = nil,
        isActive: Bool? = nil
    ) -> Bool {
        // Verificar se o novo nome já existe em outra categoria
        if let newName = name {
            if categoryExists(userId: category.userId, name: newName, excludingId: category.id) {
                print("⚠️ [Repo] Categoria com nome '\(newName)' já existe")
                return false
            }
            category.name = newName
        }

        if let colorHex = colorHex { category.colorHex = colorHex }
        if let iconName = iconName { category.iconName = iconName }
        if let isActive = isActive { category.isActive = isActive }

        category.markAsModified()

        do {
            try context.save()
            print("💾 [Repo] Categoria atualizada localmente: \(category.name)")

            Task {
                await syncManager.syncAll()
            }
            return true
        } catch {
            print("❌ [Repo] Erro ao atualizar categoria: \(error)")
            return false
        }
    }

    /// Deletar categoria (soft delete)
    func deleteCategory(_ category: Category) {
        if category.serverId != nil {
            category.markForDeletion()
        } else {
            context.delete(category)
        }

        do {
            try context.save()
            print("💾 [Repo] Categoria marcada para deleção: \(category.name)")

            Task {
                await syncManager.syncAll()
            }
        } catch {
            print("❌ [Repo] Erro ao deletar categoria: \(error)")
        }
    }

    /// Reordenar categorias (drag & drop)
    func reorderCategories(_ categories: [Category]) {
        for (index, category) in categories.enumerated() {
            category.displayOrder = index
        }

        do {
            try context.save()
            print("💾 [Repo] Categorias reordenadas")
        } catch {
            print("❌ [Repo] Erro ao reordenar categorias: \(error)")
        }
    }

    // MARK: - Seed Default Categories

    func seedDefaultCategoriesIfNeeded(userId: String) {
        let existing = getCategories(userId: userId)
        guard existing.isEmpty else { return }

        let defaults: [(name: String, color: String, icon: String)] = [
            ("Alimentação", "#FF6B6B", "fork.knife"),
            ("Transporte", "#4ECDC4", "car.fill"),
            ("Moradia", "#45B7D1", "house.fill"),
            ("Saúde", "#96CEB4", "heart.fill"),
            ("Educação", "#DDA0DD", "book.fill"),
            ("Lazer", "#FFD93D", "gamecontroller.fill"),
            ("Compras", "#FF8C42", "bag.fill"),
            ("Outros", "#95A5A6", "ellipsis.circle.fill")
        ]

        for (index, (name, color, icon)) in defaults.enumerated() {
            let category = Category(
                userId: userId,
                name: name,
                colorHex: color,
                iconName: icon,
                displayOrder: index,
                syncStatus: .pending  // Sincronizar com servidor
            )
            context.insert(category)
        }

        do {
            try context.save()
            print("💾 [Repo] Categorias padrão criadas (local only)")
        } catch {
            print("❌ [Repo] Erro ao criar categorias padrão: \(error)")
        }
    }

    // MARK: - Helpers

    func getPendingCount() -> Int {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.syncStatus != "synced" }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }
}
