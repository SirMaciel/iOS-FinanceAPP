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

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.isLoading {
                ZStack {
                    DarkBackground()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
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
        .tint(.blue)
        .preferredColorScheme(.dark)
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
                        .fill(AppColors.cardBackground)
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
    @State private var selectedCard: CreditCard?
    @State private var editingCard: CreditCard?
    @State private var viewMode: CardViewMode = .cards

    enum CardViewMode {
        case cards
        case transactions
    }

    private let cardRepo = CreditCardRepository.shared

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

    var body: some View {
        ZStack {
            DarkBackground()

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
                            if viewMode == .cards {
                                cardsList
                                    .transition(.opacity)
                            } else {
                                transactionsPlaceholder
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
                        showAddCard = true
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear(perform: loadCards)
        .sheet(isPresented: $showAddCard) {
            AddCreditCardView(onSave: loadCards)
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
        .animation(.easeInOut, value: viewMode)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            DarkSectionHeader(title: "Seus Cartões")
            Spacer()
        }
        .padding()
    }

    // MARK: - View Mode Picker

    private var viewModePicker: some View {
        HStack(spacing: 0) {
            viewModeButton(mode: .cards, icon: "creditcard", title: "Cartões")
            viewModeButton(mode: .transactions, icon: "list.bullet.rectangle", title: "Transações")
        }
        .padding(4)
        .background(AppColors.cardBackground)
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

                    Text("ativos")
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
                AppColors.cardBackground
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

            DarkButton(title: "Adicionar Cartão", icon: "plus") {
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

    // MARK: - Transactions Placeholder

    private var transactionsPlaceholder: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 40)

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }

            VStack(spacing: 8) {
                Text("Em breve")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)

                Text("As transações dos cartões\nserão exibidas aqui")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
                .frame(height: 40)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(AppColors.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }

    private func loadCards() {
        guard let userId = authManager.userId else { return }
        creditCards = cardRepo.getCreditCards(userId: userId)
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
            DarkBackground()

            VStack(spacing: 24) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(AppColors.cardBackground)
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
                            .background(AppColors.cardBackground)
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
                .background(AppColors.cardBackground)
                .cornerRadius(16)
                .padding(.horizontal)

                Spacer()

                // Botões de ação
                VStack(spacing: 12) {
                    DarkButton(title: "Editar Cartão", icon: "pencil", style: .secondary) {
                        onEdit(card)
                    }

                    DarkButton(title: "Remover Cartão", icon: "trash", style: .danger) {
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
            DarkBackground()

            ScrollView {
                VStack(spacing: 24) {
                    // Header com avatar
                    VStack(spacing: 16) {
                        ZStack {
                            // Borda gradiente
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 88, height: 88)

                            // Fundo do avatar
                            Circle()
                                .fill(AppColors.bgPrimary)
                                .frame(width: 80, height: 80)

                            // Inicial
                            Text(authManager.userName?.prefix(1).uppercased() ?? "U")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .shadow(color: .blue.opacity(0.3), radius: 16, x: 0, y: 8)

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
                        DarkSectionHeader(title: "Configurações")

                        VStack(spacing: 8) {
                            SettingsCard(
                                icon: "bell.fill",
                                title: "Notificações",
                                subtitle: "Em breve",
                                iconColor: .orange
                            )

                            SettingsCard(
                                icon: "paintbrush.fill",
                                title: "Aparência",
                                subtitle: "Em breve",
                                iconColor: .purple
                            )

                            SettingsCard(
                                icon: "square.and.arrow.up.fill",
                                title: "Exportar dados",
                                subtitle: "Em breve",
                                iconColor: .blue
                            )
                        }
                    }

                    // Seção Sobre
                    VStack(alignment: .leading, spacing: 12) {
                        DarkSectionHeader(title: "Sobre")

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

                            Text("1.0.0")
                                .font(.body)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(16)
                        .background(AppColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        )
                        .cornerRadius(16)
                    }

                    // Botão de logout
                    DarkButton(
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
