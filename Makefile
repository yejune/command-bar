.PHONY: build release

build:
	swift build -c release
	cp .build/release/CommandBar CommandBar.app/Contents/MacOS/CommandBar
	codesign --force --deep --sign - CommandBar.app
	cp -R CommandBar.app /Applications/

# make release         - patch (default)
# make release minor   - minor
# make release major   - major

release:
	@TYPE=$(word 2,$(MAKECMDGOALS)); \
	TYPE=$${TYPE:-patch}; \
	CURRENT=$$(grep -o 'v[0-9]*\.[0-9]*\.[0-9]*' tobrew.lock | head -1 | sed 's/v//'); \
	MAJOR=$$(echo $$CURRENT | cut -d. -f1); \
	MINOR=$$(echo $$CURRENT | cut -d. -f2); \
	PATCH=$$(echo $$CURRENT | cut -d. -f3); \
	if [ "$$TYPE" = "major" ]; then \
		MAJOR=$$((MAJOR + 1)); MINOR=0; PATCH=0; \
	elif [ "$$TYPE" = "minor" ]; then \
		MINOR=$$((MINOR + 1)); PATCH=0; \
	else \
		PATCH=$$((PATCH + 1)); \
	fi; \
	NEW_VERSION="$$MAJOR.$$MINOR.$$PATCH"; \
	echo "📦 Releasing v$$NEW_VERSION ($$TYPE)"; \
	echo "   Current: v$$CURRENT → New: v$$NEW_VERSION"; \
	sed -i '' "s/static let version = \".*\"/static let version = \"$$NEW_VERSION\"/" \
		Sources/CommandBar/Managers/UpdateManager.swift; \
	echo "✓ AppInfo.version updated"; \
	git add Sources/CommandBar/Managers/UpdateManager.swift && \
	git commit -m "chore: bump version to $$NEW_VERSION" && \
	git push origin main && \
	echo "✓ Version bump pushed"; \
	echo "Y" | tobrew release $$TYPE && \
	git add tobrew.lock command-bar.rb && \
	git commit -m "chore: tobrew.lock v$$NEW_VERSION" && \
	git push origin main && \
	echo "✅ v$$NEW_VERSION released!"

%:
	@:
