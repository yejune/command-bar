import SwiftUI

struct GroupRowView: View {
    let group: Group
    let commandCount: Int
    let isDefault: Bool
    let isLastGroup: Bool
    let isDragging: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var colorFor: Color {
        switch group.color {
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
            // 색상 인디케이터
            Circle()
                .fill(colorFor)
                .frame(width: 12, height: 12)

            // 그룹 정보
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(group.name)
                        .fontWeight(.medium)
                    if isDefault {
                        Text("(\(L.groupDefault))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("\(commandCount) \(L.groupCommandCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 버튼들
            HStack(spacing: 2) {
                // 편집 버튼
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(SmallHoverButtonStyle())

                // 삭제 버튼 (기본 그룹이 아니고 마지막 그룹이 아닐 때만)
                if !isDefault && !isLastGroup {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(SmallHoverButtonStyle())
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(isDragging ? 0.2 : 0.1))
        )
        .opacity(isDragging ? 0.5 : 1.0)
    }
}
