import Foundation

/// Service for suggesting categories based on transaction name
/// Uses server AI (GPT) when online, local fallback when offline
class TransactionCategorizationService {
    static let shared = TransactionCategorizationService()

    private let api = FixedBillsAPI.shared

    private init() {}

    // MARK: - Server AI Categorization

    /// Suggests category using server AI (reuses the same categorization endpoint as fixed bills)
    func suggestCategoryFromServer(
        for transactionName: String,
        amount: Double? = nil,
        existingCategories: [Category]
    ) async -> TransactionCategorySuggestion {
        do {
            let existingCatRequests = existingCategories.map {
                ExistingCategoryRequest(name: $0.name, icon: $0.iconName)
            }

            let response = try await api.suggestCategory(
                name: transactionName,
                amount: amount,
                existingCategories: existingCatRequests
            )

            let confidence: SuggestionConfidence
            if response.confidence >= 0.8 {
                confidence = .high
            } else if response.confidence >= 0.5 {
                confidence = .medium
            } else {
                confidence = .low
            }

            // Check if AI created a custom category
            let isCustom = response.isCustom ?? false

            if isCustom {
                // Custom category created by AI
                return TransactionCategorySuggestion(
                    existingCategory: nil,
                    confidence: confidence,
                    matchedKeyword: nil,
                    aiReasoning: response.reasoning,
                    isFromServer: true,
                    customCategoryName: response.category,
                    customCategoryIcon: response.icon ?? "tag.fill",
                    customCategoryColorHex: "#14B8A6"
                )
            } else {
                // Find matching existing category
                let matchedCategory = existingCategories.first { cat in
                    cat.name.lowercased() == response.category.lowercased()
                }

                return TransactionCategorySuggestion(
                    existingCategory: matchedCategory,
                    confidence: confidence,
                    matchedKeyword: nil,
                    aiReasoning: response.reasoning,
                    isFromServer: true,
                    customCategoryName: matchedCategory == nil ? response.category : nil,
                    customCategoryIcon: response.icon
                )
            }
        } catch {
            print("⚠️ [TransactionCategorizationService] Error calling API, using local fallback: \(error)")
            // Fallback to local categorization
            return suggestCategory(for: transactionName, existingCategories: existingCategories)
        }
    }

    // MARK: - Local Category Suggestion

    private let categoryKeywords: [String: [String]] = [
        "Alimentação": [
            "mercado", "supermercado", "padaria", "açougue", "hortifruti",
            "restaurante", "lanchonete", "ifood", "rappi", "uber eats",
            "mcdonald", "burger king", "subway", "pizza", "sushi",
            "café", "cafeteria", "starbucks", "comida", "almoço", "jantar"
        ],
        "Transporte": [
            "uber", "99", "taxi", "combustível", "gasolina", "etanol",
            "estacionamento", "pedágio", "ônibus", "metrô", "trem",
            "passagem", "bilhete", "posto", "shell", "ipiranga", "br"
        ],
        "Compras": [
            "shopping", "loja", "magazine", "americanas", "casas bahia",
            "amazon", "mercado livre", "shopee", "aliexpress", "shein",
            "roupa", "calçado", "tênis", "sapato", "camisa", "calça"
        ],
        "Lazer": [
            "cinema", "teatro", "show", "ingresso", "netflix", "spotify",
            "disney", "hbo", "amazon prime", "streaming", "jogo", "game",
            "ps5", "xbox", "nintendo", "bar", "balada", "festa"
        ],
        "Saúde": [
            "farmácia", "drogaria", "remédio", "medicamento", "consulta",
            "médico", "dentista", "hospital", "clínica", "exame",
            "academia", "gym", "smartfit", "crossfit"
        ],
        "Educação": [
            "curso", "livro", "escola", "faculdade", "mensalidade",
            "material", "apostila", "udemy", "alura", "coursera"
        ],
        "Casa": [
            "aluguel", "condomínio", "luz", "água", "gás", "internet",
            "móveis", "decoração", "reforma", "manutenção", "limpeza"
        ],
        "Serviços": [
            "celular", "telefone", "plano", "assinatura", "mensalidade",
            "seguro", "banco", "tarifa", "anuidade"
        ]
    ]

