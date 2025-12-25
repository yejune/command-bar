import Foundation
import CryptoKit
import Security

/// 민감한 데이터 암호화 관리자
/// - {secure:평문} 입력 → 암호화 → {🔒:refId} 저장
/// - {🔒:refId} 실행 시 → 복호화 → 원래 값
class SecureValueManager {
    static let shared = SecureValueManager()

    private let db = Database.shared
    private let keychainService = "com.commandbar.securekey"

    private init() {
        ensureActiveKey()
    }

    // MARK: - 초기화

    /// 활성 키가 없으면 새로 생성
    private func ensureActiveKey() {
        if db.getCurrentKeyVersion() == 0 {
            let _ = generateNewKey()
        }
    }

    // MARK: - Keychain 키 관리

    /// Keychain에서 키 조회
    func getKey(version: Int) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
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

    /// Keychain에 키 저장
    func saveKey(_ key: Data, version: Int) {
        // 기존 키 삭제 (있으면)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "v\(version)"
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // 새 키 저장
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "v\(version)",
            kSecValueData as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    /// 새 키 생성 및 등록
    @discardableResult
    func generateNewKey() -> Int {
        // 256비트 랜덤 키 생성
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }

        // 다음 버전 번호
        let version = db.getNextKeyVersion()

        // Keychain에 저장
        saveKey(keyData, version: version)

        // 키 해시 생성 (처음 16바이트)
        let keyHash = keyData.prefix(16).base64EncodedString()

        // DB에 버전 등록 및 활성화
        db.insertKeyVersion(version: version, keyHash: keyHash)
        db.setActiveKeyVersion(version: version)

        return version
    }

    // MARK: - 암호화/복호화

    /// 평문 암호화
    /// - Returns: (참조 ID, 암호화된 값, 키 버전)
    func encrypt(_ plaintext: String) -> (refId: String, encrypted: String, keyVersion: Int)? {
        let keyVersion = db.getCurrentKeyVersion()
        guard keyVersion > 0,
              let keyData = getKey(version: keyVersion) else {
            print("SecureValueManager: 활성 키 없음")
            return nil
        }

        let key = SymmetricKey(data: keyData)

        guard let plaintextData = plaintext.data(using: .utf8) else {
            return nil
        }

        do {
            // AES-GCM 암호화 (nonce는 자동 생성)
            let sealedBox = try AES.GCM.seal(plaintextData, using: key)

            // nonce + ciphertext + tag 결합
            guard let combined = sealedBox.combined else {
                return nil
            }

            let encrypted = combined.base64EncodedString()
            let refId = db.generateSecureId()

            return (refId, encrypted, keyVersion)
        } catch {
            print("SecureValueManager: 암호화 실패 - \(error)")
            return nil
        }
    }

