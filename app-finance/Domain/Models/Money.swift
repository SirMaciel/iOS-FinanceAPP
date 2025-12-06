import Foundation

struct Money {
    let amount: Decimal

    var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.currencyCode = "BRL"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "R$ 0,00"
    }

    var double: Double {
        NSDecimalNumber(decimal: amount).doubleValue
    }
}

extension Decimal {
    var money: Money {
        Money(amount: self)
    }
}
