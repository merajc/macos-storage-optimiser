# macos-system-data 🧹

> Native macOS command-line utility to audit, diagnose, and safely reclaim 50–100+ GB of hidden **"System Data"** bloat.

Zero dependencies. 100% native Zsh. Read-only audit by default.

[![CI](https://github.com/merajc/macos-system-data/actions/workflows/ci.yml/badge.svg)](https://github.com/merajc/macos-system-data/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: macOS](https://img.shields.io/badge/Platform-macOS-brightgreen.svg)](https://apple.com)

---

## The Problem

macOS frequently reports 50–150+ GB of storage consumed by **"System Data"** in *System Settings > General > Storage*, giving users no transparency into what is actually consuming space.

Most of this storage is not the macOS operating system. It is composed of:
1. **Darwin Temp Directory Leaks**: Chromium & Electron background updaters (Google Chrome, Microsoft Teams, Brave, Slack) leaking dozens of duplicate ~1.3 GB code-sign bundles in `/var/folders/*/*/X`.
2. **App Store Staging Caches**: Stranded multi-gigabyte pkg/ipa downloads in `/var/folders/*/*/C`.
3. **Developer Caches**: Stranded NPM (`~/.npm`), Homebrew bottles, Playwright browser downloads, DotSlash binaries, and Xcode `DerivedData`.
4. **App Virtual Disks & Caches**: Abandoned Android emulators (BlueStacks in `/Users/Shared`), Adobe Camera Raw preview databases, and container caches.
5. **APFS Local Snapshots & VM Swap**: Hidden Time Machine local snapshots locking deleted disk blocks.

---

## Installation

### Option 1: Quick Install (curl)
```bash
curl -fsSL https://raw.githubusercontent.com/merajc/macos-system-data/main/install.sh | bash
```

### Option 2: Clone & Make
```bash
git clone https://github.com/merajc/macos-system-data.git
cd macos-system-data
make install
```

---

## Quick Usage

### 1. Read-Only Audit (Default)
Safely inspect and report all System Data culprits across your drives:
```bash
macos-system-data
```

### 2. Disk Overview
```bash
macos-system-data --summary
```

### 3. Interactive Cleanup Wizard
Step-by-step confirmation prompts for each category:
```bash
macos-system-data --clean
```

### 4. Non-Destructive Dry Run
Preview exactly what would be removed without touching disk:
```bash
macos-system-data --dry-run --clean
```

### 5. Automated / Unattended Cleanup
Purge 100% safe runaway temporary bugs (Chrome code-sign clones, App Store staging):
```bash
macos-system-data --clean-tier1 -y
```

Purge developer build & package caches (NPM, Brew, Playwright, DotSlash, Pip, Xcode):
```bash
macos-system-data --clean-dev -y
```

---

## Detection & Cleanup Tiers

| Tier | Category | Targets Cleaned | Safety |
|---|---|---|---|
| **Tier 1** | **Stranded OS & App Bugs** | Chromium/Teams `.code_sign_clone` bug dumps, App Store download staging | 🟢 100% Safe |
| **Tier 2** | **Developer Caches** | `~/.npm`, Homebrew cache, Playwright browsers, DotSlash, Pip, Xcode `DerivedData`, CoreSimulator | 🟢 Safe (Re-downloadable) |
| **Tier 3** | **Virtual Disks & App Bloat** | BlueStacks Android VM (`/Users/Shared`), Adobe Camera Raw cache, Trash, Crash Logs | 🟡 Interactive Prompt |
| **Tier 4** | **System Diagnostics** | APFS Local Snapshots, macOS VM swap, Spotlight > 1 GB index, heavy `~/Library/Caches` | 🔵 Read-Only Insights |

---

## Safety Architecture

- **Read-Only by Default**: Running `macos-system-data` with no arguments never modifies or deletes any files.
- **Strict Allowed Roots**: Deletions are strictly confined to verified cache, temp, and runtime build roots.
- **Path Traversal Defense**: All targets are canonicalized via realpath resolution (`:A`) and checked against a blacklist (`/`, `/System`, `/Library`, `/Users`, `/Users/Shared`, `$HOME`, etc.).
- **Dry Run Support**: Test any cleanup operation safely using `--dry-run` or `-n`.
- **Zero External Dependencies**: Implemented in clean, native Zsh. No Python, Node, or third-party binaries required.

---

## License

MIT © [Meraj Chhaya](https://github.com/merajc)
