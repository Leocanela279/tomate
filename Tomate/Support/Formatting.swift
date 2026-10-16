import Foundation

extension Locale {
    /// The interface is in Spanish, so dates and numbers follow Spanish conventions.
    static let app = Locale(identifier: "es_ES")
}

enum Formatting {
    /// 1500 → "25:00". Minutes are not folded into hours, so 90 min reads "90:00".
    static func clock(_ seconds: Int) -> String {
        let value = max(0, seconds)
        return String(format: "%02d:%02d", value / 60, value % 60)
    }

    /// 2700 → "45 min", 2250 → "37,5 min" (halves appear when an odd length is split).
    static func minutes(fromSeconds seconds: Int) -> String {
        let value = Double(seconds) / 60
        return value.formatted(.number.precision(.fractionLength(0...1)).locale(.app)) + " min"
    }

    /// A study total: "45 min", "2 h", "1 h 35 min".
    static func duration(_ seconds: Int) -> String {
        let totalMinutes = max(0, seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes) min" }
        if minutes == 0 { return "\(hours) h" }
        return "\(hours) h \(minutes) min"
    }

    /// "18:30"
    static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(.app))
    }
}

enum DayLabel {
    /// "Hoy", "Mañana", "Ayer" or "vie 17".
    static func short(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Hoy" }
        if calendar.isDateInTomorrow(date) { return "Mañana" }
        if calendar.isDateInYesterday(date) { return "Ayer" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().locale(.app))
    }

    /// "Hoy", "Ayer" or "Lunes, 12 de octubre".
    static func long(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Hoy" }
        if calendar.isDateInYesterday(date) { return "Ayer" }
        let text = date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.app))
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}
