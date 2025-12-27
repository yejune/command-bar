import Foundation
import CryptoKit
import Security
import CommonCrypto

/// 민감한 데이터 암호화 관리자
/// - 패스워드 미설정: 평문 저장 (마스킹은 됨)
/// - 패스워드 설정: PBKDF2 → AES-GCM 암호화
/// - 패스워드 변경: key_version++, lazy migration
class SecureValueManager {
    static let shared = SecureValueManager()

    private let db = Database.shared

    // 현재 세션의 암호화 키 (패스워드에서 파생)
    private var currentKey: SymmetricKey?
    private var currentKeyVersion: Int = 0

    // PBKDF2 설정
    private let pbkdf2Iterations: UInt32 = 100_000
    private let keySize = 32  // 256 bits

    private init() {
        loadCurrentKeyVersion()
    }

    // MARK: - 패스워드 관리

    /// 패스워드 설정 여부
    var isPasswordSet: Bool {
        db.getSetting("encryption_salt") != nil
    }

    /// 현재 세션에서 인증됨
    var isUnlocked: Bool {
        currentKey != nil || !isPasswordSet
    }

    /// 현재 키 버전 로드
    private func loadCurrentKeyVersion() {
        currentKeyVersion = db.getCurrentKeyVersion()
    }

    /// 패스워드로 잠금 해제
    func unlock(password: String) -> Bool {
        guard let saltBase64 = db.getSetting("encryption_salt"),
              let salt = Data(base64Encoded: saltBase64),
              let verifierBase64 = db.getSetting("encryption_verifier"),
              let storedVerifier = Data(base64Encoded: verifierBase64) else {
            return false
        }

        // 키 파생
        guard let keyData = deriveKey(password: password, salt: salt) else {
            return false
        }

        // Verifier 확인
        let verifier = SHA256.hash(data: keyData)
        let verifierData = Data(verifier)

        if verifierData == storedVerifier {
            currentKey = SymmetricKey(data: keyData)
            loadCurrentKeyVersion()
            logInfo("SecureValueManager: 패스워드 인증 성공")
            return true
        }

        logError("SecureValueManager: 패스워드 불일치")
        return false
    }

    /// 패스워드 설정 (최초)
    func setPassword(_ password: String) -> Bool {
        guard !isPasswordSet else {
            logError("SecureValueManager: 이미 패스워드 설정됨")
            return false
        }

        // Salt 생성
        var salt = Data(count: 32)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }

        // 키 파생
        guard let keyData = deriveKey(password: password, salt: salt) else {
            return false
        }

        // Verifier 생성
        let verifier = SHA256.hash(data: keyData)
        let verifierData = Data(verifier)

        // DB에 저장
        db.setSetting("encryption_salt", value: salt.base64EncodedString())
        db.setSetting("encryption_verifier", value: verifierData.base64EncodedString())

        // 키 버전 설정
        let keyHash = keyData.prefix(16).base64EncodedString()
        let version = db.getNextKeyVersion()
        db.insertKeyVersion(version: version, keyHash: keyHash)
        db.setActiveKeyVersion(version: version)

        currentKey = SymmetricKey(data: keyData)
        currentKeyVersion = version

        logInfo("SecureValueManager: 패스워드 설정 완료 (v\(version))")
        return true
    }

    /// 패스워드 변경
    func changePassword(oldPassword: String, newPassword: String) -> Bool {
        // 기존 패스워드 확인
        guard unlock(password: oldPassword) else {
            logError("SecureValueManager: 기존 패스워드 불일치")
            return false
        }

        let oldKey = currentKey

        // 새 Salt 생성
        var newSalt = Data(count: 32)
        _ = newSalt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }

        // 새 키 파생
        guard let newKeyData = deriveKey(password: newPassword, salt: newSalt) else {
            return false
        }

        // 새 Verifier 생성
        let newVerifier = SHA256.hash(data: newKeyData)
        let newVerifierData = Data(newVerifier)

        // DB 업데이트
        db.setSetting("encryption_salt", value: newSalt.base64EncodedString())
        db.setSetting("encryption_verifier", value: newVerifierData.base64EncodedString())

        // 새 키 버전
        let keyHash = newKeyData.prefix(16).base64EncodedString()
        let newVersion = db.getNextKeyVersion()
        db.insertKeyVersion(version: newVersion, keyHash: keyHash)
        db.setActiveKeyVersion(version: newVersion)

        let newKey = SymmetricKey(data: newKeyData)
        let oldVersion = currentKeyVersion

        // 기존 데이터 마이그레이션 (즉시)
        migrateAllValues(from: oldKey!, oldVersion: oldVersion, to: newKey, newVersion: newVersion)

        currentKey = newKey
        currentKeyVersion = newVersion

        logInfo("SecureValueManager: 패스워드 변경 완료 (v\(oldVersion) → v\(newVersion))")
        return true
    }

    /// 패스워드 초기화 (모든 암호화 데이터 삭제)
    func resetPassword() {
        db.deleteSetting("encryption_salt")
        db.deleteSetting("encryption_verifier")
        // 모든 secure values 삭제
        for value in db.getAllSecureValues() {
            db.deleteSecureValue(id: value.id)
        }
        currentKey = nil
        currentKeyVersion = 0
        logInfo("SecureValueManager: 패스워드 초기화됨")
    }

    // MARK: - PBKDF2 키 파생

    private func deriveKey(password: String, salt: Data) -> Data? {
        guard let passwordData = password.data(using: .utf8) else { return nil }

        var derivedKey = Data(count: keySize)

        let result = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        pbkdf2Iterations,
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keySize
                    )
                }
            }
        }

        return result == kCCSuccess ? derivedKey : nil
    }

    // MARK: - 암호화/복호화

    /// 평문 암호화
    func encrypt(_ plaintext: String) -> (refId: String, encrypted: String, keyVersion: Int)? {
        let refId = db.generateSecureId()

        if let key = currentKey {
            // 패스워드 있음 → 암호화
            guard let plaintextData = plaintext.data(using: .utf8) else { return nil }

            do {
                let sealedBox = try AES.GCM.seal(plaintextData, using: key)
                guard let combined = sealedBox.combined else { return nil }
                let encrypted = combined.base64EncodedString()
                return (refId, encrypted, currentKeyVersion)
            } catch {
                logError("SecureValueManager: 암호화 실패 - \(error)")
                return nil
            }
        } else {
            // 패스워드 없음 → 평문 (base64)
            let encoded = Data(plaintext.utf8).base64EncodedString()
            return (refId, encoded, 0)  // version 0 = 평문
        }
    }

    /// 암호화된 값 복호화
    func decrypt(refId: String) -> String? {
        guard let stored = db.getSecureValue(id: refId) else {
            logError("SecureValueManager: refId \(refId) 없음")
            return nil
        }

        return decryptValue(encrypted: stored.encrypted, keyVersion: stored.keyVersion)
    }

    /// 값 복호화 (내부용)
    private func decryptValue(encrypted: String, keyVersion: Int) -> String? {
        guard let encryptedData = Data(base64Encoded: encrypted) else {
            return nil
        }

        if keyVersion == 0 {
            // 평문 (base64)
            return String(data: encryptedData, encoding: .utf8)
        }

        guard let key = currentKey else {
            logError("SecureValueManager: 키 없음 (잠금 상태)")
            return nil
        }

        // Lazy migration: 현재 버전과 다르면 재암호화
        // (여기서는 복호화만, 마이그레이션은 별도)

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            logError("SecureValueManager: 복호화 실패 - \(error)")
            return nil
        }
    }

    // MARK: - 마이그레이션

    /// 모든 값을 새 키로 마이그레이션
    private func migrateAllValues(from oldKey: SymmetricKey, oldVersion: Int, to newKey: SymmetricKey, newVersion: Int) {
        let allValues = db.getAllSecureValues()
        var migrated = 0

        for value in allValues {
            // 평문(v0)이거나 현재 버전이면 스킵
            if value.keyVersion == 0 || value.keyVersion == newVersion {
                continue
            }

            // 복호화
            guard let encryptedData = Data(base64Encoded: value.encrypted) else { continue }

            do {
                let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
                let decryptedData = try AES.GCM.open(sealedBox, using: oldKey)

                // 새 키로 재암호화
                let newSealedBox = try AES.GCM.seal(decryptedData, using: newKey)
                guard let newCombined = newSealedBox.combined else { continue }

                let newEncrypted = newCombined.base64EncodedString()
                db.updateSecureValue(id: value.id, encryptedValue: newEncrypted, keyVersion: newVersion)
                migrated += 1
            } catch {
                logError("SecureValueManager: 마이그레이션 실패 (\(value.id)) - \(error)")
            }
        }

        logInfo("SecureValueManager: \(migrated)개 마이그레이션 완료")
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
                        keyVersion: encrypted.keyVersion,
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
                        keyVersion: encrypted.keyVersion
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
        guard let encrypted = encrypt(newPlaintext) else {
            return false
        }

        db.updateSecureValue(id: refId, encryptedValue: encrypted.encrypted, keyVersion: encrypted.keyVersion)
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
}
