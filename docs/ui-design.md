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
the Pro Max. Wishlist, Settings and skin detail are allowed to scroll.

## Screens

- **Today:** title + wallet stack, reset countdown chip and local reset time, status
  banner (loading/signed out/error), wishlist-hit banner, 2x2 skin grid (index, tier
  badge, name, price, wishlist heart), "NIGHT MARKET IS OPEN / Ends in ..." bar (taps to
  the Night Market tab), "Updated ..." line.
- **Night Market:** title, end countdown, "Reveal all", 2x3 grid of face-down cards that
  flip on tap (revealed IDs remembered in UserDefaults; Riot's `IsSeen` also counts).
  Tab badge = unrevealed count.
- **Bundles:** one card per featured bundle (banner, name, price, time left). Missing
  from valorant-api.com: first skin art on a tier glow, name guessed from the shared
  prefix of the skin names (`Catalog.collectionName`), else "New bundle". Detail: banner,
  price, item rows; unknown items get the gold "New item / DETAILS COMING SOON" style;
  owned skins say "WEAPON SKIN · OWNED" in `Theme.owned` (mint).
- **Skin detail:** big tilting art or looping muted video, chroma swatches, level
  upgrade list with videos, price, wishlist toggle. Owned and not wishlisted: a mint "In
  your collection" pill replaces the toggle. Unknown skin: "New skin / Details coming soon".
- **Wishlist:** search every skin (all words must match, no result cap, result count
  and owned count shown), saved list, wishlist-hit banner. Tab badge = hits today.
  Owned skins get a mint "OWNED" tag; unless already wishlisted, a seal replaces the
  heart and the row dims. Owned skins never appear in the daily store or Night Market,
  so the tag only lives here and in bundles.
- **Settings:** account, region, reset time, store history day count, refresh now, notification toggles,
  Diagnostics log, widget previews (DEBUG), sign out, version.
- **Login sheet:** Riot's page in a webview, with a hint to use the Passwords key above
  the keyboard.

## Widget families

`systemSmall` (2x2 thumbs + countdown), `systemMedium` (four tiles), `systemLarge`
(four rows with names and prices + VP), `accessoryRectangular`, `accessoryInline`,
`accessoryCircular`. Wishlisted skins get a red outline. `WidgetGallery` in Settings
(DEBUG) and `-DemoWidgets YES` render them all for screenshots.
