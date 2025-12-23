import SwiftUI

struct CalendarPickerView: View {
    @Binding var selectedDate: Date?
    let dateCounts: [String: Int]  // "yyyy-MM-dd": count
    let onSelect: (Date) -> Void

    @State private var displayedMonth: Date = Date()
    @State private var cachedDays: [DayInfo] = []

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var monthYearFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy년 MM월"
        return f
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        // Reorder to start with Sunday
        var result = [String]()
        result.append(symbols[0])  // Sunday
        for i in 1..<symbols.count {
            result.append(symbols[i])
        }
        return result
    }

    private func buildDaysInMonth() -> [DayInfo] {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let year = components.year,
              let month = components.month,
              let firstOfMonth = calendar.date(from: components),
              let monthFirstWeekday = calendar.dateComponents([.weekday], from: firstOfMonth).weekday,
              let range = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }

        var days: [DayInfo] = []

        // Add empty cells for days before the first day of the month
        for _ in 0..<(monthFirstWeekday - 1) {
            days.append(DayInfo(date: nil, isCurrentMonth: false, count: 0))
        }

        // Add days of the month
        for day in range {
            var dayComponents = DateComponents()
            dayComponents.year = year
            dayComponents.month = month
            dayComponents.day = day
            if let date = calendar.date(from: dayComponents) {
                let dateString = dateFormatter.string(from: date)
                let count = dateCounts[dateString] ?? 0
                days.append(DayInfo(date: date, isCurrentMonth: true, count: count))
            }
        }

        return days
    }

    var body: some View {
        VStack(spacing: 8) {
            // Month navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthYearFormatter.string(from: displayedMonth))
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(cachedDays.indices, id: \.self) { index in
                    DayCell(
                        dayInfo: cachedDays[index],
                        isSelected: isSelected(cachedDays[index].date),
                        isToday: isToday(cachedDays[index].date),
                        onTap: {
                            if let date = cachedDays[index].date {
                                onSelect(date)
                            }
                        }
                    )
                }
            }
        }
        .padding(12)
        .frame(width: 240)
        .onAppear {
            cachedDays = buildDaysInMonth()
        }
        .onChange(of: displayedMonth) { _, _ in
            cachedDays = buildDaysInMonth()
        }
    }

    private func previousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    private func nextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    private func isSelected(_ date: Date?) -> Bool {
        guard let date = date, let selectedDate = selectedDate else { return false }
        return calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private func isToday(_ date: Date?) -> Bool {
        guard let date = date else { return false }
        return calendar.isDateInToday(date)
    }
}

// MARK: - Day Info

private struct DayInfo {
    let date: Date?
    let isCurrentMonth: Bool
    let count: Int
}

// MARK: - Day Cell

private struct DayCell: View {
    let dayInfo: DayInfo
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                if let date = dayInfo.date {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 11))
                        .foregroundStyle(dayInfo.isCurrentMonth ? .primary : .tertiary)

                    if dayInfo.count > 0 {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 3, height: 3)
                    } else {
                        Spacer()
                            .frame(height: 3)
                    }
                } else {
                    Text("")
                        .font(.system(size: 11))
                    Spacer()
                        .frame(height: 3)
                }
            }
            .frame(height: 28)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isToday ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(dayInfo.date == nil)
    }
}
