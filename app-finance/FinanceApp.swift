import SwiftUI
import SwiftData
import Combine

@main
struct FinanceApp: App {
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
        }
        .modelContainer(SwiftDataStack.shared.container)
    }
}

// MARK: - Auth Manager

@MainActor
class AuthManager: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isLoading = true
    @Published var userId: String?
    @Published var userName: String?

    private let authAPI = AuthAPI.shared
    private let tokenKey = "auth_token"
    private let userIdKey = "user_id"
    private let userNameKey = "user_name"

    init() {
        // Verificar se tem token salvo
        if let token = UserDefaults.standard.string(forKey: tokenKey),
           let savedUserId = UserDefaults.standard.string(forKey: userIdKey) {
            APIClient.shared.setToken(token)
            userId = savedUserId
            userName = UserDefaults.standard.string(forKey: userNameKey)
            isLoggedIn = true
        }
        isLoading = false
    }

    func login(email: String, password: String) async throws -> LoginResult {
        let result = try await authAPI.login(email: email, password: password)
        if case .success(let response) = result {
            completeLogin(response: response)
        }
        return result
    }

    func register(name: String, email: String, password: String) async throws -> String {
        let response = try await authAPI.register(name: name, email: email, password: password)
        return response.userId
    }

    func verifyEmail(userId: String, code: String) async throws {
        let response = try await authAPI.verifyEmail(userId: userId, code: code)
        let authResponse = AuthResponse(token: response.token, user: response.user)
        completeLogin(response: authResponse)
    }

    func resendVerificationCode(userId: String) async throws {
        _ = try await authAPI.resendVerificationCode(userId: userId)
    }

    func loginWithApple(identityToken: String, authorizationCode: String, appleUserId: String, email: String?, fullName: String?) async throws {
        let response = try await authAPI.loginWithApple(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            appleUserId: appleUserId,
            email: email,
            fullName: fullName
        )
        completeLogin(response: response)
    }

    func loginWithGoogle(idToken: String) async throws {
        let response = try await authAPI.loginWithGoogle(idToken: idToken)
        completeLogin(response: response)
    }

    func sendPasswordReset(email: String) async throws {
        _ = try await authAPI.forgotPassword(email: email)
    }

    func verifyResetCode(email: String, code: String) async throws -> String {
        return try await authAPI.verifyResetCode(email: email, code: code)
    }

    func resetPassword(email: String, token: String, newPassword: String) async throws {
        _ = try await authAPI.resetPassword(email: email, token: token, newPassword: newPassword)
    }

    func logout() {
        APIClient.shared.setToken(nil)
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
        userId = nil
        userName = nil
        isLoggedIn = false
    }

    private func completeLogin(response: AuthResponse) {
        APIClient.shared.setToken(response.token)
        UserDefaults.standard.set(response.token, forKey: tokenKey)
        UserDefaults.standard.set(response.user.id, forKey: userIdKey)
        UserDefaults.standard.set(response.user.name, forKey: userNameKey)
        userId = response.user.id
        userName = response.user.name
        isLoggedIn = true
        print("Login OK - userId: \(response.user.id)")
    }
}

// MARK: - Root View

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.isLoading {
                ZStack {
                    AppBackground()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(AppColors.accentBlue)
                        Text("Carregando...")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            } else if authManager.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    var body: some View {
        TabView {
            MonthlySummaryView()
                .tabItem {
                    Label("Resumo", systemImage: "chart.pie.fill")
                }

            FixedBillsView()
                .tabItem {
                    Label("Contas", systemImage: "calendar.badge.clock")
                }

            CreditCardView()
                .tabItem {
                    Label("Cartões", systemImage: "creditcard.fill")
                }
        }
        .tint(AppColors.accentBlue)
        .preferredColorScheme(.light) // Force Light Mode
    }
}

// MARK: - Profile Header

