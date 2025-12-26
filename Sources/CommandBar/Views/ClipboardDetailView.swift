import SwiftUI
import AppKit

struct ClipboardDetailView: View {
    let item: ClipboardItem
    let store: CommandStore
    let notesFolderName: String
    let onClose: () -> Void
    @State private var showRegisterSheet = false
    @State private var editableContent: String = ""
    @State private var isEdited: Bool = false

    var shortId: String {
        item.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L.clipboardContent)
                        .font(.headline)
                    if isEdited {
                        Text("(수정됨)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    Button(action: copyId) {
                        Text(shortId)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("ID 복사: {clipboard@\(item.id)}")
                }
                Text(item.timestamp, format: .dateTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("\(editableContent.count)자")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("• Option+S: 선택 텍스트 암호화")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()

            Divider()

            AutocompleteTextEditor(text: $editableContent, suggestions: [])
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
                .padding()
                .onChange(of: editableContent) { _, newValue in
                    isEdited = newValue != item.content
                }

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
                if isEdited {
                    Button("저장") {
                        store.updateClipboardContent(item, newContent: editableContent)
                        isEdited = false
                    }
                    .buttonStyle(HoverTextButtonStyle())
                    .foregroundStyle(.blue)
                }
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
        .frame(minWidth: 400, minHeight: 300)
        .sheet(isPresented: $showRegisterSheet) {
            RegisterClipboardSheet(store: store, item: item, onComplete: onClose)
        }
        .onAppear {
            editableContent = item.content
        }
    }

    func copyId() {
        let idString = "{clipboard@\(shortId)}"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(idString, forType: .string)
    }
}
