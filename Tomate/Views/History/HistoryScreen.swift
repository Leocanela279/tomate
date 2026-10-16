import SwiftData
import SwiftUI

struct HistoryScreen: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \FocusRecord.startedAt, order: .reverse) private var records: [FocusRecord]

    var body: some View {
        if records.isEmpty {
            EmptyState(title: "Aún no hay sesiones",
                       message: "Cuando termines tu primer pomodoro aparecerá aquí, con el tiempo que estudiaste.")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    summary
                    WeekChart(records: records)
                    ForEach(days) { day in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(DayLabel.long(for: day.date))
                                .font(Theme.font(14, .semibold))
                                .foregroundStyle(Theme.secondaryText)
                            VStack(spacing: 8) {
                                ForEach(day.records) { record in
                                    HistoryRow(record: record)
                                        .contextMenu {
                                            Button("Eliminar del historial", role: .destructive) {
                                                model.persistence.context.delete(record)
                                                model.persistence.save()
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 44)
                .padding(.vertical, 24)
            }
        }
    }

    // MARK: Summary

    private var summary: some View {
        let calendar = Calendar.current
        let today = records
            .filter { calendar.isDateInToday($0.startedAt) }
            .reduce(0) { $0 + $1.focusedSeconds }
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)) ?? .now
        // Newest first, so the last seven days are a prefix of the list.
        let week = records.prefix(while: { $0.startedAt >= weekStart })
        let weekSeconds = week.reduce(0) { $0 + $1.focusedSeconds }

        let headline: String = today > 0
            ? "Hoy llevas \(Formatting.duration(today)) de estudio"
            : "Hoy todavía no has estudiado"
        let sessions = week.count == 1 ? "1 sesión" : "\(week.count) sesiones"
        let weekLine = "En los últimos 7 días: \(Formatting.duration(weekSeconds)) en \(sessions)."

        return VStack(alignment: .leading, spacing: 6) {
            Text(headline)
                .font(Theme.font(30, .semibold))
            Text(weekLine)
                .font(Theme.font(15))
                .foregroundStyle(Theme.secondaryText)
        }
    }

    // MARK: Grouping

    private struct Day: Identifiable {
        let date: Date
        let records: [FocusRecord]
        var id: Date { date }
    }

    /// Records grouped by calendar day, newest first (the query is already sorted).
    private var days: [Day] {
        let calendar = Calendar.current
        var result: [Day] = []
        var current: (date: Date, records: [FocusRecord])?
        for record in records {
            let day = calendar.startOfDay(for: record.startedAt)
            if current?.date == day {
                current?.records.append(record)
            } else {
                if let current { result.append(Day(date: current.date, records: current.records)) }
                current = (day, [record])
            }
        }
        if let current { result.append(Day(date: current.date, records: current.records)) }
        return result
    }
}

private struct HistoryRow: View {
    let record: FocusRecord

    var body: some View {
        HStack(spacing: 16) {
            Text("\(Formatting.time(record.startedAt))–\(Formatting.time(record.endedAt))")
                .font(Theme.font(13, .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 104, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(record.subject)
                    .font(Theme.font(15, .semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer(minLength: 12)

            Text(Formatting.duration(record.focusedSeconds))
                .font(Theme.font(16, .semibold))
                .monospacedDigit()

            Image(systemName: record.completed ? "checkmark.circle.fill" : "stop.circle")
                .font(.system(size: 16))
                .foregroundStyle(record.completed ? Theme.text : Theme.tertiaryText)
                .help(record.completed ? "Completado" : "Terminado antes de tiempo")
                .accessibilityLabel(record.completed ? "Completado" : "Terminado antes de tiempo")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .panel(cornerRadius: 16)
    }

    private var detail: String {
        var parts = ["\(record.plannedMinutes) min planeados"]
        if record.breakMinutes > 0 { parts.append("en dos bloques") }
        if !record.completed { parts.append("terminado antes") }
        if record.fromSchedule { parts.append("programado") }
        return parts.joined(separator: ", ")
    }
}