struct ProfileHeader: View {
    @EnvironmentObject var authManager: AuthManager
    let onProfileTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Profile photo + greeting
            Button(action: onProfileTap) {
                HStack(spacing: 12) {
                    // Profile photo (circular)
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        Text(authManager.userName?.prefix(1).uppercased() ?? "U")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }

                    // Greeting
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Olá,")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)

                        Text(authManager.userName ?? "Usuário")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Notification icon
            Button(action: {
                // TODO: Open notifications
            }) {
                ZStack {
                    Circle()
                        .fill(AppColors.bgSecondary)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        )

                    Image(systemName: "bell.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textPrimary)

                    // Notification badge (optional - for future use)
                    // Circle()
                    //     .fill(.red)
                    //     .frame(width: 8, height: 8)
                    //     .offset(x: 6, y: -6)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.bgPrimary)
    }
}

// MARK: - Credit Card View

struct CreditCardView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var creditCards: [CreditCard] = []
    @State private var showAddCard = false
    @State private var showAddTransaction = false
    @State private var selectedCard: CreditCard?
    @State private var editingCard: CreditCard?
    @State private var viewMode: CardViewMode = .cards
    @State private var transactionFilterMode: TransactionFilterMode = .all
    @State private var cardTransactions: [Transaction] = []
    @State private var categories: [Category] = []
    @State private var selectedFilterCard: CreditCard?
    @State private var selectedMonthIndex: Int = 0
    @State private var selectedCardMonthIndex: Int = 0
    @State private var selectedTransaction: TransactionItemViewModel?
    @State private var installmentsMonthOffset: Int = 0
    @State private var showAddInstallment = false
    @State private var installmentFilterMode: InstallmentFilterMode = .all
    @State private var selectedInstallmentCard: CreditCard?
    @State private var selectedInstallmentItem: InstallmentItem?

    enum CardViewMode {
        case cards
        case transactions
        case installments
    }

    enum TransactionFilterMode: String, CaseIterable {
        case all = "Todas"
        case byCard = "Por Cartão"
    }

    enum InstallmentFilterMode: String, CaseIterable {
        case all = "Todas"
        case byCard = "Por Cartão"
    }

    private let cardRepo = CreditCardRepository.shared
    private let transactionRepo = TransactionRepository.shared
    private let categoryRepo = CategoryRepository.shared

    // MARK: - Computed Properties

    private var totalLimit: Double {
        creditCards.filter { $0.isActive }.reduce(0) { $0 + (Double(truncating: $1.limitAmount as NSDecimalNumber)) }
    }

    private var activeCardsCount: Int {
        creditCards.filter { $0.isActive }.count
    }

    private var dueSoonCards: [CreditCard] {
        let today = Calendar.current.component(.day, from: Date())
        return creditCards.filter { card in
            guard card.isActive else { return false }
            let daysUntilDue: Int
            if card.paymentDay >= today {
                daysUntilDue = card.paymentDay - today
            } else {
                // Próximo mês
                let daysInMonth = Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30
                daysUntilDue = (daysInMonth - today) + card.paymentDay
            }
            return daysUntilDue <= 5 && daysUntilDue >= 0
        }
    }

    /// Retorna todos os meses disponíveis das transações, ordenados do mais recente ao mais antigo
    private var availableMonths: [Date] {
        let calendar = Calendar.current
        var months: Set<Date> = []

        // Sempre incluir o mês atual
        let currentMonthComponents = calendar.dateComponents([.year, .month], from: Date())
        if let currentMonth = calendar.date(from: currentMonthComponents) {
            months.insert(currentMonth)
        }

        // Adicionar meses das transações
        for transaction in cardTransactions {
            let components = calendar.dateComponents([.year, .month], from: transaction.date)
            if let monthDate = calendar.date(from: components) {
                months.insert(monthDate)
            }
        }

        return months.sorted(by: >)
    }

    /// Transações do mês selecionado (exclui parcelamentos)
    private var transactionsForSelectedMonth: [Transaction] {
        guard selectedMonthIndex < availableMonths.count else { return [] }
        let selectedMonth = availableMonths[selectedMonthIndex]

        let calendar = Calendar.current
        return cardTransactions.filter { transaction in
            // Excluir parcelamentos (installments > 1)
            guard transaction.installments == nil || transaction.installments! <= 1 else { return false }
            let txComponents = calendar.dateComponents([.year, .month], from: transaction.date)
            let selectedComponents = calendar.dateComponents([.year, .month], from: selectedMonth)
            return txComponents.year == selectedComponents.year && txComponents.month == selectedComponents.month
        }.sorted { $0.date > $1.date }
    }

    /// Total do mês selecionado
    private var totalForSelectedMonth: Double {
        transactionsForSelectedMonth.reduce(0) { $0 + (Double(truncating: $1.amount as NSDecimalNumber)) }
    }

    /// Meses disponíveis para o cartão selecionado
    private func availableMonthsForCard(_ card: CreditCard) -> [Date] {
        let calendar = Calendar.current
        var months: Set<Date> = []

        // Sempre incluir o mês atual
        let currentMonthComponents = calendar.dateComponents([.year, .month], from: Date())
        if let currentMonth = calendar.date(from: currentMonthComponents) {
            months.insert(currentMonth)
        }

        // Adicionar meses das transações do cartão
        let cardTxs = cardTransactions.filter { $0.creditCardId == card.id }
        for transaction in cardTxs {
            let components = calendar.dateComponents([.year, .month], from: transaction.date)
            if let monthDate = calendar.date(from: components) {
                months.insert(monthDate)
            }
        }

        return months.sorted(by: >)
    }

    /// Transações do cartão selecionado no mês selecionado (exclui parcelamentos)
    private func transactionsForCardInMonth(_ card: CreditCard, monthIndex: Int) -> [Transaction] {
        let months = availableMonthsForCard(card)
        guard monthIndex < months.count else { return [] }
        let selectedMonth = months[monthIndex]

        let calendar = Calendar.current
        return cardTransactions.filter { transaction in
            guard transaction.creditCardId == card.id else { return false }
            // Excluir parcelamentos (installments > 1)
            guard transaction.installments == nil || transaction.installments! <= 1 else { return false }
            let txComponents = calendar.dateComponents([.year, .month], from: transaction.date)
            let selectedComponents = calendar.dateComponents([.year, .month], from: selectedMonth)
            return txComponents.year == selectedComponents.year && txComponents.month == selectedComponents.month
        }.sorted { $0.date > $1.date }
    }

    /// Total gasto no cartão em um mês específico
    private func totalForCardInMonth(_ card: CreditCard, monthIndex: Int) -> Double {
        let transactions = transactionsForCardInMonth(card, monthIndex: monthIndex)
        return transactions.reduce(0) { $0 + (Double(truncating: $1.amount as NSDecimalNumber)) }
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Header
                headerView

                if creditCards.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Summary Card
                            summaryCard

                            // View Mode Picker
                            viewModePicker

                            // Content based on mode
                            switch viewMode {
                            case .cards:
                                cardsList
                                    .transition(.opacity)
                            case .transactions:
                                transactionsContentView
                                    .transition(.opacity)
                            case .installments:
                                installmentsContentView
                                    .transition(.opacity)
                            }
                        }
                        .padding()
                        .padding(.bottom, 80)
                    }
                }
            }

            // Floating Add Button
            if !creditCards.isEmpty {
                VStack {
                    Spacer()
                    FloatingAddButton {
                        switch viewMode {
                        case .cards:
                            showAddCard = true
                        case .transactions:
                            showAddTransaction = true
                        case .installments:
                            showAddInstallment = true
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            loadCards()
            loadCategories()
        }
        .sheet(isPresented: $showAddCard) {
            AddCreditCardView(onSave: loadCards)
        }
        .sheet(isPresented: $showAddTransaction) {
            AddTransactionView(onTransactionAdded: {
                loadTransactions()
            })
        }
        .sheet(isPresented: $showAddInstallment) {
            AddExistingInstallmentSheet(
                creditCards: creditCards,
                onSave: { cardId, description, totalAmount, totalInstallments, startingInstallment, date, categoryId in
                    addExistingInstallment(
                        cardId: cardId,
                        description: description,
                        totalAmount: totalAmount,
                        totalInstallments: totalInstallments,
                        startingInstallment: startingInstallment,
                        date: date,
                        categoryId: categoryId
                    )
                }
            )
        }
        .sheet(item: $selectedCard) { card in
            CreditCardDetailView(card: card, onUpdate: loadCards, onEdit: { cardToEdit in
                selectedCard = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    editingCard = cardToEdit
                }
            })
        }
        .sheet(item: $editingCard) { card in
            AddCreditCardView(editingCard: card, onSave: loadCards)
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailSheet(
                transaction: transaction,
                onDelete: {
                    deleteTransaction(transaction.id)
                    selectedTransaction = nil
                },
                onEdit: { desc, amount, date, type, categoryId, notes in
                    updateTransaction(
                        transactionId: transaction.id,
                        description: desc,
                        amount: amount,
                        date: date,
                        type: type,
                        categoryId: categoryId,
                        notes: notes
                    )
                    selectedTransaction = nil
                }
            )
        }
        .sheet(item: $selectedInstallmentItem) { item in
            InstallmentDetailSheet(
                item: item,
                card: creditCards.first { $0.id == item.creditCardId },
                onDelete: {
                    deleteTransaction(item.transactionId)
                    selectedInstallmentItem = nil
                },
                onEdit: { desc, totalAmount, totalInstallments, currentInstallment, categoryId in
                    updateInstallment(
                        transactionId: item.transactionId,
                        description: desc,
                        totalAmount: totalAmount,
                        totalInstallments: totalInstallments,
                        currentInstallment: currentInstallment,
                        categoryId: categoryId
                    )
                    selectedInstallmentItem = nil
                }
            )
        }
        .animation(.easeInOut, value: viewMode)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            SectionHeader(title: "Seus Cartões")
            Spacer()
        }
        .padding()
        .background(AppColors.bgPrimary)
    }

    // MARK: - View Mode Picker

    private var viewModePicker: some View {
        HStack(spacing: 0) {
            viewModeButton(mode: .cards, icon: "creditcard", title: "Cartões")
            viewModeButton(mode: .transactions, icon: "list.bullet.rectangle", title: "Transações")
            viewModeButton(mode: .installments, icon: "calendar.badge.clock", title: "Parcelas")
        }
        .padding(4)
        .background(AppColors.bgSecondary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }

    private func viewModeButton(mode: CardViewMode, icon: String, title: String) -> some View {
        Button(action: {
            withAnimation {
                viewMode = mode
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(viewMode == mode ? .black : AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(
                viewMode == mode ? Color.white : Color.clear
            )
            .cornerRadius(10)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Limite Total")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textSecondary)
                        .textCase(.uppercase)

                    Text(CurrencyUtils.format(totalLimit))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 48, height: 48)

                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.purple)
                }
            }

            // Divider aesthetic
            Rectangle()
                .fill(LinearGradient(
                    colors: [AppColors.cardBorder, AppColors.cardBorder.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 1)

            HStack(spacing: 24) {
                // Cards count
                HStack(spacing: 8) {
                    Text("\(activeCardsCount)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Text(activeCardsCount == 1 ? "cartão" : "cartões")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Due soon count
                if !dueSoonCards.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.accentOrange)

                        Text("\(dueSoonCards.count)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)

                        Text("vencem logo")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.accentOrange.opacity(0.1))
                    .cornerRadius(20)
                }
            }
        }
        .padding(24)
        .background(
            ZStack {
                AppColors.bgSecondary
                // Subtle shine
                LinearGradient(
                    colors: [Color.white.opacity(0.02), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "creditcard.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("Nenhum cartão cadastrado")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)

                Text("Adicione seu primeiro cartão\npara gerenciar suas faturas")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            AppButton(title: "Adicionar Cartão", icon: "plus") {
                showAddCard = true
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    // MARK: - Cards List

    private var cardsList: some View {
        LazyVStack(spacing: 16) {
            ForEach(creditCards) { card in
                CreditCardRow(card: card) {
                    selectedCard = card
                }
            }
        }
    }

    // MARK: - Transactions View

    private var transactionsContentView: some View {
        VStack(spacing: 16) {
            // Filter Picker
            transactionFilterPicker

            if filteredTransactions.isEmpty && selectedFilterCard == nil {
                transactionsEmptyState
            } else {
                if transactionFilterMode == .all {
                    transactionsList
                } else {
                    // "Por Cartão" mode
                    if let selectedCard = selectedFilterCard {
                        // Show selected card's transactions
                        selectedCardTransactionsView(card: selectedCard)
                    } else {
                        // Show cards grid
                        transactionsGroupedByCard
                    }
                }
            }
        }
        .onAppear {
            loadTransactions()
            loadCategories()
        }
    }

    private func selectedCardTransactionsView(card: CreditCard) -> some View {
        let months = availableMonthsForCard(card)
        let currentMonthTxs = transactionsForCardInMonth(card, monthIndex: selectedCardMonthIndex)
        let monthTotal = totalForCardInMonth(card, monthIndex: selectedCardMonthIndex)

        return VStack(spacing: 16) {
            // Header with back button and card info
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedFilterCard = nil
                        selectedCardMonthIndex = 0
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.accentBlue)
                        .frame(width: 36, height: 36)
                        .background(AppColors.bgTertiary)
                        .cornerRadius(10)
                }

                MiniCardIcon(card: card)

                Text(card.cardName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()
            }
            .padding(16)
            .background(AppColors.bgSecondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )

            // Month navigation header
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    // Previous (newer months)
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selectedCardMonthIndex > 0 {
                                selectedCardMonthIndex -= 1
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(selectedCardMonthIndex > 0 ? AppColors.accentBlue : AppColors.textTertiary)
                            .frame(width: 36, height: 36)
                            .background(AppColors.bgTertiary)
                            .cornerRadius(10)
                    }
                    .disabled(selectedCardMonthIndex <= 0)

                    Spacer()

                    // Month info
                    VStack(spacing: 4) {
                        if selectedCardMonthIndex < months.count {
                            Text(monthYearString(from: months[selectedCardMonthIndex]))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)

                            Text(CurrencyUtils.format(monthTotal))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.accentRed)

                            Text("\(currentMonthTxs.count) \(currentMonthTxs.count == 1 ? "transação" : "transações")")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    Spacer()

                    // Next (older months)
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selectedCardMonthIndex < months.count - 1 {
                                selectedCardMonthIndex += 1
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(selectedCardMonthIndex < months.count - 1 ? AppColors.accentBlue : AppColors.textTertiary)
                            .frame(width: 36, height: 36)
                            .background(AppColors.bgTertiary)
                            .cornerRadius(10)
                    }
                    .disabled(selectedCardMonthIndex >= months.count - 1)
                }

                // Month indicators (dots)
                if months.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<min(months.count, 5), id: \.self) { index in
                            Circle()
                                .fill(index == selectedCardMonthIndex ? AppColors.accentBlue : AppColors.textTertiary.opacity(0.5))
                                .frame(width: index == selectedCardMonthIndex ? 8 : 6, height: index == selectedCardMonthIndex ? 8 : 6)
                                .animation(.spring(response: 0.2), value: selectedCardMonthIndex)
                        }
                        if months.count > 5 {
                            Text("+\(months.count - 5)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
            }
            .padding(16)
            .background(AppColors.bgSecondary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )

            // Transactions list
            VStack(spacing: 12) {
                if currentMonthTxs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "creditcard.and.123")
                            .font(.system(size: 40))
                            .foregroundColor(AppColors.textTertiary)

                        Text("Sem transações neste mês")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(currentMonthTxs, id: \.id) { transaction in
                            Button {
                                selectedTransaction = transactionToViewModel(transaction)
                            } label: {
                                TransactionRowCard(transaction: transactionToViewModel(transaction))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var transactionFilterPicker: some View {
        HStack(spacing: 12) {
            ForEach(TransactionFilterMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        transactionFilterMode = mode
                        selectedMonthIndex = 0  // Reset to current month
                        if mode == .all {
                            selectedFilterCard = nil
                        }
                    }
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }) {
                    Text(mode.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(transactionFilterMode == mode ? .white : AppColors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            transactionFilterMode == mode ? AppColors.accentBlue : Color.clear
                        )
                        .cornerRadius(20)
                }
            }

            Spacer()
        }
    }

    private var transactionsEmptyState: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 40)

            ZStack {
                Circle()
                    .fill(AppColors.accentBlue.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "creditcard.and.123")
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.accentBlue)
            }

            VStack(spacing: 8) {
                Text("Sem transações")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)

                Text("Adicione transações usando\nseus cartões de crédito")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
                .frame(height: 40)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(AppColors.bgSecondary)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }

    private var transactionsList: some View {
        VStack(spacing: 0) {
            // Month navigation header
            monthNavigationHeader

            // Transactions list with swipe gesture
            transactionsMonthView
        }
    }

    private var monthNavigationHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Previous month button (goes to newer months - back in list)
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if selectedMonthIndex > 0 {
                            selectedMonthIndex -= 1
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selectedMonthIndex > 0 ? AppColors.accentBlue : AppColors.textTertiary)
                        .frame(width: 36, height: 36)
                        .background(AppColors.bgTertiary)
                        .cornerRadius(10)
                }
                .disabled(selectedMonthIndex <= 0)

                Spacer()

                // Current month name
                VStack(spacing: 4) {
                    if selectedMonthIndex < availableMonths.count {
                        Text(monthYearString(from: availableMonths[selectedMonthIndex]))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)

                        Text(CurrencyUtils.format(totalForSelectedMonth))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentRed)

                        Text("\(transactionsForSelectedMonth.count) \(transactionsForSelectedMonth.count == 1 ? "transação" : "transações")")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                // Next month button (goes to older months - forward in list)
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if selectedMonthIndex < availableMonths.count - 1 {
                            selectedMonthIndex += 1
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selectedMonthIndex < availableMonths.count - 1 ? AppColors.accentBlue : AppColors.textTertiary)
                        .frame(width: 36, height: 36)
                        .background(AppColors.bgTertiary)
                        .cornerRadius(10)
                }
                .disabled(selectedMonthIndex >= availableMonths.count - 1)
            }

            // Month indicators (dots)
            if availableMonths.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<min(availableMonths.count, 5), id: \.self) { index in
                        Circle()
                            .fill(index == selectedMonthIndex ? AppColors.accentBlue : AppColors.textTertiary.opacity(0.5))
                            .frame(width: index == selectedMonthIndex ? 8 : 6, height: index == selectedMonthIndex ? 8 : 6)
                            .animation(.spring(response: 0.2), value: selectedMonthIndex)
                    }
                    if availableMonths.count > 5 {
                        Text("+\(availableMonths.count - 5)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        }
        .padding(16)
        .background(AppColors.bgSecondary)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }

    private var transactionsMonthView: some View {
        VStack(spacing: 12) {
            if transactionsForSelectedMonth.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "creditcard.and.123")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.textTertiary)

                    Text("Sem transações neste mês")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(transactionsForSelectedMonth, id: \.id) { transaction in
                        Button {
                            selectedTransaction = transactionToViewModel(transaction)
                        } label: {
                            CardTransactionRow(
                                transaction: transaction,
                                card: cardForTransaction(transaction)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.top, 16)
    }

    private func monthHeader(_ date: Date) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(AppColors.cardBorder)
                .frame(height: 1)

            Text(monthYearString(from: date))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textSecondary)
                .textCase(.uppercase)

            Rectangle()
                .fill(AppColors.cardBorder)
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "MMMM 'de' yyyy"
        let result = formatter.string(from: date)
        // Capitalizar apenas a primeira letra do mês
        return result.prefix(1).uppercased() + result.dropFirst()
    }

    private func groupedTransactionsByMonth(_ transactions: [Transaction]) -> [(month: Date, transactions: [Transaction])] {
        let calendar = Calendar.current

        // Group by year-month
        let grouped = Dictionary(grouping: transactions) { transaction -> Date in
            let components = calendar.dateComponents([.year, .month], from: transaction.date)
            return calendar.date(from: components) ?? transaction.date
        }

        // Sort by month descending (most recent first) and sort transactions within each group by date descending
        return grouped.map { (month: $0.key, transactions: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.month > $1.month }
    }

    private var transactionsGroupedByCard: some View {
        LazyVStack(spacing: 12) {
            ForEach(creditCards) { card in
                let cardTxs = cardTransactions.filter { $0.creditCardId == card.id }

                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedFilterCard = card
                        selectedCardMonthIndex = 0  // Reset to current month
                    }
                }) {
                    HStack(spacing: 12) {
                        MiniCardIcon(card: card)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.cardName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)

                            Text("\(cardTxs.count) \(cardTxs.count == 1 ? "transação" : "transações")")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(16)
                    .background(AppColors.bgSecondary)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Installments View

    private var installmentsContentView: some View {
        VStack(spacing: 16) {
            // Filter Picker
            installmentFilterPicker

            if installmentFilterMode == .all {
                // Installments for current month
                let monthInstallments = installmentsForCurrentMonth
                let totalInstallmentsAmount = monthInstallments.reduce(0.0) { $0 + $1.installmentAmount }
                let uniqueTransactions = Set(monthInstallments.map { $0.transactionId }).count

                // Month navigation with total and count
                installmentsMonthNavigationView(totalAmount: totalInstallmentsAmount, itemCount: uniqueTransactions)

                if monthInstallments.isEmpty {
                    installmentsEmptyState
                } else {
                    // Installments list
                    LazyVStack(spacing: 12) {
                        ForEach(monthInstallments, id: \.id) { item in
                            Button {
                                selectedInstallmentItem = item
                            } label: {
                                InstallmentRowCard(item: item, card: creditCards.first { $0.id == item.creditCardId })
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                // "Por Cartão" mode
                if let selectedCard = selectedInstallmentCard {
                    // Show selected card's installments
                    selectedCardInstallmentsView(card: selectedCard)
                } else {
                    // Show cards grid
                    installmentsGroupedByCard
                }
            }
        }
        .onAppear {
            loadTransactions()
            loadCategories()
        }
    }

    private var installmentFilterPicker: some View {
        HStack(spacing: 12) {
            ForEach(InstallmentFilterMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        installmentFilterMode = mode
                        installmentsMonthOffset = 0
                        if mode == .all {
                            selectedInstallmentCard = nil
                        }
                    }
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }) {
                    Text(mode.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(installmentFilterMode == mode ? .white : AppColors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            installmentFilterMode == mode ? AppColors.accentBlue : Color.clear
                        )
                        .cornerRadius(20)
                }
            }

            Spacer()
        }
    }

    private var installmentsGroupedByCard: some View {
        LazyVStack(spacing: 12) {
            ForEach(creditCards) { card in
                let cardInstallments = cardTransactions.filter {
                    $0.creditCardId == card.id &&
                    $0.installments != nil &&
                    $0.installments! > 1
                }

                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedInstallmentCard = card
                        installmentsMonthOffset = 0
                    }
                }) {
                    HStack(spacing: 12) {
                        MiniCardIcon(card: card)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.cardName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)

                            Text("\(cardInstallments.count) \(cardInstallments.count == 1 ? "parcelamento" : "parcelamentos")")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(16)
                    .background(AppColors.bgSecondary)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func selectedCardInstallmentsView(card: CreditCard) -> some View {
        VStack(spacing: 16) {
            // Header with back button and card info
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedInstallmentCard = nil
                        installmentsMonthOffset = 0
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.accentBlue)
                        .frame(width: 36, height: 36)
                        .background(AppColors.bgTertiary)
                        .cornerRadius(10)
                }

                MiniCardIcon(card: card)

                Text(card.cardName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()
            }
            .padding(16)
            .background(AppColors.bgSecondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )

            // Installments for this card
            let cardInstallments = installmentsForCurrentMonth.filter { $0.creditCardId == card.id }
            let totalAmount = cardInstallments.reduce(0.0) { $0 + $1.installmentAmount }
            let uniqueTransactions = Set(cardInstallments.map { $0.transactionId }).count

            // Month navigation with total and count
            installmentsMonthNavigationView(totalAmount: totalAmount, itemCount: uniqueTransactions)

            if cardInstallments.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.textTertiary)

                    Text("Sem parcelas neste mês")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(cardInstallments, id: \.id) { item in
                        Button {
                            selectedInstallmentItem = item
                        } label: {
                            InstallmentRowCard(item: item, card: card)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func installmentsMonthNavigationView(totalAmount: Double, itemCount: Int) -> some View {
        let currentMonth = installmentsDisplayMonth

        return VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Previous month
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        installmentsMonthOffset -= 1
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.accentBlue)
                        .frame(width: 36, height: 36)
                        .background(AppColors.bgTertiary)
                        .cornerRadius(10)
                }

                Spacer()

                // Month display with total and count
                VStack(spacing: 4) {
                    Text(monthYearString(from: currentMonth))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Text(CurrencyUtils.format(totalAmount))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.expense)

                    Text("\(itemCount) \(itemCount == 1 ? "parcelamento" : "parcelamentos")")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Next month
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        installmentsMonthOffset += 1
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.accentBlue)
                        .frame(width: 36, height: 36)
                        .background(AppColors.bgTertiary)
                        .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .background(AppColors.bgSecondary)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }

    private var installmentsEmptyState: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 20)

            ZStack {
                Circle()
                    .fill(AppColors.accentBlue.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.accentBlue)
            }

            VStack(spacing: 8) {
                Text("Sem parcelas neste mês")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)

                Text("Compras parceladas no cartão\naparecerão aqui")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
                .frame(height: 20)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(AppColors.bgSecondary)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Installment Computed Properties

    private var installmentsDisplayMonth: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .month, value: installmentsMonthOffset, to: Date()) ?? Date()
    }

    private var installmentsForCurrentMonth: [InstallmentItem] {
        let displayMonth = installmentsDisplayMonth
        var items: [InstallmentItem] = []

        // Get all transactions with installments
        let installmentTransactions = cardTransactions.filter { $0.installments != nil && $0.installments! > 1 }

        for transaction in installmentTransactions {
            guard let totalInstallments = transaction.installments else { continue }
            let startingInstallment = transaction.startingInstallment ?? 1
            let installmentAmount = transaction.amountDouble / Double(totalInstallments)

            // Get the card's closing day
            let card = creditCards.first { $0.id == transaction.creditCardId }
            let closingDay = card?.closingDay ?? 1

            // Calculate which installment appears in the display month
            let installmentForMonth = calculateInstallmentForMonth(
                transactionDate: transaction.date,
                closingDay: closingDay,
                displayMonth: displayMonth,
                totalInstallments: totalInstallments,
                startingInstallment: startingInstallment
            )

            if let installmentNumber = installmentForMonth {
                // Fetch category directly from repository to avoid timing/state issues
                let category: Category? = {
                    guard let categoryId = transaction.categoryId else { return nil }
                    return categoryRepo.getCategory(id: categoryId)
                }()

                // Use category color if available, otherwise fallback to a neutral color
                let categoryColor = category?.color ?? AppColors.textSecondary
                let categoryIcon = category?.iconName ?? "tag.fill"

                items.append(InstallmentItem(
                    id: "\(transaction.id)-\(installmentNumber)",
                    transactionId: transaction.id,
                    description: transaction.desc,
                    installmentAmount: installmentAmount,
                    totalAmount: transaction.amountDouble,
                    currentInstallment: installmentNumber,
                    totalInstallments: totalInstallments,
                    creditCardId: transaction.creditCardId,
                    categoryName: category?.name,
                    categoryColor: categoryColor,
                    categoryIcon: categoryIcon
                ))
            }
        }

        return items.sorted { $0.description < $1.description }
    }

    private func calculateInstallmentForMonth(
        transactionDate: Date,
        closingDay: Int,
        displayMonth: Date,
        totalInstallments: Int,
        startingInstallment: Int
    ) -> Int? {
        let calendar = Calendar.current

        // Determine the first billing month based on transaction date and closing day
        let transactionDay = calendar.component(.day, from: transactionDate)
        var firstBillingMonth: Date

        if transactionDay <= closingDay {
            // Transaction is before closing, first installment is in this month's bill
            let components = calendar.dateComponents([.year, .month], from: transactionDate)
            firstBillingMonth = calendar.date(from: components) ?? transactionDate
        } else {
            // Transaction is after closing, first installment is in next month's bill
            let components = calendar.dateComponents([.year, .month], from: transactionDate)
            firstBillingMonth = calendar.date(from: components) ?? transactionDate
            firstBillingMonth = calendar.date(byAdding: .month, value: 1, to: firstBillingMonth) ?? firstBillingMonth
        }

        // Calculate months between first billing month and display month
        let displayComponents = calendar.dateComponents([.year, .month], from: displayMonth)
        let displayMonthStart = calendar.date(from: displayComponents) ?? displayMonth

        let monthsDiff = calendar.dateComponents([.month], from: firstBillingMonth, to: displayMonthStart).month ?? 0

        // Calculate which installment number this would be
        let installmentNumber = startingInstallment + monthsDiff

        // Check if this installment exists
        if installmentNumber >= startingInstallment && installmentNumber <= totalInstallments {
            return installmentNumber
        }

        return nil
    }

    private func addExistingInstallment(
        cardId: String,
        description: String,
        totalAmount: Decimal,
        totalInstallments: Int,
        startingInstallment: Int,
        date: Date,
        categoryId: String?
    ) {
        guard let userId = authManager.userId else { return }

        _ = transactionRepo.createTransaction(
            userId: userId,
            type: .expense,
            amount: totalAmount,
            date: date,
            description: description,
            categoryId: categoryId,
            creditCardId: cardId,
            installments: totalInstallments,
            startingInstallment: startingInstallment
        )

        loadTransactions()
        loadCategories()
    }

    private func loadCards() {
        guard let userId = authManager.userId else { return }
        creditCards = cardRepo.getCreditCards(userId: userId)
    }

    private func loadTransactions() {
        guard let userId = authManager.userId else { return }
        cardTransactions = transactionRepo.getCreditCardTransactions(userId: userId)
    }

    private var filteredTransactions: [Transaction] {
        // Excluir parcelamentos (installments > 1)
        let nonInstallmentTransactions = cardTransactions.filter {
            $0.installments == nil || $0.installments! <= 1
        }
        if let card = selectedFilterCard {
            return nonInstallmentTransactions.filter { $0.creditCardId == card.id }
        }
        return nonInstallmentTransactions
    }

    private func cardForTransaction(_ transaction: Transaction) -> CreditCard? {
        guard let cardId = transaction.creditCardId else { return nil }
        return creditCards.first { $0.id == cardId }
    }

    private func categoryForTransaction(_ transaction: Transaction) -> Category? {
        guard let categoryId = transaction.categoryId else { return nil }
        return categories.first { $0.id == categoryId }
    }

    private func loadCategories() {
        guard let userId = authManager.userId else { return }
        categories = categoryRepo.getCategories(userId: userId)
    }

    private func transactionToViewModel(_ transaction: Transaction) -> TransactionItemViewModel {
        let category = categoryForTransaction(transaction)
        return TransactionItemViewModel(
            id: transaction.id,
            description: transaction.desc,
            amount: transaction.amountDouble,
            amountFormatted: CurrencyUtils.format(transaction.amountDouble),
            date: transaction.date,
            dateFormatted: transaction.date.shortFormatted,
            type: transaction.type,
            categoryName: category?.name,
            categoryColor: category?.color ?? .gray,
            categoryIcon: category?.iconName ?? "tag.fill",
            needsUserReview: transaction.needsUserReview,
            isPendingSync: transaction.isPendingSync,
            locationName: transaction.locationName,
            latitude: transaction.latitude,
            longitude: transaction.longitude,
            cityName: transaction.cityName,
            notes: transaction.notes,
            categoryId: transaction.categoryId
        )
    }

    private func deleteTransaction(_ transactionId: String) {
        guard let transaction = cardTransactions.first(where: { $0.id == transactionId }) else { return }
        transactionRepo.deleteTransaction(transaction)
        loadTransactions()
    }

    private func updateTransaction(
        transactionId: String,
        description: String,
        amount: Decimal,
        date: Date,
        type: TransactionType,
        categoryId: String?,
        notes: String? = nil
    ) {
        guard let transaction = cardTransactions.first(where: { $0.id == transactionId }) else { return }
        transactionRepo.updateTransaction(
            transaction,
            description: description,
            amount: amount,
            date: date,
            type: type,
            categoryId: categoryId,
            notes: notes
        )
        loadTransactions()
    }

    private func updateInstallment(
        transactionId: String,
        description: String,
        totalAmount: Decimal,
        totalInstallments: Int,
        currentInstallment: Int,
        categoryId: String?
    ) {
        guard let transaction = cardTransactions.first(where: { $0.id == transactionId }) else { return }

        // Calculate installment amount
        let installmentAmount = totalAmount / Decimal(totalInstallments)

        transaction.desc = description
        transaction.amount = installmentAmount
        transaction.installments = totalInstallments
        transaction.startingInstallment = currentInstallment
        if let categoryId = categoryId {
            transaction.categoryId = categoryId
        }
        transaction.markAsModified()

        do {
            try SwiftDataStack.shared.context.save()
            print("💾 [CreditCard] Parcelamento atualizado: \(description)")
        } catch {
            print("❌ [CreditCard] Erro ao atualizar parcelamento: \(error)")
        }

        loadTransactions()
    }
}

