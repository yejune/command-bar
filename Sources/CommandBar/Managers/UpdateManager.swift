import Foundation
import AppKit

// MARK: - App Info

struct AppInfo {
    static let version = "0.0.19"  // tobrew.lock과 동기화
    static let bundleId = "com.yejune.CommandBar"
    static let repoOwner = "yejune"
    static let repoName = "command-bar"
    static let brewTap = "yejune/tap/command-bar"
}

// MARK: - Update Manager

class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    @Published var isChecking = false
    @Published var isUpdating = false
    @Published var latestVersion: String?
    @Published var updateAvailable = false
    @Published var lastError: String?

    private init() {}

    // MARK: - Installation Detection

    var isHomebrewInstall: Bool {
        guard let execPath = Bundle.main.executablePath else { return false }
        return execPath.contains("/Cellar/") ||
               execPath.contains("/opt/homebrew/") ||
               execPath.contains("homebrew")
    }

    var installationType: String {
        isHomebrewInstall ? "Homebrew" : "직접 설치"
    }

    var executablePath: String {
        Bundle.main.executablePath ?? "알 수 없음"
    }

    // MARK: - Version Check

    func checkForUpdates() async {
        await MainActor.run {
            isChecking = true
            lastError = nil
        }

        defer {
            Task { @MainActor in
                isChecking = false
            }
        }

        do {
            let release = try await fetchLatestRelease()
            let latest = release.tagName.replacingOccurrences(of: "v", with: "")

            await MainActor.run {
                latestVersion = latest
                updateAvailable = isNewerVersion(latest, than: AppInfo.version)
            }
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
            }
        }
    }

    private func isNewerVersion(_ new: String, than current: String) -> Bool {
        let newParts = new.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(newParts.count, currentParts.count) {
            let newPart = i < newParts.count ? newParts[i] : 0
            let currentPart = i < currentParts.count ? currentParts[i] : 0

            if newPart > currentPart { return true }
            if newPart < currentPart { return false }
        }
        return false
    }

    // MARK: - GitHub API

    struct GitHubRelease: Codable {
        let tagName: String
        let assets: [Asset]

        struct Asset: Codable {
            let name: String
            let browserDownloadUrl: String

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadUrl = "browser_download_url"
            }
        }

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case assets
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        let url = URL(string: "https://api.github.com/repos/\(AppInfo.repoOwner)/\(AppInfo.repoName)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateError.networkError
        }

        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    // MARK: - Update

    func performUpdate() async {
        await MainActor.run {
            isUpdating = true
            lastError = nil
        }

        defer {
            Task { @MainActor in
                isUpdating = false
            }
        }

        if isHomebrewInstall {
            await updateViaHomebrew()
        } else {
            await MainActor.run {
                lastError = "직접 설치의 경우 GitHub에서 최신 버전을 다운로드하세요."
            }
            // Open GitHub releases page
            if let url = URL(string: "https://github.com/\(AppInfo.repoOwner)/\(AppInfo.repoName)/releases/latest") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func updateViaHomebrew() async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["brew", "upgrade", "command-bar"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                await MainActor.run {
                    // 업데이트 성공 - 앱 재시작 안내
                    let alert = NSAlert()
                    alert.messageText = "업데이트 완료"
                    alert.informativeText = "CommandBar가 업데이트되었습니다. 앱을 재시작하세요."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "지금 재시작")
                    alert.addButton(withTitle: "나중에")

                    if alert.runModal() == .alertFirstButtonReturn {
                        restartApp()
                    }
                }
            } else {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? "알 수 없는 오류"
                await MainActor.run {
                    lastError = "Homebrew 업데이트 실패: \(output)"
                }
            }
        } catch {
            await MainActor.run {
                lastError = "Homebrew 실행 실패: \(error.localizedDescription)"
            }
        }
    }

    private func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.bundlePath)
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true

        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    enum UpdateError: Error, LocalizedError {
        case networkError
        case parseError

        var errorDescription: String? {
            switch self {
            case .networkError: return "네트워크 오류"
            case .parseError: return "응답 파싱 오류"
            }
        }
    }
}
