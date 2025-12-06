import SwiftUI
import SwiftData

struct CategoriesView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = CategoriesViewModel()
    @State private var editingCategory: Category?
    @State private var isEditMode = false

    var body: some View {
        ZStack {
            // Background
            DarkBackground(blurColor1: AppColors.blurPurple, blurColor2: AppColors.blurBlue)

            // Content
            VStack(spacing: 0) {
                // Header com indicador offline e botão editar
                HStack {
                    DarkSectionHeader(title: "Suas Categorias", icon: "folder.fill")

                    Spacer()

                    if viewModel.isOffline {
                        HStack(spacing: 4) {
                            Image(systemName: "wifi.slash")
                                .font(.caption2)
                            Text("Offline")
                                .font(.caption2)
                        }
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.cardBackground)
                        .cornerRadius(8)
                    }

                    if !viewModel.categories.isEmpty {
                        Button(action: { isEditMode.toggle() }) {
                            Text(isEditMode ? "OK" : "Editar")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.accentBlue)
                        }
                        .padding(.leading, 8)
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                if viewModel.isLoading && viewModel.categories.isEmpty {
                    DarkLoadingOverlay()
                } else if viewModel.categories.isEmpty {
                    emptyState
                        .padding()
                } else {
                    List {
                        ForEach(viewModel.categories, id: \.id) { category in
                            CategoryCard(category: category) {
                                editingCategory = category
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                        .onMove(perform: viewModel.moveCategory)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .environment(\.editMode, .constant(isEditMode ? .active : .inactive))
                    .refreshable {
                        if let userId = authManager.userId {
                            await viewModel.loadCategories(userId: userId)
                        }
                    }
                }
            }
        }
        .task {
            if let userId = authManager.userId {
                await viewModel.loadCategories(userId: userId)
            }
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditView(category: category) { name, colorHex in
                viewModel.updateCategory(category, name: name, colorHex: colorHex)
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
    }

    private var emptyState: some View {
        DarkEmptyState(
            icon: "folder",
            title: "Nenhuma categoria ainda",
            subtitle: "Categorias serão criadas automaticamente ao adicionar gastos"
        )
    }
}
