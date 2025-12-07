import Foundation

struct MonthRef: Equatable, Hashable {
    let year: Int
    let month: Int

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(date: Date) {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        self.year = components.year!
        self.month = components.month!
    }

    static var current: MonthRef {
        MonthRef(date: Date())
    }

    var startDate: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))!
    }

    var endDate: Date {
        let nextMonth = addingMonths(1)
        return Calendar.current.date(byAdding: .second, value: -1, to: nextMonth.startDate)!
    }

    func addingMonths(_ months: Int) -> MonthRef {
        let components = DateComponents(year: year, month: month + months)
        let date = Calendar.current.date(from: components)!
        return MonthRef(date: date)
    }

    var apiString: String {
        String(format: "%04d-%02d", year, month)
    }

    var displayString: String {
        let date = startDate
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "MMMM 'de' yyyy"
        let str = formatter.string(from: date)
        // Capitalizar apenas a primeira letra do mês
        return str.prefix(1).uppercased() + str.dropFirst()
    }
}
