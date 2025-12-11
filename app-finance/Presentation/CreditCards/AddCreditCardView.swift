import SwiftUI

struct AddCreditCardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    // Card being edited (nil for new card)
    let editingCard: CreditCard?
    let onSave: () -> Void

    // Form fields
    @State private var cardName = ""
    @State private var holderName = ""
    @State private var lastFourDigits = ""
    @State private var selectedBank: Bank = .nubank
    @State private var selectedBankCard: BankCard?
    // Custom brand and type for "Outro" bank
    @State private var customBrand: CardBrand = .visa
    @State private var customType: CardType = .standard
    @State private var paymentDay = 10
    @State private var closingDay = 3
    @State private var limitAmount = ""

    @State private var isLoading = false

    private let cardRepo = CreditCardRepository.shared

    var isEditing: Bool { editingCard != nil }

    // Available cards for selected bank
    private var availableCards: [BankCard] {
        AvailableBankCards.cards(forBank: selectedBank)
    }

    // Computed properties from selected bank card (or custom values for "Outro")
    private var selectedBrand: CardBrand {
        if selectedBank == .other {
            return customBrand
        }
        return selectedBankCard?.defaultBrand ?? .mastercard
    }

    private var selectedType: CardType {
        if selectedBank == .other {
            return customType
        }
        return selectedBankCard?.tier ?? .standard
    }

    private var isOtherBank: Bool {
        selectedBank == .other
    }

    init(editingCard: CreditCard? = nil, onSave: @escaping () -> Void) {
        self.editingCard = editingCard
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    header

                    ScrollView {
                        VStack(spacing: 24) {
                            cardPreview
                                .padding(.top, 8)

                            formFields
                        }
                        .padding()
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear(perform: loadCardData)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(AppColors.bgSecondary)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            Spacer()

            Text(isEditing ? "Editar Cartão" : "Novo Cartão")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Button {
                saveCard()
            } label: {
                Text("Salvar")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(canSave ? AppColors.accentBlue : AppColors.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(!canSave || isLoading)
        }
        .padding()
    }

    // MARK: - Card Preview

    private var cardPreview: some View {
        CreditCardVisual(
            cardName: cardName.isEmpty ? (selectedBankCard?.displayName ?? "Meu Cartão") : cardName,
            holderName: holderName.isEmpty ? "SEU NOME" : holderName.uppercased(),
            lastFourDigits: lastFourDigits.isEmpty ? "****" : lastFourDigits,
            brand: selectedBrand,
            cardType: selectedType,
            bank: selectedBank,
            bankCard: selectedBankCard
        )
    }

    // MARK: - Form Fields

    private var formFields: some View {
        VStack(spacing: 20) {
            // Bank Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Banco")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                bankPicker
            }

            // Card Selection (only for known banks)
            if !isOtherBank {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cartão")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    cardPicker
                }
            }

            // Brand and Type pickers (only for "Outro" bank)
            if isOtherBank {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bandeira")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    brandPicker
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tipo do Cartão")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    typePicker
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Nome do cartão")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                AppTextField(
                    icon: "creditcard",
                    placeholder: "Ex: Nubank Ultravioleta",
                    text: $cardName,
                    autocapitalization: .words
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Nome no cartão")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                AppTextField(
                    icon: "person",
                    placeholder: "Nome impresso no cartão",
                    text: $holderName,
                    autocapitalization: .characters
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Últimos 4 dígitos")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                AppTextField(
                    icon: "number",
                    placeholder: "0000",
                    text: $lastFourDigits,
                    keyboardType: .numberPad
                )
                .onChange(of: lastFourDigits) { _, newValue in
                    if newValue.count > 4 {
                        lastFourDigits = String(newValue.prefix(4))
                    }
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dia fechamento")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    dayPicker(selection: $closingDay)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Dia vencimento")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    dayPicker(selection: $paymentDay)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Limite (opcional)")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                AppTextField(
                    icon: "brazilianrealsign",
                    placeholder: "R$ 0,00",
                    text: $limitAmount,
                    keyboardType: .numberPad
                )
                .onChange(of: limitAmount) { _, newValue in
                    limitAmount = formatCurrency(newValue)
                }
            }
        }
    }

    // MARK: - Currency Formatter

    private func formatCurrency(_ value: String) -> String {
        // Remove everything except digits
        let digits = value.filter { $0.isNumber }

        // Convert to cents (integer)
        guard let cents = Int(digits), cents > 0 else {
            return ""
        }

        // Format as Brazilian Real
        let reais = Double(cents) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.currencySymbol = "R$ "

        return formatter.string(from: NSNumber(value: reais)) ?? ""
    }

    private func parseCurrency(_ value: String) -> Decimal {
        // Remove everything except digits
        let digits = value.filter { $0.isNumber }

        // Convert to Decimal (cents to reais)
        guard let cents = Int(digits), cents > 0 else {
            return 0
        }

        return Decimal(cents) / 100
    }

    // MARK: - Bank Picker

    private var bankPicker: some View {
        Menu {
            ForEach(Bank.allCases, id: \.self) { bank in
                Button(action: {
                    selectedBank = bank
                    // Reset card selection when bank changes
                    if bank == .other {
                        selectedBankCard = nil
                        cardName = "Meu Cartão"
                    } else {
                        selectedBankCard = AvailableBankCards.cards(forBank: bank).first
                        if let card = selectedBankCard {
                            cardName = card.displayName
                        }
                    }
                }) {
                    HStack {
                        Text(bank.rawValue)
                        if selectedBank == bank {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Circle()
                    .fill(Color(hex: selectedBank.primaryColor) ?? .gray)
                    .frame(width: 24, height: 24)

                Text(selectedBank.rawValue)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(AppColors.bgSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .cornerRadius(16)
        }
    }

    // MARK: - Card Picker

    private var cardPicker: some View {
        Menu {
            ForEach(availableCards) { bankCard in
                Button(action: {
                    selectedBankCard = bankCard
                    // Always update card name when selecting a card
                    cardName = bankCard.displayName
                }) {
                    HStack {
                        Text(bankCard.name)
                        if bankCard.tier != .standard {
                            Text("(\(bankCard.tier.rawValue))")
                        }
                        if selectedBankCard?.id == bankCard.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                if let card = selectedBankCard {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: card.cardColor) ?? .gray)
                        .frame(width: 32, height: 20)

                    Text(card.name)
                        .foregroundColor(AppColors.textPrimary)

                    if card.tier != .standard {
                        Text(card.tier.rawValue)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.bgSecondary.opacity(0.5))
                            .cornerRadius(4)
                    }
                } else {
                    Text("Selecione o cartão")
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(AppColors.bgSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .cornerRadius(16)
        }
    }

    // MARK: - Brand Picker (for "Outro" bank)

    private var brandPicker: some View {
        Menu {
            ForEach(CardBrand.allCases, id: \.self) { brand in
                Button(action: {
                    customBrand = brand
                }) {
                    HStack {
                        Text(brand.rawValue)
                        if customBrand == brand {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: customBrand.icon)
                    .foregroundColor(AppColors.textPrimary)

                Text(customBrand.rawValue)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(AppColors.bgSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .cornerRadius(16)
        }
    }

    // MARK: - Type Picker (for "Outro" bank)

    private var typePicker: some View {
        Menu {
            ForEach(CardType.allCases, id: \.self) { type in
                Button(action: {
                    customType = type
                }) {
                    HStack {
                        Text(type.rawValue)
                        if customType == type {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                // Color indicator for card type
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: customType.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 20)

                Text(customType.rawValue)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(AppColors.bgSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .cornerRadius(16)
        }
    }

    // MARK: - Day Pickers

    private func dayPicker(selection: Binding<Int>) -> some View {
        Menu {
            ForEach(1...31, id: \.self) { day in
                Button(action: { selection.wrappedValue = day }) {
                    Text("\(day)")
                }
            }
        } label: {
            HStack {
                Text("\(selection.wrappedValue)")
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(AppColors.bgSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .cornerRadius(16)
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        let hasRequiredFields = !cardName.isEmpty && !holderName.isEmpty
        // For "Outro" bank, we don't need selectedBankCard (use custom brand/type)
        if isOtherBank {
            return hasRequiredFields
        }
        return hasRequiredFields && selectedBankCard != nil
    }

    private func loadCardData() {
        guard let card = editingCard else {
            // Set default card selection for new cards
            selectedBankCard = AvailableBankCards.cards(forBank: selectedBank).first
            return
        }

        cardName = card.cardName
        holderName = card.holderName
        lastFourDigits = card.lastFourDigits
        paymentDay = card.paymentDay
        closingDay = card.closingDay
        if card.limitAmount > 0 {
            // Format as currency for display
            let cents = Int(truncating: (card.limitAmount * 100) as NSDecimalNumber)
            limitAmount = formatCurrency(String(cents))
        }

        // Set bank
        selectedBank = card.bankEnum

        // For "Outro" bank, load custom brand and type
        if selectedBank == .other {
            customBrand = card.brandEnum
            customType = card.cardTypeEnum
        } else {
            // Find the matching BankCard for known banks
            let tier = card.cardTypeEnum
            if let matchingCard = AvailableBankCards.cards(forBank: selectedBank).first(where: { $0.tier == tier }) {
                selectedBankCard = matchingCard
            } else {
                // Fallback to first card of the bank
                selectedBankCard = AvailableBankCards.cards(forBank: selectedBank).first
            }
        }
    }

    private func saveCard() {
        guard let userId = authManager.userId else { return }

        isLoading = true

        // Parse currency format: "R$ 1.234,56" -> 1234.56
        let limit = parseCurrency(limitAmount)

        if let card = editingCard {
            // Update existing card
            cardRepo.updateCreditCard(
                card,
                cardName: cardName,
                holderName: holderName,
                lastFourDigits: lastFourDigits,
                brand: selectedBrand,
                cardType: selectedType,
                bank: selectedBank,
                paymentDay: paymentDay,
                closingDay: closingDay,
                limitAmount: limit
            )
        } else {
            // Create new card
            _ = cardRepo.createCreditCard(
                userId: userId,
                cardName: cardName,
                holderName: holderName,
                lastFourDigits: lastFourDigits,
                brand: selectedBrand,
                cardType: selectedType,
                bank: selectedBank,
                paymentDay: paymentDay,
                closingDay: closingDay,
                limitAmount: limit
            )
        }

        isLoading = false
        onSave()
        dismiss()
    }
}

// MARK: - Credit Card Visual Component (Full Size)

struct CreditCardVisual: View {
    let cardName: String
    let holderName: String
    let lastFourDigits: String
    let brand: CardBrand
    let cardType: CardType
    let bank: Bank
    var bankCard: BankCard? = nil

    // Use bankCard color if available, otherwise fall back to cardType gradient
    private var cardColors: [Color] {
        if let bankCard = bankCard {
            let color = Color(hex: bankCard.cardColor) ?? .gray
            return [color.opacity(0.9), color]
        }
        return cardType.gradientColors
    }

    private var textColor: Color {
        if let bankCard = bankCard {
            return Color(hex: bankCard.textColor) ?? .white
        }
        return .white
    }

    var body: some View {
        ZStack {
            // Background with premium gradient
            // Background with premium gradient
            if bank == .nubank && cardType == .black {
                // Nubank Ultravioleta Special Gradient
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "#5c3596") ?? .purple,
                                Color(hex: "#2D1B4E") ?? .black
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 250
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                // Standard Linear Gradient
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: cardColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        ZStack {
                            // Abstract shapes for depth
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 250, height: 250)
                                .offset(x: -100, y: -100)
                                .blur(radius: 30)
                            
                            Circle()
                                .fill(Color.black.opacity(0.15))
                                .frame(width: 200, height: 200)
                                .offset(x: 150, y: 100)
                                .blur(radius: 30)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }

            // Content
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    // Bank Logo/Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bank.rawValue)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(textColor)
                        
                        if !cardName.isEmpty && cardName != bank.rawValue {
                            Text(cardName)
                                .font(.system(size: 12))
                                .foregroundColor(textColor.opacity(0.8))
                        }
                    }

                    Spacer()

                    // Contactless Icon
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 24))
                        .foregroundColor(textColor.opacity(0.7))
                        .rotationEffect(.degrees(90))
                }

                Spacer()

                HStack {
                    // Chip
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.yellow.opacity(0.8), .orange.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 45, height: 35)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .overlay(
                            VStack(spacing: 3) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Rectangle()
                                        .fill(Color.black.opacity(0.1))
                                        .frame(height: 1)
                                }
                            }
                            .padding(.horizontal, 6)
                        )
                    
                    Spacer()
                    
                    // Brand Logo (Icon)
                    Image(systemName: brand.icon)
                        .font(.system(size: 32))
                        .foregroundColor(textColor)
                }
                .padding(.bottom, 20)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("**** **** **** \(lastFourDigits)")
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundColor(textColor)
                            .tracking(3)

                        Text(holderName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(textColor.opacity(0.8))
                            .lineLimit(1)
                    }

                    Spacer()
                    
                    Text((bankCard?.name ?? cardType.rawValue).uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(textColor.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(24)
        }
        .frame(height: 220)
        .shadow(color: cardColors.first?.opacity(0.4) ?? .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}



// MARK: - Credit Card Row (For List)

struct CreditCardRow: View {
    let card: CreditCard
    var onTap: (() -> Void)? = nil

    private var cardColors: [Color] {
        // Try to find specific bank card color matching the tier
        if let match = AvailableBankCards.cards(forBank: card.bankEnum).first(where: { $0.tier == card.cardTypeEnum }) {
            if let color = Color(hex: match.cardColor) {
                return [color.opacity(0.9), color]
            }
        }
        return card.cardTypeEnum.gradientColors
    }

    private var statusColor: Color {
        if card.isPaymentOverdue {
            return AppColors.expense
        } else if card.isPaymentDueSoon {
            return AppColors.accentOrange
        }
        return AppColors.textSecondary
    }

    private var borderColor: Color {
        if card.isPaymentOverdue || card.isPaymentDueSoon {
            return statusColor.opacity(0.3)
        }
        return AppColors.cardBorder
    }

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 16) {
                // Card Icon Container (Mini Card Visual - Limpo)
                ZStack(alignment: .topLeading) {
                    // Specific background for Nubank Ultravioleta to mimic the real card (Light center, dark edges)
                    if card.bankEnum == .nubank && card.cardTypeEnum == .black {
                         RoundedRectangle(cornerRadius: 6)
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: "#5c3596") ?? .purple, // Light center
                                        Color(hex: "#2D1B4E") ?? .black   // Dark edges
                                    ]),
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 35
                                )
                            )
                            .frame(width: 56, height: 36)
                            .shadow(color: Color(hex: "#2D1B4E")?.opacity(0.5) ?? .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: cardColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 36)
                            .shadow(color: cardColors.first?.opacity(0.3) ?? .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }

                    // Chip simulation
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [.yellow.opacity(0.8), .orange.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 12, height: 9)
                        .padding(.leading, 6)
                        .padding(.top, 10)
                }

                // Card info
                VStack(alignment: .leading, spacing: 4) {
                    // Nome e Final
                    HStack {
                        Text(card.cardName)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        if !card.lastFourDigits.isEmpty {
                            Text("•••• \(card.lastFourDigits)")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    // Limite (Linha dedicada se existir)
                    if card.limitAmount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "banknote")
                                .font(.caption2)
                            Text(card.formattedLimit)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(AppColors.accentGreen)
                        .padding(.bottom, 2)
                    }

                    // Datas (Linha dedicada para não espremer)
                    HStack(spacing: 16) {
                        // Closing Day
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text("Fecha dia \(card.closingDay)")
                                .font(.caption)
                        }
                        .foregroundColor(AppColors.textSecondary)

                        // Payment Day with status
                        HStack(spacing: 4) {
                            if card.isPaymentOverdue || card.isPaymentDueSoon {
                                Image(systemName: card.isPaymentOverdue ? "exclamationmark.circle.fill" : "clock.fill")
                                    .font(.caption2)
                            } else {
                                Image(systemName: "clock")
                                    .font(.caption2)
                            }
                            Text(card.paymentStatusText)
                                .font(.caption)
                                .fontWeight(card.isPaymentOverdue || card.isPaymentDueSoon ? .medium : .regular)
                        }
                        .foregroundColor(statusColor)
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(16)
            .background(AppColors.bgSecondary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

