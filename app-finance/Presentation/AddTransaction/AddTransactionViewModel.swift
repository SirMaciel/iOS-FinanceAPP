import Foundation
import Combine
import SwiftData
import UIKit

@MainActor
class AddTransactionViewModel: ObservableObject {
    @Published var amount: String = ""
    @Published var date: Date = Date()
    @Published var description: String = ""
    @Published var type: TransactionType = .expense
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isOffline = false

    private let transactionRepo = TransactionRepository.shared
    private let networkMonitor = NetworkMonitor.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.isOffline = !connected
            }
            .store(in: &cancellables)
    }

    func saveTransaction(userId: String, onSuccess: @escaping () -> Void) async {
        guard !amount.isEmpty, !description.isEmpty else {
            errorMessage = "Preencha todos os campos"
            return
        }

        guard let amountDecimal = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) else {
            errorMessage = "Valor inválido"
            return
        }

        isLoading = true
        errorMessage = nil

        // Salvar localmente (será sincronizado automaticamente)
        let _ = transactionRepo.createTransaction(
            userId: userId,
            type: type,
            amount: amountDecimal,
            date: date,
            description: description
        )

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        isLoading = false
        onSuccess()
    }
}
