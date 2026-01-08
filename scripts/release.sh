#!/bin/bash
# 릴리즈 자동화 스크립트
# 사용법: ./scripts/release.sh [patch|minor|major]

set -e

TYPE=${1:-patch}

# 현재 버전 읽기
CURRENT=$(grep -o 'v[0-9]*\.[0-9]*\.[0-9]*' tobrew.lock | head -1 | sed 's/v//')
MAJOR=$(echo $CURRENT | cut -d. -f1)
MINOR=$(echo $CURRENT | cut -d. -f2)
PATCH=$(echo $CURRENT | cut -d. -f3)

# 새 버전 계산
if [ "$TYPE" = "major" ]; then
    MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0
elif [ "$TYPE" = "minor" ]; then
    MINOR=$((MINOR + 1)); PATCH=0
else
    PATCH=$((PATCH + 1))
fi

NEW_VERSION="$MAJOR.$MINOR.$PATCH"

echo "📦 Releasing v$NEW_VERSION ($TYPE)"
echo "   Current: v$CURRENT"
echo "   New:     v$NEW_VERSION"
echo ""

# 1. AppInfo.version 업데이트
sed -i '' "s/static let version = \".*\"/static let version = \"$NEW_VERSION\"/" \
    Sources/CommandBar/Managers/UpdateManager.swift

echo "✓ AppInfo.version updated to $NEW_VERSION"

# 2. 커밋
git add Sources/CommandBar/Managers/UpdateManager.swift
git commit -m "chore: bump version to $NEW_VERSION"
echo "✓ Version bump committed"

# 3. 푸시
git push origin main
echo "✓ Pushed to origin"

# 4. tobrew release
echo "Y" | tobrew release $TYPE
echo "✓ Released v$NEW_VERSION"

# 5. tobrew.lock 푸시
git add tobrew.lock command-bar.rb
git commit -m "chore: tobrew.lock v$NEW_VERSION"
git push origin main
echo "✓ tobrew.lock pushed"

echo ""
echo "✅ Release v$NEW_VERSION complete!"
