# Riot and valorant-api.com

These are unofficial, undocumented Riot endpoints. Verified working on the owner's account
on 2026-09-23. Sources used at the time: RadiantConnect, diegorv/Valorant-Store-Checker,
the PrometheuzzZ valorant-api-docs fork. When something breaks, check those projects'
recent commits first.

## Login (once)

The password endpoint `PUT auth.riotgames.com/api/v1/authorization` is dead behind
hCaptcha. Login is a real web page in a `WKWebView` (`LoginView.swift`):

```
https://auth.riotgames.com/authorize?redirect_uri=https%3A%2F%2Fplayvalorant.com%2Fopt_in
  &client_id=play-valorant-web-prod&response_type=token%20id_token&nonce=<random>&scope=account%20openid
```

When the page navigates to `playvalorant.com/opt_in`, the navigation is cancelled and the
cookies `ssid, clid, csid, tdid, asid` are read from the webview's cookie store (domain
`auth.riotgames.com` wins over parent-domain duplicates). The webview uses a
non-persistent data store, so cookies exist only in the Keychain afterwards. The user
should tick "Stay signed in" (`#rememberme`).

Login form field IDs (checked in a browser): `input[name=username]`,
`input[name=password]`, remember-me `#rememberme`, submit `data-testid=btn-signin-submit`.
Fill comes from iOS Passwords AutoFill only; never script it (see `decisions.md`).

## Reauth (every fetch)

`GET` the same authorize URL with a `Cookie:` header and **redirects disabled**. Riot
answers 303:

- `Location` fragment has `access_token` and `id_token`: success. `Set-Cookie` rotates
  `ssid`, `clid`, `csid` with Max-Age 30 days. **Always save the rotated cookies**; that is
  what makes the session slide forward. `tdid`/`asid` don't rotate.
- `Location` is `authenticate.riotgames.com/...login`: session expired, show login.

`StoreService` keeps the previous cookie set as `fallback` and retries with it once if the
current set is rejected (covers a crash between receiving and saving rotated cookies).

## Calls after reauth

| Step | Request | Notes |
| --- | --- | --- |
| Entitlements | `POST https://entitlements.auth.riotgames.com/api/token/v1` body `{}` | returns `entitlements_token` |
| PUUID | `GET https://auth.riotgames.com/userinfo` | `sub`; cached in the session |
| Shard | `PUT https://riot-geo.pas.si.riotgames.com/pas/v1/product/valorant` `{"id_token": ...}` | `affinities.live`; latam/br map to `na`. Owner is `ap`. Cached. |
| Client version | `GET https://valorant-api.com/v1/version` | `riotClientVersion`, sent as `X-Riot-ClientVersion` |
| Storefront | `POST https://pd.{shard}.a.pvp.net/store/v3/storefront/{puuid}` body `{}` | v2 GET died Sept 2024. 400 without a body. |
| Wallet | `GET https://pd.{shard}.a.pvp.net/store/v1/wallet/{puuid}` | |
| Owned skins | `GET https://pd.{shard}.a.pvp.net/store/v1/entitlements/{puuid}/e7c63390-eda7-46e0-bb7a-a6abdacd2433` | `Entitlements[].ItemID` = every owned skin level (level 1 included). Failure is logged and ignored; the previous list is kept. |

