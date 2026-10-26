# DailyStore

Personal iOS app (one user, TestFlight only) that shows the VALORANT daily store, Night
Market, bundles and wallet without logging in every day. Swift 6 toolchain / SwiftUI,
iOS 26, Liquid Glass. Development happens on Windows; there is no Mac. Every build is
compiled, signed and uploaded by GitHub Actions. Load the global `ios-testflight` skill
before touching signing, `testflight.yml`, `ios/project.yml` or the compile workflow.

Read `docs/README.md` first. It indexes everything a new session needs.

## Rules that are not up for debate

- Never commit secrets: Riot cookies/tokens, App Store Connect keys, signing keys. Riot
  cookies are a password that already passed 2FA; they live only in the iOS Keychain and
  are never logged, printed or sent anywhere but Riot.
- The app never surveils the user. No analytics, no tracking, no third-party SDKs.
- Do not inject JavaScript into Riot's login page to fill or read credentials. It was
  tried and deliberately abandoned (see `docs/decisions.md`).
- Every pipeline-critical setting lives in `ios/project.yml`. Read the "Pipeline-critical
  settings" section of `docs/testflight-pipeline.md` before touching it.

## How to ship a change

GitHub has only `main`. Work branches, if any, stay local and are never pushed.

1. Run `bash tools/check-app.sh` (local compile check in WSL via xtool, a few seconds)
   until it says OK. Commit on `main` and push. Wait for the compile check
   (`gh run watch <id> --exit-status`). Comment- or docs-only commits get `[skip ci]`.
2. Download the `simulator-screenshots` artifact and look at every screen you touched.
3. `python scripts/testflight.py start` and `python scripts/testflight.py watch <id>` in
   the background. Green means Apple has processed the build. After any change to
   `testflight.yml`, run `start --dry-run` first.
4. Report the TestFlight build number with test steps the owner can do on the phone.

The owner has authorised commit, push and Actions runs, signed builds included, without
asking. Never start a signed build before the compile check is green.
Details in `docs/development.md`.
