import SwiftUI

struct PaginationView: View {
    let currentPage: Int
    let totalPages: Int
    let onPageChange: (Int) -> Void

    private let maxVisiblePages = 5

    var body: some View {
        HStack(spacing: 4) {
            // 이전 버튼
            Button(action: { onPageChange(currentPage - 1) }) {
                Image(systemName: "chevron.left")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .disabled(currentPage == 0)
            .foregroundStyle(currentPage == 0 ? .tertiary : .secondary)

            // 페이지 번호들
            ForEach(visiblePages, id: \.self) { page in
                if page == -1 {
                    Text("...")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 20)
                } else {
                    Button(action: { onPageChange(page) }) {
                        Text("\(page + 1)")
                            .font(.caption2)
                            .frame(width: 20, height: 20)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(page == currentPage ? Color.accentColor : Color.clear)
                            )
                            .foregroundStyle(page == currentPage ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 다음 버튼
            Button(action: { onPageChange(currentPage + 1) }) {
                Image(systemName: "chevron.right")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .disabled(currentPage >= totalPages - 1)
            .foregroundStyle(currentPage >= totalPages - 1 ? .tertiary : .secondary)
        }
        .padding(.vertical, 8)
    }

    private var visiblePages: [Int] {
        guard totalPages > 1 else { return [0] }

        if totalPages <= maxVisiblePages {
            return Array(0..<totalPages)
        }

        var pages: [Int] = []

        // 항상 첫 페이지
        pages.append(0)

        // 중간 페이지들
        let start = max(1, currentPage - 1)
        let end = min(totalPages - 2, currentPage + 1)

        if start > 1 {
            pages.append(-1) // ...
        }

        for i in start...end {
            pages.append(i)
        }

        if end < totalPages - 2 {
            pages.append(-1) // ...
        }

        // 항상 마지막 페이지
        pages.append(totalPages - 1)

        return pages
    }
}
