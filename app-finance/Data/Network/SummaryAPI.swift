import Foundation

struct MonthlySummaryResponse: Codable {
    let month: String
    let totalIncome: Double
    let totalExpense: Double
    let balance: Double
    let pieByCategory: [PieCategoryData]
    var transactions: [TransactionResponse]
}

struct PieCategoryData: Codable, Identifiable {
    var id: String { categoryId }
    let categoryId: String
    let name: String
    let colorHex: String
    let iconName: String
    let total: Double
    let percent: Double
}

class SummaryAPI {
    static let shared = SummaryAPI()
    private let client = APIClient.shared

    private init() {}

    func getMonthlySummary(month: String) async throws -> MonthlySummaryResponse {
        return try await client.request("/summary?month=\(month)")
    }
}
