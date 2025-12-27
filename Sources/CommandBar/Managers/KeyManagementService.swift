import Foundation
import CryptoKit

/// 암호화 키 통합 관리 서비스
/// - 로컬: 파일 기반 키 (자동, 인증 불필요)
/// - 클라우드: 패스워드 기반 키 (동기화용)
class KeyManagementService {
    static let shared = KeyManagementService()

    private let localStore = LocalKeyStore.shared
    private let cloudStore = CloudKeyStore.shared

    private init() {}

    // MARK: - Local Encryption (자동)

    /// 로컬 데이터 암호화
    func encryptLocal(_ plaintext: String) -> String? {
        guard let key = localStore.getSymmetricKey(),
              let data = plaintext.data(using: .utf8) else {
            return nil
        }

        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined?.base64EncodedString()
        } catch {
            logError("KeyManagementService: 로컬 암호화 실패 - \(error)")
            return nil
        }
    }

    /// 로컬 데이터 복호화
    func decryptLocal(_ ciphertext: String) -> String? {
        guard let key = localStore.getSymmetricKey(),
              let data = Data(base64Encoded: ciphertext) else {
            return nil
        }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decrypted = try AES.GCM.open(sealedBox, using: key)
            return String(data: decrypted, encoding: .utf8)
        } catch {
            logError("KeyManagementService: 로컬 복호화 실패 - \(error)")
            return nil
        }
    }

    // MARK: - Cloud Encryption (패스워드 기반)

    /// 클라우드 키가 unlock 되었는지
    var isCloudUnlocked: Bool {
        cloudStore.isUnlocked
    }

    /// 클라우드 동기화가 설정되었는지
    var isCloudConfigured: Bool {
        cloudStore.isConfigured
    }

    /// 클라우드 동기화 활성화 (마스터 패스워드 설정)
    func enableCloudSync(masterPassword: String) -> Bool {
        return cloudStore.setupMasterPassword(masterPassword)
    }

    /// 클라우드 키 unlock (앱 시작 시)
    func unlockCloudKey(masterPassword: String) -> Bool {
        return cloudStore.unlock(password: masterPassword)
    }

    /// 클라우드 키 lock
    func lockCloudKey() {
        cloudStore.lock()
    }

    /// 클라우드 데이터 암호화
    func encryptForCloud(_ plaintext: String) -> String? {
        guard let key = cloudStore.getSymmetricKey(),
              let data = plaintext.data(using: .utf8) else {
            return nil
        }

        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined?.base64EncodedString()
        } catch {
            logError("KeyManagementService: 클라우드 암호화 실패 - \(error)")
            return nil
        }
    }

    /// 클라우드 데이터 복호화
    func decryptFromCloud(_ ciphertext: String) -> String? {
        guard let key = cloudStore.getSymmetricKey(),
              let data = Data(base64Encoded: ciphertext) else {
            return nil
        }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decrypted = try AES.GCM.open(sealedBox, using: key)
            return String(data: decrypted, encoding: .utf8)
        } catch {
            logError("KeyManagementService: 클라우드 복호화 실패 - \(error)")
            return nil
        }
    }

    // MARK: - Re-encryption (동기화용)

    /// 로컬 데이터를 클라우드용으로 재암호화
    func reencryptForCloud(_ localCiphertext: String) -> String? {
        guard let plaintext = decryptLocal(localCiphertext) else {
            return nil
        }
        return encryptForCloud(plaintext)
    }

    /// 클라우드 데이터를 로컬용으로 재암호화
    func reencryptForLocal(_ cloudCiphertext: String) -> String? {
        guard let plaintext = decryptFromCloud(cloudCiphertext) else {
            return nil
        }
        return encryptLocal(plaintext)
    }

    // MARK: - Migration

    /// Keychain에서 로컬 키로 마이그레이션
    func migrateFromKeychain(keychainKey: Data) -> Bool {
        return localStore.migrateFromKeychain(keychainKey: keychainKey)
    }

    // MARK: - Settings

    /// 마스터 패스워드 변경
    func changeCloudPassword(oldPassword: String, newPassword: String) -> Bool {
        return cloudStore.changePassword(oldPassword: oldPassword, newPassword: newPassword)
    }

    /// 클라우드 동기화 비활성화
    func disableCloudSync() {
        cloudStore.reset()
    }
}
