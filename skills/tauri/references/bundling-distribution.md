# Tauri v2 bundling & distribution

`tauri build` compiles the Rust core in release mode and produces native installers from
your `frontendDist`. The recurring trap: unsigned binaries trigger OS warnings
("unidentified developer", SmartScreen), so signing + (on macOS) notarization is part of
shipping, not an afterthought.

## Build targets per OS

```bash
tauri build                      # all configured bundle targets for the host OS
tauri build --bundles dmg        # macOS: just the .dmg
tauri build --bundles nsis,msi   # Windows: NSIS installer + MSI
tauri build --bundles appimage,deb # Linux
tauri build --target aarch64-apple-darwin   # cross-arch (toolchain must be installed)
```

You build **on** each target OS (or in CI runners for each); there is no single-host
cross-build for everything because the bundler uses native tooling.

| OS | Bundle formats | Signing |
|----|----------------|---------|
| macOS | `.app`, `.dmg` | Developer ID cert + **notarization** (Gatekeeper) |
| Windows | NSIS (`-setup.exe`), MSI | Authenticode (SmartScreen) |
| Linux | AppImage, `.deb`, `.rpm` | No central authority; ship checksums/GPG |

## macOS signing + notarization

1. Set the signing identity in config or env:

```json
// tauri.conf.json
{ "bundle": { "macOS": { "signingIdentity": "Developer ID Application: Your Name (TEAMID)" } } }
```

2. Provide notarization credentials as env vars for `tauri build`:

```bash
export APPLE_ID="you@example.com"
export APPLE_PASSWORD="app-specific-password"   # not your Apple ID password
export APPLE_TEAM_ID="TEAMID"
tauri build --bundles dmg       # signs, then submits for notarization + staples
```

Without notarization, Gatekeeper blocks the app on a clean machine even if it's signed.

## Windows Authenticode

```json
// tauri.conf.json
{ "bundle": { "windows": {
  "certificateThumbprint": "AB12...",   // cert installed in the Windows cert store
  "digestAlgorithm": "sha256",
  "timestampUrl": "http://timestamp.digicert.com"
} } }
```

Cloud/HSM signing (Azure Trusted Signing, etc.) is the modern path for CI where a local
cert store isn't available.

## Updater plugin

The updater refuses unsigned updates by design — generate a keypair first.

```bash
tauri signer generate -w ~/.tauri/myapp.key   # prints the PUBLIC key to embed in config
```

```json
// tauri.conf.json
{ "plugins": { "updater": {
  "pubkey": "<PUBLIC KEY FROM ABOVE>",
  "endpoints": ["https://releases.example.com/{{target}}/{{arch}}/{{current_version}}"]
} } }
```

- The **private** key signs each release (`TAURI_SIGNING_PRIVATE_KEY` in CI); never commit it.
- The endpoint returns a JSON manifest with the new version, signature, and download URL.
- Frontend: install `@tauri-apps/plugin-updater`, call `check()` then `downloadAndInstall()`.

## Sidecar (embed an external binary)

Ship and run an external executable alongside your app.

```json
// tauri.conf.json
{ "bundle": { "externalBin": ["binaries/my-cli"] } }
```

Name the file per target triple (`my-cli-x86_64-apple-darwin`, etc.). Grant the
`shell:allow-execute` permission scoped to that sidecar to invoke it from Rust/JS.

## GitHub Actions release matrix (sketch)

One job per OS, each runs `tauri build` and uploads artifacts. Pair with the
`github-actions` skill for the CI mechanics.

```yaml
jobs:
  build:
    strategy:
      matrix:
        include:
          - { platform: macos-latest,   args: '--target aarch64-apple-darwin' }
          - { platform: macos-latest,   args: '--target x86_64-apple-darwin' }
          - { platform: ubuntu-22.04,   args: '' }
          - { platform: windows-latest, args: '' }
    runs-on: ${{ matrix.platform }}
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - run: npm ci && npm run tauri build -- ${{ matrix.args }}
        env:
          TAURI_SIGNING_PRIVATE_KEY: ${{ secrets.TAURI_SIGNING_PRIVATE_KEY }}
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_PASSWORD: ${{ secrets.APPLE_PASSWORD }}
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
```

On Linux runners install the WebKitGTK system deps before building (the Tauri docs list the
exact apt packages for your Ubuntu version).

## Checklist

- [ ] Build per target OS (host or CI runner), not a single cross-build.
- [ ] macOS signed **and** notarized; Windows Authenticode-signed.
- [ ] Updater keypair generated; private key only in CI secrets, public key in config.
- [ ] Sidecar binaries named per target triple + scoped `shell:allow-execute`.
- [ ] Linux WebKitGTK deps installed in CI.
