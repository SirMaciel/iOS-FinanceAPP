import SwiftUI

struct AddFixedBillView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    var editingBill: FixedBill?
    let onSave: () -> Void

    // Form fields
    @State private var name = ""
    @State private var amount = ""
    @State private var dueDay = 10
    @State private var category: FixedBillCategory = .other
    @State private var notes = ""
    @State private var isActive = true

    // Custom category fields
    @State private var isCustomCategory = false
    @State private var customCategoryName = ""
    @State private var customCategoryIcon = "tag.fill"
    @State private var customCategoryColorHex = "#14B8A6"
    @State private var showingIconPicker = false
    @State private var showingColorPicker = false

    // AI Suggestion
    @State private var aiSuggestion: CategorySuggestion?
    @State private var showingSuggestion = false
    @State private var aiDebounceTask: Task<Void, Never>?
    @State private var isAILoading = false
    @State private var originalName: String = "" // Nome original ao editar

    // Advanced options
    @State private var showAdvancedOptions = false
    @State private var totalInstallments: Int? = nil
    @State private var paidInstallments: Int? = nil
    @State private var totalInstallmentsText = ""
    @State private var paidInstallmentsText = ""

    @State private var isLoading = false
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isNameFocused: Bool

    private let repository = FixedBillRepository.shared
    private let categorizationService = FixedBillCategorizationService.shared

    var isEditing: Bool { editingBill != nil }

    init(editingBill: FixedBill? = nil, onSave: @escaping () -> Void) {
        self.editingBill = editingBill
        self.onSave = onSave
    }

    var body: some View {
        ZStack {
            DarkBackground()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 24) {
                        // Amount
                        amountSection

                        // Name
                        nameSection

                        // Category
                        categorySection

                        // Due Day
                        dueDaySection

                        // Notes
                        notesSection

                        // Advanced options
                        advancedOptionsSection

                        // Active toggle (only when editing)
                        if isEditing {
                            activeToggleSection
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear(perform: loadBillData)
        .onTapGesture {
            isAmountFocused = false
            hideKeyboard()
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerSheet(selectedIcon: $customCategoryIcon)
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerSheet(selectedColorHex: $customCategoryColorHex)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(AppColors.cardBackground)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(isEditing ? "Editar Conta" : "Nova Conta Fixa")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Button { saveBill() } label: {
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

    // MARK: - Amount Section

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Valor")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)

            HStack(spacing: 8) {
                Text("R$")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textSecondary)

                TextField("0,00", text: $amount)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(AppColors.expense)
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
            }
            .padding(16)
            .background(AppColors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .cornerRadius(16)
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nome da conta")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)

            DarkTextField(
                icon: "doc.text",
                placeholder: "Ex: Aluguel, Financiamento, Netflix",
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
    }

    private func updateAISuggestion(for billName: String) {
        // Cancelar task anterior (debounce)
        aiDebounceTask?.cancel()

        guard billName.count >= 3 else {
            withAnimation { isAILoading = false }
            aiSuggestion = nil
            return
        }

        // Se estiver editando e o nome não mudou, não ativar IA
        if isEditing && billName == originalName {
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

            // Buscar categorias customizadas existentes
            let existingCategories = getExistingCustomCategories()

            // Buscar do servidor (IA)
            let serverSuggestion = await categorizationService.suggestCategoryFromServer(
                for: billName,
                amount: Double(amount.replacingOccurrences(of: ",", with: ".")),
                existingCustomCategories: existingCategories
            )

            guard !Task.isCancelled else {
                await MainActor.run { isAILoading = false }
                return
            }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAILoading = false

                    if serverSuggestion.confidence != .none {
                        aiSuggestion = serverSuggestion
                    }
                }
            }
        }
    }

    /// Busca categorias customizadas já criadas pelo usuário nas contas fixas
    private func getExistingCustomCategories() -> [ExistingCategoryRequest] {
        guard let userId = authManager.userId else { return [] }

        let bills = repository.getFixedBills(userId: userId)
        var uniqueCategories: [String: ExistingCategoryRequest] = [:]

        for bill in bills {
            if bill.category == .custom,
               let customName = bill.customCategoryName,
               !customName.isEmpty {
                // Evitar duplicatas usando o nome como chave
                if uniqueCategories[customName] == nil {
                    uniqueCategories[customName] = ExistingCategoryRequest(
                        name: customName,
                        icon: bill.customCategoryIcon
                    )
                }
            }
        }

        return Array(uniqueCategories.values)
    }

    private func applySuggestion(_ suggestion: CategorySuggestion) {
        if suggestion.isCustomCategory {
            // Categoria customizada criada pela IA
            isCustomCategory = true
            category = .custom
            customCategoryName = suggestion.customCategoryName ?? ""
            customCategoryIcon = suggestion.customCategoryIcon ?? "tag.fill"
            // Limpar a sugestão após aplicar
            aiSuggestion = nil
        } else {
            // Categoria predefinida
            category = suggestion.category
            isCustomCategory = false
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Categoria")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)

            // AI Suggestion Banner
            if let suggestion = aiSuggestion, suggestion.confidence != .none, !isCustomCategory {
                aiSuggestionBanner(suggestion)
            }

            // Category Selector or Custom Category
            if isCustomCategory {
                customCategorySection
            } else {
                Menu {
                    // Predefined categories
                    ForEach(FixedBillCategory.predefinedCases, id: \.self) { cat in
                        Button(action: {
                            category = cat
                            isCustomCategory = false
                        }) {
                            HStack {
                                Image(systemName: cat.icon)
                                Text(cat.rawValue)
                                if category == cat && !isCustomCategory {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    Divider()

                    // Custom category option
                    Button(action: {
                        isCustomCategory = true
                        category = .custom
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Criar categoria personalizada")
                        }
                    }
                } label: {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(category.color.opacity(0.2))
                                .frame(width: 32, height: 32)

                            Image(systemName: category.icon)
                                .font(.system(size: 14))
                                .foregroundColor(category.color)
                        }

                        Text(category.rawValue)
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.caption)
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
            }
        }
    }

    // MARK: - AI Suggestion Banner

    private func aiSuggestionBanner(_ suggestion: CategorySuggestion) -> some View {
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

                    // Mostra texto de confiança (sem reasoning)
                    if suggestion.isFromServer {
                        Text(suggestion.confidenceText)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    } else if let keyword = suggestion.matchedKeyword {
                        Text("Baseado em \"\(keyword)\"")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
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

    private var customCategorySection: some View {
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
                    category = .other
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(16)
            .background(AppColors.cardBackground)
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
                    .background(AppColors.cardBackground)
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
                    .background(AppColors.cardBackground)
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

    // MARK: - Due Day Section

    private var dueDaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dia do vencimento")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)

            Menu {
                ForEach(1...31, id: \.self) { day in
                    Button(action: { dueDay = day }) {
                        HStack {
                            Text("Dia \(day)")
                            if dueDay == day {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(AppColors.textSecondary)

                    Text("Dia \(dueDay)")
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption)
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
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Observações (opcional)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)

            DarkTextField(
                icon: "note.text",
                placeholder: "Anotações sobre esta conta",
                text: $notes,
                autocapitalization: .sentences
            )
        }
    }

    // MARK: - Advanced Options Section

    private let goldColor = Color(red: 0.85, green: 0.65, blue: 0.13)

    private var advancedOptionsSection: some View {
        VStack(spacing: 0) {
            // Header button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showAdvancedOptions.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(goldColor)

                    Text("Opções avançadas")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(goldColor)

                    Spacer()

                    Image(systemName: showAdvancedOptions ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(goldColor.opacity(0.7))
                        .rotationEffect(.degrees(showAdvancedOptions ? 0 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(goldColor.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(goldColor.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Advanced options content
            if showAdvancedOptions {
                VStack(spacing: 0) {
                    // Connector line
                    Rectangle()
                        .fill(goldColor.opacity(0.2))
                        .frame(width: 1, height: 12)

                    VStack(spacing: 12) {
                        // Total installments
                        HStack(spacing: 16) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(goldColor.opacity(0.15))
                                        .frame(width: 32, height: 32)

                                    Image(systemName: "number.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(goldColor)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Total de parcelas")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColors.textPrimary)

                                    Text("Máximo 999 parcelas")
                                        .font(.caption2)
                                        .foregroundColor(AppColors.textTertiary)
                                }
                            }

                            Spacer()

                            TextField("0", text: $totalInstallmentsText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(totalInstallments != nil ? goldColor : AppColors.textTertiary)
                                .frame(width: 60)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(goldColor.opacity(0.1))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(goldColor.opacity(0.3), lineWidth: 1)
                                )
                                .onChange(of: totalInstallmentsText) { _, newValue in
                                    // Filtrar apenas números
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered != newValue {
                                        totalInstallmentsText = filtered
                                    }
                                    // Limitar a 999
                                    if let num = Int(filtered) {
                                        if num > 999 {
                                            totalInstallmentsText = "999"
                                            totalInstallments = 999
                                        } else if num > 0 {
                                            totalInstallments = num
                                        } else {
                                            totalInstallments = nil
                                        }
                                        // Ajustar parcelas pagas se necessário
                                        if let paid = paidInstallments, let total = totalInstallments, paid > total {
                                            paidInstallments = total
                                            paidInstallmentsText = "\(total)"
                                        }
                                    } else {
                                        totalInstallments = nil
                                        paidInstallments = nil
                                        paidInstallmentsText = ""
                                    }
                                }
                        }
                        .padding(14)
                        .background(AppColors.cardBackground)
                        .cornerRadius(14)

                        // Paid installments (only if total is set)
                        if let total = totalInstallments {
                            HStack(spacing: 16) {
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.green.opacity(0.15))
                                            .frame(width: 32, height: 32)

                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.green)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Parcelas pagas")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(AppColors.textPrimary)

                                        Text("Máximo \(total) parcelas")
                                            .font(.caption2)
                                            .foregroundColor(AppColors.textTertiary)
                                    }
                                }

                                Spacer()

                                TextField("0", text: $paidInstallmentsText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                                    .frame(width: 60)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                    )
                                    .onChange(of: paidInstallmentsText) { _, newValue in
                                        // Filtrar apenas números
                                        let filtered = newValue.filter { $0.isNumber }
                                        if filtered != newValue {
                                            paidInstallmentsText = filtered
                                        }
                                        // Limitar ao total de parcelas
                                        if let num = Int(filtered) {
                                            if num > total {
                                                paidInstallmentsText = "\(total)"
                                                paidInstallments = total
                                            } else {
                                                paidInstallments = num
                                            }
                                        } else {
                                            paidInstallments = 0
                                        }
                                    }
                            }
                            .padding(14)
                            .background(AppColors.cardBackground)
                            .cornerRadius(14)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity
                            ))
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(goldColor.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(goldColor.opacity(0.15), lineWidth: 1)
                    )
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                    removal: .opacity
                ))
            }
        }
    }

    // MARK: - Active Toggle Section

    private var activeToggleSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Conta ativa")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)

                Text("Contas inativas não aparecem no resumo")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $isActive)
                .labelsHidden()
                .tint(AppColors.accentGreen)
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .cornerRadius(16)
    }

    // MARK: - Helpers

    private var canSave: Bool {
        if isCustomCategory {
            return !name.isEmpty && !amount.isEmpty && !customCategoryName.isEmpty
        }
        return !name.isEmpty && !amount.isEmpty
    }

    private func loadBillData() {
        guard let bill = editingBill else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAmountFocused = true
            }
            return
        }

        name = bill.name
        originalName = bill.name // Salvar nome original para comparação
        amount = String(format: "%.2f", bill.amountDouble).replacingOccurrences(of: ".", with: ",")
        dueDay = bill.dueDay
        category = bill.category
        notes = bill.notes ?? ""
        isActive = bill.isActive

        // Load custom category data
        if bill.category == .custom {
            isCustomCategory = true
            customCategoryName = bill.customCategoryName ?? ""
            customCategoryIcon = bill.customCategoryIcon ?? "tag.fill"
            customCategoryColorHex = bill.customCategoryColorHex ?? "#14B8A6"
        }

        // Load installment data
        if let total = bill.totalInstallments, total > 0 {
            totalInstallments = total
            totalInstallmentsText = "\(total)"
            paidInstallments = bill.paidInstallments ?? 0
            paidInstallmentsText = "\(bill.paidInstallments ?? 0)"
        }
    }

    private func saveBill() {
        guard let userId = authManager.userId else { return }

        guard let amountDecimal = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) else {
            return
        }

        isLoading = true

        // Prepare custom category fields
        let finalCustomName: String? = isCustomCategory ? customCategoryName : nil
        let finalCustomIcon: String? = isCustomCategory ? customCategoryIcon : nil
        let finalCustomColor: String? = isCustomCategory ? customCategoryColorHex : nil

        if let bill = editingBill {
            // Update
            repository.updateFixedBill(
                bill,
                name: name,
                amount: amountDecimal,
                dueDay: dueDay,
                category: isCustomCategory ? .custom : category,
                notes: notes.isEmpty ? nil : notes,
                isActive: isActive,
                customCategoryName: finalCustomName,
                customCategoryIcon: finalCustomIcon,
                customCategoryColorHex: finalCustomColor,
                totalInstallments: totalInstallments,
                paidInstallments: paidInstallments
            )
        } else {
            // Create
            _ = repository.createFixedBill(
                userId: userId,
                name: name,
                amount: amountDecimal,
                dueDay: dueDay,
                category: isCustomCategory ? .custom : category,
                notes: notes.isEmpty ? nil : notes,
                customCategoryName: finalCustomName,
                customCategoryIcon: finalCustomIcon,
                customCategoryColorHex: finalCustomColor,
                totalInstallments: totalInstallments,
                paidInstallments: paidInstallments
            )
        }

        isLoading = false
        onSave()
        dismiss()
    }
}

