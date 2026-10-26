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
- **Matches:** "Matches" title with a scope capsule on the right ("ACT V · COMP ▾": this act
  or all time, and one queue or all; remembered). Under it a strip of section pills,
  History · Overview · Agents · Maps · Guns · Rounds; the sections sit side by side, so a
  swipe or a pill moves between them, and the strip stays put. Every section counts the
  same scope; custom games and modes without two sides never count toward stats. Each
  section fits in one or two screens (owner's rule): longer content goes behind small tabs or
  "See all", labels are a word or two, and there are no "last 10" comparisons.
  - **History:** compact rank card (tier emblem with glow, act and W/L, tier, RR bar that
    fills on appear, RR sparkline of the last 20 ranked games); games grouped by day
    ("TODAY 3W 1L · +38 RR · 1.58 K/D"); map-banner match cards with the result, score,
    map · agent · time (queue first when the scope is every queue), RR chip, badge (Match
    MVP or Team MVP in gold, else place on your team), and K/D/A, PS (ACS before 13.06), HS
    and ADR; result-coloured edge; 3D deal-in. Games still downloading show as pulsing
    skeletons. The end of the list pages the archive, then Riot, but only under "All time".
  - **Overview:** win donut that draws in (win % and W/L) beside K/D, Avg PS, HS% and ADR;
    a strip of KAST, DDΔ, games and time played; the Playstyle hexagon (aim = HS% on 0–40,
    entry = FK/FD on 0–2, damage = ADR on 0–220, consistency = KAST on 40–90%, clutch = clutch
    win % on 0–60, economy = econ rating on 0–120; fixed scales, never other players)
    growing from the centre; tiles for aces, 4K · 3K, clutches won and flawless rounds.
  - **Agents:** one bar split by role (Duelist, Init, Sent, Ctrl; win % from 3 games) that
    grows in; the "Main" card (most played: portrait, win %, K/D, PS); "All agents" rows with
    a win/loss bar sized by games, win % and K/D, sortable by games, win % or K/D, first 8
    then "See all". Tapping an agent opens its page.
  - **Maps:** attack and defense rounds won as a bar mirrored from the centre; a two-column
    grid of map tiles (banner, win % chip, W/L, attack and defense bars) that pop in; a
    "Not played" tile for maps you have played Competitive on but not in this scope (Riot
    publishes no map pool). Tapping a map opens its page.
  - **Guns:** the hit figure (head, body and legs as separate shapes with gaps and no neck;
    the most-hit part teal, the others grey) beside head/body/legs %; "Kills by gun" bars with
    kills and the head % of hits in rounds that gun was bought (Riot doesn't say which gun
    each hit came from), first 8 then "See all". Ability kills, and ultimates whose weapon
    valorant-api.com doesn't list, are one violet "Abilities" row.
  - **Rounds:** round win % when you get the first kill and when you die first; win % by buy
    (pistol, eco under 2,000 average loadout, force under 3,900, full) as columns that grow
    in; clutches 1v1 to 1v5 as dots (won teal); plants, defuses and flawless rounds.
    Rounds Riot fills in after a surrender and kills of yourself or teammates never count.
- **Agent page:** hero (role · games, name, W/L and win %, portrait over the agent's tint)
  and Stats / Maps / Guns tabs: K/D, Avg PS, HS%, ADR, KAST, FK · FD and 3K/4K/ace/clutch
  tiles; one row per map; kill bars for that agent. Same scope as the tab.
- **Map page:** splash hero (games, name, W/L and win %) and Rounds / Sites / Agents tabs:
  attack and defense rounds won, pistols, games by starting side; win % after your team
  planted and on retakes, per site; one row per agent played there.
- **Match detail:** zoom transition from the card. Map splash header with the result,
  score, RR, date and length; Summary / Scoreboard / Duels / Economy tabs (Economy only in
  modes with rounds). Summary: "Your game" card (agent portrait, PS or ACS, K/D/A, HS%, ADR,
  first kills, KAST), moment chips (ace, 4K, 3K, clutch 1vN, eco win, defuse, by round), and
  the rounds strip (chip per round coloured by winner, icon for how it ended, halftime
  divider). Scoreboard: one table, names pinned while PS, K/D/A, ADR, DDΔ, HS, KAST, FK, FD
  and MK (rounds with 2+ kills) scroll sideways; your team first, sorted by PS (ACS before
  13.06); your row tinted; MVP star; party icon for people you queued with; rank icon.
  Duels: kills on and deaths to each opponent as bars from a centre line. Economy: each
  team's average loadout per round (yours teal when won, red when lost), what you spent,
  econ rating and eco + force rounds won. Free-for-all modes show one list by kills, no rounds. Every player's name#tag is shown (owner's choice;
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
