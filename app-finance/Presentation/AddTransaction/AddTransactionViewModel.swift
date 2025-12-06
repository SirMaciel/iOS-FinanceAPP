import Foundation
import Combine
import SwiftData
import UIKit

// MARK: - Payment Method

enum PaymentMethod: String, CaseIterable {
    case cash = "Dinheiro"
    case pix = "Pix"
    case debit = "Débito"
    case credit = "Cartão de Crédito"

    var icon: String {
        switch self {
        case .cash: return "banknote"
        case .pix: return "qrcode"
        case .debit: return "creditcard"
        case .credit: return "creditcard.fill"
        }
    }
}

@MainActor
class AddTransactionViewModel: ObservableObject {
    @Published var amount: String = ""
    @Published var date: Date = Date()
    @Published var description: String = ""
    @Published var type: TransactionType = .expense
    @Published var paymentMethod: PaymentMethod = .cash
    @Published var selectedCreditCard: CreditCard?
    @Published var creditCards: [CreditCard] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isOffline = false

    private let transactionRepo = TransactionRepository.shared
    private let creditCardRepo = CreditCardRepository.shared
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

    func loadCreditCards(userId: String) {
        creditCards = creditCardRepo.getCreditCards(userId: userId)
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
        // Só associar cartão se for pagamento com crédito
        let cardId = paymentMethod == .credit ? selectedCreditCard?.id : nil

        let _ = transactionRepo.createTransaction(
            userId: userId,
            type: type,
            amount: amountDecimal,
            date: date,
            description: description,
            creditCardId: cardId
        )

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        isLoading = false
        onSuccess()
    }
}
