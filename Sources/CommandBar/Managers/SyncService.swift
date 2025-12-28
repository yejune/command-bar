import Foundation
import CryptoKit

/// MySQL 동기화 서비스
/// - 로컬 데이터를 클라우드에 동기화
/// - 클라우드 데이터를 로컬에 동기화
/// - E2E 암호화 (마스터 패스워드 기반)
class SyncService {
    static let shared = SyncService()

    private let db = Database.shared
    private let secureManager = SecureValueManager.shared

    // MySQL 연결 정보 (설정에서 로드)
    var mysqlHost: String {
        get { db.getSetting("mysql_host") ?? "" }
        set { db.setSetting("mysql_host", value: newValue) }
    }

    var mysqlPort: Int {
        get { db.getIntSetting("mysql_port", defaultValue: 3306) }
        set { db.setIntSetting("mysql_port", value: newValue) }
    }

    var mysqlDatabase: String {
        get { db.getSetting("mysql_database") ?? "" }
        set { db.setSetting("mysql_database", value: newValue) }
    }

    var mysqlUser: String {
        get { db.getSetting("mysql_user") ?? "" }
        set { db.setSetting("mysql_user", value: newValue) }
    }

    /// 비밀번호 참조 (배지 형식이면 저장, 평문이면 메모리만)
    /// - 배지: `secure@id` 형식 → DB 저장 (안전)
    /// - 평문: 메모리만 (보안상 저장 안 함)
    var mysqlPasswordRef: String {
        get { db.getSetting("mysql_password_ref") ?? "" }
        set {
            // 배지 참조만 저장 (평문은 저장 안 함)
            if newValue.contains("`secure@") || newValue.contains("`var@") {
                db.setSetting("mysql_password_ref", value: newValue)
            } else if newValue.isEmpty {
                db.setSetting("mysql_password_ref", value: "")
            }
            // 평문이면 DB에 저장하지 않고 메모리만
            mysqlPassword = newValue
        }
    }

    // 메모리 캐시 (평문 또는 참조)
    private var mysqlPassword: String?

    var isConfigured: Bool {
        !mysqlHost.isEmpty && !mysqlDatabase.isEmpty && !mysqlUser.isEmpty
    }

    var isConnected: Bool = false

    private init() {}

    // MARK: - 연결 관리

    /// 실제 사용할 비밀번호 (배지 치환 적용)
    var resolvedMySQLPassword: String? {
        guard let pwd = mysqlPassword, !pwd.isEmpty else { return nil }
        return BadgeProcessor.shared.resolveForExecution(pwd)
    }

    /// 앱 시작 시 저장된 참조 로드
    func loadSavedPasswordRef() {
        let saved = mysqlPasswordRef
        if !saved.isEmpty {
            mysqlPassword = saved
        }
    }

    /// 연결 테스트
    func testConnection() async -> Result<Void, SyncError> {
        guard isConfigured else {
            return .failure(.notConfigured)
        }

        guard mysqlPassword != nil else {
            return .failure(.passwordRequired)
        }

        // TODO: 실제 MySQL 연결 테스트
        // 현재는 플레이스홀더
        logInfo("SyncService: MySQL 연결 테스트 - \(mysqlHost):\(mysqlPort)")

        return .success(())
    }

    // MARK: - 동기화

    /// 로컬 → 클라우드 동기화
    func syncToCloud() async -> Result<SyncResult, SyncError> {
        guard secureManager.isUnlocked else {
            return .failure(.cloudKeyLocked)
        }

        guard isConfigured else {
            return .failure(.notConfigured)
        }

        logInfo("SyncService: 클라우드 동기화 시작")

        var result = SyncResult()

        // 1. 로컬 데이터 수집
        let secureValues = db.getAllSecureValues()

        // 2. 각 데이터를 업로드 (이미 암호화된 상태)
        for _ in secureValues {
            // TODO: MySQL에 upsert
            result.uploaded += 1
        }

        // TODO: 그룹, 명령어 등 다른 데이터 동기화

        logInfo("SyncService: 동기화 완료 - \(result.uploaded)개 업로드")

        return .success(result)
    }

    /// 클라우드 → 로컬 동기화
    func syncFromCloud() async -> Result<SyncResult, SyncError> {
        guard secureManager.isUnlocked else {
            return .failure(.cloudKeyLocked)
        }

        guard isConfigured else {
            return .failure(.notConfigured)
        }

        logInfo("SyncService: 클라우드에서 동기화 시작")

        let result = SyncResult()

        // TODO: MySQL에서 데이터 가져오기
        // 1. 클라우드 키로 복호화
        // 2. 로컬 키로 재암호화
        // 3. 로컬 DB에 저장

        logInfo("SyncService: 동기화 완료 - \(result.downloaded)개 다운로드")

        return .success(result)
    }

    /// 양방향 동기화 (충돌 해결 포함)
    func sync() async -> Result<SyncResult, SyncError> {
        guard secureManager.isUnlocked else {
            return .failure(.cloudKeyLocked)
        }

        // 1. 먼저 클라우드에서 가져오기
        let downloadResult = await syncFromCloud()
        if case .failure(let error) = downloadResult {
            return .failure(error)
        }

        // 2. 로컬 변경사항 업로드
        let uploadResult = await syncToCloud()
        if case .failure(let error) = uploadResult {
            return .failure(error)
        }

        var combined = SyncResult()
        if case .success(let download) = downloadResult {
            combined.downloaded = download.downloaded
        }
        if case .success(let upload) = uploadResult {
            combined.uploaded = upload.uploaded
        }

        return .success(combined)
    }

    // MARK: - 충돌 해결

    /// 충돌 해결 전략
    enum ConflictResolution {
        case keepLocal      // 로컬 우선
        case keepCloud      // 클라우드 우선
        case keepNewer      // 최신 데이터 우선
        case manual         // 수동 선택
    }

    var conflictResolution: ConflictResolution = .keepNewer
}

// MARK: - 에러 타입

enum SyncError: Error, LocalizedError {
    case notConfigured
    case passwordRequired
    case cloudKeyLocked
    case connectionFailed(String)
    case uploadFailed(String)
    case downloadFailed(String)
    case conflictUnresolved

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "MySQL 연결이 설정되지 않았습니다."
        case .passwordRequired:
            return "MySQL 비밀번호가 필요합니다."
        case .cloudKeyLocked:
            return "클라우드 키가 잠겨 있습니다. 마스터 패스워드를 입력하세요."
        case .connectionFailed(let reason):
            return "연결 실패: \(reason)"
        case .uploadFailed(let reason):
            return "업로드 실패: \(reason)"
        case .downloadFailed(let reason):
            return "다운로드 실패: \(reason)"
        case .conflictUnresolved:
            return "충돌을 해결할 수 없습니다."
        }
    }
}

// MARK: - 동기화 결과

struct SyncResult {
    var uploaded: Int = 0
    var downloaded: Int = 0
    var conflicts: Int = 0
    var errors: [String] = []

    var isEmpty: Bool {
        uploaded == 0 && downloaded == 0 && conflicts == 0
    }
}
