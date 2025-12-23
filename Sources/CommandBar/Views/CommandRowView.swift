import SwiftUI

struct CommandRowView: View {
    let cmd: Command
    let isSelected: Bool
    let isDragging: Bool
    let isAlerting: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onRun: () -> Void
    let onToggleFavorite: () -> Void
    let groups: [Group]
    let onMoveToGroup: (UUID) -> Void

    @State private var shakeOffset: CGFloat = 0

    var typeColor: Color {
        switch cmd.executionType {
        case .terminal: return .blue
        case .background: return .orange
        case .script: return .green
        case .schedule: return .purple
        case .api: return .cyan
        }
    }

    var typeIcon: String {
        switch cmd.executionType {
        case .terminal: return "terminal"
        case .background: return "arrow.clockwise"
        case .script: return "play.fill"
        case .schedule: return "calendar"
        case .api: return "network"
        }
    }

    var badgeText: String {
        switch cmd.executionType {
        case .terminal:
            return cmd.terminalApp.rawValue
        case .background:
            if cmd.interval == 0 { return L.manual }
            guard let lastRun = cmd.lastExecutedAt else { return formatRemaining(cmd.interval) + " " + L.timeAfter }
            let nextRun = lastRun.addingTimeInterval(Double(cmd.interval))
            let remaining = Int(nextRun.timeIntervalSinceNow)
            if remaining <= 0 { return L.scriptRunning }
            return formatRemaining(remaining) + " " + L.timeAfter
        case .script:
            return cmd.hasParameters ? L.parameter : L.buttonRun
        case .schedule:
            guard let date = cmd.scheduleDate else { return L.executionSchedule }
            let diff = date.timeIntervalSinceNow

            // 확인했으면 체크 표시
            if cmd.acknowledged {
                return "✓"
            }

            // 지난 시간 표시
            if diff < 0 {
                return formatRemaining(Int(-diff)) + " " + L.timePassed
            }
            // 남은 시간 표시
            else {
                return formatRemaining(Int(diff)) + " " + L.timeAfter
            }
        case .api:
            // 상태 코드가 있으면 표시
            if let statusCode = cmd.lastStatusCode {
                return "\(statusCode)"
            }
            // 없으면 HTTP 메서드 표시
            return cmd.httpMethod.rawValue
        }
    }

    var alertBadgeColor: Color {
        switch cmd.alertState {
        case .now: return .red
        case .fiveMinBefore: return .orange
        case .thirtyMinBefore: return .orange
        case .hourBefore: return .yellow
        case .dayBefore: return .green
        case .passed: return .gray
        case .none: return typeColor
        }
    }

    var badgeColor: Color {
        if cmd.executionType == .schedule {
            if cmd.acknowledged && cmd.alertState == .now {
                return .green  // 체크 표시일 때 초록색
            }
            if cmd.alertState != .none {
                return alertBadgeColor
            }
        }
        return typeColor
    }

    var currentGroup: Group? {
        groups.first { $0.id == cmd.groupId }
    }

    func colorFor(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "red": return .red
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "gray": return .gray
        default: return .gray
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    // 그룹 색상 표시
                    if let group = currentGroup {
                        Circle()
                            .fill(colorFor(group.color))
                            .frame(width: 8, height: 8)
                    }
                    // 즐겨찾기 별
                    Image(systemName: cmd.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(cmd.isFavorite ? .yellow : .gray.opacity(0.4))
                        .font(.caption2)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { _ in onToggleFavorite() }
                        )
                    Image(systemName: typeIcon)
                        .foregroundStyle(typeColor)
                        .frame(width: 14)
                    Text(cmd.title)
                        .lineLimit(1)
                        .fontWeight(isAlerting ? .bold : .regular)
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                        .opacity(cmd.isRunning ? 1 : 0)
                }
                if cmd.executionType == .schedule {
                    if let date = cmd.scheduleDate {
                        Text(formatScheduleDate(date, repeatType: cmd.repeatType))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if cmd.executionType == .api {
                    Text(cmd.url)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(cmd.command)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if cmd.executionType == .background {
                    Text(cmd.lastOutput ?? " ")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer()
            Text(badgeText)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badgeColor.opacity(0.2))
                .foregroundStyle(badgeColor)
                .cornerRadius(4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isAlerting ? Color.red.opacity(0.3) : (isSelected ? Color.accentColor.opacity(0.2) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isAlerting ? Color.red : (isSelected ? Color.accentColor : Color.primary.opacity(0.1)), lineWidth: isAlerting ? 2 : 1)
        )
        .offset(x: shakeOffset)
        .opacity(isDragging ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .gesture(TapGesture(count: 2).onEnded { onDoubleTap() })
        .simultaneousGesture(TapGesture(count: 1).onEnded { onTap() })
        .overlay {
            RightClickMenu(
                onSelect: onTap,
                onRun: onRun,
                onToggleFavorite: onToggleFavorite,
                cmd: cmd,
                onEdit: onEdit,
                onCopy: onCopy,
                onDelete: onDelete,
                groups: groups,
                currentGroupId: cmd.groupId,
                onMoveToGroup: onMoveToGroup
            )
        }
        .onChange(of: isAlerting) { _, newValue in
            if newValue {
                shake()
            }
        }
    }

    func shake() {
        withAnimation(.linear(duration: 0.05).repeatCount(10, autoreverses: true)) {
            shakeOffset = 5
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shakeOffset = 0
        }
    }

    func formatScheduleDate(_ date: Date, repeatType: RepeatType) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        switch repeatType {
        case .none:
            formatter.dateFormat = "M월 d일 E HH:mm"
        case .daily:
            formatter.dateFormat = "HH:mm"
        case .weekly:
            formatter.dateFormat = "E HH:mm"
        case .monthly:
            formatter.dateFormat = "d일 HH:mm"
        }
        return formatter.string(from: date)
    }

    func formatRemaining(_ seconds: Int) -> String {
        if seconds >= 86400 {
            return "\(seconds / 86400)" + L.daysUnit
        } else if seconds >= 3600 {
            return "\(seconds / 3600)" + L.hoursUnit
        } else if seconds >= 60 {
            return "\(seconds / 60)" + L.minutesUnit
        } else {
            return "\(seconds)" + L.secondsUnit
        }
    }
}
