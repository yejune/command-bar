import Foundation
import CryptoKit

/// 로컬 파일 기반 키 저장소
/// - Keychain 대신 파일 시스템에 암호화 키 저장
/// - 즉시 접근 가능 (인증 불필요)
class LocalKeyStore {
    static let shared = LocalKeyStore()

    private let keyFileName = ".local_key"
    private var cachedKey: Data?
    private let keySize = 32  // 256 bits

    private var keyFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appDir = appSupport.appendingPathComponent("CommandBar")

        // 디렉토리 생성
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        return appDir.appendingPathComponent(keyFileName)
    }

    private init() {
        loadOrCreateKey()
    }

    // MARK: - Public API

    /// 키 반환 (캐시에서 즉시)
    func getKey() -> Data? {
        return cachedKey
    }

    /// SymmetricKey로 반환
    func getSymmetricKey() -> SymmetricKey? {
        guard let keyData = cachedKey else { return nil }
        return SymmetricKey(data: keyData)
    }

    /// 키 파일 경로
    var keyPath: String {
        keyFileURL.path
    }

    /// 키 존재 여부
    var hasKey: Bool {
        cachedKey != nil
    }

    // MARK: - Key Management

    /// 키 로드 또는 생성
    private func loadOrCreateKey() {
        if FileManager.default.fileExists(atPath: keyFileURL.path) {
            loadKey()
        } else {
            generateAndSaveKey()
        }
    }

    /// 파일에서 키 로드
    private func loadKey() {
        do {
            let keyData = try Data(contentsOf: keyFileURL)
            if keyData.count == keySize {
                cachedKey = keyData
                logInfo("LocalKeyStore: 키 로드 완료")
            } else {
                logError("LocalKeyStore: 키 크기 불일치 (\(keyData.count) != \(keySize))")
                generateAndSaveKey()
            }
        } catch {
            logError("LocalKeyStore: 키 로드 실패 - \(error)")
            generateAndSaveKey()
        }
    }

    /// 새 키 생성 및 저장
    private func generateAndSaveKey() {
        var keyData = Data(count: keySize)
        let result = keyData.withUnsafeMutableBytes { ptr in
            SecRandomCopyBytes(kSecRandomDefault, keySize, ptr.baseAddress!)
        }

        guard result == errSecSuccess else {
            logError("LocalKeyStore: 랜덤 키 생성 실패")
            return
        }

        cachedKey = keyData
        saveKey()
        logInfo("LocalKeyStore: 새 키 생성 완료")
    }

    /// 키 파일에 저장
    private func saveKey() {
        guard let keyData = cachedKey else { return }

        do {
            // 원자적 쓰기
            try keyData.write(to: keyFileURL, options: [.atomic])

            // POSIX 권한 설정 (소유자만 읽기/쓰기)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: keyFileURL.path
            )

            logInfo("LocalKeyStore: 키 저장 완료 (\(keyFileURL.path))")
        } catch {
            logError("LocalKeyStore: 키 저장 실패 - \(error)")
        }
    }

    // MARK: - Migration

    /// Keychain에서 키 마이그레이션
    func migrateFromKeychain(keychainKey: Data) -> Bool {
        guard keychainKey.count == keySize else {
            logError("LocalKeyStore: 마이그레이션 실패 - 키 크기 불일치")
            return false
        }

        cachedKey = keychainKey
        saveKey()
        logInfo("LocalKeyStore: Keychain에서 마이그레이션 완료")
        return true
    }

    /// 키 재생성 (기존 데이터 복호화 불가 주의)
    func regenerateKey() {
        generateAndSaveKey()
    }

    /// 키 삭제
    func deleteKey() {
        try? FileManager.default.removeItem(at: keyFileURL)
        cachedKey = nil
        logInfo("LocalKeyStore: 키 삭제 완료")
    }
}
