import SwiftUI

struct ParameterHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.parameterHelpTitle)
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.helpSyntax)
                        .font(.subheadline.bold())
                    Text("{파라미터명}")
                        .font(.body.monospaced())
                        .padding(6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(L.parameterExample)
                        .font(.subheadline.bold())

                    SwiftUI.Group {
                        Text("echo \"Hello {name}\"")
                        Text("→ 실행 시 name 값 입력")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption.monospaced())

                    SwiftUI.Group {
                        Text("curl -X {method} {url}")
                        Text("→ 실행 시 method, url 값 입력")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption.monospaced())

                    SwiftUI.Group {
                        Text("git commit -m \"{message}\"")
                        Text("→ 실행 시 message 값 입력")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption.monospaced())
                }
            }

            HStack {
                Spacer()
                Button(L.buttonClose) { dismiss() }
                    .buttonStyle(HoverTextButtonStyle())
            }
        }
        .textSelection(.enabled)
        .padding()
        .frame(width: 320)
    }
}
