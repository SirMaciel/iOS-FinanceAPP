import Foundation
import SwiftUI
import SwiftData

// MARK: - Card Brand

enum CardBrand: String, Codable, CaseIterable {
    case visa = "Visa"
    case mastercard = "Mastercard"
    case elo = "Elo"
    case amex = "American Express"
    case hipercard = "Hipercard"
    case other = "Outro"

    var icon: String {
        switch self {
        case .visa: return "v.square.fill"
        case .mastercard: return "m.square.fill"
        case .elo: return "e.square.fill"
        case .amex: return "a.square.fill"
        case .hipercard: return "h.square.fill"
        case .other: return "creditcard.fill"
        }
    }
}

// MARK: - Card Type

enum CardType: String, Codable, CaseIterable {
    case black = "Black"
    case platinum = "Platinum"
    case gold = "Gold"
    case standard = "Standard"

    var gradientColors: [Color] {
        switch self {
        case .black:
            return [Color(hex: "#1a1a2e") ?? .black, Color(hex: "#16213e") ?? .gray, Color(hex: "#0f0f0f") ?? .black]
        case .platinum:
            return [Color(hex: "#667eea") ?? .purple, Color(hex: "#764ba2") ?? .purple]
        case .gold:
            return [Color(hex: "#f093fb") ?? .orange, Color(hex: "#f5576c") ?? .red, Color(hex: "#ffd700") ?? .yellow]
        case .standard:
            return [Color(hex: "#4facfe") ?? .blue, Color(hex: "#00f2fe") ?? .cyan]
        }
    }
}

// MARK: - Bank

enum Bank: String, Codable, CaseIterable {
    case nubank = "Nubank"
    case inter = "Inter"
    case c6 = "C6 Bank"
    case itau = "Itaú"
    case bradesco = "Bradesco"
    case santander = "Santander"
    case bb = "Banco do Brasil"
    case caixa = "Caixa"
    case btg = "BTG Pactual"
    case xp = "XP"
    case safra = "Safra"
    case sicredi = "Sicredi"
    case sicoob = "Sicoob"
    case banrisul = "Banrisul"
    case mercantil = "Mercantil"
    case bmg = "BMG"
    case pan = "Banco Pan"
    case original = "Banco Original"
    case agibank = "Agibank"
    case digio = "Digio"
    case neon = "Neon"
    case next = "Next"
    case willbank = "Will Bank"
    case picpay = "PicPay"
    case trigg = "Trigg"
    case other = "Outro"

    var primaryColor: String {
        switch self {
        case .nubank: return "#820AD1"
        case .inter: return "#FF7A00"
        case .c6: return "#121212"
        case .itau: return "#FF7200"
        case .bradesco: return "#CC092F"
        case .santander: return "#EA1D25"
        case .bb: return "#F9DD16"
        case .caixa: return "#1C60AB"
        case .btg: return "#001E50"
        case .xp: return "#000000"
        case .safra: return "#00205B"
        case .sicredi: return "#00A651"
        case .sicoob: return "#003641"
        case .banrisul: return "#004B87"
        case .mercantil: return "#E31937"
        case .bmg: return "#FF6600"
        case .pan: return "#0066CC"
        case .original: return "#00A859"
        case .agibank: return "#00C4B3"
        case .digio: return "#0066FF"
        case .neon: return "#00E5A0"
        case .next: return "#00D47E"
        case .willbank: return "#FFD700"
        case .picpay: return "#22C25F"
        case .trigg: return "#00FF7F"
        case .other: return "#6B7280"
        }
    }

    var textColor: String {
        switch self {
        case .bb: return "#0038A8"
        case .neon, .willbank: return "#1A1A2E"
        default: return "#FFFFFF"
        }
    }
}

// MARK: - Predefined Bank Cards

struct BankCard: Identifiable, Hashable {
    let id: String
    let bank: Bank
    let name: String
    let displayName: String
    let cardColor: String
    let textColor: String
    let tier: CardType
    let defaultBrand: CardBrand

