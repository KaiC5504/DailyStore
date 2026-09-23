# Decisions

Each entry: what was chosen, why, and what not to redo. Newest last.

1. **Native Swift/SwiftUI, iOS 26 minimum, no third-party packages.** Liquid Glass and
   WidgetKit need native; one user on the latest iOS means no back-deployment cost.

2. **Cookies, not tokens.** Access tokens last an hour; the remember-me cookies slide for
   30 days per use (verified with `tools/probe.py`). Keeping cookies is the whole point of
   the app. Rotated cookies must always be saved; the previous set is kept as a fallback.

3. **WKWebView login.** The password API needs hCaptcha. A real web page handles
   captcha, 2FA and social logins for free.

4. **No JavaScript credential fill.** The plan had the app store the Riot password and
   inject it into the login page. Injecting credentials into Riot's live login page was
   stopped and abandoned. Do not re-attempt JS injection or capture on Riot's login page.
   iOS Passwords AutoFill (the key above the keyboard) does the same job safely.

5. **Keychain access group instead of an App Group.** App Store profiles already allow
   `TEAMID.*` keychain groups, so app/widget sharing needed zero Apple Developer portal
   steps. An App Group would require manual portal registration because the API can't.

6. **Once per UTC day.** The owner asked not to keep hitting Riot. Snapshots are reused
   until Riot's countdown ends; only a reset, pull-to-refresh or Settings refresh fetch.

7. **Reset in UTC, displayed locally.** The store resets at 00:00 UTC. The daily
   notification's trigger is in UTC, so it follows the owner's time zone and DST with no
   settings or rescheduling.

8. **XcodeGen + Codemagic + GitHub Actions.** No Mac. Actions (free on a public repo)
   compiles, tests and screenshots every push; Codemagic (limited minutes) only signs and
   uploads from `main`. The `.xcodeproj` is never committed.

9. **Swift 5 language mode in the Xcode targets.** Strict concurrency errors can't be
   iterated on efficiently when every compile is an 11-minute CI run. The core package
   builds under Swift 6 tools and is tested locally.

10. **valorant-api.com for names/art.** It's the only free source with images. It lags new
    releases, so the catalog is checked against the store on every app open and unknown
    items render as "New item, details coming soon" (build 7). Riot's official content API
    was rejected: approved key required and no images.

11. **Fit on one screen.** Owner request (build 6): the store tabs must not need scrolling.
    Scroll-driven parallax effects were replaced with appear animations. See
    `ui-design.md`.

12. **Public repo for now.** Free macOS minutes. Owner wants it private later; remind
    them, don't flip it without being told.
