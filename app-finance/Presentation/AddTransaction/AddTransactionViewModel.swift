import Foundation
import Combine
import SwiftData
import UIKit
import SwiftUI
import CoreLocation

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
    @Published var notes: String = ""
    @Published var type: TransactionType = .expense
    @Published var paymentMethod: PaymentMethod = .cash
    @Published var selectedCreditCard: CreditCard?
    @Published var creditCards: [CreditCard] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isOffline = false

    // Categories
    @Published var categories: [Category] = []
    @Published var selectedCategory: Category?

    // Custom category fields
    @Published var isCustomCategory = false
    @Published var customCategoryName = ""
    @Published var customCategoryIcon = "tag.fill"
    @Published var customCategoryColorHex = "#14B8A6"

    // AI Categorization
    @Published var isAILoading = false
    @Published var aiSuggestion: TransactionCategorySuggestion?
    private var aiDebounceTask: Task<Void, Never>?

    // Location
    @Published var saveLocation = false
    @Published var useCurrentLocation = true
    @Published var locationName: String = ""
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var isLoadingLocation = false
    @Published var locationSearchResults: [LocationSearchResult] = []
    @Published var isSearchingLocation = false
    @Published var showMapPicker = false

    // Installments (credit card)
    @Published var installments: Int = 1
    @Published var showInstallments = false

    private let transactionRepo = TransactionRepository.shared
    private let creditCardRepo = CreditCardRepository.shared
    private let categoryRepo = CategoryRepository.shared
    private let categorizationService = TransactionCategorizationService.shared
    private let networkMonitor = NetworkMonitor.shared
    private let locationManager = LocationManager()
    private var cancellables = Set<AnyCancellable>()
    private var userId: String = ""

    init() {
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.isOffline = !connected
            }
            .store(in: &cancellables)
    }

    func loadCreditCards(userId: String) {
        self.userId = userId
        creditCards = creditCardRepo.getCreditCards(userId: userId)
    }

    func loadCategories(userId: String) {
        self.userId = userId
        categories = categoryRepo.getCategories(userId: userId)
            .filter { $0.isActive && $0.syncStatusEnum != .pendingDelete }
            .sorted { $0.displayOrder < $1.displayOrder }

        // Seed default categories if empty
        if categories.isEmpty {
            categoryRepo.seedDefaultCategoriesIfNeeded(userId: userId)
            categories = categoryRepo.getCategories(userId: userId)
                .filter { $0.isActive && $0.syncStatusEnum != .pendingDelete }
                .sorted { $0.displayOrder < $1.displayOrder }
        }

        // Pre-select "Outros" category by default
        if selectedCategory == nil {
            selectedCategory = categories.first { $0.name.lowercased() == "outros" }
        }
    }

    // MARK: - AI Categorization

    func updateAISuggestion(for transactionName: String) {
        // Cancelar task anterior (debounce)
        aiDebounceTask?.cancel()

        // Só ativar IA para gastos
        guard type == .expense else {
            withAnimation { isAILoading = false }
            aiSuggestion = nil
            return
        }

        guard transactionName.count >= 3 else {
            withAnimation { isAILoading = false }
            aiSuggestion = nil
            return
        }

        // Debounce: esperar 800ms após parar de digitar
        aiDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000) // 800ms

            guard !Task.isCancelled else { return }

            // Mostrar loading
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAILoading = true
                    aiSuggestion = nil
                }
            }

            // Chamar serviço de categorização
            let suggestion = await categorizationService.suggestCategoryFromServer(
                for: transactionName,
                amount: Double(amount.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")),
                existingCategories: categories
            )

            guard !Task.isCancelled else {
                await MainActor.run { isAILoading = false }
                return
            }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAILoading = false
                    if suggestion.confidence != .none {
                        aiSuggestion = suggestion
                    }
                }
            }
        }
    }

    func applySuggestion(_ suggestion: TransactionCategorySuggestion) {
        if let existingCategory = suggestion.existingCategory {
            // Selecionar categoria existente
            selectedCategory = existingCategory
            isCustomCategory = false
        } else if suggestion.isCustomCategory {
            // Categoria customizada criada pela IA
            isCustomCategory = true
            selectedCategory = nil
            customCategoryName = suggestion.customCategoryName ?? ""
            customCategoryIcon = suggestion.customCategoryIcon ?? "tag.fill"
            customCategoryColorHex = suggestion.customCategoryColorHex ?? "#14B8A6"
        }
        // Limpar sugestão após aplicar
        aiSuggestion = nil
    }

    func cancelAISuggestion() {
        aiDebounceTask?.cancel()
        isAILoading = false
        aiSuggestion = nil
    }

    // MARK: - Category Management

    func updateCategory(_ category: Category, name: String, colorHex: String) {
        categoryRepo.updateCategory(category, name: name, colorHex: colorHex)
        loadCategories(userId: userId)
    }

    func deleteCategory(_ category: Category) {
        // If the deleted category was selected, clear selection
        if selectedCategory?.id == category.id {
            selectedCategory = nil
        }
        categoryRepo.deleteCategory(category)
        loadCategories(userId: userId)
    }

    // MARK: - Location

    func fetchCurrentLocation() async {
        // Mostrar estado de loading imediatamente
        saveLocation = true
        useCurrentLocation = true
        isLoadingLocation = true

        if let result = await locationManager.fetchCurrentLocation() {
            let (location, placeName) = result
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            locationName = placeName ?? "Localização atual"
        } else {
            // Se falhou, voltar ao estado inicial
            saveLocation = false
            useCurrentLocation = true
            locationName = ""
        }
        isLoadingLocation = false
    }

    func clearLocation() {
        saveLocation = false
        useCurrentLocation = true
        locationName = ""
        latitude = nil
        longitude = nil
        locationSearchResults = []
    }

    func searchLocation() async {
        guard !locationName.isEmpty else {
            locationSearchResults = []
            return
        }

        isSearchingLocation = true
        await locationManager.searchLocation(query: locationName)
        locationSearchResults = locationManager.searchResults
        isSearchingLocation = false
    }

    func selectLocation(_ result: LocationSearchResult) {
        locationName = result.name
        latitude = result.coordinate.latitude
        longitude = result.coordinate.longitude
        locationSearchResults = []
        locationManager.clearSearch()
    }

    func clearSearchResults() {
        locationSearchResults = []
        locationManager.clearSearch()
    }

    func updateLocationFromMap(latitude: Double, longitude: Double) async {
        self.latitude = latitude
        self.longitude = longitude
        isLoadingLocation = true

        if let placeName = await locationManager.reverseGeocodeCoordinate(latitude: latitude, longitude: longitude) {
            locationName = placeName
        } else {
            locationName = "Local selecionado"
        }

        isLoadingLocation = false
    }

    func saveTransaction(userId: String, onSuccess: @escaping () -> Void) async {
        guard !amount.isEmpty, !description.isEmpty else {
            errorMessage = "Preencha todos os campos"
            return
        }

        // Validar nome da categoria customizada
        if isCustomCategory && customCategoryName.isEmpty {
            errorMessage = "Preencha o nome da categoria"
            return
        }

        // Converter valor formatado (1.234,56) para Decimal
        // Remove pontos de milhar e troca vírgula por ponto
        let cleanAmount = amount
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")

        guard let amountDecimal = Decimal(string: cleanAmount) else {
            errorMessage = "Valor inválido"
            return
        }

        isLoading = true
        errorMessage = nil

        // Se categoria customizada, criar primeiro
        var categoryId: String? = selectedCategory?.id

        if isCustomCategory && !customCategoryName.isEmpty {
            // Criar categoria customizada
            let newCategory = categoryRepo.createCategory(
                userId: userId,
                name: customCategoryName,
                colorHex: customCategoryColorHex,
                iconName: customCategoryIcon
            )
            categoryId = newCategory.id

            // Recarregar categorias
            loadCategories(userId: userId)
        }

        // Salvar localmente (será sincronizado automaticamente)
        // Só associar cartão se for pagamento com crédito
        let cardId = paymentMethod == .credit ? selectedCreditCard?.id : nil

        // Parcelas só para cartão de crédito
        let installmentCount = (paymentMethod == .credit && installments > 1) ? installments : nil

        let _ = transactionRepo.createTransaction(
            userId: userId,
            type: type,
            amount: amountDecimal,
            date: date,
            description: description,
            categoryId: categoryId,
            creditCardId: cardId,
            locationName: saveLocation ? locationName : nil,
            latitude: saveLocation ? latitude : nil,
            longitude: saveLocation ? longitude : nil,
            installments: installmentCount
        )

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        isLoading = false
        onSuccess()
    }
}
