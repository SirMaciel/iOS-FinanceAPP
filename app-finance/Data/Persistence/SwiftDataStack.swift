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
            FixedBill.self,
        ])

        // Usar migração automática para preservar dados quando o schema muda
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            // SwiftData faz migração automática para mudanças compatíveis
            // (adicionar campos opcionais, etc)
            container = try ModelContainer(for: schema, configurations: [config])
            print("✅ [SwiftData] Container criado com sucesso")
        } catch {
            print("❌ [SwiftData] Erro ao criar container: \(error)")

            // Tentar criar sem configuração customizada como fallback
            do {
                container = try ModelContainer(for: schema)
                print("✅ [SwiftData] Container criado com configuração padrão")
            } catch {
                print("❌ [SwiftData] Fallback falhou, resetando banco...")

                // Reset do banco em desenvolvimento - dados serão resincronizados do servidor
                Self.deleteDatabase()

                do {
                    container = try ModelContainer(for: schema, configurations: [config])
                    print("✅ [SwiftData] Container criado após reset")
                } catch {
                    fatalError("Não foi possível criar ModelContainer após reset: \(error)")
                }
            }
        }
    }

    var context: ModelContext {
        container.mainContext
    }

    /// Deleta o arquivo do banco de dados (apenas para desenvolvimento)
    private static func deleteDatabase() {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        let dbURL = appSupport.appendingPathComponent("default.store")
        let shmURL = appSupport.appendingPathComponent("default.store-shm")
        let walURL = appSupport.appendingPathComponent("default.store-wal")

        for url in [dbURL, shmURL, walURL] {
            try? fileManager.removeItem(at: url)
            print("🗑️ [SwiftData] Removido: \(url.lastPathComponent)")
        }
    }
}
