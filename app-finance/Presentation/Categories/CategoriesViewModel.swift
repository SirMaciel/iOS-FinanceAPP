import Foundation
import SwiftUI
import Combine
import SwiftData

@MainActor
class CategoriesViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isOffline = false

    private let categoryRepo = CategoryRepository.shared
    private let networkMonitor = NetworkMonitor.shared
    private let syncManager = SyncManager.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Observar mudanças de conectividade
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.isOffline = !connected
            }
            .store(in: &cancellables)

        // Observar quando sync completar para atualizar lista
        NotificationCenter.default.publisher(for: .syncCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshFromLocal()
            }
            .store(in: &cancellables)
    }

    func loadCategories(userId: String) async {
        isLoading = true
        errorMessage = nil

        // 1. Carregar do local IMEDIATAMENTE
        categories = categoryRepo.getCategories(userId: userId)
        isLoading = false

        // 2. Seed default categories if empty
        if categories.isEmpty {
            categoryRepo.seedDefaultCategoriesIfNeeded(userId: userId)
            categories = categoryRepo.getCategories(userId: userId)
        }

        // 3. Sincronizar em background se online
        if networkMonitor.isConnected {
            Task {
                await syncManager.syncAll()
            }
        }
    }

    func updateCategory(
        _ category: Category,
        name: String?,
        colorHex: String?
    ) {
        categoryRepo.updateCategory(
            category,
            name: name,
            colorHex: colorHex
        )
        refreshFromLocal()
    }

    func deleteCategory(_ category: Category) {
        categoryRepo.deleteCategory(category)
        refreshFromLocal()
    }

    func moveCategory(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        categoryRepo.reorderCategories(categories)
    }

    private func refreshFromLocal() {
        guard let userId = categories.first?.userId else { return }
        categories = categoryRepo.getCategories(userId: userId)
    }
}
