# TestFlight pipeline

Windows (code) → push → GitHub Actions (unsigned simulator build + screenshot) →
Codemagic (signed build) → TestFlight → phone.

The shape is copied from Backdrop and NextStop. Nothing here needs a Mac. The owner
tests only on TestFlight, so a change is not verified until it is on the phone.

## Files

| File | Job |
| --- | --- |
| `codemagic.yaml` | The signed build. Generates the Xcode project, creates signing files, builds the IPA, uploads to App Store Connect. |
| `scripts/codemagic.py` | Start and watch Codemagic builds from Windows. Token comes from `~/.codemagic-token`, never from the repo. |
| `ios/project.yml` | XcodeGen spec. The `.xcodeproj` is generated on the build machine and never committed. |
| `ios/Sources/App/DailyStoreApp.swift` | Smoke-test stub. Replace with the real app. |
| `ios/Sources/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png` | Placeholder icon from `scripts/make_icon.py`. Uploads without a 1024 icon are rejected. |
| `.github/workflows/ios-compile.yml` | Free compile check: builds for the simulator, launches, screenshots. Runs on every push that touches `ios/`. |

Identity used everywhere: app name `DailyStore`, scheme `DailyStore`, bundle id
`com.kaichuan.dailystore`. Changing any of these means changing `codemagic.yaml`,
`ios/project.yml` and the Actions workflow together.

The widget extension is `DailyStoreWidget`, bundle id `com.kaichuan.dailystore.widget`.
Codemagic fetches (and on first run creates) a profile for each bundle id separately.
App and widget share data through the keychain group
`$(AppIdentifierPrefix)com.kaichuan.dailystore.shared`, not an App Group. App Store
profiles already allow `TEAMID.*` keychain groups, so this needs no work in the portal.
An App Group would mean registering it by hand in the portal, since the API can't.
Both targets' `CFBundleShortVersionString` and `CFBundleVersion` must match.

Debug builds accept `-DemoData YES` (plus `-DemoTab`, `-DemoReveal`, `-DemoDetail`,
`-DemoWidgets`), so the Actions run can screenshot every screen without a Riot account.

## Pipeline-critical settings in ios/project.yml

Keep these when building out the real app. Each one was learned the hard way.

- `CODE_SIGN_STYLE: Automatic` and no `configFiles:`. Codemagic writes the team in; a
  project-level xcconfig breaks its signing step.
- `CFBundleVersion: $(CURRENT_PROJECT_VERSION)`. Codemagic sets the build number per
  run. App Store Connect rejects a build number it has already seen.
- `ITSAppUsesNonExemptEncryption: false`. Without it every build sits in TestFlight as
  "Missing Compliance".
- All four `UISupportedInterfaceOrientations~ipad` entries. Upload validation demands
  them even for iPhone-only apps.
- The declared `schemes:` block. `xcodebuild -scheme` needs it because Xcode never opens
  this project.
- `CFBundleIconName: AppIcon` and a 1024x1024 PNG with no alpha channel in the icon set.
- If source moves into a shared Swift package (Backdrop has `core/`), add that folder to
  `when.changeset.includes` in `codemagic.yaml` and to `paths` in the Actions workflow.

## Account-side pieces (already exist)

- Codemagic App Store Connect integration named `NextStop ASC key`. Team-level, shared
  by every app.
- Codemagic environment group `code_signing` with `CERT_KEY_B64` (the distribution
  certificate's private key, base64). If it turns out to be app-level rather than
  team-level, copy the value from Backdrop's app settings into a group of the same name
  on this app. Never paste it anywhere else.
- Codemagic API token in `~/.codemagic-token` on the Windows machine.

## One-time setup

Claude does:

1. Commit and push `main` to a GitHub repo `KaiC5504/DailyStore`. Public keeps macOS
   Actions minutes free, as with Backdrop. Private works too but macOS minutes bill at
   10x against the free quota.
2. Wait for the Actions run: `gh run list --branch main --limit 1`, then
   `gh run watch <id> --exit-status`.

Owner does (Claude cannot):

3. Codemagic → Apps → Add application → GitHub → `DailyStore` → select `codemagic.yaml`.
   In the app's settings confirm the `NextStop ASC key` integration and the
   `code_signing` group are visible.
4. App Store Connect → My Apps → "+" → New App: platform iOS, name `DailyStore` (if
   taken, `Daily Store`), primary language English, bundle id `com.kaichuan.dailystore`,
   SKU `dailystore`. If the bundle id is not in the dropdown, do step 6 first: the first
   Codemagic build registers it, then come back.
5. App Store Connect → DailyStore → TestFlight → Internal Testing → add yourself.

Claude does:

6. `python scripts/codemagic.py start main` then `python scripts/codemagic.py watch`.
   Expected: status `finished`, an IPA artifact, "Publishing to App Store Connect"
   succeeded.
7. Report the TestFlight build number and what to check on the phone.

## Shipping a build after that

```
git push origin main
gh run list --branch main --limit 1        # then gh run watch <id> --exit-status
python scripts/codemagic.py status         # nothing already running?
python scripts/codemagic.py start main
python scripts/codemagic.py watch
```

The push trigger in `codemagic.yaml` never fired for Backdrop, so treat the manual
start as the normal path. Internal testers get the build as soon as Apple finishes
processing. `submit_to_testflight: false` only skips external beta review.

## Gotchas baked into codemagic.yaml

- No `ios_signing:` block. It only fetches existing files and fails on a fresh bundle
  id. `fetch-signing-files --create` registers the bundle id and profile instead.
- `CERT_KEY_B64` travels as base64 because a PEM pasted into Codemagic's web form loses
  its line breaks.
- `xcode: latest` because the project targets iOS 26.
- If `fetch-signing-files` fails, the watcher prints the failing step's log. Usual
  causes: certificate key format, integration name mismatch, no app record yet.
