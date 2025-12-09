import SwiftUI
import Combine

// MARK: - Filter Types

enum TransactionFilter: String, CaseIterable {
    case all = "Todos"
    case income = "Receitas"
    case expense = "Despesas"

    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .all: return AppColors.accentBlue
        case .income: return AppColors.income
        case .expense: return AppColors.expense
        }
    }
}

enum SortOption: String, CaseIterable {
    case dateDesc = "Mais recentes"
    case dateAsc = "Mais antigas"
    case amountDesc = "Maior valor"
    case amountAsc = "Menor valor"

    var icon: String {
        switch self {
        case .dateDesc: return "calendar.badge.clock"
        case .dateAsc: return "calendar"
        case .amountDesc: return "arrow.down.circle"
        case .amountAsc: return "arrow.up.circle"
        }
    }
}

// MARK: - All Transactions ViewModel

@MainActor
class AllTransactionsViewModel: ObservableObject {
    @Published var currentMonth: MonthRef = .current
    @Published var transactions: [Transaction] = []
    @Published var categories: [Category] = []
    @Published var isLoading = false

    // Filters
    @Published var typeFilter: TransactionFilter = .all
    @Published var selectedCategoryIds: Set<String> = []
    @Published var selectedCities: Set<String> = []
    @Published var minAmount: Double?
    @Published var maxAmount: Double?
    @Published var startDate: Date?
    @Published var endDate: Date?
    @Published var sortOption: SortOption = .dateDesc
    @Published var searchText: String = ""

    // Payment Method Filter
    @Published var cards: [CreditCard] = []
    @Published var selectedCardIds: Set<String> = []

    private let transactionRepo = TransactionRepository.shared
    private let categoryRepo = CategoryRepository.shared
    private let creditCardRepo = CreditCardRepository.shared

    private var userId: String {
        UserDefaults.standard.string(forKey: "user_id") ?? ""
    }

    init() {
        loadData()
    }

    func loadData() {
        isLoading = true

        transactions = transactionRepo.getTransactions(
            month: currentMonth.apiString,
            userId: userId
        ).filter { $0.syncStatusEnum != .pendingDelete && ($0.installments == nil || $0.installments! <= 1) }

        categories = categoryRepo.getCategories(userId: userId)
        cards = creditCardRepo.getCreditCards(userId: userId)

        isLoading = false
    }

    func nextMonth() {
        currentMonth = currentMonth.addingMonths(1)
        loadData()
    }

    func previousMonth() {
        currentMonth = currentMonth.addingMonths(-1)
        loadData()
    }

    // MARK: - Computed Properties

