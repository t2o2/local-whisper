# CI/CD Setup Guide

This document explains how to set up automatic releases with Sparkle auto-updates.

## Overview

The CI/CD pipeline consists of two GitHub Actions workflows:

1. **CI** (`.github/workflows/ci.yml`): Builds and tests on every push/PR to `main`
2. **Release** (`.github/workflows/release.yml`): Creates releases when you push a version tag

## How It Works

```
Push tag v1.0.0
    ↓
GitHub Actions builds .app, .dmg, .zip
    ↓
Signs update with Sparkle EdDSA key (if configured)
    ↓
Creates GitHub Release with artifacts
    ↓
Updates appcast.xml on gh-pages branch
    ↓
Users receive update notification via Sparkle
```

## Setup Instructions

### 1. Enable GitHub Pages

1. Go to your repo **Settings** → **Pages**
2. Set Source to **Deploy from a branch**
3. Select **gh-pages** branch, **/ (root)**
4. Save

The appcast will be available at: `https://t2o2.github.io/local-whisper/appcast.xml`

### 2. Generate Sparkle EdDSA Keys (Recommended)

Sparkle uses EdDSA signatures to verify that updates are authentic. Without this, updates are unsigned (less secure but still works).

```bash
# Download Sparkle tools
curl -L -o /tmp/Sparkle.tar.xz https://github.com/sparkle-project/Sparkle/releases/download/2.5.0/Sparkle-2.5.0.tar.xz
mkdir -p /tmp/sparkle
tar -xf /tmp/Sparkle.tar.xz -C /tmp/sparkle

# Generate key pair
/tmp/sparkle/bin/generate_keys

# Output will show:
# - Private key saved to: /path/to/private/key
# - Public key: <base64 string>
```

### 3. Configure GitHub Secrets

Go to repo **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `SPARKLE_PRIVATE_KEY` | EdDSA private key (base64) | Contents of the private key file from step 2 |

### 4. Add Public Key to Info.plist

Edit `scripts/release.sh` and find `SUPublicEDKey`:

```xml
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY_HERE</string>
```

Replace with the public key from step 2.

### 5. Create a Release

```bash
# Ensure all changes are committed
git status

# Create and push a version tag
git tag v1.0.0
git push origin v1.0.0
```

The release workflow will automatically:
- Build the app
- Create .dmg and .zip files  
- Sign the update (if SPARKLE_PRIVATE_KEY is set)
- Create a GitHub Release
- Update appcast.xml on gh-pages

## Testing Updates Locally

1. Build the current version:
   ```bash
   ./scripts/release.sh 1.0.0
   ```

2. Install it to Applications

3. Build a newer version:
   ```bash
   ./scripts/release.sh 1.0.1
   ```

4. Start a local server with the update:
   ```bash
   cd dist
   python3 -m http.server 8080
   ```

5. Temporarily change `SUFeedURL` in the installed app's Info.plist to `http://localhost:8080/appcast.xml`

6. Open the app and check for updates

## Workflow Behavior

### CI Workflow (ci.yml)

- **Trigger**: Push to `main`, Pull Requests to `main`
- **Actions**: Build with `swift build -c release`
- **Caching**: Caches `.build` directory for faster builds

### Release Workflow (release.yml)

- **Trigger**: Push tags matching `v*` (e.g., `v1.0.0`, `v2.1.3`)
- **Actions**:
  1. Build release binary
  2. Create .app bundle with `release.sh`
  3. Sign update with Sparkle EdDSA (if secret is set)
  4. Generate appcast.xml
  5. Upload .dmg and .zip to GitHub Releases
  6. Push appcast.xml to gh-pages branch

## Troubleshooting

### Updates not showing up

1. Check that appcast.xml is accessible: `curl https://t2o2.github.io/local-whisper/appcast.xml`
2. Verify `SUFeedURL` in the app's Info.plist matches the appcast URL
3. Check the version in appcast.xml is higher than the installed version

### Build fails on CI

1. Check the workflow logs in GitHub Actions
2. Ensure `swift build -c release` works locally
3. Check that all dependencies are properly declared in Package.swift

### Sparkle signature errors

1. Verify the public key in Info.plist matches the private key used to sign
2. Check that `SPARKLE_PRIVATE_KEY` secret is set correctly
3. The private key should be the raw contents of the key file (not base64 encoded again)

## Version Numbering

Use semantic versioning: `MAJOR.MINOR.PATCH`

- `v1.0.0` → First stable release
- `v1.0.1` → Bug fixes
- `v1.1.0` → New features (backwards compatible)
- `v2.0.0` → Breaking changes

## Security Notes

- **Ad-hoc Signing**: The app uses ad-hoc code signing, meaning users will see an "unidentified developer" warning on first launch
- **Sparkle Signing**: EdDSA signatures ensure updates haven't been tampered with
- **Keep Private Key Secure**: Never commit the Sparkle private key to the repository
- **Key Rotation**: If you lose the private key, existing users cannot verify updates; you'll need to distribute a new version manually
