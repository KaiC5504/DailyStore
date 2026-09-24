# UI and design

## Language

- iOS 26 Liquid Glass, dark only (`preferredColorScheme(.dark)`). Native `glassEffect`,
  `GlassEffectContainer`, `.buttonStyle(.glass/.glassProminent)`.
- Every screen sits on `AmbientBackground`: a slowly drifting `MeshGradient` tinted by what
  the screen shows (Today tints to the most expensive skin's tier colour).
- Tier colour drives each card's glow, tint and shadow (`Catalog.tierColor`).
- Type: `Theme.display` (black, compressed width, uppercase) for titles and skin names;
  `Theme.label` (bold, expanded, tracked) for kickers and badges. Accent red
  `Theme.accent`, violet `Theme.violet`, gold `Theme.newItem` for items not on
  valorant-api.com yet.
- Motion everywhere: cards deal in with a 3D rotate on appear, Night Market cards flip,
  zoom navigation transitions from card to detail, pulsing/breathing SF Symbols,
  press-scale buttons (`PressableStyle`), haptics on reveal and wishlist.
- The owner's standing taste: presented and alive, never a static info dump. Keep that
  bar for new screens.

## The fit-on-one-screen rule

The app exists to make checking the store quick, so **Today, Night Market and Bundles must
show everything without scrolling** (owner's explicit request, build 6). Priority device
is the iPhone 17 Pro Max; other sizes should work too.

How it's done (`Components.swift`):

- `FitPage(minHeight:refresh:)`: a `GeometryReader` + `ScrollView` whose content is framed
  to exactly the visible height. It stays a ScrollView so pull-to-refresh works, and only
  scrolls on phones shorter than `minHeight`.
- `FillGrid`: rows that split the leftover height evenly (LazyVGrid can't). Cards use
  `maxWidth/maxHeight: .infinity` and adapt to whatever size they get.

Rules for changes: no fixed card heights on these tabs; nothing driven by scroll position
(the pages don't scroll); wallet sits beside the title instead of its own row. Check the
CI screenshot, which is a smaller phone than the owner's, so if it fits there it fits on
the Pro Max. Wishlist, Settings, skin detail, Matches and match detail are allowed to scroll.

## Screens

Tabs (build 9): Today · Bundles · Matches · Wishlist · Settings. The Night Market has no
tab because it is only live some weeks; the Today tab badge counts its unrevealed cards.

- **Today:** title + wallet stack, reset countdown chip and local reset time, status
  banner (loading/signed out/error), wishlist-hit banner, 2x2 skin grid (index, tier
  badge, name, price, wishlist heart), "NIGHT MARKET IS OPEN / Ends in ..." bar (taps to
  the full-screen Night Market; only there while one is live), "Updated ..." line.
- **Night Market:** full-screen cover from the Today bar. Title with a glass close button,
  end countdown, "Reveal all", 2x3 grid of face-down cards that flip on tap (revealed IDs
  remembered in UserDefaults; Riot's `IsSeen` also counts).
- **Bundles:** one card per featured bundle (banner, name, price, time left). Missing
  from valorant-api.com: first skin art on a tier glow, name guessed from the shared
  prefix of the skin names (`Catalog.collectionName`), else "New bundle". Detail: banner,
  price, item rows; unknown items get the gold "New item / DETAILS COMING SOON" style;
  owned skins say "WEAPON SKIN · OWNED" in `Theme.owned` (mint).
- **Skin detail:** big tilting art or looping video with sound (glass speaker button,
  remembered; plays through the silent switch and hands audio back on leave), chroma
  swatches, level upgrade list with videos, price, wishlist toggle. Videos are downloaded
  to Caches/videos (400 MB cap, oldest out) and prefetched on open, skipping Low Data
  Mode; the art dims under a spinner until the first frame. From Today and the Night
  Market (zoom transitions) the art's spin-in waits 0.45 s for the zoom to settle. Owned and not wishlisted: a mint "In
  your collection" pill replaces the toggle. Unknown skin: "New skin / Details coming soon".
- **Wishlist:** search every skin (all words must match, no result cap, result count
  and owned count shown), saved list, wishlist-hit banner. Tab badge = hits today.
  Owned skins get a mint "OWNED" tag; unless already wishlisted, a seal replaces the
  heart and the row dims. Owned skins never appear in the daily store or Night Market,
  so the tag only lives here and in bundles.
- **Matches:** "Match History" title; rank card (tier emblem with tier-colour glow, RR
  bar that fills on appear, RR trend chart of the last 20 ranked games drawn left to
  right, act W/L); form strip (last 10 as pips that pop in, win % and K/D of the last 20);
  top 3 agents and top 3 maps (games, win %, K/D; custom games excluded); queue filter
  chips; map-banner match cards (agent, VICTORY/DEFEAT/DRAW or placement, score, K/D/A,
  RR chip, ACS, queue, map, relative time; result-coloured edge; 3D deal-in). Games still
  downloading show as pulsing skeleton cards. Scrolling to the end pages the archive, then
  asks Riot for older games; the footer says when Riot has nothing older.
- **Match detail:** zoom transition from the card. Map splash header with the result,
  score, RR, date and length; "Your game" card (agent portrait, ACS, K/D/A, HS%, ADR,
  first bloods, KAST); rounds strip (chip per round coloured by winner, icon for how it
  ended, halftime divider); scoreboard by team (your team first, sorted by ACS; your row
  tinted; MVP star; party icon for people you queued with; rank icon). Free-for-all modes
  show one list by kills, no rounds. Every player's name#tag is shown (owner's choice;
  the API can't tell who hid their name). Players name-service has nothing for fall back
  to their agent name ("Name hidden" on the player sheet).
- **Round sheet:** kill feed in time order (killer, weapon kill icon or the killer's
  ability icon, victim; your team teal, enemies red), plant and defuse, loadouts per
  player (weapon, armor, value, spent).
- **Player sheet:** agent, name, rank, the same stat card, and kills/deaths against each
  opponent in that match. Nothing is looked up about their other games.
- **Settings:** account, region, reset time, store history day count, refresh now, notification toggles,
  Diagnostics log, widget previews (DEBUG), sign out, version.
- **Login sheet:** Riot's page in a webview, with a hint to use the Passwords key above
  the keyboard.

## Widget families

`systemSmall` (2x2 thumbs + countdown), `systemMedium` (four tiles), `systemLarge`
(four rows with names and prices + VP), `accessoryRectangular`, `accessoryInline`,
`accessoryCircular`. Wishlisted skins get a red outline. `WidgetGallery` in Settings
(DEBUG) and `-DemoWidgets YES` render them all for screenshots.
