import Foundation

// MARK: - Language Pack Export/Import

struct LanguagePackExport: Codable {
    let version: Int
    let languageCode: String
    let languageName: String
    let strings: LocalizedStrings

    init(languageCode: String, languageName: String, strings: LocalizedStrings) {
        self.version = 1
        self.languageCode = languageCode
        self.languageName = languageName
        self.strings = strings
    }
}
