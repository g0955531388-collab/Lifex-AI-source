# Build Wave 1 Report — Android Debug APK

**Branch:** `codex/apk-build-wave-1`  
**Baseline:** `18a936d`  
**Mode:** Build verification only — no new modules/features.

---

## Build Status

**BLOCKED**

## Exact Failure

1. Initial: `java.util.zip.ZipException: zip END header not found` while unzipping Gradle distribution under sandbox `GRADLE_USER_HOME` (`…\cursor-sandbox-cache\…\gradle\wrapper\dists\gradle-8.7-bin\bhs2…`).
2. After local Gradle dist repair: `Could not resolve` AGP/`classpath` artifacts from `dl.google.com` (timeout).
3. With user `GRADLE_USER_HOME`: `Could not HEAD` deps on `maven.aliyun.com` (DNS: remote name could not be resolved).
4. Offline `gradlew assembleDebug --offline`: Flutter `:gradle` compiled, then `No cached version available for offline mode` for `error_prone_annotations-2.27.0` and `kotlinx-coroutines-core-jvm-1.8.0` (jars exist on disk under modules-2 but not accepted for offline resolution against current repo metadata).

## Root Cause

**Environment/network isolation in the agent runtime**, not a broken Flutter/Android project configuration at baseline `18a936d`.

Proven:

- `compileSdk=36`, `targetSdk=36`, `minSdk=24`, package `lifex_ai`, Kotlin plugin `2.2.20`, AGP `8.3.2`, Gradle wrapper `8.7` — consistent with last APK-oriented main tip.
- `dl.google.com`, `repo1.maven.org`, `maven.google.com` → **timeout**.
- `maven.aliyun.com` → **DNS failure**.
- Sandbox redirects `GRADLE_USER_HOME` to a TEMP cache that had a **corrupt/partial** `gradle-8.7-bin.zip`.

## Repository Fix Possible

**NO** (for the remaining Maven download/DNS blocker from inside this agent environment).

Local-only cache repair of the Gradle zip is **outside the git tree** and does not belong in the PR as an app change.

## Fix Applied

| Change | In git? |
|--------|---------|
| Created branch `codex/apk-build-wave-1` from `18a936d` | yes (branch) |
| Copied valid `gradle-8.7` dist into sandbox Gradle home | **no** (local env) |
| Tried `org.gradle.offline=true` then **reverted** | no lasting repo change |
| No new modules / no feature code | n/a |

## Remaining Blocker

Agent host cannot reach Android/Google/Maven artifact hosts required to finish `assembleDebug` when cache metadata is incomplete for offline mode.

## Required External Action

1. Run on a machine/CI with Maven access (GitHub Actions on this baseline historically builds APK), **or**
2. Pre-seed a complete Gradle module cache + run `gradlew assembleDebug --offline` outside the sandbox, **or**
3. Re-run this wave with unrestricted network / non-sandboxed Gradle home.

Suggested verify command after network is available:

```bash
git checkout codex/apk-build-wave-1   # at 18a936d
cd Lifex-AI/lifex_ai
flutter pub get
flutter build apk --debug
# expect: build/app/outputs/flutter-apk/app-debug.apk
```

## Validation (this session)

| Step | Result |
|------|--------|
| flutter pub get | PASS (earlier on branch) |
| flutter analyze (full) | NOT RUN as closure (out of wave if not required after APK fail) |
| architecture tests | NOT re-run this wave (no code changes) |
| flutter build apk --debug | **FAIL / BLOCKED** |
| APK artifact verified | **NO** |

## Architecture findings (Detected but Not Fixed)

- Prior branch `codex/lifex-repair-baseline` holds large ARP/contract work — **not required** to prove baseline APK; left untouched for later waves.
- Aliyun-first mirrors in `settings.gradle.kts` help some networks but cannot help when DNS/outbound Maven is fully blocked.
- Do not treat Graph/Search/modules as in-scope for this wave.

## Classification

| Item | Class |
|------|--------|
| Wave branch from baseline | IMPLEMENTED |
| Environment diagnosis | IMPLEMENTED |
| Debug APK | BLOCKED |
| Minimal in-repo build fix | NOT YET IMPLEMENTED (none proven effective under current network) |
| Draft PR with honest status | (see Git section of agent final report) |
