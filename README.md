# ReadArc

Agent-powered PDF reader for Mac, built with SwiftUI and PDFKit.

## Features

- Open local PDF files from the toolbar or File menu.
- Render PDFs with native `PDFView`.
- Page navigation and zoom controls.
- In-document text search with match navigation.
- Agent chat panel for PDF-aware reading and analysis.
- Recent PDF sidebar.
- Basic file-open support when the staged `.app` is opened with a PDF.

## Run

```bash
./script/build_and_run.sh
```

The same script is wired to the Codex app Run action through `.codex/environments/environment.toml`.

## Verify

```bash
swift run --build-system native ReadArcCoreSmokeTests
./script/build_and_run.sh --verify
```

## GitHub Release

Create a local DMG test artifact:

```bash
./script/release_github.sh --version 0.1.0 --ad-hoc --skip-notary --format dmg
```

Create a signed and notarized draft GitHub Release with a DMG installer:

```bash
./script/release_github.sh --version 0.1.0 --publish --format dmg
```

Formal public releases require:

- An Apple Developer Program account.
- A `Developer ID Application` certificate in Keychain.
- A stored notarytool profile, for example `readarc-notary`.
- A GitHub repository with source pushed before creating the release.

The DMG uses the standard macOS install pattern: drag `ReadArc.app` onto the
`Applications` shortcut.

Store notarization credentials once:

```bash
xcrun notarytool store-credentials readarc-notary \
  --apple-id "APPLE_ID_EMAIL" \
  --team-id "TEAM_ID" \
  --password "APP_SPECIFIC_PASSWORD"
```
