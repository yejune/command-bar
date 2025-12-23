# CommandBar

[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

macOS용 명령어 런처, 클립보드 관리자, 일정 알림 앱

[English](README.md)

## 설치

### 다운로드 (권장)
1. [Releases](https://github.com/yejune/command-bar/releases)에서 DMG 다운로드
2. DMG 열고 CommandBar를 Applications로 드래그
3. 첫 실행: 우클릭 → 열기 (Gatekeeper 우회)

### 소스에서 빌드
```bash
make build
```

## 기능

### 명령 실행 방식

| 타입 | 설명 |
|------|------|
| **터미널** | iTerm2 또는 Terminal에서 실행, 출력 히스토리 저장 |
| **백그라운드** | 터미널 없이 자동 반복 실행 (10분, 1시간, 6시간, 12시간, 24시간, 7일) |
| **스크립트** | 파라미터 지원, 리사이즈 가능한 결과 창 |
| **일정** | 날짜/시간 알림, 반복 (매일/매주/매월), 미리 알림 |
| **API** | REST API 테스트 (모든 HTTP 메서드) |

### 스크립트 파라미터
```bash
echo "Hello {name}"                      # 텍스트 입력
curl -X {method:GET|POST|PUT} {url}      # 드롭다운 + 텍스트 입력
git checkout {branch:main|develop}       # 드롭다운 선택
```
- 쉘 특수문자 자동 이스케이프 (`"`, `$`, `` ` ``, `\`)
- 스마트 따옴표 자동 변환

### 일정 알림
- 남은 시간 실시간 표시 (1일, 2시간, 30초...)
- 미리 알림: 1시간 전, 30분 전, 10분 전, 5분 전, 1분 전
- 시간 되면 부르르 효과
- 일회성: 체크 표시 / 반복: 다음 알림으로 자동 리셋

### API 요청
- HTTP 메서드: GET, POST, PUT, DELETE, PATCH
- 헤더, 쿼리 파라미터, 바디 설정
- 파라미터 지원: URL, 헤더, 바디에 `{변수명}` 사용
- 바디 타입: JSON, Form Data, Multipart (파일 업로드)
- 응답 히스토리 저장

### 데이터 관리

| 기능 | 설명 |
|------|------|
| **히스토리** | 실행 기록 텍스트/날짜 검색 (최대 100개) |
| **클립보드** | 클립보드 모니터링 및 검색 (최대 10,000개), Apple 메모로 보내기 |
| **그룹** | 색상별 명령어 정리, 드래그 앤 드롭 순서 변경 |
| **즐겨찾기** | 별 아이콘 토글, 그룹과 조합 필터 |
| **휴지통** | 삭제 항목 복구 가능 |

### 창 기능
- 항상 위에 표시 옵션
- 배경 투명도 조절
- 포커스 잃으면 자동 숨기기 (투명도 설정 가능)
- 창 위치/크기 기억

### 다국어
- 한국어, 영어, 일본어
- 커스텀 언어팩 내보내기/가져오기

## 사용법

### 명령 추가
1. `+` 버튼 클릭
2. 제목 입력
3. 실행 방식 선택 및 설정
4. 저장

### 명령 실행
- 더블클릭
- 우클릭 → 실행

### 수정/삭제
- 우클릭 → 수정/삭제

### 순서 변경
- 드래그 앤 드롭

### 하단 바
📄 명령 목록 | ➕ 추가 | 📁 그룹 | 📋 클립보드 | 🕐 히스토리 | 🗑 휴지통 | ⚙️ 설정

## 단축키

| 키 | 동작 |
|----|------|
| `↑/↓` | 항목 이동 |
| `Enter` | 선택 항목 실행 |
| `Delete` | 선택 항목 삭제 |

## 예시

### 백그라운드 명령
| 명령 | 설명 | 주기 |
|------|------|------|
| `date +%H:%M:%S` | 현재 시간 | 1초 |
| `uptime` | 시스템 가동 시간 | 60초 |
| `df -h \| head -2` | 디스크 사용량 | 300초 |
| `curl -s "wttr.in/Seoul?format=3"` | 서울 날씨 | 3600초 |

### API 요청

**파라미터 포함 GET:**
```
URL: https://api.example.com/users/{userId}
→ 실행 시 userId 입력 프롬프트
```

**JSON 바디 POST:**
```
URL: https://api.example.com/users
헤더: Content-Type: application/json
바디: {"name": "{userName}", "email": "{userEmail}"}
→ 실행 시 userName, userEmail 입력
```

**Multipart 파일 업로드:**
```
URL: https://api.example.com/upload
바디 타입: Multipart
텍스트: description: 내 파일
파일: file: /path/to/image.png
→ MIME 타입 자동 감지
```

## 데이터 저장

모든 데이터는 SQLite 데이터베이스에 저장:
```
~/.command_bar/command_bar.db
```

## 요구사항

- macOS 14.0+
- Swift 5.9+

## 라이선스

MIT
