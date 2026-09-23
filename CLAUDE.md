# DailyStore

Personal iOS app (one user, TestFlight only) that shows the VALORANT daily store, Night
Market, bundles and wallet without logging in every day. Swift 6 toolchain / SwiftUI,
iOS 26, Liquid Glass. Development happens on Windows; there is no Mac. Every build is
compiled by GitHub Actions and signed by Codemagic.

Read `docs/README.md` first. It indexes everything a new session needs.

## Rules that are not up for debate

- Never commit secrets: Riot cookies/tokens, the Codemagic token, signing keys. Riot
  cookies are a password that already passed 2FA; they live only in the iOS Keychain and
  are never logged, printed or sent anywhere but Riot.
- The app never surveils the user. No analytics, no tracking, no third-party SDKs.
- Do not inject JavaScript into Riot's login page to fill or read credentials. It was
  tried and deliberately abandoned (see `docs/decisions.md`).
- Every pipeline-critical setting lives in `ios/project.yml`. Read the "Pipeline-critical
  settings" section of `docs/testflight-pipeline.md` before touching it.

## How to ship a change

1. Work on `dev`. Push. Wait for the GitHub Actions run (`gh run watch <id> --exit-status`).
2. Download the `simulator-screenshots` artifact and look at every screen you touched.
3. `git checkout main && git merge --ff-only dev && git push`, then
   `python scripts/codemagic.py start main` and `python scripts/codemagic.py watch`.
4. Report the TestFlight build number with test steps the owner can do on the phone.

The owner has authorised commit, push, Actions and Codemagic runs without asking.
Details in `docs/development.md`.
