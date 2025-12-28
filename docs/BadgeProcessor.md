# Badge System Documentation

## Overview

배지 시스템은 민감한 정보(secure), 변수(var), 명령어 참조(command)를 안전하게 관리하고 표시하는 통합 시스템입니다.

## Badge Types

| Type | Prefix | Color | 용도 |
|------|--------|-------|------|
| secure | `secure` | Pink | 암호화된 민감한 값 (비밀번호, API 키 등) |
| command | `command` | Blue | 다른 명령어 참조/체이닝 |
| variable | `var` | Green | 재사용 가능한 변수 |

## Data Flow

```
[입력] → [저장] → [표시] → [실행]

입력: {type#label:value} 또는 {type#label} 또는 {type:value}
저장: `type@id` (6자리 고유 ID)
표시: BadgeTextAttachment (라벨 또는 ID 표시)
실행: 실제 값으로 치환
```

## Input Patterns

### 새로 생성 (값 포함)
```
{secure#비밀번호:mySecret123}  → 암호화 후 `secure@abc123`
[secure#비밀번호:mySecret123]  → 동일
{var#서버주소:https://api.com}  → 저장 후 `var@def456`
```

### 기존 참조 (라벨로)
```
{secure#비밀번호}  → 기존 라벨 조회 → `secure@abc123`
{command#API호출}  → 기존 라벨 조회 → `command@ghi789`
{var#서버주소}     → 기존 라벨 조회 → `var@def456`
```

### 직접 ID 참조
```
{secure@abc123}  → `secure@abc123`
{command@ghi789} → `command@ghi789`
```

### 값만 (라벨 없이)
```
{secure:mySecret}  → 암호화 후 `secure@xyz999` (라벨 없음)
```

## Trigger Syntax (자동완성)

| 트리거 | 의미 | 자동완성 내용 |
|--------|------|--------------|
| `{type:` | 입력 모드 | 라벨 목록 |
| `{type#` | 라벨 힌팅 | 라벨 목록 |
| `{type@` | ID 힌팅 | ID 목록 |
| `[type:` | 입력 모드 (대괄호) | 라벨 목록 |
| `[type#` | 라벨 힌팅 (대괄호) | 라벨 목록 |
| `[type@` | ID 힌팅 (대괄호) | ID 목록 |

## Core Classes

### BadgeProcessor (통합 처리)

```swift
class BadgeProcessor {
    static let shared = BadgeProcessor()

    // 저장 전 변환: {type#label:value} → `type@id`
    func convertToStorageFormat(_ text: String) -> BadgeProcessResult

    // 실행 전 변환: `type@id` → 실제 값
    func resolveForExecution(_ text: String) -> String

    // 표시용 변환: `type@id` → BadgeTextAttachment
    func convertToBadges(in attrString: NSMutableAttributedString)

    // 자동완성 제안
    func getSuggestions(for type: BadgeType, isIdHint: Bool, filter: String) -> [String]
}
```

### BadgeTextAttachment (UI 표시)

```swift
class BadgeTextAttachment: NSTextAttachment {
    let badgeType: BadgeType
    let refId: String
    let labelText: String?
    let originalText: String  // 저장 형식: `type@id`
    let jsonPath: String?     // command 전용
}
```

### BadgeType (타입 정의)

```swift
enum BadgeType: String {
    case secure = "secure"
    case command = "command"
    case variable = "var"
}
```

## Storage Format

모든 배지는 `\`type@id\`` 형식으로 저장됩니다:
- `\`secure@abc123\`` - 암호화된 값 참조
- `\`command@def456\`` - 명령어 참조
- `\`var@ghi789\`` - 변수 참조
- `\`command@abc123|data.token\`` - JSON path 포함 (command 전용)

## Database Tables

### secure_values
```sql
CREATE TABLE secure_values (
    id TEXT PRIMARY KEY,
    encrypted_value TEXT NOT NULL,
    key_version INTEGER DEFAULT 1,
    label TEXT,
    created_at TEXT
);
```

### variables
```sql
CREATE TABLE variables (
    id TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    label TEXT,
    created_at TEXT,
    updated_at TEXT
);
```

### commands (label 컬럼 사용)
```sql
-- commands 테이블의 label 컬럼으로 참조
```

## Usage Examples

### 저장 시
```swift
let result = BadgeProcessor.shared.convertToStorageFormat(inputText)
if result.hasError {
    // 에러 처리
} else {
    // result.text 저장
}
```

### 실행 시
```swift
let resolved = BadgeProcessor.shared.resolveForExecution(storedText)
// resolved에는 실제 값이 치환됨
```

### 표시 시
```swift
let attrString = NSMutableAttributedString(string: storedText)
BadgeProcessor.shared.convertToBadges(in: attrString)
// attrString에 배지가 포함됨
```

## Maintenance Guide

### 새 배지 타입 추가 시

1. `BadgeType` enum에 케이스 추가
2. Database에 관련 테이블/메서드 추가
3. `BadgeProcessor`에서 처리 로직 추가:
   - `processXxxPatterns()` 메서드 추가
   - `convertToStorageFormat()`에서 호출
   - `resolveValue()`에 케이스 추가
   - `getSuggestions()`에 케이스 추가

### 입력 패턴 추가 시

1. 정규식 패턴 정의
2. `convertToStorageFormat()` 또는 해당 `processXxxPatterns()`에 추가
3. `AutocompleteTextEditor`의 트리거에 추가

### 테스트 항목

1. 저장 → 표시 → 실행 전체 플로우
2. 라벨 중복 에러
3. 없는 라벨 참조 에러
4. 여러 타입 혼합 사용
5. JSON path 추출 (command)

