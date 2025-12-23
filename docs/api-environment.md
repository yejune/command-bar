# API 환경(Environment) 관리 기능

## 개요

Postman/RapidAPI/Paw처럼 API 호출 시 환경별 변수를 관리하고 자동 치환하는 기능.

## 사용 예시

### 환경 설정
```
환경 "개발" (Dev):
  - HOST_API: http://localhost:3000
  - HOST_FRONT: http://localhost:8080
  - token: dev-123-abc
  - apiKey: development-key

환경 "운영" (Production):
  - HOST_API: https://api.example.com
  - HOST_FRONT: https://www.example.com
  - token: prod-456-xyz
  - apiKey: production-key
```

### API 명령에서 사용
```
URL: {{HOST_API}}/users/{{userId}}
Headers:
  Authorization: Bearer {{token}}
  X-API-Key: {{apiKey}}
```

### 실행 결과
개발 환경 선택 시:
```
URL: http://localhost:3000/users/{{userId}}
Headers:
  Authorization: Bearer dev-123-abc
  X-API-Key: development-key
```

## 문법

| 문법 | 용도 | 치환 시점 |
|------|------|----------|
| `{{변수명}}` | 환경 변수 | 실행 전 자동 치환 |
| `{파라미터}` | 입력 파라미터 | 실행 시 사용자 입력 |
| `{파라미터:옵션1\|옵션2}` | 선택 파라미터 | 실행 시 드롭다운 선택 |

### 치환 순서
1. 환경 변수 `{{var}}` 먼저 치환
2. 입력 파라미터 `{param}` 치환
3. API 실행

## UI 설계

### 1. 환경 관리 화면 (Paw 방식 - 테이블 뷰)

변수 중심으로 환경별 값을 열로 비교:

```
+----------------------------------------------------------------+
| 환경 관리                    [+ 변수] [+ 환경]                   |
+----------------------------------------------------------------+
| Group    | Variable      | Dev           | Staging | Production |
+----------------------------------------------------------------+
| var      | HOST_API      | http://local  | http:// | https://   |
|          | HOST_FRONT    | http://local  | http:// | https://   |
|----------|---------------|---------------|---------|------------|
| header   | token         | dev-123       | stg-456 | prod-789   |
|          | apiKey        | abc           | def     | ghi        |
+----------------------------------------------------------------+
|                              [● Dev 활성]                       |
+----------------------------------------------------------------+
```

### 2. 환경 편집 (Postman 방식 - 개별 편집)

환경 선택 후 해당 환경의 변수만 편집:

```
+------------------------------------------+
| 환경 편집: 개발                           |
+------------------------------------------+
| 그룹: [▼ var]                            |
| 변수명: [HOST_API                      ] |
| 값:    [http://localhost:3000          ] |
|                              [+ 추가]    |
+------------------------------------------+
```

### 3. 환경 선택 (하단 바)

```
[📄 명령] [+] [📁] [📋] [🕐] [🗑] ... [🌐 환경] [▼ 개발] [⚙️]
```

## 데이터 구조

### APIEnvironment 모델
```swift
struct APIEnvironment: Identifiable, Codable {
    var id = UUID()
    var name: String              // "개발", "운영", "스테이징"
    var variables: [String: String]  // key-value 쌍
    var group: String?            // "var", "header" 등 (선택적)
    var order: Int                // 정렬 순서
}
```

### DB 테이블
```sql
CREATE TABLE environments (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    variables TEXT NOT NULL,  -- JSON 형태로 저장
    sort_order INTEGER DEFAULT 0
);

-- 활성 환경은 settings 테이블 활용
-- key: "activeEnvironmentId", value: UUID 문자열
```

## 구현 파일

| 파일 | 설명 |
|------|------|
| `Models/APIEnvironment.swift` | 환경 모델 |
| `Managers/Database.swift` | DB 테이블 + CRUD |
| `Managers/CommandStore.swift` | 환경 상태 관리 |
| `Models/Command.swift` | {{변수}} 치환 로직 |
| `Views/EnvironmentListView.swift` | 환경 목록 (Paw 방식) |
| `Views/EnvironmentEditSheet.swift` | 환경 편집 (Postman 방식) |
| `Views/ContentView.swift` | 환경 선택 UI |

## 참고

- [Postman Environments](https://learning.postman.com/docs/sending-requests/managing-environments/)
- [Paw Environments](https://paw.cloud/docs/environments)
- [RapidAPI Environments](https://docs.rapidapi.com/docs/environments)
