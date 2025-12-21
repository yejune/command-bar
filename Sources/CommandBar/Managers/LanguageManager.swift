import SwiftUI
import AppKit

// 전역 언어 매니저
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
            loadStrings()
        }
    }

    @Published var strings: LocalizedStrings

    private let customStringsKey = "customLanguageStrings"

    private init() {
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "ko"
        self.currentLanguage = Language(rawValue: savedLanguage) ?? .korean
        self.strings = .korean
        loadStrings()
    }

    private func loadStrings() {
        // 먼저 커스텀 언어팩이 있는지 확인
        if let customData = UserDefaults.standard.data(forKey: customStringsKey),
           let customStrings = try? JSONDecoder().decode(LocalizedStrings.self, from: customData) {
            strings = customStrings
        } else {
            strings = LocalizedStrings.forLanguage(currentLanguage)
        }
    }

    func importLanguagePack(from data: Data) -> Bool {
        guard let pack = try? JSONDecoder().decode(LanguagePackExport.self, from: data) else {
            return false
        }

        // 커스텀 언어팩 저장
        if let encoded = try? JSONEncoder().encode(pack.strings) {
            UserDefaults.standard.set(encoded, forKey: customStringsKey)
            strings = pack.strings
            return true
        }
        return false
    }

    func exportLanguagePackTemplate() -> Data? {
        let pack = LanguagePackExport(
            languageCode: "custom",
            languageName: "Custom Language",
            strings: strings
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(pack)
    }

    func resetToBuiltIn() {
        UserDefaults.standard.removeObject(forKey: customStringsKey)
        strings = LocalizedStrings.forLanguage(currentLanguage)
    }

    var hasCustomPack: Bool {
        UserDefaults.standard.data(forKey: customStringsKey) != nil
    }
}

// 편의를 위한 전역 접근자
var L: LocalizedStrings { LanguageManager.shared.strings }