// MARK: - Mini Card Icon

struct MiniCardIcon: View {
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
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: cardColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 24)

            // Chip
            RoundedRectangle(cornerRadius: 1)
                .fill(LinearGradient(colors: [.yellow.opacity(0.8), .orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 6, height: 4)
                .offset(x: -10, y: 2)
        }
    }
}

// MARK: - Card Transaction Row

struct CardTransactionRow: View {
    let transaction: Transaction
    let card: CreditCard?

    private var formattedAmount: String {
        CurrencyUtils.format(Double(truncating: transaction.amount as NSDecimalNumber))
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: transaction.date)
    }

    private var cardColors: [Color] {
        guard let card = card else { return [.gray, .gray.opacity(0.7)] }
        if let match = AvailableBankCards.cards(forBank: card.bankEnum).first(where: { $0.tier == card.cardTypeEnum }) {
            if let color = Color(hex: match.cardColor) {
                return [color, color.opacity(0.7)]
            }
        }
        return card.cardTypeEnum.gradientColors
    }

    var body: some View {
        HStack(spacing: 12) {
            // Mini Card Icon
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: cardColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 26)

                // Chip
                RoundedRectangle(cornerRadius: 1)
                    .fill(LinearGradient(colors: [.yellow.opacity(0.8), .orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 6, height: 4)
                    .offset(x: -12, y: 3)
            }

            // Transaction Info
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.desc)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let card = card {
                        Text(card.cardName)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Text("•")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)

                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            // Amount + chevron
            HStack(spacing: 4) {
                Text(formattedAmount)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary.opacity(0.5))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color.white.opacity(0.001))
        .contentShape(Rectangle())
    }
}

