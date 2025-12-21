# CommandBar

macOS용 명령어 런처 및 일정 알림 앱

## 설치

```bash
# 빌드
swiftc -parse-as-library -framework Cocoa -framework SwiftUI -framework UserNotifications \
  -o CommandBar.app/Contents/MacOS/CommandBar Sources/CommandBar/main.swift

# Applications 폴더에 설치
cp -r CommandBar.app /Applications/
```

## 기능

### 1. 터미널 명령 실행
- iTerm2 또는 Terminal에서 명령 실행
- 더블클릭 또는 우클릭 메뉴로 실행

### 2. 백그라운드 명령 실행
- 터미널 없이 백그라운드에서 명령 실행
- 결과가 리스트에 표시됨
- 주기 설정으로 자동 반복 실행 (예: 5초마다 `date` 실행)

### 3. 스크립트 실행
- 파라미터 지원: `{파라미터명}` 형식으로 입력
- 실행 시 파라미터 값 입력 받음
- 결과를 모달로 표시

```bash
# 예시
echo "Hello {name}"           # name 입력 받음
curl -X {method} {url}        # method, url 입력 받음
git commit -m "{message}"     # message 입력 받음
```

### 4. 일정 알림
- 날짜/시간 설정으로 알림 예약
- 남은 시간 실시간 표시 (1일, 2시간, 30초...)
- 미리 알림: 1시간 전, 30분 전, 10분 전, 5분 전, 1분 전
- 시간이 되면 부르르 효과로 알림
- 클릭하면 확인 (체크 표시)
- 확인 안 하면 5분 후 "지남" 표시

### 5. 히스토리
- 모든 실행 기록 저장 (최대 100개)
- 기록 유형: 실행, 백그라운드, 스크립트, 일정 알림, 미리 알림, 등록, 삭제, 복원, 제거
- 출력 결과 클릭하여 확인 가능

## 사용법

### 명령 추가
1. `+` 버튼 클릭
2. 제목 입력
3. 실행 방식 선택:
   - **터미널**: iTerm2 / Terminal 선택
   - **백그라운드**: 주기 입력 (0이면 수동)
   - **스크립트**: 파라미터 `{name}` 형식 지원
   - **일정**: 날짜/시간, 미리 알림 선택

### 명령 실행
- 더블클릭
- 우클릭 → 실행

### 명령 수정/삭제
- 우클릭 → 수정/삭제

### 순서 변경
- 드래그 앤 드롭

### 하단 버튼
- 📄 명령 목록
- ➕ 명령 추가
- 🕐 히스토리
- 🗑 휴지통
- ⚙️ 설정

### 설정
- 항상 위에 표시
- 설정 내보내기/가져오기 (JSON)

## 단축키

- `↑/↓`: 항목 선택
- `Enter`: 선택한 항목 실행
- `Delete`: 선택한 항목 삭제

## 백그라운드 명령 예시

| 명령 | 설명 | 주기 |
|------|------|------|
| `date +%H:%M:%S` | 현재 시간 | 1초 |
| `uptime` | 시스템 가동 시간 | 60초 |
| `df -h \| head -2` | 디스크 사용량 | 300초 |
| `curl -s wttr.in/Seoul?format=3` | 서울 날씨 | 3600초 |

## 요구사항

- macOS 14.0+
- Swift 5.9+