    /// Suggests a category based on the transaction name using keyword matching
    func suggestCategory(for transactionName: String, existingCategories: [Category]) -> TransactionCategorySuggestion {
        let normalizedName = transactionName.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)

        var bestMatchName: String?
        var highestScore: Int = 0
        var matchedKeyword: String?

        for (categoryName, keywords) in categoryKeywords {
            for keyword in keywords {
                let normalizedKeyword = keyword.lowercased()
                    .folding(options: .diacriticInsensitive, locale: .current)

                if normalizedName.contains(normalizedKeyword) {
                    var score = normalizedKeyword.count

                    // Bonus for exact match
                    if normalizedName == normalizedKeyword ||
                       normalizedName.hasPrefix(normalizedKeyword + " ") ||
                       normalizedName.hasSuffix(" " + normalizedKeyword) ||
                       normalizedName.contains(" " + normalizedKeyword + " ") {
                        score += 5
                    }

                    if score > highestScore {
                        highestScore = score
                        bestMatchName = categoryName
                        matchedKeyword = keyword
                    }
                }
            }
        }

        let confidence: SuggestionConfidence
        if highestScore >= 10 {
            confidence = .high
        } else if highestScore >= 5 {
            confidence = .medium
        } else if highestScore > 0 {
            confidence = .low
        } else {
            confidence = .none
        }

        // Find existing category with similar name
        var matchedCategory: Category?
        if let matchName = bestMatchName {
            matchedCategory = existingCategories.first { cat in
                cat.name.lowercased().contains(matchName.lowercased()) ||
                matchName.lowercased().contains(cat.name.lowercased())
            }
        }

        return TransactionCategorySuggestion(
            existingCategory: matchedCategory,
            confidence: confidence,
            matchedKeyword: matchedKeyword,
            isFromServer: false,
            customCategoryName: matchedCategory == nil ? bestMatchName : nil
        )
    }
}

// MARK: - Supporting Types

struct TransactionCategorySuggestion {
    let existingCategory: Category?
    let confidence: SuggestionConfidence
    let matchedKeyword: String?
    let aiReasoning: String?
    let isFromServer: Bool
    let customCategoryName: String?
    let customCategoryIcon: String?
    let customCategoryColorHex: String?

    init(
        existingCategory: Category? = nil,
        confidence: SuggestionConfidence,
        matchedKeyword: String? = nil,
        aiReasoning: String? = nil,
        isFromServer: Bool = false,
        customCategoryName: String? = nil,
        customCategoryIcon: String? = nil,
        customCategoryColorHex: String? = nil
    ) {
        self.existingCategory = existingCategory
        self.confidence = confidence
        self.matchedKeyword = matchedKeyword
        self.aiReasoning = aiReasoning
        self.isFromServer = isFromServer
        self.customCategoryName = customCategoryName
        self.customCategoryIcon = customCategoryIcon
        self.customCategoryColorHex = customCategoryColorHex
    }

    /// Check if it's a custom category suggestion
    var isCustomCategory: Bool {
        existingCategory == nil && customCategoryName != nil
    }

    /// Display name
    var displayName: String {
        existingCategory?.name ?? customCategoryName ?? "Sem categoria"
    }

    /// Display icon
    var displayIcon: String {
        existingCategory?.iconName ?? customCategoryIcon ?? "tag.fill"
    }

    /// Display color hex
    var displayColorHex: String {
        existingCategory?.colorHex ?? customCategoryColorHex ?? "#14B8A6"
    }

    var confidenceText: String {
        if isFromServer {
            switch confidence {
            case .high: return "Alta confiança"
            case .medium: return "Média confiança"
            case .low: return "Baixa confiança"
            case .none: return ""
            }
        } else {
            switch confidence {
            case .high: return "Sugestão forte"
            case .medium: return "Sugestão"
            case .low: return "Possível"
            case .none: return ""
            }
        }
    }
}