    init(id: String, bank: Bank, name: String, displayName: String, cardColor: String, textColor: String = "#FFFFFF", tier: CardType, defaultBrand: CardBrand = .mastercard) {
        self.id = id
        self.bank = bank
        self.name = name
        self.displayName = displayName
        self.cardColor = cardColor
        self.textColor = textColor
        self.tier = tier
        self.defaultBrand = defaultBrand
    }
}

struct AvailableBankCards {
    static let all: [BankCard] = [
        // NUBANK
        BankCard(id: "nubank_roxinho", bank: .nubank, name: "Roxinho", displayName: "Nubank Roxinho", cardColor: "#820AD1", tier: .gold),
        BankCard(id: "nubank_ultravioleta", bank: .nubank, name: "Ultravioleta", displayName: "Nubank Ultravioleta", cardColor: "#2D1B4E", tier: .black),

        // BANCO INTER
        BankCard(id: "inter_gold", bank: .inter, name: "Gold", displayName: "Inter Gold", cardColor: "#FF7A00", tier: .gold),
        BankCard(id: "inter_platinum", bank: .inter, name: "Platinum", displayName: "Inter Platinum", cardColor: "#FF7A00", tier: .platinum),
        BankCard(id: "inter_black", bank: .inter, name: "Black", displayName: "Inter Black", cardColor: "#1A1A1A", tier: .black),
        BankCard(id: "inter_black_win", bank: .inter, name: "Black Win", displayName: "Inter Black Win", cardColor: "#1A1A1A", tier: .black),

        // C6 BANK
        BankCard(id: "c6_standard", bank: .c6, name: "Standard", displayName: "C6 Bank", cardColor: "#2D2D2D", tier: .standard),
        BankCard(id: "c6_platinum", bank: .c6, name: "Platinum", displayName: "C6 Platinum", cardColor: "#A8A8A8", textColor: "#121212", tier: .platinum),
        BankCard(id: "c6_black", bank: .c6, name: "Black", displayName: "C6 Black", cardColor: "#1A1A1A", tier: .black),
        BankCard(id: "c6_carbon", bank: .c6, name: "Carbon", displayName: "C6 Carbon", cardColor: "#121212", tier: .black),
        BankCard(id: "c6_blue", bank: .c6, name: "Blue", displayName: "C6 Blue", cardColor: "#2563EB", tier: .standard),
        BankCard(id: "c6_pink", bank: .c6, name: "Pink", displayName: "C6 Pink", cardColor: "#EC4899", tier: .standard),
        BankCard(id: "c6_gold", bank: .c6, name: "Gold", displayName: "C6 Gold", cardColor: "#D4AF37", tier: .gold),

        // ITAÚ
        BankCard(id: "itau_click", bank: .itau, name: "Click", displayName: "Itaú Click", cardColor: "#1E3A5F", tier: .platinum, defaultBrand: .visa),
        BankCard(id: "itau_gold", bank: .itau, name: "Gold", displayName: "Itaú Gold", cardColor: "#D4AF37", tier: .gold),
        BankCard(id: "itau_platinum", bank: .itau, name: "Platinum", displayName: "Itaú Platinum", cardColor: "#7C7C7C", tier: .platinum),
        BankCard(id: "itau_personnalite_infinite", bank: .itau, name: "Personnalité Infinite", displayName: "Itaú Personnalité Visa Infinite", cardColor: "#1A1A1A", tier: .black, defaultBrand: .visa),
        BankCard(id: "itau_personnalite_black", bank: .itau, name: "Personnalité Black", displayName: "Itaú Personnalité Mastercard Black", cardColor: "#1A1A1A", tier: .black),
        BankCard(id: "itau_azul_gold", bank: .itau, name: "Azul Gold", displayName: "Azul Itaucard Gold", cardColor: "#0066CC", tier: .gold, defaultBrand: .visa),
        BankCard(id: "itau_azul_platinum", bank: .itau, name: "Azul Platinum", displayName: "Azul Itaucard Platinum", cardColor: "#1E3A5F", tier: .platinum, defaultBrand: .visa),
        BankCard(id: "itau_azul_infinite", bank: .itau, name: "Azul Infinite", displayName: "Azul Itaucard Visa Infinite", cardColor: "#1A1A1A", tier: .black, defaultBrand: .visa),
        BankCard(id: "itau_latam_gold", bank: .itau, name: "LATAM Pass Gold", displayName: "LATAM Pass Itaucard Gold", cardColor: "#D4AF37", tier: .gold, defaultBrand: .visa),
        BankCard(id: "itau_latam_platinum", bank: .itau, name: "LATAM Pass Platinum", displayName: "LATAM Pass Itaucard Platinum", cardColor: "#7C7C7C", tier: .platinum, defaultBrand: .visa),
        BankCard(id: "itau_latam_black", bank: .itau, name: "LATAM Pass Black", displayName: "LATAM Pass Itaucard Black", cardColor: "#1A1A1A", tier: .black),

        // BRADESCO
        BankCard(id: "bradesco_internacional", bank: .bradesco, name: "Internacional", displayName: "Bradesco Internacional", cardColor: "#CC092F", tier: .standard, defaultBrand: .visa),
        BankCard(id: "bradesco_gold", bank: .bradesco, name: "Gold", displayName: "Bradesco Gold", cardColor: "#D4AF37", tier: .gold, defaultBrand: .visa),
        BankCard(id: "bradesco_platinum", bank: .bradesco, name: "Platinum", displayName: "Bradesco Platinum", cardColor: "#7C7C7C", tier: .platinum, defaultBrand: .visa),
        BankCard(id: "bradesco_visa_infinite", bank: .bradesco, name: "Visa Infinite", displayName: "Bradesco Visa Infinite", cardColor: "#1A1A1A", tier: .black, defaultBrand: .visa),
        BankCard(id: "bradesco_black", bank: .bradesco, name: "Black", displayName: "Bradesco Mastercard Black", cardColor: "#1A1A1A", tier: .black),
        BankCard(id: "bradesco_aeternum", bank: .bradesco, name: "Aeternum", displayName: "Bradesco Aeternum", cardColor: "#0D0D0D", tier: .black, defaultBrand: .visa),
        BankCard(id: "bradesco_elo_mais", bank: .bradesco, name: "Elo Mais", displayName: "Bradesco Elo Mais", cardColor: "#0066CC", tier: .standard, defaultBrand: .elo),
        BankCard(id: "bradesco_elo_grafite", bank: .bradesco, name: "Elo Grafite", displayName: "Bradesco Elo Grafite", cardColor: "#4A4A4A", tier: .platinum, defaultBrand: .elo),
        BankCard(id: "bradesco_elo_nanquim", bank: .bradesco, name: "Elo Nanquim", displayName: "Bradesco Elo Nanquim", cardColor: "#0D0D0D", tier: .black, defaultBrand: .elo),
        BankCard(id: "bradesco_amex_green", bank: .bradesco, name: "Amex Green", displayName: "American Express Green", cardColor: "#006600", tier: .standard, defaultBrand: .amex),
        BankCard(id: "bradesco_amex_gold", bank: .bradesco, name: "Amex Gold", displayName: "American Express Gold", cardColor: "#D4AF37", tier: .gold, defaultBrand: .amex),
        BankCard(id: "bradesco_amex_platinum", bank: .bradesco, name: "Amex Platinum", displayName: "American Express Platinum", cardColor: "#C0C0C0", tier: .platinum, defaultBrand: .amex),
        BankCard(id: "bradesco_smiles_gold", bank: .bradesco, name: "Smiles Gold", displayName: "Bradesco Smiles Visa Gold", cardColor: "#D4AF37", tier: .gold, defaultBrand: .visa),
        BankCard(id: "bradesco_smiles_platinum", bank: .bradesco, name: "Smiles Platinum", displayName: "Bradesco Smiles Visa Platinum", cardColor: "#7C7C7C", tier: .platinum, defaultBrand: .visa),
        BankCard(id: "bradesco_smiles_infinite", bank: .bradesco, name: "Smiles Infinite", displayName: "Bradesco Smiles Visa Infinite", cardColor: "#1A1A1A", tier: .black, defaultBrand: .visa),

        // SANTANDER
        BankCard(id: "santander_sx", bank: .santander, name: "SX", displayName: "Santander SX", cardColor: "#FFFFFF", textColor: "#EA1D25", tier: .standard, defaultBrand: .visa),
        BankCard(id: "santander_play", bank: .santander, name: "Play", displayName: "Santander Play", cardColor: "#FFD700", textColor: "#1A1A1A", tier: .standard),
        BankCard(id: "santander_123", bank: .santander, name: "1|2|3", displayName: "Santander 1|2|3", cardColor: "#1A1A1A", tier: .platinum),
        BankCard(id: "santander_unique", bank: .santander, name: "Unique", displayName: "Santander Unique", cardColor: "#1A1A1A", tier: .black, defaultBrand: .visa),
        BankCard(id: "santander_unlimited", bank: .santander, name: "Unlimited", displayName: "Santander Unlimited", cardColor: "#1A1A1A", tier: .black, defaultBrand: .visa),
        BankCard(id: "santander_aadvantage_platinum", bank: .santander, name: "AAdvantage Platinum", displayName: "Santander AAdvantage Platinum", cardColor: "#7C7C7C", tier: .platinum),
        BankCard(id: "santander_aadvantage_black", bank: .santander, name: "AAdvantage Black", displayName: "Santander AAdvantage Black", cardColor: "#1A1A1A", tier: .black),
        BankCard(id: "santander_smiles_gold", bank: .santander, name: "Smiles Gold", displayName: "Santander Smiles Visa Gold", cardColor: "#D4AF37", tier: .gold, defaultBrand: .visa),
        BankCard(id: "santander_smiles_platinum", bank: .santander, name: "Smiles Platinum", displayName: "Santander Smiles Visa Platinum", cardColor: "#7C7C7C", tier: .platinum, defaultBrand: .visa),
        BankCard(id: "santander_smiles_infinite", bank: .santander, name: "Smiles Infinite", displayName: "Santander Smiles Visa Infinite", cardColor: "#1A1A1A", tier: .black, defaultBrand: .visa),

        // BANCO DO BRASIL (OUROCARD)
        BankCard(id: "bb_internacional", bank: .bb, name: "Internacional", displayName: "Ourocard Internacional", cardColor: "#0066CC", tier: .standard, defaultBrand: .visa),
        BankCard(id: "bb_gold", bank: .bb, name: "Gold", displayName: "Ourocard Gold", cardColor: "#D4AF37", tier: .gold, defaultBrand: .visa),
        BankCard(id: "bb_platinum", bank: .bb, name: "Platinum", displayName: "Ourocard Platinum", cardColor: "#7C7C7C", tier: .platinum, defaultBrand: .visa),
        BankCard(id: "bb_visa_infinite", bank: .bb, name: "Visa Infinite", displayName: "Ourocard Visa Infinite", cardColor: "#1A1A1A", tier: .black, defaultBrand: .visa),
        BankCard(id: "bb_black", bank: .bb, name: "Black", displayName: "Ourocard Mastercard Black", cardColor: "#1A1A1A", tier: .black),
        BankCard(id: "bb_elo_grafite", bank: .bb, name: "Elo Grafite", displayName: "Ourocard Elo Grafite", cardColor: "#4A4A4A", tier: .platinum, defaultBrand: .elo),
        BankCard(id: "bb_elo_nanquim", bank: .bb, name: "Elo Nanquim", displayName: "Ourocard Elo Nanquim", cardColor: "#0D0D0D", tier: .black, defaultBrand: .elo),
        BankCard(id: "bb_smiles_gold", bank: .bb, name: "Smiles Gold", displayName: "Ourocard Smiles Visa Gold", cardColor: "#D4AF37", tier: .gold, defaultBrand: .visa),
        BankCard(id: "bb_smiles_platinum", bank: .bb, name: "Smiles Platinum", displayName: "Ourocard Smiles Visa Platinum", cardColor: "#7C7C7C", tier: .platinum, defaultBrand: .visa),
        BankCard(id: "bb_smiles_infinite", bank: .bb, name: "Smiles Infinite", displayName: "Ourocard Smiles Visa Infinite", cardColor: "#1A1A1A", tier: .black, defaultBrand: .visa),

        // CAIXA
        BankCard(id: "caixa_sim", bank: .caixa, name: "SIM", displayName: "Caixa SIM", cardColor: "#1C60AB", tier: .standard, defaultBrand: .visa),
        BankCard(id: "caixa_gold", bank: .caixa, name: "Gold", displayName: "Caixa Gold", cardColor: "#D4AF37", tier: .gold, defaultBrand: .visa),
        BankCard(id: "caixa_platinum", bank: .caixa, name: "Platinum", displayName: "Caixa Platinum", cardColor: "#7C7C7C", tier: .platinum, defaultBrand: .visa),
        BankCard(id: "caixa_visa_infinite", bank: .caixa, name: "Visa Infinite", displayName: "Caixa Visa Infinite", cardColor: "#1A1A1A", tier: .black, defaultBrand: .visa),
        BankCard(id: "caixa_black", bank: .caixa, name: "Black", displayName: "Caixa Mastercard Black", cardColor: "#1A1A1A", tier: .black),
        BankCard(id: "caixa_elo_mais", bank: .caixa, name: "Elo Mais", displayName: "Caixa Elo Mais", cardColor: "#0066CC", tier: .standard, defaultBrand: .elo),
        BankCard(id: "caixa_elo_grafite", bank: .caixa, name: "Elo Grafite", displayName: "Caixa Elo Grafite", cardColor: "#4A4A4A", tier: .platinum, defaultBrand: .elo),
        BankCard(id: "caixa_elo_nanquim", bank: .caixa, name: "Elo Nanquim", displayName: "Caixa Elo Nanquim", cardColor: "#0D0D0D", tier: .black, defaultBrand: .elo),

        // BTG PACTUAL
        BankCard(id: "btg_standard", bank: .btg, name: "Standard", displayName: "BTG Pactual", cardColor: "#001E50", tier: .standard),
        BankCard(id: "btg_black", bank: .btg, name: "Black", displayName: "BTG Black", cardColor: "#1A1A1A", tier: .black),

        // XP
        BankCard(id: "xp_standard", bank: .xp, name: "Standard", displayName: "XP", cardColor: "#000000", tier: .standard, defaultBrand: .visa),
        BankCard(id: "xp_infinite", bank: .xp, name: "Infinite", displayName: "XP Visa Infinite", cardColor: "#1A1A1A", tier: .black, defaultBrand: .visa),

        // SAFRA
        BankCard(id: "safra_platinum", bank: .safra, name: "Platinum", displayName: "Safra Visa Platinum", cardColor: "#C0C0C0", tier: .platinum, defaultBrand: .visa),
        BankCard(id: "safra_visa_infinite", bank: .safra, name: "Visa Infinite", displayName: "Safra Visa Infinite", cardColor: "#1A1A1A", tier: .black, defaultBrand: .visa),
        BankCard(id: "safra_black", bank: .safra, name: "Black", displayName: "Safra Mastercard Black", cardColor: "#1A1A1A", tier: .black),

        // SICREDI
        BankCard(id: "sicredi_internacional", bank: .sicredi, name: "Internacional", displayName: "Sicredi Internacional", cardColor: "#00A651", tier: .standard),
        BankCard(id: "sicredi_gold", bank: .sicredi, name: "Gold", displayName: "Sicredi Gold", cardColor: "#D4AF37", tier: .gold),
        BankCard(id: "sicredi_platinum", bank: .sicredi, name: "Platinum", displayName: "Sicredi Platinum", cardColor: "#7C7C7C", tier: .platinum),
        BankCard(id: "sicredi_black", bank: .sicredi, name: "Black", displayName: "Sicredi Black", cardColor: "#1A1A1A", tier: .black),

        // SICOOB
        BankCard(id: "sicoob_classico", bank: .sicoob, name: "Clássico", displayName: "Sicoobcard Clássico", cardColor: "#003641", tier: .standard),
        BankCard(id: "sicoob_gold", bank: .sicoob, name: "Gold", displayName: "Sicoobcard Gold", cardColor: "#D4AF37", tier: .gold),
        BankCard(id: "sicoob_platinum", bank: .sicoob, name: "Platinum", displayName: "Sicoobcard Platinum", cardColor: "#7C7C7C", tier: .platinum),
        BankCard(id: "sicoob_black", bank: .sicoob, name: "Black", displayName: "Sicoobcard Black", cardColor: "#1A1A1A", tier: .black),
        BankCard(id: "sicoob_zenith", bank: .sicoob, name: "Zenith", displayName: "Sicoobcard Zenith", cardColor: "#0D0D0D", tier: .black, defaultBrand: .visa),

        // BANRISUL
        BankCard(id: "banrisul_gold", bank: .banrisul, name: "Gold", displayName: "Banrisul Gold", cardColor: "#D4AF37", tier: .gold),
        BankCard(id: "banrisul_platinum", bank: .banrisul, name: "Platinum", displayName: "Banrisul Platinum", cardColor: "#4A4A4A", tier: .platinum),
        BankCard(id: "banrisul_black", bank: .banrisul, name: "Black", displayName: "Banrisul Mastercard Black", cardColor: "#1A1A1A", tier: .black),

        // MERCANTIL
        BankCard(id: "mercantil_classic", bank: .mercantil, name: "Classic", displayName: "Mercantil Visa Classic", cardColor: "#0066CC", tier: .standard, defaultBrand: .visa),
        BankCard(id: "mercantil_gold", bank: .mercantil, name: "Gold", displayName: "Mercantil Visa Gold", cardColor: "#D4AF37", tier: .gold, defaultBrand: .visa),
        BankCard(id: "mercantil_platinum", bank: .mercantil, name: "Platinum", displayName: "Mercantil Visa Platinum", cardColor: "#7C7C7C", tier: .platinum, defaultBrand: .visa),

        // BMG
        BankCard(id: "bmg_internacional", bank: .bmg, name: "Internacional", displayName: "BMG Mastercard", cardColor: "#FF6600", tier: .standard),
        BankCard(id: "bmg_consignado", bank: .bmg, name: "Consignado", displayName: "BMG Consignado", cardColor: "#FF6600", tier: .standard),

        // BANCO PAN
        BankCard(id: "pan_internacional", bank: .pan, name: "Internacional", displayName: "Banco Pan", cardColor: "#0066CC", tier: .standard),
        BankCard(id: "pan_gold", bank: .pan, name: "Gold", displayName: "Banco Pan Gold", cardColor: "#D4AF37", tier: .gold),
        BankCard(id: "pan_platinum", bank: .pan, name: "Platinum", displayName: "Banco Pan Platinum", cardColor: "#7C7C7C", tier: .platinum),

        // BANCO ORIGINAL
        BankCard(id: "original_internacional", bank: .original, name: "Internacional", displayName: "Original", cardColor: "#00A859", tier: .standard),
        BankCard(id: "original_gold", bank: .original, name: "Gold", displayName: "Original Gold", cardColor: "#D4AF37", tier: .gold),
        BankCard(id: "original_platinum", bank: .original, name: "Platinum", displayName: "Original Platinum", cardColor: "#7C7C7C", tier: .platinum),
        BankCard(id: "original_black", bank: .original, name: "Black", displayName: "Original Black", cardColor: "#1A1A1A", tier: .black),

        // AGIBANK
        BankCard(id: "agibank_internacional", bank: .agibank, name: "Internacional", displayName: "Agibank Mastercard", cardColor: "#00C4B3", tier: .standard),

        // DIGIO
        BankCard(id: "digio_internacional", bank: .digio, name: "Internacional", displayName: "Digio", cardColor: "#0066FF", tier: .standard, defaultBrand: .visa),

        // NEON
        BankCard(id: "neon_internacional", bank: .neon, name: "Internacional", displayName: "Neon", cardColor: "#00E5A0", textColor: "#1A1A2E", tier: .standard, defaultBrand: .visa),

        // NEXT
        BankCard(id: "next_internacional", bank: .next, name: "Internacional", displayName: "Next", cardColor: "#00D47E", tier: .standard, defaultBrand: .visa),

        // WILL BANK
        BankCard(id: "willbank_gold", bank: .willbank, name: "Gold", displayName: "Will Bank", cardColor: "#FFD700", textColor: "#1A1A2E", tier: .gold),

        // PICPAY
        BankCard(id: "picpay_standard", bank: .picpay, name: "Standard", displayName: "PicPay Card", cardColor: "#22C25F", tier: .standard),

        // TRIGG
        BankCard(id: "trigg_internacional", bank: .trigg, name: "Internacional", displayName: "Trigg", cardColor: "#00FF7F", tier: .standard, defaultBrand: .visa),

        // OUTRO
        BankCard(id: "other_standard", bank: .other, name: "Outro", displayName: "Outro Cartão", cardColor: "#6B7280", tier: .standard, defaultBrand: .visa)
    ]