// MARK: - Card Transaction Row Compact

struct CardTransactionRowCompact: View {
    let transaction: Transaction

    private var formattedAmount: String {
        CurrencyUtils.format(Double(truncating: transaction.amount as NSDecimalNumber))
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: transaction.date)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Date
            Text(formattedDate)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 40)

            // Description
            Text(transaction.desc)
                .font(.subheadline)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)

            Spacer()

            // Amount
            Text(formattedAmount)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.accentRed)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(AppColors.bgTertiary.opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - Credit Card Detail View

struct CreditCardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let card: CreditCard
    let onUpdate: () -> Void
    let onEdit: (CreditCard) -> Void

    private let cardRepo = CreditCardRepository.shared

    // Get the card type name (e.g., "Ultravioleta" instead of "Black")
    private var cardTypeName: String {
        if let bankCard = AvailableBankCards.cards(forBank: card.bankEnum).first(where: { $0.tier == card.cardTypeEnum }) {
            return bankCard.name
        }
        return card.cardTypeEnum.rawValue
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 24) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(AppColors.bgSecondary)
                            .cornerRadius(10)
                    }

                    Spacer()

                    Text(card.cardName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Button(action: {
                        onEdit(card)
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.accentBlue)
                            .frame(width: 36, height: 36)
                            .background(AppColors.bgSecondary)
                            .cornerRadius(10)
                    }
                }
                .padding()

                // Card visual
                CreditCardVisual(
                    cardName: card.cardName,
                    holderName: card.holderName.uppercased(),
                    lastFourDigits: card.lastFourDigits,
                    brand: card.brandEnum,
                    cardType: card.cardTypeEnum,
                    bank: card.bankEnum,
                    bankCard: AvailableBankCards.cards(forBank: card.bankEnum).first(where: { $0.tier == card.cardTypeEnum })
                )
                .padding(.horizontal)

                // Detalhes
                VStack(spacing: 16) {
                    detailRow(title: "Banco", value: card.bankEnum.rawValue)
                    detailRow(title: "Bandeira", value: card.brandEnum.rawValue)
                    detailRow(title: "Tipo", value: cardTypeName)
                    detailRow(title: "Fechamento", value: "Dia \(card.closingDay)")
                    detailRow(title: "Vencimento", value: "Dia \(card.paymentDay)")
                    if card.limitAmount > 0 {
                        detailRow(title: "Limite", value: card.formattedLimit)
                    }
                }
                .padding()
                .background(AppColors.bgSecondary)
                .cornerRadius(16)
                .padding(.horizontal)

                Spacer()

                // Botões de ação
                VStack(spacing: 12) {
                    AppButton(title: "Editar Cartão", icon: "pencil", style: .secondary) {
                        onEdit(card)
                    }

                    AppButton(title: "Remover Cartão", icon: "trash", style: .danger) {
                        cardRepo.deleteCreditCard(card)
                        onUpdate()
                        dismiss()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        ZStack {
            // Background
            AppBackground()

            ScrollView {
                VStack(spacing: 24) {
                    // Header com avatar (mesmo estilo da página resumo)
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)

                            Text(authManager.userName?.prefix(1).uppercased() ?? "U")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }

                        VStack(spacing: 4) {
                            Text(authManager.userName ?? "Usuário")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)

                            HStack(spacing: 6) {
                                Circle()
                                    .fill(AppColors.accentGreen)
                                    .frame(width: 8, height: 8)

                                Text("Conta ativa")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.accentGreen)
                            }
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                    // Seção Configurações
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Configurações")

                        VStack(spacing: 8) {
                            SettingsCard(
                                icon: "person.fill",
                                title: "Editar perfil",
                                subtitle: "Nome e foto",
                                iconColor: .blue
                            )

                            SettingsCard(
                                icon: "lock.fill",
                                title: "Trocar senha",
                                subtitle: "Alterar sua senha",
                                iconColor: .orange
                            )

                            SettingsCard(
                                icon: "envelope.fill",
                                title: "Trocar email",
                                subtitle: "Alterar seu email",
                                iconColor: .purple
                            )
                        }
                    }

                    // Seção Sobre
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Sobre")

                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AppColors.textSecondary.opacity(0.15))
                                    .frame(width: 40, height: 40)

                                Image(systemName: "info.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Text("Versão")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textPrimary)

                            Spacer()

                            Text("v0.0.1")
                                .font(.body)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(16)
                        .background(AppColors.bgSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        )
                        .cornerRadius(16)
                    }

                    // Botão de logout
                    AppButton(
                        title: "Sair da conta",
                        icon: "rectangle.portrait.and.arrow.right",
                        style: .danger
                    ) {
                        authManager.logout()
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
        }
    }
}

