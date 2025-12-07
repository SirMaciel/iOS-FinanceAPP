import SwiftUI
import SwiftData
import MapKit

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = AddTransactionViewModel()
    @FocusState private var isAmountFocused: Bool

    // Sheets for custom category
    @State private var showingIconPicker = false
    @State private var showingColorPicker = false
    @State private var showingCategoryManagement = false

    let onTransactionAdded: () -> Void

    var body: some View {
        ZStack {
            // Background
            DarkBackground()

            // Content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Text("Cancelar")
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Text("Nova Transação")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)

                        // Indicador offline
                        if viewModel.isOffline {
                            Image(systemName: "wifi.slash")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    Spacer()

                    Button(action: {
                        Task {
                            if let userId = authManager.userId {
                                await viewModel.saveTransaction(
                                    userId: userId,
                                    onSuccess: {
                                        onTransactionAdded()
                                        dismiss()
                                    }
                                )
                            }
                        }
                    }) {
                        Text("Salvar")
                            .fontWeight(.semibold)
                            .foregroundColor(viewModel.isLoading ? AppColors.textTertiary : AppColors.accentBlue)
                    }
                    .disabled(viewModel.isLoading)
                }
                .padding()

                ScrollView {
                    VStack(spacing: 24) {
                        // Tipo
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tipo de transação")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            DarkSegmentedPicker(
                                selection: $viewModel.type,
                                options: [
                                    (.expense, "Gasto"),
                                    (.income, "Receita")
                                ]
                            )
                        }

                        // Valor
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

                                TextField("0,00", text: $viewModel.amount)
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(AppColors.textPrimary)
                                    .keyboardType(.decimalPad)
                                    .focused($isAmountFocused)
                                    .onChange(of: viewModel.amount) { _, newValue in
                                        viewModel.amount = formatCurrencyInput(newValue)
                                    }
                            }
                            .padding(16)
                            .background(AppColors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.cardBorder, lineWidth: 1)
                            )
                            .cornerRadius(16)
                        }

                        // Data
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Data")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(AppColors.textSecondary)

                                DatePicker("", selection: $viewModel.date, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .environment(\.locale, Locale(identifier: "pt_BR"))
                                    .labelsHidden()
                                    .colorScheme(.dark)

                                Spacer()
                            }
                            .padding(16)
                            .background(AppColors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.cardBorder, lineWidth: 1)
                            )
                            .cornerRadius(16)
                        }

                        // Localização (opcional) - apenas para gastos
                        if viewModel.type == .expense {
                            locationSection
                        }

                        // Forma de Pagamento (apenas para gastos)
                        if viewModel.type == .expense {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Forma de Pagamento")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.textSecondary)

                                paymentMethodPicker
                            }

                            // Parcelamento (apenas para cartão de crédito)
                            Group {
                                if viewModel.paymentMethod == .credit {
                                    installmentSection
                                        .transition(.opacity)
                                }
                            }
                            .animation(.easeInOut(duration: 0.15), value: viewModel.paymentMethod)
                        }

                        // Nome
                        nameSection

                        // Categoria (apenas para gastos)
                        if viewModel.type == .expense {
                            categorySection
                        }

                        // Descrição (opcional) - sempre por último
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Descrição (opcional)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)

                            DarkTextField(
                                icon: "text.alignleft",
                                placeholder: "Detalhes adicionais...",
                                text: $viewModel.notes,
                                autocapitalization: .sentences
                            )
                        }
                    }
                    .padding()
                    .onTapGesture { isAmountFocused = false; hideKeyboard() }
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onTapGesture { isAmountFocused = false; hideKeyboard() }
        .disabled(viewModel.isLoading)
        .overlay {
            if viewModel.isLoading {
                DarkLoadingOverlay(message: "Salvando...")
            }
        }
        .alert("Erro", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .onAppear {
            // Carregar cartões de crédito e categorias
            if let userId = authManager.userId {
                viewModel.loadCreditCards(userId: userId)
                viewModel.loadCategories(userId: userId)
            }

            // Auto-foca no campo de valor com pequeno delay para garantir que a view está pronta
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAmountFocused = true
            }
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerSheet(selectedIcon: $viewModel.customCategoryIcon)
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerSheet(selectedColorHex: $viewModel.customCategoryColorHex)
        }
        .sheet(isPresented: $viewModel.showMapPicker) {
            LocationMapPickerSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementSheet(
                categories: viewModel.categories,
                onUpdate: { category, name, colorHex in
                    viewModel.updateCategory(category, name: name, colorHex: colorHex)
                },
                onDelete: { category in
                    viewModel.deleteCategory(category)
                }
            )
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nome")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)

            DarkTextField(
                icon: "bag",
                placeholder: viewModel.type == .income ? "Ex: Salário, Freelance, etc." : "Ex: Supermercado, Uber, etc.",
                text: $viewModel.description,
                autocapitalization: .sentences
            )
            .onChange(of: viewModel.description) { _, newValue in
                viewModel.updateAISuggestion(for: newValue)
            }

            // AI Loading indicator
            if viewModel.isAILoading && viewModel.type == .expense {
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
        .animation(.easeInOut(duration: 0.2), value: viewModel.isAILoading)
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Categoria")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)

            // AI Suggestion Banner
            if let suggestion = viewModel.aiSuggestion, suggestion.confidence != .none, !viewModel.isCustomCategory {
                aiSuggestionBanner(suggestion)
            }

            // Category Selector or Custom Category
            if viewModel.isCustomCategory {
                customCategorySection
            } else {
                Menu {
                    // Existing categories
                    ForEach(viewModel.categories) { cat in
                        Button(action: {
                            viewModel.selectedCategory = cat
                            viewModel.isCustomCategory = false
                        }) {
                            HStack {
                                Image(systemName: cat.iconName)
                                Text(cat.name)
                                if viewModel.selectedCategory?.id == cat.id && !viewModel.isCustomCategory {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    Divider()

                    // Custom category option
                    Button(action: {
                        viewModel.isCustomCategory = true
                        viewModel.selectedCategory = nil
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Criar categoria personalizada")
                        }
                    }

                    // Manage categories option
                    Button(action: {
                        showingCategoryManagement = true
                    }) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            Text("Gerenciar categorias")
                        }
                    }
                } label: {
                    HStack {
                        if let category = viewModel.selectedCategory {
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

    private func aiSuggestionBanner(_ suggestion: TransactionCategorySuggestion) -> some View {
        let accentColor: Color = suggestion.isFromServer ? .blue : .purple

        return Button(action: {
            viewModel.applySuggestion(suggestion)
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

    private var customCategorySection: some View {
        VStack(spacing: 12) {
            // Custom category name
            HStack {
                ZStack {
                    Circle()
                        .fill((Color(hex: viewModel.customCategoryColorHex) ?? .teal).opacity(0.2))
                        .frame(width: 32, height: 32)

                    Image(systemName: viewModel.customCategoryIcon)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: viewModel.customCategoryColorHex) ?? .teal)
                }

                TextField("Nome da categoria", text: $viewModel.customCategoryName)
                    .font(.body)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Button(action: {
                    viewModel.isCustomCategory = false
                    viewModel.selectedCategory = nil
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
                        Image(systemName: viewModel.customCategoryIcon)
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: viewModel.customCategoryColorHex) ?? .teal)

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
                            .fill(Color(hex: viewModel.customCategoryColorHex) ?? .teal)
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

    // MARK: - Location Section

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Localização (opcional)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)

            // State 1: Location saved with GPS coordinates - show card with map
            if viewModel.saveLocation && viewModel.useCurrentLocation && (viewModel.latitude != nil || viewModel.isLoadingLocation) {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.green)

                        if viewModel.isLoadingLocation {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Obtendo localização...")
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.locationName.isEmpty ? "Localização atual" : viewModel.locationName)
                                    .foregroundColor(AppColors.textPrimary)
                                    .lineLimit(2)
                            }
                        }

                        Spacer()

                        Button(action: {
                            viewModel.clearLocation()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .padding(16)

                    // Map preview when we have coordinates
                    if let lat = viewModel.latitude, let lon = viewModel.longitude, !viewModel.isLoadingLocation {
                        locationMapPreview(latitude: lat, longitude: lon)
                    }
                }
                .background(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(16)
            }
            // State 2: Manual location entry mode (with or without coordinates from search)
            else if viewModel.saveLocation && !viewModel.useCurrentLocation {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: viewModel.latitude != nil ? "mappin.circle.fill" : "mappin")
                            .foregroundColor(viewModel.latitude != nil ? .green : AppColors.textSecondary)

                        TextField("Ex: Shopping Center Norte", text: $viewModel.locationName)
                            .foregroundColor(AppColors.textPrimary)
                            .submitLabel(.search)
                            .onSubmit {
                                Task {
                                    await viewModel.searchLocation()
                                }
                            }

                        if viewModel.isSearchingLocation {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        }

                        Button(action: {
                            viewModel.clearLocation()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .padding(16)

                    // Search Results
                    if !viewModel.locationSearchResults.isEmpty {
                        Divider()
                            .background(AppColors.cardBorder)

                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(viewModel.locationSearchResults) { result in
                                    Button(action: {
                                        viewModel.selectLocation(result)
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "mappin.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 20))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(result.name)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(AppColors.textPrimary)
                                                    .lineLimit(1)

                                                if !result.address.isEmpty && result.address != result.name {
                                                    Text(result.address)
                                                        .font(.caption)
                                                        .foregroundColor(AppColors.textSecondary)
                                                        .lineLimit(1)
                                                }
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(AppColors.textTertiary)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    if result.id != viewModel.locationSearchResults.last?.id {
                                        Divider()
                                            .background(AppColors.cardBorder)
                                            .padding(.leading, 48)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }

                    // Map preview when location was selected from search
                    if let lat = viewModel.latitude, let lon = viewModel.longitude, viewModel.locationSearchResults.isEmpty {
                        Divider()
                            .background(AppColors.cardBorder)
                        locationMapPreview(latitude: lat, longitude: lon)
                    }
                }
                .background(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(viewModel.latitude != nil ? Color.green.opacity(0.3) : AppColors.cardBorder, lineWidth: 1)
                )
                .cornerRadius(16)
            }
            // State 3: Initial state - show buttons
            else {
                HStack(spacing: 12) {
                    // Current location button
                    Button(action: {
                        Task {
                            await viewModel.fetchCurrentLocation()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if viewModel.isLoadingLocation {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "location.fill")
                            }
                            Text("Usar atual")
                                .font(.subheadline)
                        }
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoadingLocation)

                    // Map picker button (Inserir manualmente)
                    Button(action: {
                        viewModel.showMapPicker = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin")
                            Text("Inserir manualmente")
                                .font(.subheadline)
                        }
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: - Map Preview

    private func locationMapPreview(latitude: Double, longitude: Double) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )

        return Map(initialPosition: .region(region), interactionModes: []) {
            Marker(viewModel.locationName.isEmpty ? "Localização" : viewModel.locationName, coordinate: coordinate)
                .tint(.green)
        }
        .frame(height: 120)
        .clipShape(
            .rect(
                topLeadingRadius: 0,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 16,
                topTrailingRadius: 0
            )
        )
        .allowsHitTesting(false)
    }

    // MARK: - Installment Section

    private var installmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tipo de Pagamento")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)

            HStack(spacing: 12) {
                // À vista option
                Button(action: {
                    viewModel.installments = 1
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.installments == 1 ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(viewModel.installments == 1 ? .green : AppColors.textTertiary)
                        Text("À vista")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(viewModel.installments == 1 ? Color.green.opacity(0.1) : AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(viewModel.installments == 1 ? Color.green.opacity(0.3) : AppColors.cardBorder, lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())

                // Parcelado option
                Menu {
                    ForEach(2...24, id: \.self) { i in
                        Button(action: {
                            viewModel.installments = i
                        }) {
                            HStack {
                                Text("\(i)x")
                                if viewModel.installments == i {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.installments > 1 ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(viewModel.installments > 1 ? .purple : AppColors.textTertiary)
                        Text(viewModel.installments > 1 ? "\(viewModel.installments)x" : "Parcelado")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(viewModel.installments > 1 ? Color.purple.opacity(0.1) : AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(viewModel.installments > 1 ? Color.purple.opacity(0.3) : AppColors.cardBorder, lineWidth: 1)
                    )
                    .cornerRadius(12)
                }

                Spacer()
            }

            // Show installment value preview
            if viewModel.installments > 1, !viewModel.amount.isEmpty {
                let cleanAmount = viewModel.amount
                    .replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: ".")
                if let total = Double(cleanAmount) {
                    let perInstallment = total / Double(viewModel.installments)
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                        Text("\(viewModel.installments)x de R$ \(String(format: "%.2f", perInstallment).replacingOccurrences(of: ".", with: ","))")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .animation(.none, value: viewModel.installments)
    }

    // MARK: - Payment Method Picker

    private var paymentMethodPicker: some View {
        Menu {
            // Opções básicas: Dinheiro, Pix, Débito
            Button(action: {
                viewModel.paymentMethod = .cash
                viewModel.selectedCreditCard = nil
            }) {
                HStack {
                    Image(systemName: PaymentMethod.cash.icon)
                    Text(PaymentMethod.cash.rawValue)
                    if viewModel.paymentMethod == .cash {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Button(action: {
                viewModel.paymentMethod = .pix
                viewModel.selectedCreditCard = nil
            }) {
                HStack {
                    Image(systemName: PaymentMethod.pix.icon)
                    Text(PaymentMethod.pix.rawValue)
                    if viewModel.paymentMethod == .pix {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Button(action: {
                viewModel.paymentMethod = .debit
                viewModel.selectedCreditCard = nil
            }) {
                HStack {
                    Image(systemName: PaymentMethod.debit.icon)
                    Text(PaymentMethod.debit.rawValue)
                    if viewModel.paymentMethod == .debit {
                        Image(systemName: "checkmark")
                    }
                }
            }

            // Cartões de Crédito (se houver)
            if !viewModel.creditCards.isEmpty {
                Divider()

                // Seção de Cartões de Crédito
                ForEach(viewModel.creditCards, id: \.id) { card in
                    Button(action: {
                        viewModel.paymentMethod = .credit
                        viewModel.selectedCreditCard = card
                    }) {
                        HStack {
                            Image(systemName: "creditcard.fill")
                                .foregroundColor(cardColor(for: card))
                            Text(card.cardName)
                            if viewModel.paymentMethod == .credit && viewModel.selectedCreditCard?.id == card.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack {
                // Ícone baseado no método selecionado
                if viewModel.paymentMethod == .credit, let card = viewModel.selectedCreditCard {
                    miniCardIcon(for: card)
                    Text(card.cardName)
                        .foregroundColor(AppColors.textPrimary)
                } else {
                    Image(systemName: viewModel.paymentMethod.icon)
                        .foregroundColor(paymentMethodColor)
                    Text(viewModel.paymentMethod.rawValue)
                        .foregroundColor(AppColors.textPrimary)
                }

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

    private var paymentMethodColor: Color {
        switch viewModel.paymentMethod {
        case .cash: return .green
        case .pix: return .cyan
        case .debit: return .orange
        case .credit: return .purple
        }
    }

    private func miniCardIcon(for card: CreditCard) -> some View {
        let cardColors: [Color] = {
            if let match = AvailableBankCards.cards(forBank: card.bankEnum).first(where: { $0.tier == card.cardTypeEnum }) {
                if let color = Color(hex: match.cardColor) {
                    return [color.opacity(0.9), color]
                }
            }
            return card.cardTypeEnum.gradientColors
        }()

        return RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: cardColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 28, height: 18)
            .overlay(
                RoundedRectangle(cornerRadius: 1)
                    .fill(LinearGradient(colors: [.yellow.opacity(0.8), .orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 6, height: 4)
                    .offset(x: -6, y: 2)
            )
    }

    private func cardColor(for card: CreditCard) -> Color {
        if let match = AvailableBankCards.cards(forBank: card.bankEnum).first(where: { $0.tier == card.cardTypeEnum }) {
            if let color = Color(hex: match.cardColor) {
                return color
            }
        }
        return card.cardTypeEnum.gradientColors.first ?? .purple
    }

    /// Formata entrada para moeda brasileira (apenas números, com vírgula para decimais)
    private func formatCurrencyInput(_ input: String) -> String {
        // Remove tudo que não é número
        let digitsOnly = input.filter { $0.isNumber }

        // Se vazio, retorna vazio
        guard !digitsOnly.isEmpty else { return "" }

        // Converte para centavos
        guard let cents = Int(digitsOnly) else { return "" }

        // Formata como moeda (divide por 100 para obter reais)
        let reais = Double(cents) / 100.0

        // Formata com separador de milhares e vírgula decimal
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        return formatter.string(from: NSNumber(value: reais)) ?? ""
    }
}

// MARK: - Location Map Picker Sheet

struct LocationMapPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AddTransactionViewModel

    // Map camera position - start with a default region, will be updated on appear
    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -23.5505, longitude: -46.6333),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var initialCoordinate: CLLocationCoordinate2D?
    @State private var isLoadingAddress = false
    @State private var addressPreview: String = ""
    @State private var isLoadingInitialLocation = true
    @State private var hasUserInteracted = false
    @State private var geocodeTask: Task<Void, Never>?

    // Search
    @State private var searchQuery: String = ""
    @State private var searchResults: [LocationSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool

    private let locationManager = CLLocationManager()

    var body: some View {
        ZStack {
            DarkBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    Text("Escolher no Mapa")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Button("Confirmar") {
                        if let coord = selectedCoordinate {
                            Task {
                                viewModel.saveLocation = true
                                viewModel.useCurrentLocation = false
                                await viewModel.updateLocationFromMap(
                                    latitude: coord.latitude,
                                    longitude: coord.longitude
                                )
                                dismiss()
                            }
                        } else {
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.accentBlue)
                }
                .padding()

                // Map with centered pin
                ZStack {
                    Map(position: $mapCameraPosition, interactionModes: [.pan, .zoom]) {
                    }
                    .onMapCameraChange(frequency: .onEnd) { context in
                        let newCoord = context.camera.centerCoordinate
                        selectedCoordinate = newCoord

                        // Only geocode if user has moved the map significantly from initial position
                        guard let initial = initialCoordinate else { return }

                        let latDiff = abs(newCoord.latitude - initial.latitude)
                        let lonDiff = abs(newCoord.longitude - initial.longitude)

                        // Check if user moved more than ~100 meters from initial position
                        let hasMovedSignificantly = latDiff > 0.001 || lonDiff > 0.001

                        if hasMovedSignificantly && !hasUserInteracted {
                            hasUserInteracted = true
                        }

                        // Only trigger geocoding if user has actually interacted
                        if hasUserInteracted {
                            reverseGeocodeCoordinate(newCoord)
                        }
                    }

                    // Center pin overlay
                    VStack(spacing: 0) {
                        Image(systemName: "mappin")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.green)

                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)

                    // Loading overlay
                    if isLoadingInitialLocation {
                        Color.black.opacity(0.5)
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                            Text("Obtendo localização...")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                }

                // Search bar and results
                VStack(spacing: 0) {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.textSecondary)

                        TextField("Buscar endereço...", text: $searchQuery)
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                            .focused($isSearchFocused)
                            .onChange(of: searchQuery) { _, newValue in
                                performSearch(query: newValue)
                            }

                        if isSearching {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        } else if !searchQuery.isEmpty {
                            Button(action: {
                                searchQuery = ""
                                searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                    .padding()
                    .background(AppColors.cardBackground)

                    // Current address indicator (when not searching)
                    if searchQuery.isEmpty && !addressPreview.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)

                            if isLoadingAddress {
                                Text("Buscando endereço...")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            } else {
                                Text(addressPreview)
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(AppColors.bgSecondary)
                    }

                    // Search results
                    if !searchResults.isEmpty {
                        Divider()
                            .background(AppColors.cardBorder)

                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(searchResults) { result in
                                    Button(action: {
                                        selectSearchResult(result)
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "mappin.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 20))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(result.name)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(AppColors.textPrimary)
                                                    .lineLimit(1)

                                                if !result.address.isEmpty && result.address != result.name {
                                                    Text(result.address)
                                                        .font(.caption)
                                                        .foregroundColor(AppColors.textSecondary)
                                                        .lineLimit(1)
                                                }
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(AppColors.textTertiary)
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    if result.id != searchResults.last?.id {
                                        Divider()
                                            .background(AppColors.cardBorder)
                                            .padding(.leading, 48)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                        .background(AppColors.cardBackground)
                    }
                }
                .background(AppColors.cardBackground)
                .cornerRadius(16)
                .padding()
            }
        }
        .task {
            await setupInitialPosition()
        }
    }

    private func setupInitialPosition() async {
        // If we already have coordinates from viewModel, use them
        if let lat = viewModel.latitude, let lon = viewModel.longitude {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            selectedCoordinate = coord
            initialCoordinate = coord
            addressPreview = viewModel.locationName

            let region = MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )
            mapCameraPosition = .region(region)
            isLoadingInitialLocation = false
            return
        }

        // Request location permission
        locationManager.requestWhenInUseAuthorization()

        // Wait a bit for location to be available
        try? await Task.sleep(nanoseconds: 800_000_000)

        // Get current location
        if let location = locationManager.location {
            let coord = location.coordinate
            selectedCoordinate = coord
            initialCoordinate = coord

            let region = MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )
            mapCameraPosition = .region(region)

            // Fetch address for initial location
            await fetchInitialAddress(coord)
        }

        isLoadingInitialLocation = false
    }

    private func fetchInitialAddress(_ coordinate: CLLocationCoordinate2D) async {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        // Usar nova API MKReverseGeocodingRequest do iOS 26
        guard let request = MKReverseGeocodingRequest(location: location) else {
            addressPreview = "Local selecionado"
            return
        }

        do {
            let mapItems = try await request.mapItems
            if let mapItem = mapItems.first {
                addressPreview = mapItem.address?.shortAddress ?? "Local selecionado"
            } else {
                addressPreview = "Local selecionado"
            }
        } catch {
            addressPreview = "Local selecionado"
        }
    }

    private func reverseGeocodeCoordinate(_ coordinate: CLLocationCoordinate2D) {
        // Cancel previous task
        geocodeTask?.cancel()

        geocodeTask = Task {
            // Debounce - wait before starting geocoding
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce

            if Task.isCancelled { return }

            // Now show loading
            await MainActor.run {
                isLoadingAddress = true
            }

            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

            // Usar nova API MKReverseGeocodingRequest do iOS 26
            guard let request = MKReverseGeocodingRequest(location: location) else {
                await MainActor.run {
                    addressPreview = "Local selecionado"
                    isLoadingAddress = false
                }
                return
            }

            do {
                let mapItems = try await request.mapItems

                if Task.isCancelled { return }

                let address = mapItems.first?.address?.shortAddress ?? "Local selecionado"

                await MainActor.run {
                    addressPreview = address
                    isLoadingAddress = false
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        addressPreview = "Local selecionado"
                        isLoadingAddress = false
                    }
                }
            }
        }
    }

    // MARK: - Search

    private func performSearch(query: String) {
        searchTask?.cancel()

        guard query.count >= 2 else {
            searchResults = []
            return
        }

        searchTask = Task {
            // Debounce
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

            if Task.isCancelled { return }

            await MainActor.run {
                isSearching = true
            }

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.resultTypes = [.address, .pointOfInterest]

            // Use current map region for better results
            if let coord = selectedCoordinate {
                request.region = MKCoordinateRegion(
                    center: coord,
                    latitudinalMeters: 50000,
                    longitudinalMeters: 50000
                )
            }

            let search = MKLocalSearch(request: request)

            do {
                let response = try await search.start()

                if Task.isCancelled { return }

                let results = response.mapItems.compactMap { item -> LocationSearchResult? in
                    guard let name = item.name else { return nil }

                    // Usar nova API address do iOS 26
                    let address = item.address?.shortAddress ?? ""

                    return LocationSearchResult(
                        name: name,
                        address: address,
                        coordinate: item.location.coordinate
                    )
                }

                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        searchResults = []
                        isSearching = false
                    }
                }
            }
        }
    }

    private func selectSearchResult(_ result: LocationSearchResult) {
        // Update map position
        let region = MKCoordinateRegion(
            center: result.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        mapCameraPosition = .region(region)

        // Update selected coordinate and address
        selectedCoordinate = result.coordinate
        initialCoordinate = result.coordinate
        addressPreview = result.name
        hasUserInteracted = false

        // Clear search
        searchQuery = ""
        searchResults = []
        isSearchFocused = false
    }
}

// MARK: - Category Management Sheet

struct CategoryManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    let categories: [Category]
    let onUpdate: (Category, String, String) -> Void
    let onDelete: (Category) -> Void

    @State private var editingCategory: Category?
    @State private var categoryToDelete: Category?
    @State private var showDeleteConfirmation = false

    var body: some View {
        ZStack {
            DarkBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Fechar") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    Text("Gerenciar Categorias")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    // Spacer for symmetry
                    Text("Fechar")
                        .foregroundColor(.clear)
                }
                .padding()

                if categories.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "folder")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.textTertiary)
                        Text("Nenhuma categoria")
                            .font(.headline)
                            .foregroundColor(AppColors.textSecondary)
                        Text("Crie categorias ao adicionar transações")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(categories) { category in
                                CategoryManagementRow(
                                    category: category,
                                    onEdit: { editingCategory = category },
                                    onDelete: {
                                        categoryToDelete = category
                                        showDeleteConfirmation = true
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditView(category: category) { name, colorHex in
                onUpdate(category, name, colorHex)
            }
        }
        .alert("Excluir Categoria", isPresented: $showDeleteConfirmation) {
            Button("Cancelar", role: .cancel) {
                categoryToDelete = nil
            }
            Button("Excluir", role: .destructive) {
                if let category = categoryToDelete {
                    onDelete(category)
                    categoryToDelete = nil
                }
            }
        } message: {
            if let category = categoryToDelete {
                Text("Tem certeza que deseja excluir a categoria \"\(category.name)\"? Transações com essa categoria não serão excluídas.")
            }
        }
    }
}

// MARK: - Category Management Row

private struct CategoryManagementRow: View {
    let category: Category
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Category icon
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: category.iconName)
                    .font(.system(size: 18))
                    .foregroundColor(category.color)
            }

            // Category name
            Text(category.name)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            // Edit button
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(AppColors.cardBackground)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.expense)
                    .frame(width: 36, height: 36)
                    .background(AppColors.expense.opacity(0.1))
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
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
