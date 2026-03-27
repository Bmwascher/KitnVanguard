---
name: release-workflow
description: >
  Addon release and publishing workflow. Covers version bumping, changelog
  updates, git tagging, .pkgmeta configuration, and the GitHub Actions
  packager pipeline for CurseForge and Wago.io.
  Triggers: release, version, tag, publish, changelog, CurseForge, Wago,
  packager, pkgmeta, deploy, ship, upload, distribution.
---

# Release Workflow

## Release Steps (in order)

1. Verify all changes are committed and tested in-game
2. Update version in .toc: ## Version: X.Y.Z
3. Add entry to CHANGELOG.md with today's date
4. Commit: git add . && git commit -m "Release vX.Y.Z: brief description"
5. Tag: git tag vX.Y.Z
6. Push: git push origin main && git push origin vX.Y.Z
7. The tag push triggers GitHub Actions which builds and uploads

## GitHub Actions Workflow

File: .github/workflows/release.yml

```yaml
name: Package and Release

on:
  push:
    tags:
      - "v*"

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: BigWigsMods/packager-action@v2
        with:
          args: -g v${{ github.ref_name }}
        env:
          CF_API_KEY: ${{ secrets.CF_API_KEY }}
          WAGO_API_TOKEN: ${{ secrets.WAGO_API_TOKEN }}
          GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}
```

## Required GitHub Secrets

Set these in your repo, Settings, Secrets, Actions:

- CF_API_KEY: CurseForge, My Projects, API Token
- WAGO_API_TOKEN: Wago.io, Account Settings, API Key
- GITHUB_TOKEN: automatically provided by GitHub Actions

## .pkgmeta Configuration

```yaml
package-as: KitnTest

ignore:
  - .github
  - .claude
  - .pkgmeta
  - .luacheckrc
  - .gitignore
  - README.md
  - CHANGELOG.md
  - .wow-api-reference
```

## Version in .toc

Use the @project-version@ token for automatic version injection:
```
## Version: @project-version@
```
The packager replaces this with the git tag (e.g. v1.2.3) at build time.

## CHANGELOG.md Format

```markdown
# Changelog

## [1.0.0] - 2026-03-27
### Added
- Initial release
- Slash command system with /kitntest help and /kitntest diag
```