## File Structure

```
Sources/CommandBar/
├── Managers/
│   ├── BadgeProcessor.swift      # 통합 처리 (핵심)
│   ├── SecureValueManager.swift  # 암호화 전담
│   └── Database.swift            # 저장소
├── Components/
│   ├── BadgeTextAttachment.swift # UI 배지
│   └── AutocompleteTextEditor.swift # 자동완성
└── Models/
    └── Command.swift             # 명령어 모델
```

## 새 필드에 배지 시스템 적용하기

새로운 텍스트 필드에서 배지 시스템을 사용하려면 **표시**, **입력**, **저장** 세 가지를 구현합니다.

### 1. 표시 (Display)

저장된 `\`type@id\`` 형식을 배지로 표시합니다.

**방법 A: AutocompleteTextEditor 사용 (권장)**
```swift
// SwiftUI View에서
AutocompleteTextEditor(
    text: $myText,
    suggestions: envVars,           // $ 자동완성용 환경변수 목록
    idSuggestions: commandList      // {command: 자동완성용
)
```

**방법 B: 수동 변환**
```swift
// NSMutableAttributedString에 배지 적용
let attrString = NSMutableAttributedString(string: storedText)
BadgeProcessor.shared.convertToBadges(in: attrString)
textView.textStorage?.setAttributedString(attrString)
```

**방법 C: 읽기 전용 표시 (문자열)**
```swift
// `type@id` → [label] 형식으로 변환
let displayText = BadgeTextAttachment.convertToDisplayString(storedText)
// 예: `secure@abc123` → [비밀번호]
```

### 2. 입력 (Input)

사용자가 배지를 입력할 수 있게 합니다.

**방법 A: AutocompleteTextEditor 사용 (권장)**
- `{type:`, `{type#`, `{type@` 입력 시 자동완성 팝업 표시
- 자동으로 트리거 감지 및 제안 목록 표시

**방법 B: 수동 트리거 감지**
```swift
// 커서 위치에서 트리거 감지
if let triggerInfo = BadgeProcessor.shared.detectBadgeTrigger(
    in: text,
    cursorPosition: cursorPos
) {
    // triggerInfo.type: BadgeType
    // triggerInfo.filter: 필터 텍스트
    // triggerInfo.isIdHint: @ 트리거 여부

    // 제안 목록 조회
    let suggestions = BadgeProcessor.shared.getSuggestions(
        for: triggerInfo.type,
        isIdHint: triggerInfo.isIdHint,
        filter: triggerInfo.filter
    )

    // 선택 시 대체 텍스트 생성
    let replacement = BadgeProcessor.shared.buildReplacement(
        for: triggerInfo,
        suggestion: selectedSuggestion,
        commandId: nil  // command 타입일 경우 ID 전달
    )
}
```

### 3. 저장 (Save)

입력된 텍스트를 저장 형식으로 변환합니다.

```swift
// 저장 전 변환
let result = BadgeProcessor.shared.convertToStorageFormat(inputText)

if let error = result.error {
    // 에러 표시 (예: 중복 라벨, 없는 참조)
    showError(error, at: result.errorRange)
} else {
    // result.text를 DB에 저장
    database.save(result.text)
}
```

**변환 예시:**
```
입력: {secure#API키:sk-12345}
저장: `secure@abc123`

입력: {var#서버주소}
저장: `var@def456`

입력: {command#데이터조회}
저장: `command@ghi789`
```

### 4. 실행 (Execute)

저장된 텍스트를 실행 시 실제 값으로 치환합니다.

```swift
// 실행 전 값 치환
let resolvedText = BadgeProcessor.shared.resolveForExecution(storedText)
// `secure@abc123` → 실제 비밀번호
// `var@def456` → 실제 변수 값
// `command@ghi789` → 마지막 실행 결과
```

### 전체 적용 예시

```swift
struct MyTextFieldView: View {
    @State var text: String = ""  // 저장 형식 (`type@id`)

    var body: some View {
        VStack {
            // 1. 표시 + 입력
            AutocompleteTextEditor(
                text: $text,
                suggestions: getEnvVars(),
                idSuggestions: getCommands()
            )

            Button("저장") {
                // 2. 저장 (이미 자동 변환됨)
                // AutocompleteTextEditor가 입력 시 `type@id`로 유지
                database.save(text)
            }

            Button("실행") {
                // 3. 실행
                let resolved = BadgeProcessor.shared.resolveForExecution(text)
                execute(resolved)
            }
        }
    }
}
```

### 체크리스트

새 필드 적용 시 확인사항:

- [ ] **표시**: 저장된 텍스트가 배지로 보이는가?
- [ ] **입력**: `{type:` 입력 시 자동완성이 동작하는가?
- [ ] **저장**: 저장 시 `\`type@id\`` 형식으로 변환되는가?
- [ ] **실행**: 실행 시 실제 값으로 치환되는가?
- [ ] **편집**: 배지 더블클릭 시 편집 가능한가? (필요시)
- [ ] **복사/붙여넣기**: 배지가 올바르게 처리되는가?

## Migration Notes

기존 분산된 로직을 `BadgeProcessor`로 통합:
- `SecureValueManager.processForSave` → `BadgeProcessor.convertToStorageFormat`
- `SecureValueManager.processForExecution` → `BadgeProcessor.resolveForExecution`
- `BadgeUtils.convertToBadges` → `BadgeProcessor.convertToBadges`
- `CommandStore.processIdVarLabels` → `BadgeProcessor.convertToStorageFormat`
