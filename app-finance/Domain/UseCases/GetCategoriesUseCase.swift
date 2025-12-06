import Foundation
import SwiftData

class GetCategoriesUseCase {
    func execute(context: ModelContext) async throws -> [CategoryResponse] {
        let response = try await CategoriesAPI.shared.getAll()

        // Sincronizar com local
        let allLocalCategories = (try? context.fetch(FetchDescriptor<Category>())) ?? []

        for catResponse in response {
            let catResponseId = catResponse.id
            let existing = allLocalCategories.first { $0.id == catResponseId || $0.serverId == catResponseId }

            if let existing = existing {
                existing.name = catResponse.name
                existing.colorHex = catResponse.colorHex
                existing.iconName = catResponse.iconName
                existing.isActive = catResponse.isActive
                existing.lastSyncAttempt = Date()
                existing.syncStatusEnum = .synced
            } else {
                let newCat = catResponse.toLocal(context: context)
                context.insert(newCat)
            }
        }

        try context.save()

        return response
    }
}
