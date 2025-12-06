import Foundation
import SwiftData

@MainActor
class SwiftDataStack {
    static let shared = SwiftDataStack()

    let container: ModelContainer

    private init() {
        let schema = Schema([
            Transaction.self,
            Category.self,
            CreditCard.self,
        ])

        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Se falhar (provavelmente por mudança de schema), tentar deletar o banco e recriar
            print("⚠️ [SwiftData] Erro ao criar container: \(error)")
            print("⚠️ [SwiftData] Tentando recriar o banco de dados...")

            // Deletar arquivos do banco de dados
            Self.deleteDatabase()

            // Tentar novamente
            do {
                container = try ModelContainer(for: schema, configurations: [config])
                print("✅ [SwiftData] Banco de dados recriado com sucesso")
            } catch {
                fatalError("Não foi possível criar ModelContainer mesmo após reset: \(error)")
            }
        }
    }

    var context: ModelContext {
        container.mainContext
    }

    private static func deleteDatabase() {
        let fileManager = FileManager.default

        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        // SwiftData usa arquivos .store por padrão
        let possibleFiles = [
            "default.store",
            "default.store-shm",
            "default.store-wal"
        ]

        for fileName in possibleFiles {
            let fileURL = appSupport.appendingPathComponent(fileName)
            try? fileManager.removeItem(at: fileURL)
        }

        print("🗑️ [SwiftData] Arquivos do banco deletados")
    }
}
