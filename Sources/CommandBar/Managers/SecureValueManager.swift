import Foundation
import CryptoKit
import Security

/// 민감한 데이터 암호화 관리자
/// - {secure:평문} 입력 → 암호화 → `secure@refId` 저장
/// - `secure@refId` 실행 시 → 복호화 → 원래 값
/// - 로컬: 파일 기반 키 (Keychain 제거)
/// - 클라우드: 패스워드 기반 키 (동기화용)
class SecureValueManager {
    static let shared = SecureValueManager()

    private let db = Database.shared
    private let keyService = KeyManagementService.shared

    // Legacy Keychain (마이그레이션용)
    private let legacyKeychainService = "com.commandbar.securekey"
    private var legacyKeyCache: [Int: Data] = [:]

    private init() {
        migrateFromKeychainIfNeeded()
    }

    // MARK: - 마이그레이션 (Keychain → LocalKeyStore)

    /// 기존 Keychain 데이터 마이그레이션
    private func migrateFromKeychainIfNeeded() {
        // 이미 마이그레이션 완료 여부 확인
        if db.getBoolSetting("keychain_migrated", defaultValue: false) {
            logInfo("SecureValueManager: 이미 마이그레이션 완료됨")
            return
        }

        let allValues = db.getAllSecureValues()
        if allValues.isEmpty {
            // 마이그레이션할 데이터 없음
            db.setBoolSetting("keychain_migrated", value: true)
            return
        }

        logInfo("SecureValueManager: Keychain에서 마이그레이션 시작 (\(allValues.count)개)")

        // 기존 Keychain 키들 로드
        let maxVersion = allValues.map { $0.keyVersion }.max() ?? 0
        for version in 1...maxVersion {
            if let key = loadLegacyKeyFromKeychain(version: version) {
                legacyKeyCache[version] = key
            }
        }

        // 각 값을 새 로컬 키로 재암호화
        var migrated = 0
        for value in allValues {
            if let plaintext = decryptWithLegacyKey(encrypted: value.encrypted, keyVersion: value.keyVersion) {
                if let newEncrypted = keyService.encryptLocal(plaintext) {
                    db.updateSecureValue(id: value.id, encryptedValue: newEncrypted, keyVersion: 0)  // version 0 = 로컬 키
                    migrated += 1
                }
            }
        }

        // Keychain 키 삭제 (선택사항 - 백업용으로 유지해도 됨)
        // deleteAllLegacyKeys()

        db.setBoolSetting("keychain_migrated", value: true)
        legacyKeyCache.removeAll()

        logInfo("SecureValueManager: 마이그레이션 완료 (\(migrated)/\(allValues.count))")
    }

