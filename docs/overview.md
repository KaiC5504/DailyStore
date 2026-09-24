# Overview

## What it is

A personal iPhone app for the owner (KaiC, VALORANT account on the Asia-Pacific shard
`ap`, lives in Malaysia/Australia) to check the VALORANT store. Apps like ValTracker make
you log in every day because they keep only Riot's one-hour access token. DailyStore keeps
Riot's remember-me cookies in the Keychain and silently re-authenticates with them, so
the owner logs in once and the session keeps sliding forward (see `riot-api.md`).

Distribution is TestFlight internal testing only. It is not meant for the App Store:
Riot's terms list store checkers as unapproved third-party tools, so keep it personal.

## Scope (all shipped)

- Daily store: the four skins with tier, price, art; reset countdown in local time.
- Wallet: VP, Radianite, Kingdom Credits.
- Night Market: flip-to-reveal cards with discount and price, end countdown. Opened full
  screen from the Today bar, which only shows while one is live (no tab since build 9).
- Featured bundles: banner, name, price, contents list with per-item prices.
- Skin detail: chroma (colour variant) picker, level upgrade videos, drag-to-tilt art,
  wishlist toggle.
- Wishlist: search every skin, heart it; badge and banner when one is in today's store or
  Night Market; notification. Owned skins are tagged (owned skins never show up in the
  store, so the tag matters in search and bundles only).
- Store history: every day's store is recorded on the phone from build 8. No screen yet;
  it exists so a future "last seen" feature has data.
- Matches (build 9): rank and RR trend, recent form, top agents and maps, every match
  with scoreboard, round timeline, kill feed, loadouts and per-player stats. All modes,
  filterable. Every match loaded is kept on the phone for good (Riot lists about five
  weeks); older games load as you scroll.
- Widget: home screen small/medium/large, lock screen rectangular/inline/circular. Fetches
  the new store itself after the reset.
- Notifications: daily "New store is up" at the reset (local time), wishlist alert.
- Background refresh after the reset.
- Store caching: Riot is asked at most once per UTC day, plus manual pull-to-refresh.
- Settings: notification toggles, force refresh, Diagnostics log (no secrets), sign out.

Out of scope unless the owner asks: multiple accounts, Android, App Store release,
purchasing, accessory store, a match widget (declined for now on 2026-09-23).

## Status

Milestones from the original plan (`~/.claude/plans/i-want-to-make-cryptic-kurzweil.md`
on the owner's machine):

| Milestone | Content | State |
| --- | --- | --- |
| M0 | `tools/probe.py`, proved cookie reauth + storefront v3 on the real account | Done |
| M1 | ValorantCore package + tests, webview login, Keychain session, plain store list | Done (build 3) |
| M2 | Liquid Glass UI, Night Market, bundles, skin detail, wallet | Done (build 5) |
| M3 | Widget, wishlist, notifications, background refresh | Done (build 5) |

The plan's "credential auto-fill with Face ID via JavaScript" was dropped; iOS Passwords
AutoFill covers it instead. See `decisions.md`.

## Build history

Version is `MARKETING_VERSION` in `ios/project.yml`; the build number is Codemagic's.

| Build | Version | What changed |
| --- | --- | --- |
| 1-2 | 0.1.0 | Pipeline smoke test (stub app) |
| 3 | 0.1.0 | M1: login, Keychain cookies, plain store list |
| 4 | 0.2.0 | Failed: widget had no provisioning profile |
| 5 | 0.2.0 | M2 + M3: full UI, widget, wishlist, notifications, once-a-day caching |
| 6 | 0.2.0 | Today/Night Market/Bundles fit on one screen; catalog refetches when the store has unknown items; wishlist search no longer capped at 60 |
| 7 | 0.2.0 | Items valorant-api.com hasn't listed show as "New item, details coming soon"; catalog check on every app open |
| 8 | 0.2.0 | Owned skins tagged in wishlist search, skin detail and bundles; store history recorded daily (no screen) |
| 9 | 0.3.0 | Matches tab (rank, RR trend, stats, match detail, rounds, kill feed, player sheets, local archive); Night Market tab removed, opens full screen from Today |
| 10 | 0.3.1 | Player names from name-service (match details send them blank); skin videos cached on disk, play with sound (mute toggle); smoother skin detail entrance from Today |

## Known limitations

- Names and art come from valorant-api.com, a community mirror. New content (e.g. the
  Champions 2026 bundle on 2026-09-23) shows as "New item" until the site adds it,
  usually a day or two. Nothing in Riot's store response carries names or images.
- The Riot session lasts as long as something reauths at least once every 30 days. If the
  phone isn't used for a month, the owner signs in again.
- Wishlist alerts depend on the widget or background refresh running after the reset,
  which iOS schedules at its discretion, so they can arrive late.
- The widget does not download the catalog itself; it uses the compact copy the app last
  saved. New names appear in the widget after the app has been opened.
- The owned list comes with the once-a-day store fetch. A skin bought today shows as
  owned after the next reset, or straight away after a pull-to-refresh.
- The match archive only starts on the first open of the Matches tab and can reach back
  as far as Riot still lists (about five weeks). Games older than that are gone for good.
- Matches refresh when the tab opens (at most every two minutes) or on pull-to-refresh;
  nothing fetches them in the background.
- Riot has blocked third-party clients by User-Agent before. If every request suddenly
  fails with 403, change `RiotAPI.userAgent` first.

## Ideas for later (not started, not approved)

Recorded so a future session doesn't lose them. Each needs the owner's go-ahead.

- A match widget (rank, last game). Would need its own refresh; declined for build 9.
- More stats from the archive: weapon accuracy, per-map side win rates, RR per agent.
- Accessory store (Kingdom Credits items; `AccessoryStore` is already in the response).
- A screen for store history ("last seen" per skin, calendar). Data is being recorded.
- Price-drop / Night Market wishlist hits highlighted in the widget.
- Interactive widget (App Intents) to open a specific skin.
- Flip the repo to private once development settles (see `development.md`).