    static func cards(forBank bank: Bank) -> [BankCard] {
        all.filter { $0.bank == bank }.sorted { tierOrder($0.tier) < tierOrder($1.tier) }
    }

    static func card(byId id: String) -> BankCard? {
        all.first { $0.id == id }
    }

    private static func tierOrder(_ tier: CardType) -> Int {
        switch tier {
        case .standard: return 0
        case .gold: return 1
        case .platinum: return 2
        case .black: return 3
        }
    }
}

// MARK: - Credit Card Model

@Model
final class CreditCard: Identifiable {
    @Attribute(.unique) var id: String
    var userId: String
    var cardName: String           // Nome personalizado do cartão
    var holderName: String         // Nome impresso no cartão
    var lastFourDigits: String     // Últimos 4 dígitos
    var brand: String              // CardBrand.rawValue
    var cardType: String           // CardType.rawValue
    var bank: String               // Bank.rawValue
    var paymentDay: Int            // Dia do vencimento (1-31)
    var closingDay: Int            // Dia do fechamento (1-31)
    var limitAmount: Decimal       // Limite do cartão
    var isActive: Bool
    var displayOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        cardName: String,
        holderName: String,
        lastFourDigits: String = "",
        brand: CardBrand = .visa,
        cardType: CardType = .standard,
        bank: Bank = .other,
        paymentDay: Int = 10,
        closingDay: Int = 3,
        limitAmount: Decimal = 0,
        isActive: Bool = true,
        displayOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.cardName = cardName
        self.holderName = holderName
        self.lastFourDigits = lastFourDigits
        self.brand = brand.rawValue
        self.cardType = cardType.rawValue
        self.bank = bank.rawValue
        self.paymentDay = paymentDay
        self.closingDay = closingDay
        self.limitAmount = limitAmount
        self.isActive = isActive
        self.displayOrder = displayOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Computed Properties

    var brandEnum: CardBrand {
        get { CardBrand(rawValue: brand) ?? .other }
        set { brand = newValue.rawValue }
    }

    var cardTypeEnum: CardType {
        get { CardType(rawValue: cardType) ?? .standard }
        set { cardType = newValue.rawValue }
    }

    var bankEnum: Bank {
        get { Bank(rawValue: bank) ?? .other }
        set { bank = newValue.rawValue }
    }

    var formattedLimit: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: limitAmount as NSDecimalNumber) ?? "R$ 0,00"
    }

    var maskedNumber: String {
        "**** **** **** \(lastFourDigits.isEmpty ? "****" : lastFourDigits)"
    }
}
