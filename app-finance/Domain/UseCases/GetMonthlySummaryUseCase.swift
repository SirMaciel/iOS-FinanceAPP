import Foundation

class GetMonthlySummaryUseCase {
    func execute(month: MonthRef) async throws -> MonthlySummaryResponse {
        return try await SummaryAPI.shared.getMonthlySummary(month: month.apiString)
    }
}
