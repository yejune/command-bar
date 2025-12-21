import SwiftUI

struct ClipboardDetailView: View {
    let item: ClipboardItem
    let store: CommandStore
    let notesFolderName: String
    let onClose: () -> Void
    @State private var showRegisterSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L.clipboardContent)
                    .font(.headline)
                Text(item.timestamp, format: .dateTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(item.content.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            OutputTextView(text: item.content)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
                .padding()

            Divider()

            HStack {
                Button(L.registerClipboardTitle) {
                    showRegisterSheet = true
                }
                .buttonStyle(HoverTextButtonStyle())
                Button(L.clipboardSendToNotes) {
                    store.sendToNotes(item, folderName: notesFolderName)
                    onClose()
                }
                .buttonStyle(HoverTextButtonStyle())
                Spacer()
                Button(L.buttonDelete) {
                    store.removeClipboardItem(item)
                    onClose()
                }
                .buttonStyle(HoverTextButtonStyle())
                .foregroundStyle(.red)
                Button(L.buttonClose) { onClose() }
                    .buttonStyle(HoverTextButtonStyle())
            }
            .padding()
        }
        .frame(minWidth: 300, minHeight: 200)
        .sheet(isPresented: $showRegisterSheet) {
            RegisterClipboardSheet(store: store, item: item, onComplete: onClose)
        }
    }
}
