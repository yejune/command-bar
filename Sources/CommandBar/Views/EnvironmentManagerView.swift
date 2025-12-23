import SwiftUI
import AppKit

/// API 환경 관리 창 (Paw 방식 테이블 뷰)
struct EnvironmentManagerView: View {
    @ObservedObject var store: CommandStore
    @Environment(\.dismiss) private var dismiss

    @State private var editingEnvId: UUID?
    @State private var editingVarKey: String?
    @State private var newVariableName = ""
    @State private var showAddEnvironment = false
    @State private var showAddVariable = false
    @State private var newEnvName = ""
    @State private var newEnvColor = "blue"

    // 모든 환경에서 사용되는 변수 이름 목록
    var allVariableNames: [String] {
        var names = Set<String>()
        for env in store.environments {
            for key in env.variables.keys {
                names.insert(key)
            }
        }
        return names.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text(L.envManagerTitle)
                    .font(.headline)

                Spacer()

                Button(action: { showAddVariable = true }) {
                    Label(L.envAddVariable, systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(HoverButtonStyle())
                .popover(isPresented: $showAddVariable) {
                    addVariablePopover
                }

                Button(action: { showAddEnvironment = true }) {
                    Label(L.envAddEnvironment, systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(HoverButtonStyle())
                .popover(isPresented: $showAddEnvironment) {
                    addEnvironmentPopover
                }

                Button(action: exportEnvironments) {
                    Label(L.envExport, systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(HoverButtonStyle())

                Button(action: importEnvironments) {
                    Label(L.envImport, systemImage: "square.and.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(HoverButtonStyle())
            }
            .padding()

            Divider()

            if store.environments.isEmpty {
                // 환경이 없을 때
                VStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(L.envNoEnvironments)
                        .foregroundStyle(.secondary)
                    Button(L.envAddFirst) {
                        showAddEnvironment = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if allVariableNames.isEmpty {
                // 변수가 없을 때
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(L.envNoVariables)
                        .foregroundStyle(.secondary)
                    Button(L.envAddFirstVariable) {
                        showAddVariable = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 테이블 뷰
                GeometryReader { geometry in
                    ScrollView([.horizontal, .vertical]) {
                        VStack(alignment: .leading, spacing: 0) {
                            // 헤더 행
                            HStack(spacing: 0) {
                                Text(L.envVariable)
                                    .font(.caption.bold())
                                    .frame(width: 120, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.gray.opacity(0.1))

                                ForEach(store.environments) { env in
                                    environmentColumnHeader(env)
                                }
                            }

                            Divider()

                            // 변수 행들
                            ForEach(allVariableNames, id: \.self) { varName in
                                variableRow(varName)
                                Divider()
                            }

                            Spacer(minLength: 0)
                        }
                        .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
                    }
                }
            }

            Divider()

            // 활성 환경 선택
            HStack {
                Text(L.envActiveEnvironment)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(store.environments) { env in
                    Button(action: {
                        store.setActiveEnvironment(env)
                    }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(colorFor(env.color))
                                .frame(width: 8, height: 8)
                            Text(env.name)
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(store.activeEnvironmentId == env.id ? colorFor(env.color).opacity(0.2) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(store.activeEnvironmentId == env.id ? colorFor(env.color) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if store.activeEnvironmentId != nil {
                    Button(action: {
                        store.setActiveEnvironment(nil)
                    }) {
                        Text(L.envClear)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button(L.buttonClose) {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    // MARK: - 환경 컬럼 헤더

    func environmentColumnHeader(_ env: APIEnvironment) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(colorFor(env.color))
                .frame(width: 10, height: 10)

            Text(env.name)
                .font(.caption.bold())
                .lineLimit(1)

            Spacer()

            Menu {
                Button(L.envEdit) {
                    editingEnvId = env.id
                }
                Button(L.envDelete, role: .destructive) {
                    store.deleteEnvironment(env)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 16)
        }
        .frame(width: 140, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(colorFor(env.color).opacity(0.1))
        .contextMenu {
            Button(L.envEdit) {
                editingEnvId = env.id
            }
            Button(L.envDelete, role: .destructive) {
                store.deleteEnvironment(env)
            }
        }
    }

    // MARK: - 변수 행

    func variableRow(_ varName: String) -> some View {
        HStack(spacing: 0) {
            // 변수 이름
            HStack {
                Text(varName)
                    .font(.caption)
                    .lineLimit(1)

                Spacer()

                Button(action: {
                    deleteVariable(varName)
                }) {
                    Image(systemName: "trash")
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .opacity(0.6)
            }
            .frame(width: 120, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            // 각 환경별 값
            ForEach(store.environments) { env in
                variableCell(env: env, varName: varName)
            }
        }
        .background(Color.gray.opacity(0.02))
    }

    // MARK: - 변수 셀

    func variableCell(env: APIEnvironment, varName: String) -> some View {
        let value = env.variables[varName] ?? ""

        return TextField("", text: Binding(
            get: { env.variables[varName] ?? "" },
            set: { newValue in
                var updatedEnv = env
                updatedEnv.variables[varName] = newValue
                store.updateEnvironment(updatedEnv)
            }
        ))
        .textFieldStyle(.plain)
        .font(.caption)
        .frame(width: 140, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(value.isEmpty ? Color.clear : colorFor(env.color).opacity(0.05))
    }

    // MARK: - 변수 추가 팝오버

    var addVariablePopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.envAddVariable)
                .font(.headline)

            TextField(L.envVariableName, text: $newVariableName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button(L.buttonCancel) {
                    newVariableName = ""
                    showAddVariable = false
                }

                Spacer()

                Button(L.buttonAdd) {
                    addVariable()
                }
                .disabled(newVariableName.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 250)
    }

    // MARK: - 환경 추가 팝오버

    var addEnvironmentPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.envAddEnvironment)
                .font(.headline)

            TextField(L.envName, text: $newEnvName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text(L.envColor)
                ForEach(APIEnvironment.availableColors, id: \.self) { color in
                    Button(action: { newEnvColor = color }) {
                        Circle()
                            .fill(colorFor(color))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(newEnvColor == color ? Color.primary : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Button(L.buttonCancel) {
                    newEnvName = ""
                    newEnvColor = "blue"
                    showAddEnvironment = false
                }

                Spacer()

                Button(L.buttonAdd) {
                    addEnvironment()
                }
                .disabled(newEnvName.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 300)
    }

    // MARK: - Actions

    func addVariable() {
        guard !newVariableName.isEmpty else { return }

        // 모든 환경에 빈 값으로 변수 추가
        for i in store.environments.indices {
            if store.environments[i].variables[newVariableName] == nil {
                store.environments[i].variables[newVariableName] = ""
            }
        }
        store.saveEnvironments()

        newVariableName = ""
        showAddVariable = false
    }

    func deleteVariable(_ varName: String) {
        // 모든 환경에서 변수 삭제
        for i in store.environments.indices {
            store.environments[i].variables.removeValue(forKey: varName)
        }
        store.saveEnvironments()
    }

    func addEnvironment() {
        guard !newEnvName.isEmpty else { return }

        let env = APIEnvironment(
            name: newEnvName,
            color: newEnvColor,
            variables: [:],
            order: store.environments.count
        )
        store.addEnvironment(env)

        newEnvName = ""
        newEnvColor = "blue"
        showAddEnvironment = false
    }

    func exportEnvironments() {
        guard let data = store.exportEnvironments() else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "environments.json"

        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }

    func importEnvironments() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? Data(contentsOf: url) {
                _ = store.importEnvironments(data, merge: true)
            }
        }
    }

    func colorFor(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "red": return .red
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "gray": return .gray
        case "yellow": return .yellow
        default: return .blue
        }
    }
}

// MARK: - 환경 관리 창 컨트롤러

class EnvironmentManagerWindowController: NSWindowController {
    static var shared: EnvironmentManagerWindowController?

    static func show(store: CommandStore) {
        if let existing = shared {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = EnvironmentManagerView(store: store)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = L.envManagerTitle
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 700, height: 500))
        window.center()

        let controller = EnvironmentManagerWindowController(window: window)
        controller.showWindow(nil)
        shared = controller

        // 창이 닫힐 때 참조 해제
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            shared = nil
        }
    }
}
