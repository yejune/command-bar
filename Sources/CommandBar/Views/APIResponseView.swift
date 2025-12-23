import SwiftUI
import AppKit

// MARK: - API Response State
class APIResponseState: ObservableObject {
    @Published var isLoading: Bool = true
    @Published var statusCode: Int = 0
    @Published var headers: [String: String] = [:]
    @Published var responseBody: String = ""
    @Published var executionTime: TimeInterval = 0
    @Published var elapsedTime: TimeInterval = 0

    private var timer: Timer?
    private var startTime: Date?

    func startTimer() {
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startTime else { return }
            self.elapsedTime = Date().timeIntervalSince(start)
        }
    }

    func update(statusCode: Int, headers: [String: String], responseBody: String, executionTime: TimeInterval) {
        timer?.invalidate()
        timer = nil
        self.statusCode = statusCode
        self.headers = headers
        self.responseBody = responseBody
        self.executionTime = executionTime
        self.isLoading = false
    }

    deinit {
        timer?.invalidate()
    }
}

struct APIResponseView: View {
    let method: String
    let url: String
    @ObservedObject var state: APIResponseState
    let onClose: () -> Void

    @State private var isHeadersExpanded = false

    var statusColor: Color {
        switch state.statusCode {
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
        if let jsonData = state.responseBody.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }
        return state.responseBody
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
                    if state.isLoading {
                        Text(String(format: "%.1fs", state.elapsedTime))
                            .font(.caption.monospaced())
                            .foregroundStyle(.orange)
                    } else {
                        Text(String(format: "%.2f", state.executionTime * 1000) + "ms")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()

            Divider()

            if state.isLoading {
                // 로딩 중: 스피너만 표시
                VStack {
                    Spacer()
                    ProgressView()
                    Text(L.apiLoading)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 완료: 상태코드/헤더/바디 표시
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

                            Text("\(state.statusCode)")
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

                // 응답 헤더
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: { isHeadersExpanded.toggle() }) {
                        HStack {
                            Image(systemName: isHeadersExpanded ? "chevron.down" : "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(L.apiResponseHeaders)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("(\(state.headers.count))")
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
                            if state.headers.isEmpty {
                                Text(L.apiNoResponse)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                    .padding(.vertical, 4)
                            } else {
                                ForEach(Array(state.headers.keys.sorted()), id: \.self) { key in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(key + ":")
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: true, vertical: false)

                                        Text(state.headers[key] ?? "")
                                            .font(.system(.caption, design: .monospaced))
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)
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

                    if state.responseBody.isEmpty {
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
            }

            Divider()

            // 하단 버튼
            HStack {
                Button(L.apiCopyResponse) {
                    copyResponseToClipboard()
                }
                .buttonStyle(HoverTextButtonStyle())
                .disabled(state.isLoading || state.responseBody.isEmpty)

                Spacer()

                Button(L.buttonClose) {
                    onClose()
                }
                .buttonStyle(HoverTextButtonStyle())
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            if state.isLoading {
                state.startTimer()
            }
        }
    }

    var statusCodeDescription: String {
        switch state.statusCode {
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
        pasteboard.setString(state.responseBody, forType: .string)
    }
}
