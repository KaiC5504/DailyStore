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

The site lags new releases (Champions 2026 was missing on release day; its data was still
from client 13.05). The app handles that with `Catalog.missingIDs` and "New item" UI; see
`architecture.md`. There is no better free source: Riot's official content API needs an
approved key and has no images.

## Probe

`uv run tools/probe.py` runs the whole chain from Windows with a pasted Cookie header
(hidden input). It prints step names, status codes and today's skin names, never tokens.
Use it first when Riot changes something, before touching Swift.