// MARK: - Icon Picker Sheet

struct IconPickerSheet: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss

    private let icons = [
        "tag.fill", "star.fill", "heart.fill", "house.fill", "car.fill",
        "bolt.fill", "flame.fill", "drop.fill", "leaf.fill", "sun.max.fill",
        "moon.fill", "cloud.fill", "snowflake", "wind", "thermometer.medium",
        "cart.fill", "bag.fill", "creditcard.fill", "banknote.fill", "wallet.pass.fill",
        "building.2.fill", "building.columns.fill", "storefront.fill", "shippingbox.fill",
        "airplane", "bus.fill", "tram.fill", "bicycle", "figure.walk",
        "fork.knife", "cup.and.saucer.fill", "wineglass.fill", "birthday.cake.fill",
        "tv.fill", "gamecontroller.fill", "headphones", "music.note", "film.fill",
        "book.fill", "graduationcap.fill", "pencil", "paintbrush.fill", "camera.fill",
        "phone.fill", "envelope.fill", "globe", "wifi", "antenna.radiowaves.left.and.right",
        "heart.text.square.fill", "cross.fill", "pills.fill", "syringe.fill", "bandage.fill",
        "dumbbell.fill", "figure.run", "sportscourt.fill", "tennis.racket", "basketball.fill",
        "pawprint.fill", "hare.fill", "tortoise.fill", "fish.fill", "bird.fill",
        "gift.fill", "party.popper.fill", "theatermasks.fill", "ticket.fill", "sparkles",
        "wrench.fill", "hammer.fill", "screwdriver.fill", "paintbrush.pointed.fill",
        "shield.fill", "lock.fill", "key.fill", "checkmark.shield.fill",
        "doc.fill", "folder.fill", "tray.fill", "archivebox.fill", "trash.fill"
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 6)

    var body: some View {
        NavigationView {
            ZStack {
                DarkBackground()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(icons, id: \.self) { icon in
                            Button(action: {
                                selectedIcon = icon
                                dismiss()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(selectedIcon == icon ? AppColors.accentBlue.opacity(0.3) : AppColors.cardBackground)
                                        .frame(width: 48, height: 48)

                                    Image(systemName: icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(selectedIcon == icon ? AppColors.accentBlue : AppColors.textSecondary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Escolher Ícone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Color Picker Sheet

struct ColorPickerSheet: View {
    @Binding var selectedColorHex: String
    @Environment(\.dismiss) private var dismiss

    private let colors: [(String, String)] = [
        ("#EF4444", "Vermelho"),
        ("#F97316", "Laranja"),
        ("#F59E0B", "Âmbar"),
        ("#EAB308", "Amarelo"),
        ("#84CC16", "Lima"),
        ("#22C55E", "Verde"),
        ("#10B981", "Esmeralda"),
        ("#14B8A6", "Teal"),
        ("#06B6D4", "Ciano"),
        ("#0EA5E9", "Céu"),
        ("#3B82F6", "Azul"),
        ("#6366F1", "Índigo"),
        ("#8B5CF6", "Violeta"),
        ("#A855F7", "Roxo"),
        ("#D946EF", "Fúcsia"),
        ("#EC4899", "Rosa"),
        ("#F43F5E", "Rosé"),
        ("#78716C", "Cinza"),
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 6)

    var body: some View {
        NavigationView {
            ZStack {
                DarkBackground()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(colors, id: \.0) { color in
                            Button(action: {
                                selectedColorHex = color.0
                                dismiss()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: color.0) ?? .gray)
                                        .frame(width: 48, height: 48)

                                    if selectedColorHex == color.0 {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Escolher Cor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AddFixedBillView(onSave: {})
}
