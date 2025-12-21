import SwiftUI
import AppKit

struct APIResponseView: View {
    let method: String
    let url: String
    let statusCode: Int
    let headers: [String: String]
    let responseBody: String
    let executionTime: TimeInterval
    let onClose: () -> Void

    @State private var isHeadersExpanded = false

    var statusColor: Color {
        switch statusCode {
        case 200..<300:
            return .green
        case 300..<400:
            return .blue
        case 400..<500:
            return .orange
        case 500..<600:
            return .red
        default:
            return .gray
        }
    }

    var formattedBody: String {
        // JSON인 경우 포맷팅 시도
        if let jsonData = responseBody.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }
        return responseBody
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 요청 정보 헤더
            VStack(alignment: .leading, spacing: 8) {
                Text(L.apiRequestInfo)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(method)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)

                    Text(url)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                HStack(spacing: 4) {
                    Text(L.apiExecutionTime + ":")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f", executionTime * 1000) + "ms")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            // 상태 코드
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(L.apiStatusCode + ":")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)

                        Text("\(statusCode)")
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundStyle(statusColor)

                        Text(statusCodeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // 응답 헤더 (접을 수 있는 섹션)
            VStack(alignment: .leading, spacing: 0) {
                Button(action: { isHeadersExpanded.toggle() }) {
                    HStack {
                        Image(systemName: isHeadersExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(L.apiResponseHeaders)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("(\(headers.count))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if isHeadersExpanded {
                    VStack(alignment: .leading, spacing: 4) {
                        if headers.isEmpty {
                            Text(L.apiNoResponse)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(Array(headers.keys.sorted()), id: \.self) { key in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(key + ":")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 150, alignment: .leading)

                                    Text(headers[key] ?? "")
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }

            Divider()

            // 응답 바디
            VStack(alignment: .leading, spacing: 4) {
                Text(L.apiResponseBody)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)

                if responseBody.isEmpty {
                    Text(L.apiNoResponse)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    OutputTextView(text: formattedBody)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                        .padding(.horizontal)
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.bottom, 8)

            Divider()

            // 하단 버튼
            HStack {
                Button(L.apiCopyResponse) {
                    copyResponseToClipboard()
                }
                .buttonStyle(HoverTextButtonStyle())
                .disabled(responseBody.isEmpty)

                Spacer()

                Button(L.buttonClose) {
                    onClose()
                }
                .buttonStyle(HoverTextButtonStyle())
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    var statusCodeDescription: String {
        switch statusCode {
        case 200: return "OK"
        case 201: return "Created"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        default: return ""
        }
    }

    func copyResponseToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(responseBody, forType: .string)
    }
}