// MARK: - Installment Item Model

struct InstallmentItem: Identifiable {
    let id: String
    let transactionId: String
    let description: String
    let installmentAmount: Double  // Valor da parcela
    let totalAmount: Double        // Valor total da compra
    let currentInstallment: Int
    let totalInstallments: Int
    let creditCardId: String?
    let categoryName: String?
    let categoryColor: Color
    let categoryIcon: String
}

// MARK: - Installment Row Card

struct InstallmentRowCard: View {
    let item: InstallmentItem
    let card: CreditCard?

    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(item.categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: item.categoryIcon)
                    .font(.system(size: 16))
                    .foregroundColor(item.categoryColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.description)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    // Installment info
                    Text("\(item.currentInstallment)/\(item.totalInstallments)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.accentBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColors.accentBlue.opacity(0.15))
                        .cornerRadius(6)

                    // Card name with separator
                    if let card = card {
                        Circle()
                            .fill(AppColors.textTertiary)
                            .frame(width: 4, height: 4)

                        Text(card.cardName)
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }

            Spacer()

            // Amount + chevron
            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(CurrencyUtils.format(item.installmentAmount))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)

                    Text("Total: \(CurrencyUtils.format(item.totalAmount))")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary.opacity(0.5))
            }
        }
        .padding(16)
        .background(AppColors.bgSecondary)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Installment Detail Sheet

