import SwiftUI
import LocalAuthentication

struct SecureValueItem: Identifiable, Hashable {
    let id: String
    let label: String?
    let createdAt: Date
    let keyVersion: Int

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SecureValueItem, rhs: SecureValueItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct SecureListView: View {
    @State private var secureValues: [SecureValueItem] = []
    @State private var selectedItem: SecureValueItem?
    @State private var showDecryptedValue: Bool = false
    @State private var decryptedValue: String = ""
    @State private var searchText: String = ""
    @State private var showDeleteConfirm: Bool = false
    @State private var itemToDelete: SecureValueItem?
    @State private var errorMessage: String?
    @State private var showLabelEdit: Bool = false
    @State private var editingLabel: String = ""

    var filteredValues: [SecureValueItem] {
        if searchText.isEmpty {
            return secureValues
        }
        return secureValues.filter { item in
            if let label = item.label {
                return label.localizedCaseInsensitiveContains(searchText)
            }
            return item.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("암호화된 값 목록")
                    .font(.headline)
                Text("\(secureValues.count)개의 암호화된 값")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Search field
                TextField("검색 (라벨 또는 ID)", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()

            Divider()

            // List
            if filteredValues.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(searchText.isEmpty ? "저장된 암호화된 값이 없습니다" : "검색 결과가 없습니다")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedItem) {
                    ForEach(filteredValues) { item in
                        SecureValueRow(item: item)
                            .tag(item)
                            .contextMenu {
                                Button("복호화하여 보기") {
                                    authenticateAndDecrypt(item)
                                }
                                Button("클립보드에 복사") {
                                    authenticateAndCopyToClipboard(item)
                                }
                                Divider()
                                Button("라벨 수정") {
                                    selectedItem = item
                                    editingLabel = item.label ?? ""
                                    showLabelEdit = true
                                }
                                Divider()
                                Button("삭제", role: .destructive) {
                                    itemToDelete = item
                                    showDeleteConfirm = true
                                }
                            }
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // Actions
            HStack {
                if let selected = selectedItem {
                    Button("복호화하여 보기") {
                        authenticateAndDecrypt(selected)
                    }
                    .buttonStyle(HoverTextButtonStyle())

                    Button("클립보드에 복사") {
                        authenticateAndCopyToClipboard(selected)
                    }
                    .buttonStyle(HoverTextButtonStyle())

                    Button("라벨 수정") {
                        editingLabel = selected.label ?? ""
                        showLabelEdit = true
                    }
                    .buttonStyle(HoverTextButtonStyle())

                    Spacer()

                    Button("삭제") {
                        itemToDelete = selected
                        showDeleteConfirm = true
                    }
                    .buttonStyle(HoverTextButtonStyle())
                    .foregroundStyle(.red)
                } else {
                    Text("항목을 선택하세요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding()
        }
        .frame(minWidth: 280, minHeight: 400)
        .onAppear {
            loadSecureValues()
        }
        .sheet(isPresented: $showDecryptedValue) {
            DecryptedValueSheet(
                item: selectedItem,
                decryptedValue: decryptedValue,
                onClose: {
                    showDecryptedValue = false
                    decryptedValue = ""
                }
            )
        }
        .sheet(isPresented: $showLabelEdit) {
            LabelEditSheet(
                item: selectedItem,
                label: $editingLabel,
                onSave: {
                    if let item = selectedItem {
                        updateLabel(item, newLabel: editingLabel)
                    }
                    showLabelEdit = false
                },
                onClose: {
                    showLabelEdit = false
                }
            )
        }
        .alert("삭제 확인", isPresented: $showDeleteConfirm) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                if let item = itemToDelete {
                    deleteSecureValue(item)
                }
            }
        } message: {
            if let item = itemToDelete {
                let displayName = item.label ?? "ID: \(item.id)"
                Text("'\(displayName)'을(를) 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.")
            }
        }
        .alert("오류", isPresented: .constant(errorMessage != nil)) {
            Button("확인") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    func loadSecureValues() {
        let items = Database.shared.getAllSecureValuesWithDetails()
        secureValues = items.map { item in
            SecureValueItem(
                id: item.id,
                label: item.label,
                createdAt: item.createdAt,
                keyVersion: item.keyVersion
            )
        }
    }

    func authenticateAndDecrypt(_ item: SecureValueItem) {
        authenticate { success in
            if success {
                if let plaintext = SecureValueManager.shared.decrypt(refId: item.id) {
                    decryptedValue = plaintext
                    showDecryptedValue = true
                } else {
                    errorMessage = "복호화에 실패했습니다."
                }
            }
        }
    }

    func authenticateAndCopyToClipboard(_ item: SecureValueItem) {
        authenticate { success in
            if success {
                if let plaintext = SecureValueManager.shared.decrypt(refId: item.id) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(plaintext, forType: .string)

                    // 성공 피드백 (선택적)
                    NSSound.beep()
                } else {
                    errorMessage = "복호화에 실패했습니다."
                }
            }
        }
    }

    func deleteSecureValue(_ item: SecureValueItem) {
        SecureValueManager.shared.deleteValue(refId: item.id)
        loadSecureValues()
        selectedItem = nil
    }

    func updateLabel(_ item: SecureValueItem, newLabel: String) {
        // 라벨 중복 검사 (자기 자신 제외)
        let trimmedLabel = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLabel.isEmpty {
            if let existingId = Database.shared.getSecureIdByLabel(trimmedLabel), existingId != item.id {
                errorMessage = "라벨 '\(trimmedLabel)'이(가) 이미 존재합니다."
                return
            }
        }
        Database.shared.updateSecureLabel(id: item.id, label: trimmedLabel.isEmpty ? nil : trimmedLabel)
        loadSecureValues()
        // 선택 상태 업데이트
        if let updated = secureValues.first(where: { $0.id == item.id }) {
            selectedItem = updated
        }
    }

    func authenticate(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?

        // 생체 인증 가능 여부 확인
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "암호화된 값을 보려면 인증이 필요합니다"

            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        completion(true)
                    } else {
                        if let error = authError as? LAError {
                            switch error.code {
                            case .userCancel, .userFallback, .systemCancel:
                                // 사용자가 취소한 경우
                                break
                            default:
                                errorMessage = "인증에 실패했습니다: \(error.localizedDescription)"
                            }
                        }
                        completion(false)
                    }
                }
            }
        } else {
            // 인증 불가능한 경우
            DispatchQueue.main.async {
                errorMessage = "이 기기에서 인증을 사용할 수 없습니다."
                completion(false)
            }
        }
    }
}

struct SecureValueRow: View {
    let item: SecureValueItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.blue)
                .font(.system(size: 16))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                if let label = item.label {
                    Text(label)
                        .font(.body)
                        .fontWeight(.medium)
                    Text("ID: \(item.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)
                } else {
                    Text("ID: \(item.id)")
                        .font(.body)
                        .fontWeight(.medium)
                        .fontDesign(.monospaced)
                }

                HStack {
                    Text(item.createdAt, format: .dateTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("키 v\(item.keyVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct DecryptedValueSheet: View {
    let item: SecureValueItem?
    let decryptedValue: String
    let onClose: () -> Void

    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("복호화된 값")
                        .font(.headline)
                    Spacer()
                    if let item = item {
                        if let label = item.label {
                            Text(label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("ID: \(item.id)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                if let item = item {
                    Text(item.createdAt, format: .dateTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            // Decrypted value
            ScrollView {
                Text(decryptedValue)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
            .padding()

            Divider()

            // Actions
            HStack {
                Button(action: copyToClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "복사됨" : "클립보드에 복사")
                    }
                }
                .buttonStyle(HoverTextButtonStyle())
                .foregroundStyle(isCopied ? .green : .primary)

                Spacer()

                Button("닫기", action: onClose)
                    .buttonStyle(HoverTextButtonStyle())
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(decryptedValue, forType: .string)
        isCopied = true

        // 2초 후 복사됨 상태 해제
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }
}

struct LabelEditSheet: View {
    let item: SecureValueItem?
    @Binding var label: String
    let onSave: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("라벨 수정")
                    .font(.headline)
                if let item = item {
                    Text("ID: \(item.id)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            // Label input
            VStack(alignment: .leading, spacing: 8) {
                Text("라벨")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("라벨을 입력하세요", text: $label)
                    .textFieldStyle(.roundedBorder)
                Text("라벨을 비워두면 ID만 표시됩니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Spacer()

            Divider()

            // Actions
            HStack {
                Button("취소", action: onClose)
                    .buttonStyle(HoverTextButtonStyle())
                Spacer()
                Button("저장", action: onSave)
                    .buttonStyle(HoverTextButtonStyle())
                    .keyboardShortcut(.return, modifiers: [])
            }
            .padding()
        }
        .frame(width: 350, height: 220)
    }
}
