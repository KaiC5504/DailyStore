# TestFlight pipeline

Windows (code) → local compile check → push → GitHub Actions `ios-compile.yml`
(unsigned simulator build + screenshots) → GitHub Actions `testflight.yml` (signed build,
upload, wait for Apple) → TestFlight → phone.

Nothing here needs a Mac. The owner tests only on TestFlight, so a change is not verified
until it is on the phone. The full playbook, including every manual step and known
failures, is the global `ios-testflight` skill.

Codemagic signed builds 1-11. It was retired on 2026-10-26: its free queue often waited
longer than the build, and GitHub's macOS runners are free on a public repo.

## Files

| File | Job |
| --- | --- |
| `.github/workflows/testflight.yml` | The signed build. Runs only when dispatched, only on `main`: generates the Xcode project, fetches signing files for the app and the widget, builds the IPA, uploads, then waits until Apple has processed it. |
| `scripts/testflight.py` | Start and watch signed builds from Windows. Refuses to start unless the `testflight` environment is locked to `main` with its secrets in place. |
| `scripts/testflight-requirements.txt` | Hash-pinned codemagic-cli-tools (the open-source signing and upload CLI; no Codemagic account involved). |
| `ios/project.yml` | XcodeGen spec. The `.xcodeproj` is generated on the build machine and never committed. |
| `ios/Sources/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png` | App icon (fanned glass cards) from `scripts/make_icon.py`. Uploads without a 1024 icon are rejected. |
| `.github/workflows/ios-compile.yml` | Free compile check: core tests, simulator build, launch, demo-mode screenshots. Runs on pushes to `main` that touch `ios/`. |
| `tools/check-app.sh`, `tools/app-check/` | Local compile check before pushing: the app and widget sources built with SwiftPM in WSL against xtool's iOS SDK. Mirrors the targets in `ios/project.yml`; keep it in step. |

Identity used everywhere: app name `DailyStore`, scheme `DailyStore`, bundle id
`com.kaichuan.dailystore`, App Store Connect Apple ID `6815139973`. Changing any of these
means changing `testflight.yml`, `ios/project.yml` and the compile workflow together.

The widget extension is `DailyStoreWidget`, bundle id `com.kaichuan.dailystore.widget`.
`testflight.yml` fetches a profile for each bundle id separately. App and widget share
data through the keychain group `$(AppIdentifierPrefix)com.kaichuan.dailystore.shared`,
not an App Group. App Store profiles already allow `TEAMID.*` keychain groups, so this
needs no work in the portal. An App Group would mean registering it by hand in the
portal, since the API can't. Both targets' `CFBundleShortVersionString` and
`CFBundleVersion` must match.

Debug builds accept `-DemoData YES` and friends (see `development.md`), so the compile
check can screenshot every screen without a Riot account.

## Pipeline-critical settings in ios/project.yml

Keep these. Each one was learned the hard way.

- `CODE_SIGN_STYLE: Automatic` and no `configFiles:`. `xcode-project use-profiles`
  writes the team in, and a project-level xcconfig crashes it.
- `CFBundleVersion: $(CURRENT_PROJECT_VERSION)`. The workflow passes the build number
  per run, `max(latest in App Store Connect, BUILD_NUMBER_FLOOR) + 1`. App Store Connect
  rejects a build number it has already seen.
- `ITSAppUsesNonExemptEncryption: false`. Without it every build sits in TestFlight as
  "Missing Compliance".
- All four `UISupportedInterfaceOrientations~ipad` entries. Upload validation demands
  them even for iPhone-only apps.
- The declared `schemes:` block. `xcodebuild -scheme` needs it because Xcode never opens
  this project.
- `CFBundleIconName: AppIcon` and a 1024x1024 PNG with no alpha channel in the icon set.
- If source moves into another Swift package, add it to `paths` in `ios-compile.yml`
  and to `tools/app-check/`.

## Secrets and the public log

The repo is public, so the build log is public too.

- The GitHub environment `testflight` can only be used from `main`. It holds
  `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_IDENTIFIER`,
  `APP_STORE_CONNECT_PRIVATE_KEY` (the team's `GitHub Actions` API key, shared by every
  app), `CERT_KEY_B64` (the distribution certificate's private key, base64 because a PEM
  pasted into a web form loses its line breaks) and `SIGNING_NAME` (masks the legal name
  in the certificate). Check with `gh secret list --env testflight -R KaiC5504/DailyStore`.
- Secrets reach only the steps that need them. Never upload the IPA or Xcode logs, never
  `set -x`.
- A normal build only finds the existing certificate and profiles. `start
  --create-signing` registers a new bundle id or profile (a new extension, a changed
  capability) or renews an expired certificate.

## Shipping a build

GitHub has only `main`. Check locally first (see `development.md`), push `main`, and
start the signed build once its compile check is green and the screenshots look right.

```
git push origin main
python scripts/testflight.py start
python scripts/testflight.py watch <id>     # in the background; about 15-20 min
```

Green means Apple has processed the build, so it is installable from TestFlight within
minutes. The build number is in the run summary and the "Pick the build number" step.
After any change to `testflight.yml` or the scripts, run `start --dry-run` first: it
signs and checks the IPA without uploading. On failure, check the skill's
`reference/troubleshooting.md` before debugging from scratch.