struct InstallmentDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    let item: InstallmentItem
    let card: CreditCard?
    let onDelete: () -> Void
    var onEdit: ((String, Decimal, Int, Int, String?) -> Void)? = nil

    @State private var showDeleteConfirmation = false
    @State private var showingEditSheet = false

    private var totalAmount: Double {
        item.installmentAmount * Double(item.totalInstallments)
    }

    private var paidAmount: Double {
        item.installmentAmount * Double(item.currentInstallment - 1)
    }

    private var remainingAmount: Double {
        item.installmentAmount * Double(item.totalInstallments - item.currentInstallment + 1)
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(AppColors.bgSecondary)
                            .cornerRadius(10)
                    }

                    Spacer()

                    Text("Detalhes do Parcelamento")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    // Edit button
                    if onEdit != nil {
                        Button(action: { showingEditSheet = true }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.accentBlue)
                                .frame(width: 36, height: 36)
                                .background(AppColors.bgSecondary)
                                .cornerRadius(10)
                        }
                    } else {
                        Color.clear
                            .frame(width: 36, height: 36)
                    }
                }
                .padding()

                ScrollView {
                    VStack(spacing: 24) {
                        // Main Card
                        VStack(spacing: 20) {
                            // Category Icon
                            ZStack {
                                Circle()
                                    .fill(item.categoryColor.opacity(0.15))
                                    .frame(width: 64, height: 64)

                                Image(systemName: item.categoryIcon)
                                    .font(.system(size: 24))
                                    .foregroundColor(item.categoryColor)
                            }

                            // Description
                            Text(item.description)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)
                                .multilineTextAlignment(.center)

                            // Installment Badge
                            HStack(spacing: 8) {
                                Text("Parcela")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textSecondary)

                                Text("\(item.currentInstallment)/\(item.totalInstallments)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.accentBlue)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(AppColors.accentBlue.opacity(0.1))
                            .cornerRadius(20)

                            // Installment Amount
                            VStack(spacing: 4) {
                                Text("Valor da Parcela")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)

                                Text(CurrencyUtils.format(item.installmentAmount))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.expense)
                            }
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(AppColors.bgSecondary)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        )

                        // Details Card
                        VStack(spacing: 16) {
                            // Card Info
                            if let card = card {
                                HStack(spacing: 12) {
                                    MiniCardIcon(card: card)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Cartão")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textSecondary)

                                        Text(card.cardName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(AppColors.textPrimary)
                                    }

                                    Spacer()
                                }

                                Divider().background(AppColors.cardBorder)
                            }

                            // Category
                            if let categoryName = item.categoryName {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(item.categoryColor.opacity(0.15))
                                            .frame(width: 36, height: 36)

                                        Image(systemName: item.categoryIcon)
                                            .font(.system(size: 14))
                                            .foregroundColor(item.categoryColor)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Categoria")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textSecondary)

                                        Text(categoryName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(AppColors.textPrimary)
                                    }

                                    Spacer()
                                }

                                Divider().background(AppColors.cardBorder)
                            }

                            // Total Amount
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Valor Total")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)

                                    Text(CurrencyUtils.format(totalAmount))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.textPrimary)
                                }

                                Spacer()
                            }

                            Divider().background(AppColors.cardBorder)

                            // Progress
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Progresso")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)

                                    Spacer()

                                    Text("\(item.currentInstallment - 1) de \(item.totalInstallments) pagas")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(AppColors.bgTertiary)
                                            .frame(height: 8)

                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(AppColors.accentGreen)
                                            .frame(width: geo.size.width * CGFloat(item.currentInstallment - 1) / CGFloat(item.totalInstallments), height: 8)
                                    }
                                }
                                .frame(height: 8)

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Pago")
                                            .font(.caption2)
                                            .foregroundColor(AppColors.textTertiary)
                                        Text(CurrencyUtils.format(paidAmount))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(AppColors.accentGreen)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("Restante")
                                            .font(.caption2)
                                            .foregroundColor(AppColors.textTertiary)
                                        Text(CurrencyUtils.format(remainingAmount))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(AppColors.expense)
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(AppColors.bgSecondary)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        )

                        // Delete Button
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                Text("Excluir Parcelamento")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.expense)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColors.expense.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
            }
        }
        .confirmationDialog("Excluir Parcelamento", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Excluir", role: .destructive) {
                onDelete()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta ação excluirá todas as parcelas deste parcelamento. Deseja continuar?")
        }
        .sheet(isPresented: $showingEditSheet) {
            EditInstallmentSheet(
                item: item,
                card: card,
                onSave: { desc, amount, totalInstallments, currentInstallment, categoryId in
                    onEdit?(desc, amount, totalInstallments, currentInstallment, categoryId)
                    showingEditSheet = false
                    dismiss()
                }
            )
        }
    }
}

// MARK: - Edit Installment Sheet

