# Development

## The machine

Windows 11, no Mac. Tools on the owner's machine:

- Swift 6.3 for Windows. It builds and tests `ios/Packages/ValorantCore` (pure Swift, no
  UIKit). It cannot build the app.
- `gh` logged in as `KaiC5504`. Repo: `KaiC5504/DailyStore` (public, see below).
- Python for `scripts/` and `tools/`; `uv` runs `tools/probe.py`.
- Orca for any browser work. Do not use the claude-in-chrome tools.

## The loop

Compile feedback only comes from CI, and Codemagic minutes are limited (500 free a
month, roughly 15 per build), so:

1. Commit on `dev` and push. Actions (`.github/workflows/ios-compile.yml`) runs on every
   branch: core package tests, XcodeGen, simulator build, launch, demo screenshots.
   It takes about 11 minutes.
   ```
   gh run list --branch dev --limit 1
   gh run watch <id> --exit-status
   gh run view <id> --log-failed | grep "error:"     # on failure
   gh run download <id> -n simulator-screenshots -D <scratch dir>
   ```
2. Open the screenshots you care about and actually look at them. They are the only view
   of the UI before the phone. They come from a 6.3" simulator (1170x2532); the owner's
   phone is an iPhone 17 Pro Max (larger).
3. When green and the pixels look right: `git checkout main && git merge --ff-only dev &&
   git push origin main`.
4. `python scripts/codemagic.py start main` then `python scripts/codemagic.py watch`.
   About 12-15 minutes. The Codemagic push trigger is unreliable; always start by hand.
5. Tell the owner the build number, what changed, how it works, and test steps.

The owner has authorised steps 1-5 without asking each time. Chain commands with `&&`.

Screenshot names: `01-first-launch` (real, signed-out), then demo mode `02-today`,
`03-night-hidden` and `04-night-revealed` (the Night Market cover opened from Today),
`05-bundles`, `06-detail`, `07-wishlist`, `08-settings`, `09-widgets`,
`10-wishlist-owned` (search "Reaver", owned tags), `11-matches`, `12-match-detail`,
`13-round` (round 7 sheet), `14-player` (6th scoreboard row), `15-deathmatch`.

## Local tests

```
cd ios/Packages/ValorantCore && swift test
```

69 tests as of build 10 (Swift Testing, `@Test`). Fixtures are in
`Tests/ValorantCoreTests/Support.swift` and `MatchFixtures.swift` (hand-written matches in
the real shape; the repo is public, so never commit real match JSON with other players'
names). Anything that can live in ValorantCore should,
because that is the only code testable without CI. Reset/time maths, parsing, caching
decisions and catalog lookups all have tests; add one for new logic there.

Gotchas on Windows: `swift test` output is noisy; filter with
`grep -E "✘|Test run with"`. Date formatting output contains a narrow no-break space
(U+202F) before AM/PM; the test helpers strip it.

## Demo mode

Debug builds read launch arguments so CI can screenshot without a Riot account:

- `-DemoData YES`: use `DemoData.swift` (real item IDs, fake wallet) and skip Riot.
- `-DemoTab today|bundles|matches|wishlist|settings`
- `-DemoNight YES`: open the Night Market cover on launch.
- `-DemoReveal YES`: Night Market cards start revealed.
- `-DemoMatch N`: open the Nth match on the Matches tab (6 is the Deathmatch).
- `-DemoRound N` / `-DemoPlayer N`: with `-DemoMatch`, open that round's sheet or the Nth
  scoreboard row's player sheet.
- `-DemoDetail N`: open the Nth daily skin's detail page.
- `-DemoSearch text`: prefill the wishlist search.
- `-DemoWidgets YES`: show the widget gallery instead of the app.

All of it is `#if DEBUG`; release builds never see it. New screens should get a demo
path and a screenshot line in the workflow.

## Conventions

- Comments explain why, never what. No "Note:", no emoji, no section dividers. Match the
  file's existing density.
- SwiftUI, Observation (`@Observable`), async/await. No third-party dependencies.
- Swift language mode 5 in the Xcode targets on purpose (see `decisions.md`); the package
  uses Swift 6 tools.
- Design tokens only from `ios/Sources/Shared/Theme.swift`; don't hardcode colours.
- Python edits to Swift files: write the script to a scratch file and run it. Inline
  heredocs with Swift string interpolation and apostrophes break the shell.

## Security

- `.gitignore` excludes `*.cookies`, `.env*`, keys, profiles, `*token*.txt`.
- The Codemagic token is `~/.codemagic-token`. `CERT_KEY_B64` lives only in the Codemagic
  `code_signing` group.
- The Diagnostics log and `probe.py` must never print cookies or tokens. Log step names
  and HTTP status codes only.

## Repo visibility

Public now because macOS Actions minutes are free for public repos and bill at 10x on
private ones (each run is about 11 macOS minutes, so about 110 billed minutes private).
The owner wants it private once development settles. Remind them; flip it only when they
say so (`gh repo edit KaiC5504/DailyStore --visibility private --accept-visibility-change-consequences`).

## Working with the owner

- Report every change as: what was built, how it works, how to test it on the phone.
  They don't read code; a change isn't done until they can check it themselves.
- Be blunt. Say when something is a bad idea, including their own suggestion.
- Plan first and get approval for milestone-sized work; just do small fixes.
- Max polish by default: motion, glass, reveals. Static info-dump screens are a no.
- Refer to the owner as they/them.