    var filteredTransactions: [TransactionItemViewModel] {
        var filtered = transactions

        // Type filter
        switch typeFilter {
        case .income:
            filtered = filtered.filter { $0.type == .income }
        case .expense:
            filtered = filtered.filter { $0.type == .expense }
        case .all:
            break
        }

        // Category filter
        if !selectedCategoryIds.isEmpty {
            filtered = filtered.filter { tx in
                guard let catId = tx.categoryId else { return false }
                // Check if the transaction's categoryId matches any selected category's id or serverId
                return categories.contains { cat in
                    selectedCategoryIds.contains(cat.id) && (cat.id == catId || cat.serverId == catId)
                }
            }
        }

        // City filter
        if !selectedCities.isEmpty {
            filtered = filtered.filter { tx in
                // 1. Try cityName (geocoded)
                if let txCityName = tx.cityName, !txCityName.isEmpty {
                    // Check if current tx city is in the selected set (case-insensitive check)
                    return selectedCities.contains { $0.localizedCaseInsensitiveCompare(txCityName) == .orderedSame }
                }

                // 2. Try locationName extraction
                guard let locName = tx.locationName, !locName.isEmpty else { return false }

                if let city = extractCity(from: locName) {
                    return selectedCities.contains { $0.localizedCaseInsensitiveCompare(city) == .orderedSame }
                }

                // 3. Fallback: contains check
                return selectedCities.contains { locName.localizedCaseInsensitiveContains($0) }
            }
        }

        // Credit Card filter
        if !selectedCardIds.isEmpty {
            filtered = filtered.filter { tx in
                guard let cardId = tx.creditCardId else { return false }
                return selectedCardIds.contains(cardId)
            }
        }

        // Amount filter
        if let min = minAmount {
            filtered = filtered.filter { $0.amountDouble >= min }
        }
        if let max = maxAmount {
            filtered = filtered.filter { $0.amountDouble <= max }
        }

        // Date range filter
        if let start = startDate {
            let startOfDay = Calendar.current.startOfDay(for: start)
            filtered = filtered.filter { $0.date >= startOfDay }
        }
        if let end = endDate {
            // End of day for the end date
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: end))!
            filtered = filtered.filter { $0.date < endOfDay }
        }

        // Search text
        if !searchText.isEmpty {
            filtered = filtered.filter { tx in
                tx.desc.localizedCaseInsensitiveContains(searchText) ||
                (tx.locationName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Sort
        switch sortOption {
        case .dateDesc:
            filtered.sort { $0.date > $1.date }
        case .dateAsc:
            filtered.sort { $0.date < $1.date }
        case .amountDesc:
            filtered.sort { $0.amountDouble > $1.amountDouble }
        case .amountAsc:
            filtered.sort { $0.amountDouble < $1.amountDouble }
        }

        // Map to view models
        return filtered.map { tx in
            let category = categories.first { $0.id == tx.categoryId || $0.serverId == tx.categoryId }
            return TransactionItemViewModel(
                id: tx.id,
                description: tx.desc,
                amount: tx.amountDouble,
                amountFormatted: CurrencyUtils.format(tx.amountDouble),
                date: tx.date,
                dateFormatted: tx.date.shortFormatted,
                type: tx.type,
                categoryName: category?.name,
                categoryColor: category?.color ?? .gray,
                categoryIcon: category?.iconName ?? "tag.fill",
                needsUserReview: tx.needsUserReview,
                isPendingSync: tx.isPendingSync,
                locationName: tx.locationName,
                latitude: tx.latitude,
                longitude: tx.longitude,
                cityName: tx.cityName,
                notes: tx.notes,
                categoryId: tx.categoryId
            )
        }
    }

    /// Total de despesas do mês (sem filtros)
    var totalMonthExpense: Double {
        transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amountDouble }
    }

    /// Total de despesas com filtros aplicados
    var totalFilteredExpense: Double {
        filteredTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    /// Verifica se há filtros ativos que afetam o total
    var hasActiveFilters: Bool {
        typeFilter != .all ||
        !selectedCategoryIds.isEmpty ||
        !selectedCardIds.isEmpty ||
        !selectedCities.isEmpty ||
        minAmount != nil ||
        maxAmount != nil ||
        startDate != nil ||
        endDate != nil ||
        !searchText.isEmpty
    }

    /// Extrai cidades únicas das transações com contagem de gastos
    var uniqueCitiesWithAmount: [(city: String, amount: Double)] {
        var cityAmounts: [String: Double] = [:]

        for tx in transactions where tx.type == .expense {
            // Priorizar cityName (extraído das coordenadas via geocodificação)
            if let city = tx.cityName, !city.isEmpty {
                cityAmounts[city, default: 0] += tx.amountDouble
            } else if let locName = tx.locationName, !locName.isEmpty {
                // Fallback: extrair cidade do texto da localização
                if let city = extractCity(from: locName), !city.isEmpty {
                    cityAmounts[city, default: 0] += tx.amountDouble
                }
            }
        }

        return cityAmounts.map { ($0.key, $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    /// Extrai a cidade de uma string de localização
    /// Formato típico: "Rua X, 123, Bairro, Cidade, MG" ou "Rua X, 123, Cidade - MG"
    private func extractCity(from locationName: String) -> String? {
        // Normalizar separadores (alguns endereços usam " - " para separar estado)
        let normalized = locationName
            .replacingOccurrences(of: " - ", with: ", ")
            .replacingOccurrences(of: " – ", with: ", ")

        let parts = normalized.components(separatedBy: ", ")

        // Lista de siglas de estados brasileiros
        let stateAbbreviations = Set([
            "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA",
            "MT", "MS", "MG", "PA", "PB", "PR", "PE", "PI", "RJ", "RN",
            "RS", "RO", "RR", "SC", "SP", "SE", "TO", "Brasil", "Brazil"
        ])

        // Encontrar o índice do estado
        var stateIndex: Int? = nil
        for (index, part) in parts.enumerated().reversed() {
            let trimmed = part.trimmingCharacters(in: .whitespaces).uppercased()
            if stateAbbreviations.contains(trimmed) ||
               (trimmed.count == 2 && trimmed == trimmed.uppercased() && trimmed.allSatisfy({ $0.isLetter })) {
                stateIndex = index
                break
            }
        }

        // A cidade é o componente imediatamente antes do estado
        if let stateIdx = stateIndex, stateIdx > 0 {
            let cityPart = parts[stateIdx - 1].trimmingCharacters(in: .whitespaces)
            // Verificar se não é um número (número do endereço)
            if !cityPart.isEmpty && Int(cityPart) == nil {
                return cityPart
            }
            // Se for número, tentar o anterior
            if stateIdx > 1 {
                let prevPart = parts[stateIdx - 2].trimmingCharacters(in: .whitespaces)
                if !prevPart.isEmpty && Int(prevPart) == nil {
                    return prevPart
                }
            }
        }

        // Fallback: pegar o penúltimo componente que não seja número ou sigla de estado
        for part in parts.reversed() {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty,
               Int(trimmed) == nil,
               !stateAbbreviations.contains(trimmed.uppercased()),
               !(trimmed.count == 2 && trimmed == trimmed.uppercased()) {
                return trimmed
            }
        }

        return nil
    }

    /// Lista de cidades para o filtro
    var uniqueCities: [String] {
        uniqueCitiesWithAmount.map { $0.city }
    }

    var activeFiltersCount: Int {
        var count = 0
        if typeFilter != .all { count += 1 }
        if !selectedCategoryIds.isEmpty { count += 1 }
        if !selectedCardIds.isEmpty { count += 1 }
        if !selectedCities.isEmpty { count += 1 }
        if minAmount != nil || maxAmount != nil { count += 1 }
        if startDate != nil || endDate != nil { count += 1 }
        return count
    }

    func clearAllFilters() {
        typeFilter = .all
        selectedCategoryIds = []
        selectedCardIds = []
        selectedCities = []
        minAmount = nil
        maxAmount = nil
        startDate = nil
        endDate = nil
        searchText = ""
    }

    func deleteTransaction(_ id: String) async {
        if let tx = transactionRepo.getTransaction(id: id) {
            transactionRepo.deleteTransaction(tx)
            loadData()
        }
    }

    func updateTransaction(
        transactionId: String,
        description: String,
        amount: Decimal,
        date: Date,
        type: TransactionType,
        categoryId: String?,
        notes: String? = nil
    ) async {
        guard let transaction = transactions.first(where: { $0.id == transactionId }) else {
            return
        }

        transactionRepo.updateTransaction(
            transaction,
            description: description,
            amount: amount,
            date: date,
            type: type,
            categoryId: categoryId,
            notes: notes
        )

        loadData()
    }
}

// MARK: - All Transactions View

struct AllTransactionsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AllTransactionsViewModel()

    @State private var selectedTransaction: TransactionItemViewModel?
    @State private var showingFilters = false
    @State private var showingSearch = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Header with month navigation
                headerSection

                // Search bar (if visible)
                if showingSearch {
                    searchBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Quick filters
                quickFiltersSection

                // Transactions list
                if viewModel.filteredTransactions.isEmpty {
                    emptyState
                } else {
                    transactionsList
                }
            }
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailSheet(
                transaction: transaction,
                onDelete: {
                    Task {
                        await viewModel.deleteTransaction(transaction.id)
                    }
                    selectedTransaction = nil
                },
                onEdit: { desc, amount, date, type, categoryId, notes in
                    Task {
                        await viewModel.updateTransaction(
                            transactionId: transaction.id,
                            description: desc,
                            amount: amount,
                            date: date,
                            type: type,
                            categoryId: categoryId,
                            notes: notes
                        )
                    }
                    selectedTransaction = nil
                }
            )
        }
        .sheet(isPresented: $showingFilters) {
            AdvancedFiltersSheet(viewModel: viewModel)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(AppColors.bgSecondary)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Transações")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                // Search & Filter buttons
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showingSearch.toggle()
                        }
                    } label: {
                        Image(systemName: showingSearch ? "magnifyingglass.circle.fill" : "magnifyingglass")
                            .font(.system(size: 18))
                            .foregroundColor(showingSearch ? AppColors.accentBlue : AppColors.textSecondary)
                            .frame(width: 40, height: 40)
                            .background(showingSearch ? AppColors.accentBlue.opacity(0.15) : AppColors.bgSecondary)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top)

            // Month navigation
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.previousMonth()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(AppColors.bgSecondary)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 4) {
                    Text(viewModel.currentMonth.displayString)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    // Total de despesas
                    Text(CurrencyUtils.format(viewModel.hasActiveFilters ? viewModel.totalFilteredExpense : viewModel.totalMonthExpense))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.expense)

                    // Contagem de transações
                    Text("\(viewModel.filteredTransactions.count) transações")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.nextMonth()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(AppColors.bgSecondary)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.textTertiary)

                TextField("Buscar transações...", text: $viewModel.searchText)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textPrimary)

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            .padding(12)
            .background(AppColors.bgSecondary)
            .cornerRadius(12)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Quick Filters

    private var quickFiltersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Type filters
                ForEach(TransactionFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        icon: filter.icon,
                        isSelected: viewModel.typeFilter == filter,
                        color: filter.color
                    ) {
                        withAnimation(.spring(response: 0.25)) {
                            viewModel.typeFilter = filter
                        }
                    }
                }

                Divider()
                    .frame(height: 24)
                    .background(AppColors.cardBorder)

                // Sort button
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button {
                            viewModel.sortOption = option
                        } label: {
                            HStack {
                                Image(systemName: option.icon)
                                Text(option.rawValue)
                                if viewModel.sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.caption)
                        Text("Ordenar")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppColors.bgSecondary)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
                }

                // Advanced filters button
                Button {
                    showingFilters = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption)
                        Text("Filtros")
                            .font(.caption)
                            .fontWeight(.medium)

                        if viewModel.activeFiltersCount > 0 {
                            Text("\(viewModel.activeFiltersCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 18, height: 18)
                                .background(AppColors.accentBlue)
                                .clipShape(Circle())
                        }
                    }
                    .foregroundColor(viewModel.activeFiltersCount > 0 ? AppColors.accentBlue : AppColors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(viewModel.activeFiltersCount > 0 ? AppColors.accentBlue.opacity(0.1) : AppColors.bgSecondary)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(viewModel.activeFiltersCount > 0 ? AppColors.accentBlue.opacity(0.3) : AppColors.cardBorder, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.accentBlue.opacity(0.2), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: viewModel.activeFiltersCount > 0 ? "line.3.horizontal.decrease.circle" : "doc.text.magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.accentBlue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text(viewModel.activeFiltersCount > 0 ? "Nenhum resultado" : "Nenhuma transação")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)

                Text(viewModel.activeFiltersCount > 0 ? "Tente ajustar os filtros" : "Suas transações deste mês\naparecerão aqui")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if viewModel.activeFiltersCount > 0 {
                Button {
                    withAnimation {
                        viewModel.clearAllFilters()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle")
                        Text("Limpar filtros")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.accentBlue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(AppColors.accentBlue.opacity(0.1))
                    .cornerRadius(12)
                }
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Transactions List

    private var transactionsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.filteredTransactions) { transaction in
                    Button {
                        selectedTransaction = transaction
                    } label: {
                        TransactionRowCard(transaction: transaction)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteTransaction(transaction.id)
                            }
                        } label: {
                            Label("Excluir", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Filter Card Icon Helper

struct FilterCardIcon: View {
    let card: CreditCard
    
    private var cardColors: [Color] {
        if let match = AvailableBankCards.cards(forBank: card.bankEnum).first(where: { $0.tier == card.cardTypeEnum }) {
            if let color = Color(hex: match.cardColor) {
                return [color, color.opacity(0.7)]
            }
        }
        return card.cardTypeEnum.gradientColors
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: cardColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 45, height: 30)
                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)

            // Chip
            RoundedRectangle(cornerRadius: 1.5)
                .fill(LinearGradient(colors: [.yellow.opacity(0.8), .orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 8, height: 5)
                .offset(x: -12, y: 4)
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : AppColors.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? color : AppColors.bgSecondary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? color : AppColors.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Advanced Filters Sheet

struct AdvancedFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AllTransactionsViewModel
    
    @State private var minAmountText: String = ""
    @State private var maxAmountText: String = ""
    @State private var citySearchText: String = ""
    @State private var useDateFilter: Bool = false
    @State private var localStartDate: Date = Date()
    @State private var localEndDate: Date = Date()
    
    // Filtros locais
    @State private var localSelectedCategoryIds: Set<String> = []
    @State private var localSelectedCardIds: Set<String> = []
    @State private var localSelectedCities: Set<String> = []
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        // 1. Period (Most important)
                        dateFilterSection
                        
                        // 2. Payment Method (Credit Cards)
                        paymentMethodFilterSection

                        // 3. Category filter
                        categoryFilterSection

                        // 4. Amount filter
                        amountFilterSection
                        
                        // 5. Location filter
                        locationFilterSection

                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        clearAll()
                    } label: {
                        Text("Limpar")
                            .font(.body)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        applyAllFilters()
                        dismiss()
                    } label: {
                        Text("Aplicar")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentBlue)
                    }
                }
            }
        }
        .onAppear {
            initializeFilters()
        }
    }
    
    private func initializeFilters() {
        // Init local state based on ViewModel
        localSelectedCategoryIds = viewModel.selectedCategoryIds
        localSelectedCardIds = viewModel.selectedCardIds
        localSelectedCities = viewModel.selectedCities
        
        if let min = viewModel.minAmount {
            minAmountText = String(format: "%.2f", min).replacingOccurrences(of: ".", with: ",")
        }
        if let max = viewModel.maxAmount {
            maxAmountText = String(format: "%.2f", max).replacingOccurrences(of: ".", with: ",")
        }
        
        // Date Logic
        if viewModel.startDate != nil || viewModel.endDate != nil {
            useDateFilter = true
            localStartDate = viewModel.startDate ?? viewModel.currentMonth.startDate
            localEndDate = viewModel.endDate ?? viewModel.currentMonth.endDate
        } else {
            localStartDate = viewModel.currentMonth.startDate
            localEndDate = viewModel.currentMonth.endDate
        }
    }
    
    private func clearAll() {
        withAnimation {
            localSelectedCategoryIds = []
            localSelectedCardIds = []
            localSelectedCities = []
            minAmountText = ""
            maxAmountText = ""
            useDateFilter = false
            localStartDate = viewModel.currentMonth.startDate
            localEndDate = viewModel.currentMonth.endDate
            citySearchText = ""
        }
    }
    
    private func applyAllFilters() {
        // Update ViewModel with local state
        viewModel.selectedCategoryIds = localSelectedCategoryIds
        viewModel.selectedCardIds = localSelectedCardIds
        viewModel.selectedCities = localSelectedCities
        
        // Amounts
        let minValue = parseAmount(minAmountText)
        let maxValue = parseAmount(maxAmountText)
        
        if let min = minValue, let max = maxValue, min > max {
            // Swap if user inverted
            viewModel.minAmount = max
            viewModel.maxAmount = min
        } else {
            viewModel.minAmount = minValue
            viewModel.maxAmount = maxValue
        }
        
        // Dates
        if useDateFilter {
            viewModel.startDate = localStartDate
            viewModel.endDate = localEndDate
        } else {
            viewModel.startDate = nil
            viewModel.endDate = nil
        }
    }

    // MARK: - Date Filter Section
    
    private var monthStartDate: Date { viewModel.currentMonth.startDate }
    private var monthEndDate: Date { viewModel.currentMonth.endDate }

    private var dateFilterSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            header(title: "Período", icon: "calendar.badge.clock", color: AppColors.accentBlue) {
                if useDateFilter {
                    Button("Mês inteiro") {
                        withAnimation {
                            useDateFilter = false
                            localStartDate = monthStartDate
                            localEndDate = monthEndDate
                        }
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.accentBlue)
                }
            }

            // Quick Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    periodChip("Mês todo", isSelected: !useDateFilter) {
                        withAnimation { useDateFilter = false }
                    }
                    
                    periodChip("Personalizado", isSelected: useDateFilter) {
                        withAnimation { useDateFilter = true }
                    }
                }
            }

            if useDateFilter {
                HStack(spacing: 12) {
                    datePickerField(title: "De", selection: $localStartDate, range: monthStartDate...monthEndDate)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                    
                    datePickerField(title: "Até", selection: $localEndDate, range: localStartDate...monthEndDate)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding()
        .background(AppColors.bgSecondary)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.cardBorder, lineWidth: 0.5)
        )
    }
    
    private func datePickerField(title: String, selection: Binding<Date>, range: ClosedRange<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    
                DatePicker("", selection: selection, in: range, displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "pt_BR"))
                    .scaleEffect(0.9)
                    .fixedSize()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(AppColors.bgTertiary)
            .cornerRadius(8)
        }
    }
    
    // MARK: - Payment Method Filter

    private var paymentMethodFilterSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            header(title: "Cartão Utilizado", icon: "creditcard.fill", color: .purple) {
                if !localSelectedCardIds.isEmpty {
                    Button("Limpar") {
                        withAnimation { localSelectedCardIds = [] }
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.accentBlue)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Option: All (Clears selection)
                    Button {
                        withAnimation { localSelectedCardIds = [] }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(localSelectedCardIds.isEmpty ? AppColors.accentBlue : AppColors.bgTertiary)
                                    .frame(width: 45, height: 30)
                                    .shadow(color: localSelectedCardIds.isEmpty ? AppColors.accentBlue.opacity(0.3) : .clear, radius: 2, x: 0, y: 1)
                                
                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(localSelectedCardIds.isEmpty ? .white : AppColors.textSecondary)
                            }
                            
                            Text("Todos")
                                .font(.caption)
                                .fontWeight(localSelectedCardIds.isEmpty ? .semibold : .regular)
                                .foregroundColor(localSelectedCardIds.isEmpty ? AppColors.textPrimary : AppColors.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    ForEach(viewModel.cards) { card in
                        let isSelected = localSelectedCardIds.contains(card.id)
                        
                        Button {
                            withAnimation {
                                if isSelected {
                                    localSelectedCardIds.remove(card.id)
                                } else {
                                    localSelectedCardIds.insert(card.id)
                                }
                            }
                        } label: {
                            VStack(spacing: 8) {
                                // Card Visual
                                ZStack {
                                    FilterCardIcon(card: card)
                                    
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.white, lineWidth: 2)
                                            .frame(width: 45, height: 30)
                                        
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.green))
                                            .font(.caption)
                                            .offset(x: 18, y: -12) // Top right corner badge
                                            .shadow(radius: 1)
                                    }
                                }
                                
                                Text(card.cardName)
                                    .font(.caption)
                                    .fontWeight(isSelected ? .semibold : .regular)
                                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                                    .lineLimit(1)
                                    .frame(maxWidth: 80)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
            }
        }
        .padding()
        .background(AppColors.bgSecondary)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.cardBorder, lineWidth: 0.5)
        )
    }

    // MARK: - Category Filter Section

    private var categoryFilterSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            header(title: "Categorias", icon: "tag.fill", color: .orange) {
                if !localSelectedCategoryIds.isEmpty {
                    Button("Limpar") {
                        withAnimation { localSelectedCategoryIds = [] }
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.accentBlue)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 10) {
                ForEach(viewModel.categories) { category in
                    let isSelected = localSelectedCategoryIds.contains(category.id)

                    Button {
                        if isSelected {
                            localSelectedCategoryIds.remove(category.id)
                        } else {
                            localSelectedCategoryIds.insert(category.id)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: category.iconName)
                                .font(.caption)
                            Text(category.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                        }
                        .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? category.color : AppColors.bgTertiary)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? category.color : AppColors.cardBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(AppColors.bgSecondary)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.cardBorder, lineWidth: 0.5)
        )
    }
    
    // MARK: - Amount Filter Section
    
    private var isAmountInverted: Bool {
        guard let min = parseAmount(minAmountText), let max = parseAmount(maxAmountText) else { return false }
        return min > max
    }

    private var amountFilterSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            header(title: "Faixa de Valor", icon: "dollarsign.circle.fill", color: .green) {
                if !minAmountText.isEmpty || !maxAmountText.isEmpty {
                    Button("Limpar") {
                        minAmountText = ""
                        maxAmountText = ""
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.accentBlue)
                }
            }

            HStack(spacing: 16) {
                amountField(title: "Mínimo", text: $minAmountText, error: isAmountInverted)
                amountField(title: "Máximo", text: $maxAmountText, error: isAmountInverted)
            }
            
            if isAmountInverted {
                Text("Nota: O valor mínimo é maior que o máximo. Eles serão invertidos ao aplicar.")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(AppColors.bgSecondary)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isAmountInverted ? Color.orange : AppColors.cardBorder, lineWidth: isAmountInverted ? 1 : 0.5)
        )
    }
    
    private func amountField(title: String, text: Binding<String>, error: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            
            HStack {
                Text("R$")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textTertiary)
                
                TextField("0,00", text: text)
                    .font(.body)
                    .fontWeight(.medium)
                    .keyboardType(.decimalPad)
                    .onChange(of: text.wrappedValue) { _, newValue in
                        text.wrappedValue = formatCurrencyInput(newValue)
                    }
            }
            .padding(12)
            .background(AppColors.bgTertiary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(error ? Color.orange.opacity(0.5) : AppColors.cardBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Location Filter Section
    
    private var filteredCities: [(city: String, amount: Double)] {
        if citySearchText.isEmpty { return [] }
        return viewModel.uniqueCitiesWithAmount.filter {
            $0.city.localizedCaseInsensitiveContains(citySearchText)
        }
    }

    private var locationFilterSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            header(title: "Localização", icon: "mappin.circle.fill", color: .red) {
                if !localSelectedCities.isEmpty {
                    Button("Limpar") {
                        withAnimation {
                            localSelectedCities = []
                            citySearchText = ""
                        }
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.accentBlue)
                }
            }
            
            // Search Input
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.textTertiary)
                
                TextField("Buscar cidade...", text: $citySearchText)
                    .font(.subheadline)
                
                if !citySearchText.isEmpty {
                    Button { citySearchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding(10)
            .background(AppColors.bgTertiary)
            .cornerRadius(10)

            // Cities List
            if viewModel.uniqueCitiesWithAmount.isEmpty {
                Text("Nenhuma localização registrada")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.vertical, 8)
            } else {
                let list = citySearchText.isEmpty ? viewModel.uniqueCitiesWithAmount : filteredCities
                
                if list.isEmpty {
                    Text("Nenhuma cidade encontrada")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.vertical)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(list, id: \.city) { item in
                                cityRow(item)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
        }
        .padding()
        .background(AppColors.bgSecondary)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.cardBorder, lineWidth: 0.5)
        )
    }
    
    private func cityRow(_ item: (city: String, amount: Double)) -> some View {
        let isSelected = localSelectedCities.contains(item.city)
        
        return Button {
            withAnimation {
                if isSelected {
                    localSelectedCities.remove(item.city)
                } else {
                    localSelectedCities.insert(item.city)
                }
            }
        } label: {
            HStack {
                // Pin Icon
                Image(systemName: isSelected ? "mappin.circle.fill" : "mappin.circle")
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .green : AppColors.textTertiary)
                
                Text(item.city)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .green : AppColors.textPrimary)
                
                Spacer()
                
                // Spent Amount restored
                Text(CurrencyUtils.format(item.amount))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.expense)
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding(12)
            .background(isSelected ? Color.green.opacity(0.1) : AppColors.bgTertiary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helpers
    
    private func header<Content: View>(title: String, icon: String, color: Color, @ViewBuilder actions: () -> Content = { EmptyView() }) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                    .padding(6)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
            }
            Spacer()
            actions()
        }
    }
    
    private func periodChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AppColors.accentBlue : AppColors.bgTertiary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
    
    private func parseAmount(_ text: String) -> Double? {
        guard !text.isEmpty else { return nil }
        let clean = text.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        return Double(clean)
    }
    
    private func formatCurrencyInput(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        guard !digits.isEmpty else { return "" }
        guard let cents = Int(digits) else { return "" }
        let reais = Double(cents) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: reais)) ?? ""
    }
}

#Preview {
    AllTransactionsView()
}