struct EditInstallmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    let item: InstallmentItem
    let card: CreditCard?
    let onSave: (String, Decimal, Int, Int, String?) -> Void

    @State private var name: String
    @State private var totalAmountText: String
    @State private var totalInstallments: Int
    @State private var currentInstallment: Int
    @State private var selectedCategory: Category?
    @State private var categories: [Category] = []

    // AI Categorization
    @State private var isAILoading = false
    @State private var aiSuggestion: TransactionCategorySuggestion?
    @State private var aiDebounceTask: Task<Void, Never>?

    // Custom category
    @State private var isCustomCategory = false
    @State private var customCategoryName = ""
    @State private var customCategoryIcon = "tag.fill"
    @State private var customCategoryColorHex = "#14B8A6"
    @State private var showingIconPicker = false
    @State private var showingColorPicker = false

    private let categoryRepo = CategoryRepository.shared
    private let categorizationService = TransactionCategorizationService.shared

    init(item: InstallmentItem, card: CreditCard?, onSave: @escaping (String, Decimal, Int, Int, String?) -> Void) {
        self.item = item
        self.card = card
        self.onSave = onSave

        let totalAmount = item.installmentAmount * Double(item.totalInstallments)
        _name = State(initialValue: item.description)
        _totalAmountText = State(initialValue: String(format: "%.2f", totalAmount).replacingOccurrences(of: ".", with: ","))
        _totalInstallments = State(initialValue: item.totalInstallments)
        _currentInstallment = State(initialValue: item.currentInstallment)
    }

    private var totalAmount: Decimal {
        let cleanText = totalAmountText
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Decimal(string: cleanText) ?? 0
    }

    private var installmentAmount: Decimal {
        guard totalInstallments > 0 else { return 0 }
        return totalAmount / Decimal(totalInstallments)
    }

    private var isValid: Bool {
        let categoryValid = !isCustomCategory || !customCategoryName.isEmpty
        return !name.isEmpty && totalAmount > 0 && totalInstallments > 1 && currentInstallment >= 1 && currentInstallment <= totalInstallments && categoryValid
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(AppColors.bgSecondary)
                            .cornerRadius(10)
                    }

                    Spacer()

                    Text("Editar Parcelamento")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Button {
                        saveInstallment()
                    } label: {
                        Text("Salvar")
                            .fontWeight(.semibold)
                            .foregroundColor(isValid ? AppColors.accentBlue : AppColors.textTertiary)
                    }
                    .disabled(!isValid)
                }
                .padding()

                ScrollView {
                    VStack(spacing: 20) {
                        // Card Info (read-only)
                        if let card = card {
                            HStack(spacing: 12) {
                                MiniCardIcon(card: card)

                                Text(card.cardName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.textPrimary)

                                Spacer()

                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(16)
                            .background(AppColors.bgSecondary)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.cardBorder, lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }

                        // Nome
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nome")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            AppTextField(
                                icon: "bag",
                                placeholder: "Ex: iPhone 15, Geladeira, etc.",
                                text: $name,
                                autocapitalization: .sentences
                            )
                            .onChange(of: name) { _, newValue in
                                updateAISuggestion(for: newValue)
                            }

                            // AI Loading indicator
                            if isAILoading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                        .scaleEffect(0.8)

                                    Text("IA analisando...")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)

                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: isAILoading)
                        .padding(.horizontal)

                        // Categoria
                        editCategorySection
                            .padding(.horizontal)

                        // Valor Total
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Valor Total")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            HStack(spacing: 8) {
                                Text("R$")
                                    .font(.headline)
                                    .foregroundColor(AppColors.textSecondary)

                                TextField("0,00", text: $totalAmountText)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.textPrimary)
                                    .keyboardType(.decimalPad)
                                    .onChange(of: totalAmountText) { _, newValue in
                                        totalAmountText = formatCurrencyInput(newValue)
                                    }
                            }
                            .padding(16)
                            .background(AppColors.bgSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.cardBorder, lineWidth: 1)
                            )
                            .cornerRadius(16)
                        }
                        .padding(.horizontal)

                        // Installments
                        HStack(spacing: 12) {
                            // Parcelas Pagas
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Parcelas Pagas")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.textSecondary)

                                HStack {
                                    Button(action: {
                                        if currentInstallment > 1 {
                                            currentInstallment -= 1
                                        }
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(currentInstallment > 1 ? AppColors.accentBlue : AppColors.textTertiary)
                                    }
                                    .disabled(currentInstallment <= 1)

                                    Text("\(currentInstallment - 1)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.textPrimary)
                                        .frame(minWidth: 50)

                                    Button(action: {
                                        if currentInstallment < totalInstallments {
                                            currentInstallment += 1
                                        }
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(currentInstallment < totalInstallments ? AppColors.accentBlue : AppColors.textTertiary)
                                    }
                                    .disabled(currentInstallment >= totalInstallments)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity)
                                .background(AppColors.bgSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(AppColors.cardBorder, lineWidth: 1)
                                )
                                .cornerRadius(16)
                            }

                            // Total de Parcelas
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Total de Parcelas")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.textSecondary)

                                HStack {
                                    Button(action: {
                                        if totalInstallments > 2 {
                                            totalInstallments -= 1
                                            if currentInstallment > totalInstallments {
                                                currentInstallment = totalInstallments
                                            }
                                        }
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(totalInstallments > 2 ? AppColors.accentBlue : AppColors.textTertiary)
                                    }
                                    .disabled(totalInstallments <= 2)

                                    Text("\(totalInstallments)x")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.textPrimary)
                                        .frame(minWidth: 50)

                                    Button(action: {
                                        if totalInstallments < 48 {
                                            totalInstallments += 1
                                        }
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(totalInstallments < 48 ? AppColors.accentBlue : AppColors.textTertiary)
                                    }
                                    .disabled(totalInstallments >= 48)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity)
                                .background(AppColors.bgSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(AppColors.cardBorder, lineWidth: 1)
                                )
                                .cornerRadius(16)
                            }
                        }
                        .padding(.horizontal)

                        // Installment Preview
                        if totalAmount > 0 {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Valor por parcela")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)

                                    Spacer()

                                    Text(CurrencyUtils.format(installmentAmount))
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.accentBlue)
                                }

                                HStack {
                                    Text("Parcelas restantes")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)

                                    Spacer()

                                    Text("\(totalInstallments - currentInstallment + 1) de \(totalInstallments)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColors.textPrimary)
                                }
                            }
                            .padding(16)
                            .background(AppColors.accentBlue.opacity(0.1))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .onAppear {
            loadCategories()
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerSheet(selectedIcon: $customCategoryIcon)
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerSheet(selectedColorHex: $customCategoryColorHex)
        }
    }

    // MARK: - Category Section

    private var editCategorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Categoria")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)

            // AI Suggestion Banner
            if let suggestion = aiSuggestion, suggestion.confidence != .none, !isCustomCategory {
                editAISuggestionBanner(suggestion)
            }

            // Category Selector or Custom Category
            if isCustomCategory {
                editCustomCategorySection
            } else {
                Menu {
                    // Existing categories
                    ForEach(categories) { cat in
                        Button(action: {
                            selectedCategory = cat
                            isCustomCategory = false
                        }) {
                            HStack {
                                Image(systemName: cat.iconName)
                                Text(cat.name)
                                if selectedCategory?.id == cat.id && !isCustomCategory {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    Divider()

                    // Custom category option
                    Button(action: {
                        isCustomCategory = true
                        selectedCategory = nil
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Criar categoria personalizada")
                        }
                    }
                } label: {
                    HStack {
                        if let category = selectedCategory {
                            ZStack {
                                Circle()
                                    .fill(category.color.opacity(0.2))
                                    .frame(width: 32, height: 32)

                                Image(systemName: category.iconName)
                                    .font(.system(size: 14))
                                    .foregroundColor(category.color)
                            }

                            Text(category.name)
                                .foregroundColor(AppColors.textPrimary)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(AppColors.textSecondary.opacity(0.2))
                                    .frame(width: 32, height: 32)

                                Image(systemName: "tag")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Text("Selecionar categoria")
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(16)
                    .background(AppColors.bgSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
                    .cornerRadius(16)
                }
            }
        }
    }

    // MARK: - AI Suggestion Banner

    private func editAISuggestionBanner(_ suggestion: TransactionCategorySuggestion) -> some View {
        let accentColor: Color = suggestion.isFromServer ? .blue : .purple

        return Button(action: {
            applySuggestion(suggestion)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.2))
                        .frame(width: 36, height: 36)

                    Image(systemName: suggestion.displayIcon)
                        .font(.system(size: 16))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(suggestion.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)

                        if suggestion.isFromServer {
                            Text("IA")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(accentColor)
                                .cornerRadius(4)
                        }

                        if suggestion.isCustomCategory {
                            Text("Nova")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }

                    Text(suggestion.confidenceText)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Text("Aplicar")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.15))
                    .cornerRadius(8)
            }
            .padding(12)
            .background(
                LinearGradient(
                    colors: [accentColor.opacity(0.1), accentColor.opacity(0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accentColor.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Custom Category Section

    private var editCustomCategorySection: some View {
        VStack(spacing: 12) {
            // Custom category name
            HStack {
                ZStack {
                    Circle()
                        .fill((Color(hex: customCategoryColorHex) ?? .teal).opacity(0.2))
                        .frame(width: 32, height: 32)

                    Image(systemName: customCategoryIcon)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: customCategoryColorHex) ?? .teal)
                }

                TextField("Nome da categoria", text: $customCategoryName)
                    .font(.body)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Button(action: {
                    isCustomCategory = false
                    selectedCategory = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(16)
            .background(AppColors.bgSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .cornerRadius(16)

            // Icon and Color pickers
            HStack(spacing: 12) {
                // Icon picker
                Button(action: { showingIconPicker = true }) {
                    HStack {
                        Image(systemName: customCategoryIcon)
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: customCategoryColorHex) ?? .teal)

                        Text("Ícone")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(12)
                    .background(AppColors.bgSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())

                // Color picker
                Button(action: { showingColorPicker = true }) {
                    HStack {
                        Circle()
                            .fill(Color(hex: customCategoryColorHex) ?? .teal)
                            .frame(width: 20, height: 20)

                        Text("Cor")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(12)
                    .background(AppColors.bgSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - AI Categorization

    private func updateAISuggestion(for nameText: String) {
        aiDebounceTask?.cancel()

        guard nameText.count >= 3 else {
            withAnimation { isAILoading = false }
            aiSuggestion = nil
            return
        }

        aiDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000) // 800ms debounce

            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAILoading = true
                    aiSuggestion = nil
                }
            }

            let suggestion = await categorizationService.suggestCategoryFromServer(
                for: nameText,
                amount: Double(truncating: NSDecimalNumber(decimal: totalAmount)),
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

    private func applySuggestion(_ suggestion: TransactionCategorySuggestion) {
        if let existingCategory = suggestion.existingCategory {
            selectedCategory = existingCategory
            isCustomCategory = false
        } else if suggestion.isCustomCategory {
            isCustomCategory = true
            selectedCategory = nil
            customCategoryName = suggestion.customCategoryName ?? ""
            customCategoryIcon = suggestion.customCategoryIcon ?? "tag.fill"
            customCategoryColorHex = suggestion.customCategoryColorHex ?? "#14B8A6"
        }
        aiSuggestion = nil
    }

    private func saveInstallment() {
        var categoryId: String? = selectedCategory?.id

        // Create custom category if needed
        if isCustomCategory && !customCategoryName.isEmpty, let userId = authManager.userId {
            let newCategory = categoryRepo.createCategory(
                userId: userId,
                name: customCategoryName,
                colorHex: customCategoryColorHex,
                iconName: customCategoryIcon
            )
            categoryId = newCategory.id
        }

        onSave(name, totalAmount, totalInstallments, currentInstallment, categoryId)
    }

    private func loadCategories() {
        guard let userId = authManager.userId else { return }
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

        // Find existing category
        if let categoryName = item.categoryName {
            selectedCategory = categories.first { $0.name == categoryName }
        }
    }

    private func formatCurrencyInput(_ input: String) -> String {
        let digitsOnly = input.filter { $0.isNumber }
        guard !digitsOnly.isEmpty else { return "" }
        guard let cents = Int(digitsOnly) else { return "" }

        let reais = Double(cents) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        return formatter.string(from: NSNumber(value: reais)) ?? ""
    }
}

// MARK: - Add Existing Installment Sheet

struct AddExistingInstallmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    let creditCards: [CreditCard]
    let onSave: (String, String, Decimal, Int, Int, Date, String?) -> Void

    @State private var selectedCard: CreditCard?
    @State private var description: String = ""
    @State private var totalAmountText: String = ""
    @State private var totalInstallments: Int = 2
    @State private var startingInstallment: Int = 1
    @State private var purchaseDate: Date = Date()
    @State private var selectedCategory: Category?
    @State private var categories: [Category] = []

    // AI Categorization
    @State private var isAILoading = false
    @State private var aiSuggestion: TransactionCategorySuggestion?
    @State private var aiDebounceTask: Task<Void, Never>?

    // Custom category
    @State private var isCustomCategory = false
    @State private var customCategoryName = ""
    @State private var customCategoryIcon = "tag.fill"
    @State private var customCategoryColorHex = "#14B8A6"
    @State private var showingIconPicker = false
    @State private var showingColorPicker = false

    private let categoryRepo = CategoryRepository.shared
    private let categorizationService = TransactionCategorizationService.shared

    private var totalAmount: Decimal {
        // Remove thousand separators (.) and convert decimal separator (,) to (.)
        let cleanText = totalAmountText
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Decimal(string: cleanText) ?? 0
    }

    private var installmentAmount: Decimal {
        guard totalInstallments > 0 else { return 0 }
        return totalAmount / Decimal(totalInstallments)
    }

    private var isValid: Bool {
        let categoryValid = !isCustomCategory || !customCategoryName.isEmpty
        return selectedCard != nil && !description.isEmpty && totalAmount > 0 && totalInstallments > 1 && startingInstallment >= 1 && startingInstallment <= totalInstallments && categoryValid
    }

    private var effectiveCategoryId: String? {
        if isCustomCategory && !customCategoryName.isEmpty {
            return nil // Will create new category on save
        }
        return selectedCategory?.id
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(AppColors.bgSecondary)
                            .cornerRadius(10)
                    }

                    Spacer()

                    Text("Adicionar Parcela")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Button {
                        guard let card = selectedCard else { return }

                        var categoryId: String? = selectedCategory?.id

                        // Create custom category if needed
                        if isCustomCategory && !customCategoryName.isEmpty, let userId = authManager.userId {
                            let newCategory = categoryRepo.createCategory(
                                userId: userId,
                                name: customCategoryName,
                                colorHex: customCategoryColorHex,
                                iconName: customCategoryIcon
                            )
                            categoryId = newCategory.id
                        }

                        onSave(card.id, description, totalAmount, totalInstallments, startingInstallment, purchaseDate, categoryId)
                        dismiss()
                    } label: {
                        Text("Salvar")
                            .fontWeight(.semibold)
                            .foregroundColor(isValid ? AppColors.accentBlue : AppColors.textTertiary)
                    }
                    .disabled(!isValid)
                }
                .padding()

                ScrollView {
                    VStack(spacing: 20) {
                        // Card Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cartão")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            Menu {
                                ForEach(creditCards) { card in
                                    Button(action: {
                                        selectedCard = card
                                    }) {
                                        HStack {
                                            Text(card.cardName)
                                            if selectedCard?.id == card.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    if let card = selectedCard {
                                        MiniCardIcon(card: card)
                                        Text(card.cardName)
                                            .foregroundColor(AppColors.textPrimary)
                                    } else {
                                        Image(systemName: "creditcard")
                                            .foregroundColor(AppColors.textSecondary)
                                        Text("Selecionar cartão")
                                            .foregroundColor(AppColors.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .padding(16)
                                .background(AppColors.bgSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(AppColors.cardBorder, lineWidth: 1)
                                )
                                .cornerRadius(16)
                            }
                        }
                        .padding(.horizontal)

                        // Nome
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nome")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            AppTextField(
                                icon: "bag",
                                placeholder: "Ex: iPhone 15, Geladeira, etc.",
                                text: $description,
                                autocapitalization: .sentences
                            )
                            .onChange(of: description) { _, newValue in
                                updateAISuggestion(for: newValue)
                            }

                            // AI Loading indicator
                            if isAILoading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                        .scaleEffect(0.8)

                                    Text("IA analisando...")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)

                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: isAILoading)
                        .padding(.horizontal)

                        // Categoria
                        installmentCategorySection
                            .padding(.horizontal)

                        // Total Amount
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Valor Total")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            HStack(spacing: 8) {
                                Text("R$")
                                    .font(.headline)
                                    .foregroundColor(AppColors.textSecondary)

                                TextField("0,00", text: $totalAmountText)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.textPrimary)
                                    .keyboardType(.decimalPad)
                                    .onChange(of: totalAmountText) { _, newValue in
                                        totalAmountText = formatCurrencyInput(newValue)
                                    }
                            }
                            .padding(16)
                            .background(AppColors.bgSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.cardBorder, lineWidth: 1)
                            )
                            .cornerRadius(16)
                        }
                        .padding(.horizontal)

                        // Installments
                        HStack(spacing: 12) {
                            // Parcelas Pagas (starting installment)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Parcelas Pagas")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.textSecondary)

                                HStack {
                                    Button(action: {
                                        if startingInstallment > 1 {
                                            startingInstallment -= 1
                                        }
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(startingInstallment > 1 ? AppColors.accentBlue : AppColors.textTertiary)
                                    }
                                    .disabled(startingInstallment <= 1)

                                    Text("\(startingInstallment - 1)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.textPrimary)
                                        .frame(minWidth: 50)

                                    Button(action: {
                                        if startingInstallment < totalInstallments {
                                            startingInstallment += 1
                                        }
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(startingInstallment < totalInstallments ? AppColors.accentBlue : AppColors.textTertiary)
                                    }
                                    .disabled(startingInstallment >= totalInstallments)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity)
                                .background(AppColors.bgSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(AppColors.cardBorder, lineWidth: 1)
                                )
                                .cornerRadius(16)
                            }

                            // Total Installments
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Total de Parcelas")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.textSecondary)

                                HStack {
                                    Button(action: {
                                        if totalInstallments > 2 {
                                            totalInstallments -= 1
                                            if startingInstallment > totalInstallments {
                                                startingInstallment = totalInstallments
                                            }
                                        }
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(totalInstallments > 2 ? AppColors.accentBlue : AppColors.textTertiary)
                                    }
                                    .disabled(totalInstallments <= 2)

                                    Text("\(totalInstallments)x")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.textPrimary)
                                        .frame(minWidth: 50)

                                    Button(action: {
                                        if totalInstallments < 48 {
                                            totalInstallments += 1
                                        }
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(totalInstallments < 48 ? AppColors.accentBlue : AppColors.textTertiary)
                                    }
                                    .disabled(totalInstallments >= 48)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity)
                                .background(AppColors.bgSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(AppColors.cardBorder, lineWidth: 1)
                                )
                                .cornerRadius(16)
                            }
                        }
                        .padding(.horizontal)

                        // Installment Preview
                        if totalAmount > 0 {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Valor por parcela")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)

                                    Spacer()

                                    Text(CurrencyUtils.format(installmentAmount))
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.accentBlue)
                                }

                                HStack {
                                    Text("Parcelas restantes")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)

                                    Spacer()

                                    Text("\(totalInstallments - startingInstallment + 1) de \(totalInstallments)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColors.textPrimary)
                                }
                            }
                            .padding(16)
                            .background(AppColors.accentBlue.opacity(0.1))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }

                        // Purchase Date
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Data da Compra")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 18))
                                    .foregroundColor(AppColors.accentBlue)

                                DatePicker("", selection: $purchaseDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .environment(\.locale, Locale(identifier: "pt_BR"))
                                    .tint(AppColors.textPrimary)

                                Spacer()
                            }
                            .padding(16)
                            .background(AppColors.bgSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.cardBorder, lineWidth: 1)
                            )
                            .cornerRadius(16)
                        }
                        .padding(.horizontal)

                    }
                    .padding(.vertical)
                }
            }
        }
        .onAppear {
            loadCategories()
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerSheet(selectedIcon: $customCategoryIcon)
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerSheet(selectedColorHex: $customCategoryColorHex)
        }
    }

    // MARK: - Category Section

    private var installmentCategorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Categoria")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)

            // AI Suggestion Banner
            if let suggestion = aiSuggestion, suggestion.confidence != .none, !isCustomCategory {
                installmentAISuggestionBanner(suggestion)
            }

            // Category Selector or Custom Category
            if isCustomCategory {
                installmentCustomCategorySection
            } else {
                Menu {
                    // Existing categories
                    ForEach(categories) { cat in
                        Button(action: {
                            selectedCategory = cat
                            isCustomCategory = false
                        }) {
                            HStack {
                                Image(systemName: cat.iconName)
                                Text(cat.name)
                                if selectedCategory?.id == cat.id && !isCustomCategory {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    Divider()

                    // Custom category option
                    Button(action: {
                        isCustomCategory = true
                        selectedCategory = nil
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Criar categoria personalizada")
                        }
                    }
                } label: {
                    HStack {
                        if let category = selectedCategory {
                            ZStack {
                                Circle()
                                    .fill(category.color.opacity(0.2))
                                    .frame(width: 32, height: 32)

                                Image(systemName: category.iconName)
                                    .font(.system(size: 14))
                                    .foregroundColor(category.color)
                            }

                            Text(category.name)
                                .foregroundColor(AppColors.textPrimary)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(AppColors.textSecondary.opacity(0.2))
                                    .frame(width: 32, height: 32)

                                Image(systemName: "tag")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Text("Selecionar categoria")
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(16)
                    .background(AppColors.bgSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
                    .cornerRadius(16)
                }
            }
        }
    }

    // MARK: - AI Suggestion Banner

    private func installmentAISuggestionBanner(_ suggestion: TransactionCategorySuggestion) -> some View {
        let accentColor: Color = suggestion.isFromServer ? .blue : .purple

        return Button(action: {
            applySuggestion(suggestion)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.2))
                        .frame(width: 36, height: 36)

                    Image(systemName: suggestion.displayIcon)
                        .font(.system(size: 16))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(suggestion.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)

                        if suggestion.isFromServer {
                            Text("IA")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(accentColor)
                                .cornerRadius(4)
                        }

                        if suggestion.isCustomCategory {
                            Text("Nova")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }

                    Text(suggestion.confidenceText)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Text("Aplicar")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.15))
                    .cornerRadius(8)
            }
            .padding(12)
            .background(
                LinearGradient(
                    colors: [accentColor.opacity(0.1), accentColor.opacity(0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accentColor.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Custom Category Section

    private var installmentCustomCategorySection: some View {
        VStack(spacing: 12) {
            // Custom category name
            HStack {
                ZStack {
                    Circle()
                        .fill((Color(hex: customCategoryColorHex) ?? .teal).opacity(0.2))
                        .frame(width: 32, height: 32)

                    Image(systemName: customCategoryIcon)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: customCategoryColorHex) ?? .teal)
                }

                TextField("Nome da categoria", text: $customCategoryName)
                    .font(.body)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Button(action: {
                    isCustomCategory = false
                    selectedCategory = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(16)
            .background(AppColors.bgSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .cornerRadius(16)

            // Icon and Color pickers
            HStack(spacing: 12) {
                // Icon picker
                Button(action: { showingIconPicker = true }) {
                    HStack {
                        Image(systemName: customCategoryIcon)
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: customCategoryColorHex) ?? .teal)

                        Text("Ícone")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(12)
                    .background(AppColors.bgSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())

                // Color picker
                Button(action: { showingColorPicker = true }) {
                    HStack {
                        Circle()
                            .fill(Color(hex: customCategoryColorHex) ?? .teal)
                            .frame(width: 20, height: 20)

                        Text("Cor")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(12)
                    .background(AppColors.bgSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - AI Categorization

    private func updateAISuggestion(for name: String) {
        aiDebounceTask?.cancel()

        guard name.count >= 3 else {
            withAnimation { isAILoading = false }
            aiSuggestion = nil
            return
        }

        aiDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000) // 800ms debounce

            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAILoading = true
                    aiSuggestion = nil
                }
            }

            let suggestion = await categorizationService.suggestCategoryFromServer(
                for: name,
                amount: Double(truncating: NSDecimalNumber(decimal: totalAmount)),
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

    private func applySuggestion(_ suggestion: TransactionCategorySuggestion) {
        if let existingCategory = suggestion.existingCategory {
            selectedCategory = existingCategory
            isCustomCategory = false
        } else if suggestion.isCustomCategory {
            isCustomCategory = true
            selectedCategory = nil
            customCategoryName = suggestion.customCategoryName ?? ""
            customCategoryIcon = suggestion.customCategoryIcon ?? "tag.fill"
            customCategoryColorHex = suggestion.customCategoryColorHex ?? "#14B8A6"
        }
        aiSuggestion = nil
    }

    private func loadCategories() {
        guard let userId = authManager.userId else { return }
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
    }

    /// Formats currency input for Brazilian Real (only numbers, comma for decimals)
    private func formatCurrencyInput(_ input: String) -> String {
        // Remove everything that's not a number
        let digitsOnly = input.filter { $0.isNumber }

        // If empty, return empty
        guard !digitsOnly.isEmpty else { return "" }

        // Convert to cents
        guard let cents = Int(digitsOnly) else { return "" }

        // Format as currency (divide by 100 to get reais)
        let reais = Double(cents) / 100.0

        // Format with thousand separators and decimal comma
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        return formatter.string(from: NSNumber(value: reais)) ?? ""
    }
}
