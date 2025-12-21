.PHONY: build release patch minor major

build:
	swift build -c release
	cp .build/release/CommandBar CommandBar.app/Contents/MacOS/CommandBar

# make release / make patch  - patch (default)
# make minor                 - minor
# make major                 - major

release patch:
	@$(MAKE) _release TYPE=patch

minor:
	@$(MAKE) _release TYPE=minor

major:
	@$(MAKE) _release TYPE=major

_release:
	@CURRENT=$$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"); \
	MAJOR=$$(echo $$CURRENT | sed 's/v//' | cut -d. -f1); \
	MINOR=$$(echo $$CURRENT | sed 's/v//' | cut -d. -f2); \
	PATCH=$$(echo $$CURRENT | sed 's/v//' | cut -d. -f3); \
	if [ "$(TYPE)" = "major" ]; then \
		MAJOR=$$((MAJOR + 1)); MINOR=0; PATCH=0; \
	elif [ "$(TYPE)" = "minor" ]; then \
		MINOR=$$((MINOR + 1)); PATCH=0; \
	else \
		PATCH=$$((PATCH + 1)); \
	fi; \
	NEW_VERSION="v$$MAJOR.$$MINOR.$$PATCH"; \
	echo "Releasing $$NEW_VERSION..."; \
	git tag $$NEW_VERSION && \
	git push origin $$NEW_VERSION && \
	git push origin main && \
	echo "Done! $$NEW_VERSION released."
