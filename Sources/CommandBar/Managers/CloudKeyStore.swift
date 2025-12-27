import Foundation
import CryptoKit
import CommonCrypto

/// 클라우드 동기화용 패스워드 기반 키 저장소
/// - PBKDF2로 마스터 패스워드에서 키 파생
/// - 키는 세션 중 메모리에만 유지 (앱 종료 시 소멸)
/// - Salt와 Verifier만 DB에 저장 (키 자체는 저장 안 함)
class CloudKeyStore {
    static let shared = CloudKeyStore()

    private let db = Database.shared
    private var cachedKey: Data?  // 세션 중 메모리만
    private let keySize = 32  // 256 bits
    private let iterations: UInt32 = 100_000  // PBKDF2 반복 횟수

    private init() {}

    // MARK: - Public API

    /// 클라우드 키 반환 (unlock 필요)
    func getKey() -> Data? {
        return cachedKey
    }

    /// SymmetricKey로 반환
    func getSymmetricKey() -> SymmetricKey? {
        guard let keyData = cachedKey else { return nil }
        return SymmetricKey(data: keyData)
    }

    /// 키가 unlock 되었는지
    var isUnlocked: Bool {
        cachedKey != nil
    }

    /// 클라우드 동기화가 설정되었는지
    var isConfigured: Bool {
        db.getSetting("cloud_key_salt") != nil
    }

    // MARK: - Setup & Unlock

    /// 마스터 패스워드 설정 (최초 1회)
    /// - Returns: 성공 여부
    func setupMasterPassword(_ password: String) -> Bool {
        guard !password.isEmpty else {
            logError("CloudKeyStore: 빈 패스워드")
            return false
        }

        // Salt 생성
        var salt = Data(count: 16)
        let result = salt.withUnsafeMutableBytes { ptr in
            SecRandomCopyBytes(kSecRandomDefault, 16, ptr.baseAddress!)
        }
        guard result == errSecSuccess else {
            logError("CloudKeyStore: Salt 생성 실패")
            return false
        }

        // 키 파생
        guard let derivedKey = deriveKey(password: password, salt: salt) else {
            logError("CloudKeyStore: 키 파생 실패")
            return false
        }

        // Verifier 생성 (SHA256 해시)
        let verifier = SHA256.hash(data: derivedKey)
        let verifierData = Data(verifier)

        // DB에 저장
        db.setSetting("cloud_key_salt", value: salt.base64EncodedString())
        db.setSetting("cloud_key_verifier", value: verifierData.base64EncodedString())
        db.setBoolSetting("cloud_sync_enabled", value: true)

        // 메모리에 캐시
        cachedKey = derivedKey

        logInfo("CloudKeyStore: 마스터 패스워드 설정 완료")
        return true
    }

    /// 마스터 패스워드로 unlock
    /// - Returns: 성공 여부
    func unlock(password: String) -> Bool {
        guard let saltStr = db.getSetting("cloud_key_salt"),
              let salt = Data(base64Encoded: saltStr),
              let verifierStr = db.getSetting("cloud_key_verifier"),
              let storedVerifier = Data(base64Encoded: verifierStr) else {
            logError("CloudKeyStore: 설정되지 않음")
            return false
        }

        // 키 파생
        guard let derivedKey = deriveKey(password: password, salt: salt) else {
            logError("CloudKeyStore: 키 파생 실패")
            return false
        }

        // Verifier 검증
        let verifier = Data(SHA256.hash(data: derivedKey))
        guard verifier == storedVerifier else {
            logError("CloudKeyStore: 패스워드 불일치")
            return false
        }

        // 메모리에 캐시
        cachedKey = derivedKey

        logInfo("CloudKeyStore: Unlock 성공")
        return true
    }

    /// Lock (키 메모리에서 제거)
    func lock() {
        cachedKey = nil
        logInfo("CloudKeyStore: Locked")
    }

    /// 패스워드 변경
    func changePassword(oldPassword: String, newPassword: String) -> Bool {
        // 기존 패스워드 검증
        guard unlock(password: oldPassword) else {
            return false
        }

        // 새 패스워드로 재설정
        lock()
        return setupMasterPassword(newPassword)
    }

    /// 클라우드 설정 초기화
    func reset() {
        db.deleteSetting("cloud_key_salt")
        db.deleteSetting("cloud_key_verifier")
        db.setBoolSetting("cloud_sync_enabled", value: false)
        cachedKey = nil
        logInfo("CloudKeyStore: 초기화 완료")
    }

    // MARK: - Key Derivation

    /// PBKDF2로 키 파생
    private func deriveKey(password: String, salt: Data) -> Data? {
        guard let passwordData = password.data(using: .utf8) else {
            return nil
        }

        var derivedKey = Data(count: keySize)

        let status = derivedKey.withUnsafeMutableBytes { keyPtr in
            passwordData.withUnsafeBytes { pwPtr in
                salt.withUnsafeBytes { saltPtr in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        pwPtr.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        iterations,
                        keyPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keySize
                    )
                }
            }
        }

        return status == kCCSuccess ? derivedKey : nil
    }
}
