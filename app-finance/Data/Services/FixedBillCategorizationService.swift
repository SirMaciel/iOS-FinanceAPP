import Foundation

/// Service for suggesting categories based on fixed bill name
/// Usa IA do servidor (GPT) quando online, fallback local quando offline
class FixedBillCategorizationService {
    static let shared = FixedBillCategorizationService()

    private let api = FixedBillsAPI.shared

    private init() {}

    // MARK: - Server AI Categorization

    /// Sugere categoria usando IA do servidor (gpt-5-nano, reasoning_effort: minimal - resposta instantânea)
    func suggestCategoryFromServer(
        for billName: String,
        amount: Double? = nil,
        existingCustomCategories: [ExistingCategoryRequest]? = nil
    ) async -> CategorySuggestion {
        do {
            let response = try await api.suggestCategory(
                name: billName,
                amount: amount,
                existingCategories: existingCustomCategories
            )

            let confidence: SuggestionConfidence
            if response.confidence >= 0.8 {
                confidence = .high
            } else if response.confidence >= 0.5 {
                confidence = .medium
            } else {
                confidence = .low
            }

            // Verificar se a IA criou uma categoria customizada
            // IMPORTANTE: "Outros" NUNCA é customizada - é categoria predefinida
            let normalizedCategory = response.category.lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
            let isOther = normalizedCategory == "outros" || normalizedCategory == "other"
            let isCustom = isOther ? false : (response.isCustom ?? false)

            if isCustom {
                // Categoria customizada criada pela IA
                return CategorySuggestion(
                    category: .custom,
                    confidence: confidence,
                    matchedKeyword: nil,
                    aiReasoning: response.reasoning,
                    isFromServer: true,
                    customCategoryName: response.category,
                    customCategoryIcon: response.icon ?? "tag.fill"
                )
            } else {
                // Categoria predefinida
                return CategorySuggestion(
                    category: response.fixedBillCategory,
                    confidence: confidence,
                    matchedKeyword: nil,
                    aiReasoning: response.reasoning,
                    isFromServer: true
                )
            }
        } catch {
            print("⚠️ [FixedBillCategorizationService] Erro ao chamar API, usando fallback local: \(error)")
            // Fallback para categorização local
            return suggestCategory(for: billName)
        }
    }

    // MARK: - Category Keywords
    // Prioridade: keywords mais específicas têm peso maior
    // Streaming/SaaS = Assinatura, Lazer físico = Entretenimento

    private let categoryKeywords: [FixedBillCategory: [String]] = [
        .housing: [
            "aluguel", "condomínio", "condominio", "iptu", "casa", "apartamento",
            "moradia", "hipoteca", "financiamento imobiliário", "financiamento imobiliario",
            "rent", "mortgage", "imóvel", "imovel"
        ],
        .utilities: [
            "luz", "água", "agua", "energia", "eletricidade", "gás", "gas",
            "enel", "cemig", "light", "cpfl", "celesc", "copel", "sabesp",
            "sanepar", "comgas", "naturgy", "equatorial", "neoenergia", "energisa"
        ],
        .health: [
            "plano de saúde", "plano de saude", "saúde", "saude", "convênio médico",
            "convenio medico", "unimed", "amil", "bradesco saúde", "bradesco saude",
            "sulamerica saude", "hapvida", "notredame", "dental", "odontológico",
            "odontologico", "odontoprev", "farmácia", "farmacia", "drogaria",
            "academia", "gym", "smartfit", "smart fit", "bluefit", "bodytech"
        ],
        .education: [
            "faculdade", "universidade", "escola", "curso", "mensalidade escolar",
            "colégio", "colegio", "educação", "educacao", "material escolar",
            "inglês", "ingles", "idioma", "pós-graduação", "pos-graduacao", "mba",
            "duolingo", "alura", "udemy", "coursera", "wizard", "ccaa", "fisk"
        ],
        .transport: [
            "carro", "moto", "veículo", "veiculo", "combustível", "combustivel",
            "gasolina", "etanol", "ipva", "licenciamento", "seguro auto",
            "estacionamento", "pedágio", "pedagio", "transporte",
            "metrô", "metro", "ônibus", "onibus", "bilhete único", "bilhete unico"
        ],
        .subscription: [
            // Streaming de vídeo
            "netflix", "amazon prime", "prime video", "disney", "disney+",
            "hbo", "hbo max", "max", "globoplay", "apple tv", "paramount",
            "star+", "starplus", "crunchyroll", "mubi", "telecine", "youtube premium",
            // Streaming de música
            "spotify", "deezer", "apple music", "tidal", "amazon music",
            // Streaming de jogos
            "xbox game pass", "gamepass", "playstation plus", "ps plus",
            "nintendo online", "geforce now", "steam",
            // Software/SaaS
            "microsoft 365", "office 365", "adobe", "creative cloud",
            "dropbox", "icloud", "google one", "notion", "canva", "figma",
            "chatgpt", "openai", "github", "copilot",
            // Outros
            "linkedin", "tinder", "bumble", "rappi prime", "ifood",
            "assinatura", "streaming", "mensalidade app"
        ],
        .entertainment: [
            // Lazer físico/presencial
            "cinema", "teatro", "show", "ingresso", "evento",
            "clube", "parque", "lazer", "diversão", "diversao",
            "bar", "restaurante", "balada"
        ],
        .insurance: [
            "seguro", "seguradora", "porto seguro", "bradesco seguros", "sulamerica seguros",
            "itaú seguros", "itau seguros", "liberty", "allianz", "mapfre", "tokio marine",
            "seguro de vida", "seguro residencial", "proteção", "protecao",
            "previdência", "previdencia", "prev"
        ],
        .loan: [
            "empréstimo", "emprestimo", "financiamento", "crédito", "credito",
            "parcela", "consignado", "dívida", "divida", "prestação", "prestacao"
        ]
    ]

