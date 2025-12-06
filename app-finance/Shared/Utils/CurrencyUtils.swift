import Foundation

struct CurrencyUtils {
    static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.currencyCode = "BRL"
        return formatter
    }()

    static func format(_ value: Decimal) -> String {
        formatter.string(from: NSDecimalNumber(decimal: value)) ?? "R$ 0,00"
    }

    static func format(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
}