    /// Legacy Keychain에서 키 로드
    private func loadLegacyKeyFromKeychain(version: Int) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyKeychainService,
            kSecAttrAccount as String: "v\(version)",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return data
        }
        return nil
    }

    /// Legacy 키로 복호화
    private func decryptWithLegacyKey(encrypted: String, keyVersion: Int) -> String? {
        guard let keyData = legacyKeyCache[keyVersion],
              let encryptedData = Data(base64Encoded: encrypted) else {
            return nil
        }

        let key = SymmetricKey(data: keyData)

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            logError("SecureValueManager: Legacy 복호화 실패 - \(error)")
            return nil
        }
    }

    // MARK: - 암호화/복호화

    /// 평문 암호화
    /// - Returns: (참조 ID, 암호화된 값)
    func encrypt(_ plaintext: String) -> (refId: String, encrypted: String)? {
        guard let encrypted = keyService.encryptLocal(plaintext) else {
            logError("SecureValueManager: 암호화 실패")
            return nil
        }

        let refId = db.generateSecureId()
        return (refId, encrypted)
    }

    /// 암호화된 값 복호화
    func decrypt(refId: String) -> String? {
        guard let stored = db.getSecureValue(id: refId) else {
            logError("SecureValueManager: refId \(refId) 없음")
            return nil
        }

        // keyVersion 0 = 로컬 키, 그 외 = legacy (마이그레이션 안 된 경우)
        if stored.keyVersion == 0 {
            return keyService.decryptLocal(stored.encrypted)
        } else {
            // Legacy fallback (마이그레이션 안 된 경우)
            if legacyKeyCache.isEmpty {
                // 키 다시 로드 시도
                if let key = loadLegacyKeyFromKeychain(version: stored.keyVersion) {
                    legacyKeyCache[stored.keyVersion] = key
                }
            }
            return decryptWithLegacyKey(encrypted: stored.encrypted, keyVersion: stored.keyVersion)
        }
    }

    // MARK: - 텍스트 처리

    /// 저장 전 처리 결과
    struct ProcessResult {
        var text: String
        var error: String?
        var errorRange: NSRange?
    }

    /// 저장 전 처리:
    /// - {secure:값}, [secure:값] → 암호화 → `secure@refId`
    /// - {secure#라벨:값}, [secure#라벨:값] → 암호화 + 라벨 저장 → `secure@refId`
    /// - {secure#라벨}, [secure#라벨] → 기존 라벨 참조 → `secure@id`
    func processForSave(_ text: String) -> ProcessResult {
        var result = text

        // 1. {secure#라벨:값} 또는 [secure#라벨:값] 패턴 처리 (라벨 + 새 암호화)
        let labelValuePatterns = ["\\{secure#([^:}]+):([^}]+)\\}", "\\[secure#([^:\\]]+):([^\\]]+)\\]"]
        for pattern in labelValuePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()

            for match in matches {
                guard let fullRange = Range(match.range, in: result),
                      let labelRange = Range(match.range(at: 1), in: result),
                      let valueRange = Range(match.range(at: 2), in: result) else {
                    continue
                }

                let label = String(result[labelRange])
                let plaintext = String(result[valueRange])

                // 라벨 중복 검사
                if db.secureLabelExists(label) {
                    return ProcessResult(text: text, error: "라벨 '\(label)'이(가) 이미 존재합니다.", errorRange: match.range)
                }

                // 암호화
                if let encrypted = encrypt(plaintext) {
                    db.insertSecureValue(
                        id: encrypted.refId,
                        encryptedValue: encrypted.encrypted,
                        keyVersion: 0,  // 로컬 키
                        label: label
                    )
                    result.replaceSubrange(fullRange, with: "`secure@\(encrypted.refId)`")
                }
            }
        }

        // 2. {secure#라벨} 또는 [secure#라벨] 패턴 처리 (기존 라벨 참조)
        let labelOnlyPatterns = ["\\{secure#([^:}]+)\\}", "\\[secure#([^:\\]]+)\\]"]
        for pattern in labelOnlyPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()

            for match in matches {
                guard let fullRange = Range(match.range, in: result),
                      let labelRange = Range(match.range(at: 1), in: result) else {
                    continue
                }

                let label = String(result[labelRange])

                if let existingId = db.getSecureIdByLabel(label) {
                    result.replaceSubrange(fullRange, with: "`secure@\(existingId)`")
                } else {
                    return ProcessResult(text: text, error: "라벨 '\(label)'을(를) 찾을 수 없습니다.", errorRange: match.range)
                }
            }
        }

        // 3. {secure:값} 또는 [secure:값] 패턴 처리 (라벨 없이 새 암호화)
        let simplePatterns = ["\\{secure:([^}]+)\\}", "\\[secure:([^\\]]+)\\]"]
        for pattern in simplePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()

            for match in matches {
                guard let fullRange = Range(match.range, in: result),
                      let plaintextRange = Range(match.range(at: 1), in: result) else {
                    continue
                }

                let plaintext = String(result[plaintextRange])

                if let encrypted = encrypt(plaintext) {
                    db.insertSecureValue(
                        id: encrypted.refId,
                        encryptedValue: encrypted.encrypted,
                        keyVersion: 0  // 로컬 키
                    )
                    result.replaceSubrange(fullRange, with: "`secure@\(encrypted.refId)`")
                }
            }
        }

        return ProcessResult(text: result, error: nil, errorRange: nil)
    }

    /// 실행 전 처리: `secure@id` → 복호화 → 원래 값
    func processForExecution(_ text: String) -> String {
        var result = text

        guard let regex = try? NSRegularExpression(pattern: "`secure@([^`]+)`") else {
            return result
        }

        let range = NSRange(result.startIndex..., in: result)
        let matches = regex.matches(in: result, range: range).reversed()

        if !matches.isEmpty {
            logChain("secure 치환 시작: \(matches.count)개 발견")
        }

        for match in matches {
            guard let fullRange = Range(match.range, in: result),
                  let refIdRange = Range(match.range(at: 1), in: result) else {
                continue
            }

            let refId = String(result[refIdRange])
            let label = db.getSecureLabelById(refId) ?? refId

            if let plaintext = decrypt(refId: refId) {
                logChain("secure@\(refId) (\(label)) → ****")
                result.replaceSubrange(fullRange, with: plaintext)
            } else {
                logChain("secure@\(refId) (\(label)) → 복호화 실패")
            }
        }

        return result
    }

    // MARK: - 값 관리

    /// 암호화된 값 수정 (새 평문으로 재암호화)
    func updateValue(refId: String, newPlaintext: String) -> Bool {
        guard let encrypted = keyService.encryptLocal(newPlaintext) else {
            return false
        }

        db.updateSecureValue(id: refId, encryptedValue: encrypted, keyVersion: 0)
        return true
    }

    /// 암호화된 값 삭제
    func deleteValue(refId: String) {
        db.deleteSecureValue(id: refId)
    }

    /// 모든 secure value ID 목록
    func getAllRefIds() -> [String] {
        return db.getAllSecureValues().map { $0.id }
    }

    /// 모든 라벨 목록
    func getAllLabels() -> [String] {
        return db.getAllSecureLabels()
    }

    // MARK: - 클라우드 동기화용

    /// 클라우드용으로 암호화
    func encryptForCloud(_ plaintext: String) -> String? {
        return keyService.encryptForCloud(plaintext)
    }

    /// 클라우드에서 복호화
    func decryptFromCloud(_ ciphertext: String) -> String? {
        return keyService.decryptFromCloud(ciphertext)
    }

    /// 로컬 → 클라우드용 재암호화
    func reencryptForCloud(refId: String) -> String? {
        guard let stored = db.getSecureValue(id: refId) else { return nil }
        return keyService.reencryptForCloud(stored.encrypted)
    }

    /// 클라우드 → 로컬용 재암호화
    func reencryptFromCloud(_ cloudCiphertext: String) -> String? {
        return keyService.reencryptForLocal(cloudCiphertext)
    }
}