    // Telecomunicações têm categoria própria dentro de utilities
    private let telecomKeywords: [String] = [
        "internet", "telefone", "celular", "móvel", "movel", "fibra",
        "vivo", "claro", "tim", "oi", "net", "sky", "brisanet", "algar"
    ]

    // MARK: - Category Suggestion

    /// Suggests a category based on the bill name using keyword matching
    func suggestCategory(for billName: String) -> CategorySuggestion {
        let normalizedName = billName.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)

        var bestMatch: FixedBillCategory = .other
        var highestScore: Int = 0
        var matchedKeyword: String?

        // Primeiro, verificar keywords principais
        for (category, keywords) in categoryKeywords {
            for keyword in keywords {
                let normalizedKeyword = keyword.lowercased()
                    .folding(options: .diacriticInsensitive, locale: .current)

                if normalizedName.contains(normalizedKeyword) {
                    // Score baseado no tamanho + bonus para match exato
                    var score = normalizedKeyword.count

                    // Bonus para match mais preciso (palavra inteira)
                    if normalizedName == normalizedKeyword ||
                       normalizedName.hasPrefix(normalizedKeyword + " ") ||
                       normalizedName.hasSuffix(" " + normalizedKeyword) ||
                       normalizedName.contains(" " + normalizedKeyword + " ") {
                        score += 5
                    }

                    if score > highestScore {
                        highestScore = score
                        bestMatch = category
                        matchedKeyword = keyword
                    }
                }
            }
        }

        // Verificar telecom (mapeia para utilities)
        for keyword in telecomKeywords {
            let normalizedKeyword = keyword.lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)

            if normalizedName.contains(normalizedKeyword) {
                var score = normalizedKeyword.count
                if normalizedName == normalizedKeyword ||
                   normalizedName.hasPrefix(normalizedKeyword + " ") ||
                   normalizedName.hasSuffix(" " + normalizedKeyword) {
                    score += 5
                }

                if score > highestScore {
                    highestScore = score
                    bestMatch = .utilities
                    matchedKeyword = keyword
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

        return CategorySuggestion(
            category: bestMatch,
            confidence: confidence,
            matchedKeyword: matchedKeyword
        )
    }

    /// Returns all possible category suggestions sorted by relevance
    func getAllSuggestions(for billName: String) -> [CategorySuggestion] {
        let normalizedName = billName.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)

        var suggestions: [FixedBillCategory: (score: Int, keyword: String?)] = [:]

        for (category, keywords) in categoryKeywords {
            for keyword in keywords {
                let normalizedKeyword = keyword.lowercased()
                    .folding(options: .diacriticInsensitive, locale: .current)

                if normalizedName.contains(normalizedKeyword) {
                    let score = normalizedKeyword.count
                    if let existing = suggestions[category] {
                        if score > existing.score {
                            suggestions[category] = (score, keyword)
                        }
                    } else {
                        suggestions[category] = (score, keyword)
                    }
                }
            }
        }

        return suggestions
            .map { category, data in
                let confidence: SuggestionConfidence
                if data.score >= 8 {
                    confidence = .high
                } else if data.score >= 4 {
                    confidence = .medium
                } else {
                    confidence = .low
                }
                return CategorySuggestion(
                    category: category,
                    confidence: confidence,
                    matchedKeyword: data.keyword
                )
            }
            .sorted { $0.confidence.rawValue > $1.confidence.rawValue }
    }
}

// MARK: - Supporting Types

struct CategorySuggestion {
    let category: FixedBillCategory
    let confidence: SuggestionConfidence
    let matchedKeyword: String?
    let aiReasoning: String?
    let isFromServer: Bool
    let customCategoryName: String?
    let customCategoryIcon: String?

    init(
        category: FixedBillCategory,
        confidence: SuggestionConfidence,
        matchedKeyword: String? = nil,
        aiReasoning: String? = nil,
        isFromServer: Bool = false,
        customCategoryName: String? = nil,
        customCategoryIcon: String? = nil
    ) {
        self.category = category
        self.confidence = confidence
        self.matchedKeyword = matchedKeyword
        self.aiReasoning = aiReasoning
        self.isFromServer = isFromServer
        self.customCategoryName = customCategoryName
        self.customCategoryIcon = customCategoryIcon
    }

    /// Verifica se é uma categoria customizada criada pela IA
    var isCustomCategory: Bool {
        category == .custom && customCategoryName != nil
    }

    /// Nome para exibição (customizado ou predefinido)
    var displayName: String {
        customCategoryName ?? category.rawValue
    }

    /// Ícone para exibição (customizado ou predefinido)
    var displayIcon: String {
        customCategoryIcon ?? category.icon
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

    var sourceIcon: String {
        isFromServer ? "brain.head.profile" : "sparkles"
    }
}

enum SuggestionConfidence: Int, Comparable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    static func < (lhs: SuggestionConfidence, rhs: SuggestionConfidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
