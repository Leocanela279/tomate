import Charts
import SwiftUI

/// Study minutes per day for the last seven days. Hover a bar to read its value.
struct WeekChart: View {
    let records: [FocusRecord]
    @State private var hoveredDate: Date?

    private struct DayTotal: Identifiable {
        let date: Date
        let minutes: Int
        var id: Date { date }
    }

    var body: some View {
        let data = totals
        let calendar = Calendar.current
        let top = max(30, data.map(\.minutes).max() ?? 0)

        VStack(alignment: .leading, spacing: 12) {
            Text("Minutos de estudio, últimos 7 días")
                .font(Theme.font(14, .semibold))
                .foregroundStyle(Theme.secondaryText)

            Chart(data) { day in
                let isToday = calendar.isDateInToday(day.date)
                let isHovered = hoveredDate.map { calendar.isDate($0, inSameDayAs: day.date) } ?? false

                BarMark(x: .value("Día", day.date, unit: .day),
                        y: .value("Minutos", day.minutes),
                        width: .ratio(0.55))
                    .foregroundStyle(Theme.cream.opacity(isToday || isHovered ? 1 : 0.55))
                    .cornerRadius(4)
                    .annotation(position: .top, spacing: 4) {
                        if isHovered || (isToday && hoveredDate == nil && day.minutes > 0) {
                            Text("\(day.minutes) min")
                                .font(Theme.font(12, .semibold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.cream)
                        }
                    }
            }
            .chartYScale(domain: 0...(top + top / 6))
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine()
                        .foregroundStyle(Theme.cream.opacity(0.12))
                    AxisValueLabel()
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            .chartXSelection(value: $hoveredDate)
            .frame(height: 170)
        }
        .padding(20)
        .panel(cornerRadius: 20)
    }

    private var totals: [DayTotal] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let start = calendar.date(byAdding: .day, value: -6, to: today) else { return [] }

        var minutesByDay: [Date: Int] = [:]
        // Records arrive newest first, so stop at the first one older than the window.
        for record in records {
            if record.startedAt < start { break }
            minutesByDay[calendar.startOfDay(for: record.startedAt), default: 0] += record.focusedSeconds
        }

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return DayTotal(date: date, minutes: (minutesByDay[date] ?? 0) / 60)
        }
    }
}
