# Architecture

## Layout

```
ios/
  project.yml                  XcodeGen spec (the .xcodeproj is generated, never committed)
  Packages/ValorantCore/       Pure Swift package, no UIKit. Tested on Windows and CI.
    RiotAuth.swift             authorize URL, redirect/token parsing, RiotError
    RiotCookies.swift          the five cookies, Set-Cookie merging (rotation)
    RiotAPI.swift              reauth, entitlements, userinfo, geo/shard, storefront v3, wallet, headers
    Storefront.swift           models + lenient parsing of the storefront and wallet
    StoreService.swift         actor: session -> reauth (with fallback jar) -> store + wallet -> StoreSnapshot
    Catalog.swift              valorant-api.com skins/tiers/bundles/buddies/sprays/cards/titles
    Schedule.swift             StoreClock (UTC reset maths), staleness, Wishlist.hits,
                               CompactCatalog (for the widget), Catalog.missingIDs
    HTTPClient.swift           URLSession wrapper with redirects disabled
  Sources/Shared/              Compiled into BOTH the app and the widget
    SharedKeychain.swift       keychain access group, SharedState, KeychainSessionStore
    StoreRefresher.swift       the one fetch path; Notifier; Prefs
    Theme.swift                design tokens
    WidgetModel.swift          StoreEntry, entry builder, thumbnail cache
    WidgetViews.swift          all widget family views, WidgetGallery (DEBUG)
  Sources/App/                 App only
    DailyStoreApp.swift        @main, RootView TabView, background task registration
    AppModel.swift             @Observable state: phase, snapshot, catalog, wishlist, log
    TodayView / NightMarketView / BundlesView / WishlistView / SettingsView / SkinDetailView
    Components.swift           AmbientBackground, RemoteImage, PriceTag, TierBadge,
                               CountdownChip, ScreenTitle, FitPage, FillGrid, LoopingVideo
    LoginView.swift            WKWebView Riot login, harvests cookies
    DemoData.swift             DEBUG sample store
  Sources/Widget/StoreWidget.swift   WidgetBundle + TimelineProvider
tools/probe.py                 Windows smoke test of the Riot chain (paste cookies, hidden input)
scripts/codemagic.py           start/watch/status Codemagic builds
scripts/make_icon.py           generates the app icon PNG
```

## Data flow

```
LoginView (WKWebView) --cookies--> StoreService.signIn --> Keychain (session)
                                                   \--> fetch()
fetch(): Keychain session -> reauth (cookies -> tokens, rotated cookies saved)
         -> entitlements + client version (+ puuid, shard once) -> storefront + wallet
         -> StoreSnapshot
StoreRefresher.current(): saved snapshot if not stale, else fetch -> SharedState.save
         -> wishlist alert
AppModel / widget / background task all go through StoreRefresher.
```

## Storage: one shared keychain group, no App Group

App and widget share `$(AppIdentifierPrefix)com.kaichuan.dailystore.shared`. App Store
provisioning profiles already allow `TEAMID.*` keychain groups, so this needed no Apple
Developer portal work, which an App Group would have. Items (service
`com.kaichuan.dailystore`, accessibility AfterFirstUnlockThisDeviceOnly so the widget and
background refresh can read them while the phone is locked):

| Account | Contents | Written by |
| --- | --- | --- |
| `riot-session` | `RiotSession`: current cookies, previous cookies (fallback), puuid, shard | StoreService |
| `store-snapshot` | latest `StoreSnapshot`; `save` keeps whichever is newer | StoreRefresher |
| `wishlist` | `Set<String>` of lowercased skin level IDs | AppModel |
| `compact-catalog` | `CompactCatalog`: name, tier colour, icon per skin for the widget | AppModel |
| `alert-state` | wishlist alerts on/off, UTC day last alerted | Settings, Notifier |

If the entitlement is missing (unsigned simulator builds), `SharedKeychain` falls back to
the app's default group. `migrateLegacySession()` moves build 3's session into the group.

App-only storage: `FileCache` in Caches for the full `Catalog` (`catalog.json`),
`UserDefaults` for revealed Night Market offer IDs, the daily-reminder toggle and
`catalogRetryAt`.

## Caching rules

- **Store:** a snapshot is stale once Riot's own countdown
  (`SingleItemOffersRemainingDurationInSeconds` from fetch time) runs out, or at the next
  00:00 UTC if the countdown is missing. Until then nobody calls Riot:
  launch/foreground use the saved snapshot. After the reset the first of
  {app open, reset timer while open, widget timeline, background task} fetches.
  Pull-to-refresh and Settings > Refresh force a fetch.
- **Catalog (valorant-api.com):** refetched when the client version changes, when it has
  no bundles, or when `Catalog.missingIDs(in:)` finds store skins/bundles it can't name.
  The last case is checked on every launch and foreground, at most once per 5 minutes
  (`catalogRetryAt`). The full catalog is about 760 KB compressed.
- **Images:** `URLCache.shared` 64 MB memory / 400 MB disk. The widget downsizes
  thumbnails with ImageIO because widget memory is tight.

## Timing

`StoreClock` in `Schedule.swift`. Reset is 00:00 UTC every day; shown in the device's
local time zone, so it follows the owner between Malaysia (8:00 AM) and Australia
(10 or 11 AM depending on DST) with no settings. Night Market and bundle end times come
from Riot's remaining-seconds fields plus `fetchedAt`.

## Widget

`StoreProvider.getTimeline`: uses the saved snapshot if fresh, otherwise does the same
reauth + fetch the app does (and saves rotated cookies). Timeline: the current entry and
an "expired" entry at the reset; reload policy is reset + 60 s. On failure it retries in
15 minutes. Signed-out / session-expired shows "Open DailyStore to sign in". Tapping opens
the app via `dailystore://today`.

## Notifications

- Daily reset: one repeating `UNCalendarNotificationTrigger` at 00:01 UTC. Because the
  trigger is in UTC, it lands on the right local time everywhere without rescheduling.
  On by default; permission is requested after the first successful store load.
- Wishlist: fired by whoever fetches the new store (app, widget, background task) when a
  wishlisted skin is in the daily store or Night Market, once per UTC day.

## Background refresh

`BGAppRefreshTask` `com.kaichuan.dailystore.refresh`, scheduled for 2 minutes after the
next reset whenever the app goes to the background. iOS decides when it really runs.

## AppModel lifecycle

- `start()` (launch): load the catalog cache, migrate the legacy session, load the saved
  snapshot. Signed out: show login. Fresh snapshot: show it, arm the reset timer, check
  the catalog. Stale: fetch.
- `resume()` (foreground): adopt a newer snapshot the widget saved; fetch if stale,
  otherwise re-arm the timer and check the catalog.
- `run()` wraps every fetch: sets `phase`, maps `sessionExpired`/`notSignedIn` to the
  login sheet, logs to Diagnostics, reloads widgets.