    /// 암호화된 값 복호화
    func decrypt(refId: String) -> String? {
        guard let stored = db.getSecureValue(id: refId) else {
            print("SecureValueManager: refId \(refId) 없음")
            return nil
        }

        guard let keyData = getKey(version: stored.keyVersion) else {
            print("SecureValueManager: 키 버전 \(stored.keyVersion) 없음")
            return nil
        }

        guard let encryptedData = Data(base64Encoded: stored.encrypted) else {
            return nil
        }

        let key = SymmetricKey(data: keyData)

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            let plaintext = String(data: decryptedData, encoding: .utf8)

            // Lazy migration: 구버전 키면 신버전으로 재암호화
            let currentVersion = db.getCurrentKeyVersion()
            if stored.keyVersion < currentVersion {
                migrateValue(refId: refId, plaintext: plaintext ?? "", toVersion: currentVersion)
            }

            return plaintext
        } catch {
            print("SecureValueManager: 복호화 실패 - \(error)")
            return nil
        }
    }

    /// 값을 새 키 버전으로 마이그레이션
    private func migrateValue(refId: String, plaintext: String, toVersion: Int) {
        guard let keyData = getKey(version: toVersion),
              let plaintextData = plaintext.data(using: .utf8) else {
            return
        }

        let key = SymmetricKey(data: keyData)

        do {
            let sealedBox = try AES.GCM.seal(plaintextData, using: key)
            guard let combined = sealedBox.combined else { return }

            let encrypted = combined.base64EncodedString()
            db.updateSecureValue(id: refId, encryptedValue: encrypted, keyVersion: toVersion)
            print("SecureValueManager: \(refId) 마이그레이션 완료 → v\(toVersion)")
        } catch {
            print("SecureValueManager: 마이그레이션 실패 - \(error)")
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
    /// - {secure:값} → 암호화 → {🔒:refId}
    /// - {secure#라벨:값} → 암호화 + 라벨 저장 → {🔒:refId}
    /// - {secure#라벨} → 기존 라벨 참조 → {🔒:refId}
    func processForSave(_ text: String) -> ProcessResult {
        var result = text

        // 1. {secure#라벨:값} 패턴 처리 (라벨 + 새 암호화)
        if let labelValueRegex = try? NSRegularExpression(pattern: "\\{secure#([^:}]+):([^}]+)\\}") {
            let range = NSRange(result.startIndex..., in: result)
            let matches = labelValueRegex.matches(in: result, range: range).reversed()

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
                        keyVersion: encrypted.keyVersion,
                        label: label
                    )
                    result.replaceSubrange(fullRange, with: "{🔒:\(encrypted.refId)}")
                }
            }
        }

        // 2. {secure#라벨} 패턴 처리 (기존 라벨 참조)
        if let labelOnlyRegex = try? NSRegularExpression(pattern: "\\{secure#([^:}]+)\\}") {
            let range = NSRange(result.startIndex..., in: result)
            let matches = labelOnlyRegex.matches(in: result, range: range).reversed()

            for match in matches {
                guard let fullRange = Range(match.range, in: result),
                      let labelRange = Range(match.range(at: 1), in: result) else {
                    continue
                }

                let label = String(result[labelRange])

                // 라벨로 ID 조회
                if let existingId = db.getSecureIdByLabel(label) {
                    result.replaceSubrange(fullRange, with: "{🔒:\(existingId)}")
                } else {
                    return ProcessResult(text: text, error: "라벨 '\(label)'을(를) 찾을 수 없습니다.", errorRange: match.range)
                }
            }
        }

        // 3. {secure:값} 패턴 처리 (라벨 없이 새 암호화)
        if let simpleRegex = try? NSRegularExpression(pattern: "\\{secure:([^}]+)\\}") {
            let range = NSRange(result.startIndex..., in: result)
            let matches = simpleRegex.matches(in: result, range: range).reversed()

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
                        keyVersion: encrypted.keyVersion
                    )
                    result.replaceSubrange(fullRange, with: "{🔒:\(encrypted.refId)}")
                }
            }
        }

        return ProcessResult(text: result, error: nil, errorRange: nil)
    }

    /// 실행 전 처리: {🔒:refId} → 복호화 → 원래 값
    func processForExecution(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\\{🔒:([^}]+)\\}") else {
            return text
        }

        var result = text
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range).reversed()

        for match in matches {
            guard let fullRange = Range(match.range, in: result),
                  let refIdRange = Range(match.range(at: 1), in: result) else {
                continue
            }

            let refId = String(result[refIdRange])

            // 복호화
            if let plaintext = decrypt(refId: refId) {
                result.replaceSubrange(fullRange, with: plaintext)
            }
        }

        return result
    }

    // MARK: - 값 관리

    /// 암호화된 값 수정 (새 평문으로 재암호화)
    func updateValue(refId: String, newPlaintext: String) -> Bool {
        guard let encrypted = encrypt(newPlaintext) else {
            return false
        }

        db.updateSecureValue(
            id: refId,
            encryptedValue: encrypted.encrypted,
            keyVersion: encrypted.keyVersion
        )
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

    // MARK: - 키 로테이션

    /// 새 키로 교체 (기존 값들은 Lazy migration)
    func rotateKey() -> Int {
        return generateNewKey()
    }

    /// 모든 값을 현재 키로 강제 마이그레이션
    func migrateAllToCurrentKey() {
        let currentVersion = db.getCurrentKeyVersion()
        let allValues = db.getAllSecureValues()

        for value in allValues {
            if value.keyVersion < currentVersion {
                if let plaintext = decrypt(refId: value.id) {
                    migrateValue(refId: value.id, plaintext: plaintext, toVersion: currentVersion)
                }
            }
        }
    }

    /// 현재 키 버전 정보
    func getCurrentKeyInfo() -> (version: Int, valueCount: Int) {
        let version = db.getCurrentKeyVersion()
        let count = db.getSecureValuesByKeyVersion(version: version).count
        return (version, count)
    }
}