Match history (app only, verified with `tools/probe.py --matches` on 2026-09-23; research
checked VRY's final 2026 code and the techchrism docs, which are stale since April 2024):

| Step | Request | Notes |
| --- | --- | --- |
| History | `GET https://pd.{shard}.a.pvp.net/match-history/v1/history/{puuid}?startIndex=N&endIndex=N+20` | `{Total, History[{MatchID, GameStartTime ms, QueueID}]}`. Pages wider than 20 fail with 400 `MATCH_HISTORY_INVALID_INDICES`. The owner's account listed 89 games going back 5 weeks. |
| Details | `GET https://pd.{shard}.a.pvp.net/match-details/v1/matches/{matchId}` | 600+ KB for a competitive match, mostly `playerLocations`. 404 = gone, skipped. |
| RR | `GET https://pd.{shard}.a.pvp.net/mmr/v1/players/{puuid}/competitiveupdates?startIndex=N&endIndex=N+20&queue=competitive` | `Matches[{MatchID, TierAfterUpdate, RankedRatingAfterUpdate, RankedRatingEarned, ...}]`. Same 20 cap (`MMR_INVALID_INDICES`). |
| Rank | `GET https://pd.{shard}.a.pvp.net/mmr/v1/players/{puuid}` | `QueueSkills.competitive.SeasonalInfoBySeasonID[act].CompetitiveTier/RankedRating/NumberOfWins/NumberOfGames`. No entry = unranked this act. |
| Current act | `GET https://shared.{shard}.a.pvp.net/content-service/v3/content` | `Seasons[]` with `IsActive` and `Type` `act`/`episode`. Same game headers. |

Match details facts from real responses:
- `matchInfo.queueID` is `""` for custom games (`provisioningFlowID` `CustomGame`). Seen
  queues: `competitive`, `skirmish2v2`, `""`. Weapon UUIDs come uppercase.
- Competitive has `roundResults[].playerEconomies[]` (with `subject`); other modes only
  fill `playerStats[].economy`. `teams`, `roundResults`, `roundDamage`, `playerEconomies`
  can be null.
- Riot now sends `roundResults[].firstBloodPlayer`, `winningTeamRole`, `matchMvp`,
  `teams[].mvp`, and obfuscated `TempValue*` fields (ignored).
- `finishingDamage.damageItem` is a weapon UUID, an ability slot (`Ultimate`,
  `Ability1`, `Ability2`, `GrenadeAbility`) or `""`. Skirmish custom games use weapons
  valorant-api.com doesn't list; those show a generic icon.
- `players[].gameName` and `tagLine` arrive blank (seen on the owner's matches in build 9,
  2026-09-24). Names come from `PUT https://pd.{shard}.a.pvp.net/name-service/v2/players`
  with a JSON array of PUUIDs (game headers), which returns
  `[{DisplayName, Subject, GameName, TagLine}]`. Called once per downloaded match for its
  blank players, and once when an older archived match without names is opened.
  `Match.namesChecked` records that the lookup ran, so a player name-service has no name
  for doesn't trigger a call on every open. A failure
  is logged and the match is saved anyway. `tools/probe.py --names` checks it, printing counts only.
- Deathmatch hasn't been seen yet. The code treats anything without exactly two teams as
  free-for-all ranked by kills.

Match calls retry 429/500/502/503 twice (Retry-After, else 10 s then 20 s). Details are
fetched two at a time with 300 ms between pairs.

Game-server headers: `Authorization: Bearer`, `X-Riot-Entitlements-JWT`,
`X-Riot-ClientPlatform` (fixed base64 PC descriptor in `RiotAPI.clientPlatform`),
`X-Riot-ClientVersion`, and the User-Agent in `RiotAPI.userAgent` (one constant; Riot has
blocked apps by UA before).

## Storefront shape (parsed leniently)

- `SkinsPanelLayout.SingleItemStoreOffers` (four daily offers; `OfferID`, `Rewards[0].ItemID`
  = skin **level** UUID, `Cost[VP]`) and `SingleItemOffersRemainingDurationInSeconds`.
- `FeaturedBundle.Bundles[]`: `DataAssetID` (valorant-api bundle uuid), `Items[]` with
  `Item.ItemTypeID`, `Item.ItemID`, `BasePrice`, `DiscountedPrice`, totals,
  `DurationRemainingInSeconds`.
- `BonusStore` (Night Market) only when one is running: `BonusStoreOffers[]` with
  `DiscountPercent`, `DiscountCosts`, `IsSeen`, and `BonusStoreRemainingDurationInSeconds`.
- Also present and ignored: `AccessoryStore`, `PluginStores`, `UpgradeCurrencyStore`.

IDs:

| What | ID |
| --- | --- |
| VP | `85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741` |
| Radianite | `e59aa87c-4cbf-517a-5983-6e81511be9b7` |
| Kingdom Credits | `85ca954a-41f2-ce94-9b45-8ca3dd39a00d` |
| Item type: skin | `e7c63390-eda7-46e0-bb7a-a6abdacd2433` |
| buddy | `dd3bf334-87f3-40bd-b043-682a57a8dc3a` |
| spray | `d5f120f8-ff8c-4aac-92ea-f2b5acbe9475` |
| player card | `3f296c07-64c3-494c-923b-fe692a4fa1bd` |
| player title | `de7caa6b-adf7-4588-bbd1-143831e786c6` |
| flex | `03a572de-4234-31ed-d344-ababa488f981` |

## valorant-api.com (names and art)

Riot's store response has IDs and prices only. Everything visual comes from
valorant-api.com, fetched with `?language=en-US`:

- `/v1/weapons/skins`: indexed by `levels[0].uuid` (that is what the store sends). Uses
  `displayName`, level `displayIcon` (fallback: first chroma `fullRender`),
  `streamedVideo` on levels/chromas, `contentTierUuid`, `chromas[]` (`swatch`,
  `fullRender`). Chroma names like `"...Level 4\r\n(Variant 1 Red)"` are cleaned to `Red`;
  level items like `EEquippableSkinLevelItem::VFX` become `VFX`.
- `/v1/contenttiers`: `highlightColor` is RRGGBBAA (alpha dropped), `rank`, `displayIcon`.
- `/v1/bundles`: keyed by `uuid` = store `DataAssetID`. `displayIcon` banner,
  `verticalPromoImage`, `displayNameSubText`.
- `/v1/buddies/levels`, `/v1/sprays`, `/v1/playercards`, `/v1/playertitles`: bundle
  extras. Flex items are not fetched.
- Matches (`MatchAssets`): `/v1/maps` keyed by `mapUrl` (equals `matchInfo.mapId`, a path,
  not the uuid; The Range is listed twice), `/v1/agents?isPlayableCharacter=true`
  (abilities by `slot`, `Grenade` renamed to Riot's `GrenadeAbility`),
  `/v1/competitivetiers` (last entry is the current episode; tiers 3-27), `/v1/weapons`
  (`killStreamIcon`), `/v1/gear` (armor), `/v1/gamemodes/queues` (queue display names;
  `newmap` is renamed every season, so names aren't hard-coded).

The site lags new releases (Champions 2026 was missing on release day; its data was still
from client 13.05). The app handles that with `Catalog.missingIDs` and "New item" UI; see
`architecture.md`. There is no better free source: Riot's official content API needs an
approved key and has no images.

## Probe

`uv run tools/probe.py` runs the whole chain from Windows with a pasted Cookie header
(hidden input). It prints step names, status codes and today's skin names, never tokens.
Use it first when Riot changes something, before touching Swift.

`uv run tools/probe.py --matches` checks the match endpoints instead: page limits, how far
back history goes, one match per queue as a shape tree (keys, types, list sizes), game
enum values, and whether map/agent/weapon/armor IDs resolve on valorant-api.com. It never
prints names, tags, PUUIDs or tokens. Redirect it to a file outside the repo.

Getting the Cookie header: DevTools > Network with Preserve log on, open the authorize
URL above (the bare `auth.riotgames.com` page just errors), sign in with Stay signed in,
load the URL again, and copy the `Cookie` request header of that `authorize` request.
