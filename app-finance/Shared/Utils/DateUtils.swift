import Foundation

extension Date {
    var monthRef: MonthRef {
        MonthRef(date: self)
    }

    var shortFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .short
        return formatter.string(from: self)
    }

    var mediumFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .medium
        return formatter.string(from: self)
    }
}

extension Calendar {
    static let brCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "pt_BR")
        return calendar
    }()
}
