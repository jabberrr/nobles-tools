# CONTEXT.md — briefing for Claude Code sessions on Nobles Tools

Read this whole file before working on the repo. Keep it accurate: it is the project's memory between sessions.

## Work rules

1. **Use subagents efficiently.** When a task has independent parts, split them across subagents in whatever configuration is most efficient (research ∥ implementation, core ∥ UI, and so on). Give each one a precise brief and an explicit file scope so they don't collide. **Always finish with a critic subagent** that reviews the work against the original goals and quality bar. Fix what it finds before calling the work done.
2. **Write high-quality code.** Code should be polished, idiomatic and sensibly structured: small focused files, clear names, concise doc comments, no dead code or debugging leftovers. Don't write code that merely works. Don't trade away much efficiency for polish either.
3. **Check work with GitHub CI.** Push to the working branch and confirm the `CI` workflow is green: the iOS build plus NoblesKit tests on macOS and Linux. Read failing logs with the GitHub MCP tools (`mcp__github__get_job_logs`) and fix until green. Local checks don't replace CI, because only CI can compile the SwiftUI/WidgetKit targets.
4. **Update this file after completing something.** Add any new context a future session would need (decisions, gotchas, verified facts, changed structure), and remove anything that has gone stale. Log the work in the **Session log** at the bottom.
5. **Add new work habits here when asked.** When the user asks for a new habit, add it to this list in the same format.

## Project brief

Nobles Tools is an iOS app (iOS 17+, SwiftUI, Swift 6) for **Noble and Greenough School** (Nobles, Dedham MA). Users create, customize and use widgets. The app UI is deliberately minimal: it is a widget designer, in the style of Widgetsmith. Users make named **designs** in the app (content settings plus a theme) and see a live preview at every size. Then they add a Nobles Tools widget to the Home or Lock Screen and pick a design from **Edit Widget**.

Widget kinds (`WidgetKind`):

| Kind | Content | Families |
| --- | --- | --- |
| `menu` | Flik dining menu for Lunch, Dinner or "Next Meal" (auto-advances as each meal ends). Filters (`MenuFilter`): everything, entrées only, no salads/soups, only chosen stations ("Just…"), everything except chosen stations. Toggle for station headers. A **featured dish** (`MenuConfiguration.featuredStation`: the first dish of a chosen station, or Automatic = first entrée) leads every size and is the only dish on Lock Screen sizes. A chosen station overrides the filter; Automatic follows it. "Just Entrées" shows nothing (with a message) when no entrée station exists. | all six: systemSmall/Medium/Large, accessoryCircular/Rectangular/Inline |
| `countdown` | Days left in the current quarter, semester or school year (`Term.Kind`), counted as school days, weekdays or calendar days. Number, ring or bar style. | all six |
| `scores` | Recent results and upcoming games for Nobles teams, filtered by sport, with a varsity-only option. | all six |
| `spending` | The signed-in student's own school-store spending (cafe chits, athletic store) from the Nobles portal. Needs the account connected in **Settings → Nobles Account** (Veracross web sign-in; only the session cookie + person id are kept, never the password). Shows total spent / remaining against an in-app limit / latest charge (`StoreHighlight`), a recent-charges list, and per-store totals. Store filter; optional spending limit set in the app (the charges endpoint doesn't carry it). | all six |

All kinds share a `Theme`: palette, font style and background style.

**Cafe Wrapped** (an app feature, not a widget kind): a Spotify-Wrapped-style story recapping the semester's cafe purchases from the same charges as `spending`. Only cafes count (`CafeWrapped.isCafe`: whole-word cafe/snack/coffee/grill/deli/kitchen; anything "athletic" is out). Ten full-screen pages, tapped through (right ~65% forward, left back; nothing auto-advances):
1. Intro.
2. Total, with a month chart.
3. Each cafe, with its top 3 items.
4. Top 5 items.
5. The #1 item wrapped in **foil shaped like it, which comes off in stages, one per tap** (5 taps, `FoilWrap`): it loosens, the top, left and right peel back, then it crumples away.
6. Busiest hours.
7. Days.
8. Records: streak, items tried, biggest buy, first buy.
9. A persona card the user taps to reveal (charge-up, flip, light burst).
10. A shareable poster.

Every stat reveals with an animation. The Total page has a cumulative spending line that draws in.
- **Item pictures:** branded items show a product photo (`CafeItemArt.productImage(for:)` → asset `product-<slug>`); everything else shows an emoji (`CafeItemArt.emoji(for:)`).
- **No spoilers:** nothing before the favorite page shows the #1 item. The top-items strip and the cafes page's row for it are foil "? ? ?" chips (`FoilSurface`), and the intro's floating emoji leave it out.
- **Words:** plain, short sentences, at the user's request ("remove all typical claudisms"). No dashes or semicolons in sentences, no puns or cute sign-offs, no "Here's"/"That's…!". Keep to this in every new string.
- **Type:** SF Pro only, never Rounded. SF Pro Expanded for headlines and big figures (the user liked the #1 item name's font), plain SF Pro elsewhere, and not too bold. Every font comes from a `WrappedStyle` token.
- **Opening it:** Settings → Cafe Wrapped has the testing buttons the user asked for "for now" (own data, or sample data).
- **Banner:** the design list shows one when `CafeWrapped.isReady`, from 6 days before a semester ends to 21 days after, and an account is connected.

The user files requests as cards on the Trello board **Nobles Tools** (https://trello.com/b/pxLsChDf/nobles-tools; the Trello MCP tools reach it). When asked to address new cards, comment on each one with what changed. Leave the **"Future (claude ignore this list)"** list alone.

Visual language (Shared/):
- A common header: an icon in an accent circle, the title, and a detail that shortens when space is tight.
- Small uppercase section labels with icons.
- Icons for stations (`Symbols.swift`, keyword-mapped), sports (`SportSymbol`) and terms (`Term.Kind.symbolName`).
- Lists show fewer items in full plus "+N more" instead of truncating.
  - The exception is a list that opts into `FittingList(hidesOverflowWhenEmpty:)`, such as the spending charges. It never shows a bare "+N more": when even one row plus the count won't fit, it shows one row without it, then nothing.
- Where space is tiny, names step down through short forms before any cut: `MenuItem.shortName`, `Game.shortOpponent`/`opponentInitials` ("BB&N"), `Game.teamVariants` ("Girls Field Hockey · MS" → "Field Hockey · MS"). Only an inline Lock Screen dish too long even in short form is cut, and then at a word.
  - The exception, at the user's request: the spending rectangular Lock Screen's latest item gets two lines of `caption2`, then one, cut at the end of the line. That shows more of the name than cutting at a word.
- Icon chips and W/L badges cut their symbol out of the accent fill, so they survive iOS's tinted and clear Home Screen modes (which keep only alpha).
- Circular Lock Screen widgets fill the widget before drawing the disc: `circularBackdrop(for:disc:)`, shared by `WidgetChrome` and the preview frame.
- Palettes must pass `PaletteTests`: text at least 4.5:1 and accent at least 3:1 on both gradient ends.

## Repository map

```
CLAUDE.md                   Imports this file, so Claude Code loads it automatically.
project.yml                 XcodeGen spec: the source of truth for the Xcode project.
NoblesTools.xcodeproj       GENERATED from project.yml by CI and committed (with App|Widgets Info.plist and
                            entitlements), so users just pull and open. Never hand-edit; change project.yml.
Config/Signing.xcconfig     Signing: the user's DEVELOPMENT_TEAM, then the optional, gitignored Config/Local.xcconfig.
NoblesKit/                  Swift package, Foundation-only (no SwiftUI). Builds on iOS, macOS and Linux.
  Sources/NoblesKit/
    Core/                   LocalDate/DateSpan (school-time-zone days), HTTPClient, AppGroup, ResponseCache
                            (last-good responses, pruned after 30 days), CachingFetcher (network → cache
                            fallback), LenientDecoding, TextMatching (accent/case-insensitive matching),
                            HTMLScanning (tag/attribute scanning plus entity decoding, no dependencies)
    Designs/                WidgetDesign/WidgetContent/Theme/Palette, DesignStore (app-group UserDefaults)
    Menu/                   Models, NutrisliceModels (lenient DTOs), MenuGrouping (rows → stations),
                            MenuFiltering (styles + highlights), MenuTypes (discovery), MenuService, preview data
    Calendar/               SchoolCalendar/Term/Countdown models, NoblesCalendar (built-in 2026–27), countdown math
    Scores/                 Game/GameFeed/Scoreboard models, NoblesAthleticsProvider (AthleticsResults JSON +
                            AthleticsSchedule HTML + AthleticsParsing), ScoresService, preview data
    Store/                  Spending: StoreModels (charge/total/statement/session/config + StoreSessionStore in
                            the app group), StoreChargesResponse (get_charges.php JSON), StoreService (authed
                            fetch + auth/offline classification + cache), Money (Decimal.usd), preview data;
                            Cafe Wrapped: CafeWrapped(+Types) (the semester recap's stats), CafePersona
                            (time-of-day buckets + persona rules), CafeItemArt (item name → food emoji),
                            CafeWrappedPreviewData (a seeded, deterministic sample semester)
  Tests/NoblesKitTests/     swift-testing tests. Fixtures/real-* are REAL captured responses; synthetic-* are hand-written.
Shared/                     SwiftUI widget views, theme mapping and formatting, compiled into BOTH app and widget
App/                        App target: DesignLibrary (state), design list, editor with live previews,
                            PreviewData (loads real data once for previews), Settings (calendar editor,
                            Nobles Account). Store/ holds the Veracross web sign-in (StoreLoginView),
                            the StoreAccount connection manager and its Settings section.
                            Wrapped/ is Cafe Wrapped: CafeWrappedView (story container), CafeWrappedLauncher
                            (loads the account's recap or the sample, with message screens), Pages/ (one per
                            page), Effects/ (FoilWrap with FoilCover/FoilMasks/FoilFinish/FoilGeometry/FoilBall,
                            FoilSurface, reveals, counting text, confetti, light burst, backdrops, shimmer, hint),
                            WrappedStyle/WrappedPage/WrappedFormat (type, palettes, wording of figures).
                            Previews/DesignWidgetContent draws a design from given data (editor + gallery);
                            Previews/WidgetGallery is every widget × size from fixed sample data;
                            Previews/WrappedGallery is every Wrapped page in its finished state.
Snapshots/                  WidgetSnapshots test target: renders WidgetGallery to PNGs (when SNAPSHOT_OUTPUT_DIR is set).
App/Assets.xcassets/        FoilTexture (a real foil photo, see Data sources) and Products/product-<slug> photos.
docs/widgets/               The rendered PNGs, committed by CI. Look at them to check layouts; the README shows them.
Widgets/                    Widget extension: WidgetBundle, four AppIntentConfiguration widgets and their
                            timeline providers, Intents/ (configuration intents and design entities)
.github/workflows/
  ci.yml                    Linux `swift test` (swift:6.1 container); macOS: XcodeGen → `swift test` → xcodebuild
                            (default signing, like a fresh clone) → commits the regenerated project on push
  api-smoke.yml             Weekly live check of the menu API and the athletics sources (prints response shapes)
  capture-fixtures.yml      Manual: commits real menu and athletics responses into NoblesKit test fixtures
  render-widgets.yml        Renders WidgetGallery on a simulator and commits PNGs to docs/widgets (on view changes)
.github/scripts/            Workflow helpers: commit-xcode-project.sh, commit-renders.sh, extract-schedule.py
```

Identifiers:
- Bundle IDs `app.dabora.noblestools` and `app.dabora.noblestools.widgets`.
- Team `6W4ZKDHBVD`, set in `Config/Signing.xcconfig`.
- App group `group.app.dabora.noblestools` (`AppGroup.identifier`).
- URL scheme `noblestools://design/<uuid>`, which opens that design's editor.

## Architecture

- **NoblesKit holds all the logic.** It does networking, decoding, filtering, calendar math and persistence. Keep it free of SwiftUI and WidgetKit so it stays testable on Linux. Use `#if canImport(FoundationNetworking)` for Linux, and guard Darwin-only APIs with `#if canImport(Darwin)`.
- **Shared/ views are the single rendering path.** The widget and the app's live preview use the same views.
  - The widget size is a `family:` parameter, because `\.widgetFamily` can't be set outside WidgetKit.
  - Theme colors are resolved once and passed in: by `WidgetChrome` in the widget, and by `WidgetPreviewFrame`/`DesignPreview` in the app. `WidgetChrome` also applies `containerBackground` and the deep link.
- **Persistence:** `DesignStore` stores JSON in app-group `UserDefaults`, under versioned keys (`designs.v1`, `designs.seeded.v1`, `calendar.v1`).
  - It is a `Sendable` struct, so widget timeline providers use it directly.
  - Every settings field decodes with a default when it's missing or unreadable (e.g. a removed enum case). The design list decodes lossily, so one corrupt design can't wipe the rest. Only a design without a readable `id` or `content` is dropped.
  - The app wraps the store in a `@MainActor @Observable` `DesignLibrary`. It saves 500 ms after the last edit, and immediately when the app leaves the foreground. It then reloads only the affected widget kind (`WidgetCenter.reloadTimelines(ofKind: kind.timelineKind)`).
- **Widget configuration:** each widget has an `AppIntent` with one optional design parameter. There is one concrete `AppEntity` type per kind, because AppIntents metadata can't handle generic entities. If no design is chosen, or the chosen one was deleted, the widget uses the first saved design of that kind, else `WidgetDesign.makeDefault(kind)`.
- **Timelines:**
  - Menu: entries at now and at the next meal hand-off (`upcomingMenus(limit: 2)`), plus each school midnight for "Today"/"Tomorrow" labels; it reloads at the hand-off, at most 6 h out.
  - Countdown: one entry per school midnight.
  - Scores: refreshes every 2 h, or every 60 min on game days. It also adds an entry at the next school midnight, so the "Today" labels and the results/upcoming split move to the new day.
- **Offline:** `ResponseCache` keeps the last good raw response per URL in the app-group container. Services fall back to it on network errors. The scores feed also reports the cache time (`GameFeed.fetchedAt`), so the widget can show "Updated 4h ago" once data is older than its 2 h refresh.
- **App previews:** `PreviewData` fetches each data source once and filters locally per design, so toggling settings never re-fetches. It falls back to sample data, labelled as such, when offline.
  - Spending previews show the connected account's own statement, or its cached copy badged as the widget would show it. They use the sample only when no account is connected.
  - `PreviewData.storeSession` is the account they show. Settings changes the account through its own `StoreAccount`, so `DesignListView` calls `refreshStoreSession()` when the Settings sheet closes. That drops the old account's spending and its load times, then every spending preview loads the new account (the request key carries the session). Anything else that ever connects or disconnects must call it too.
- **Cafe Wrapped data:** `CafeWrappedLauncher` reads `PreviewData.spending` (the connected account's statement, or its cached copy), and the semester comes from `CafeWrapped.semester(in: library.calendar, on:)`. During the 21 days after a semester ends, the recap stays on that semester, even when the next one has started. A cached statement is recapped only up to the day it was fetched, and the launcher first says so ("Your recap stops at …"). All the stats math is in NoblesKit and tested; the app only draws it.
- **Dates:** use `LocalDate` and `Calendar.school` (America/New_York) for anything that is a school day or a meal time. Never use the device time zone for school logic.

## Data sources (verified facts)

### Menus: Flik Independent School Dining, served by Nutrislice (verified 2026-10-25)
- Base URL: `https://nobleandgreenough.api.flikisdining.com/menu/api`. School slug: `noble-and-greenough-school`.
- `GET /schools/` lists active menu types: **Lunch (`lunch`, id 2800)** and **Dinner (`dinner`, id 3154)** only. **There is no breakfast menu.** `menu-type/breakfast/...` returns 404. The app discovers menu types at runtime, so a future breakfast menu would show up automatically.
- `GET /weeks/school/{school}/menu-type/{slug}/{yyyy}/{MM}/{dd}/` returns the Sunday–Saturday week containing that date. Top-level keys: `bold_all_entrees_enabled, days, id, last_updated, menu_type_id, start_date`.
- **Nobles' items are mostly text-only.** A dish row has `food: null` and the dish name in `text`. Some rows have a `food` object with `name`, but `food_category` is always `""`. Item `date` is null; use the day's date. Rows with empty `text` and no food are icons or spacers; skip them.
- Station headers have `is_section_title: true` and `is_station_header: true`, with the title in `text`.
  - Lunch stations: Soup Station, Hot Entree, Vegan Entree, Sides, Weekly Composed Salad, Dessert, plus themed specials (e.g. "Dracula's Cookie Extravaganza").
  - Dinner stations: Hot Entree, Sides, Vegan Option, Dessert.
  - Because categories are empty, entrée and soup/salad detection is based on station titles.
- Dinner is served Monday–Thursday. Friday shows only a "No Dinner Services" header.
  - A header with no dishes under it is dropped. On a day with no dishes at all, its headers and holiday rows are kept as `DailyMenu.notes`.
  - Widgets don't show notes yet: `upcomingMenu` skips ahead to the next day that has dishes.
- Service end times used for auto-advance (`Meal.serviceEnds`): lunch 1:30 pm, dinner 7:00 pm. These are estimates. The Nobles dining page lists dinner as 5–7 pm Mon–Thu.
- The sandbox network policy blocks this host for Claude Code cloud sessions. Use the CI workflows to reach it (see Environment gotchas).

### Scores: Nobles Athletics (no live source exists)
- Research found **no official live, in-game score source** for Nobles. The Nobles athletics portal (`nobilis.nobles.edu/Athletics/`, home-built PHP), the ISL site (islsports.org, on rSchoolToday/Arbiter) and MaxPreps all post **finals only**, after games.
  - MaxPreps' ToS forbids scraping.
  - ScoreStream has sporadic fan-reported live scores but no public API.
- Sources used by `NoblesAthleticsProvider` (verified 2026-10-25, no auth needed):
  - **Results:** `https://nobilis.nobles.edu/Athletics/endpoints/latest_results.php?page=1`. Nobles' "Latest Results" page loads this JSON, which returns the 100 most recent results, newest first. Fields: `event_id`, `team_name`, `athletic_opponent`, `game_score_us`, `game_score_opponent`, `formatted_start_date` (M/d/yyyy, no time), `outcome` (W/L/T), `score`.
    - Trust `outcome`, don't compute it: cross country "15-59" is listed as an L.
    - Scores are strings or null. Middle school rows often have an outcome with no real score (`"0"`/null, `score: ""`).
    - The opponent can be the string `"None"`.
    - Results lag games by about a week.
  - **Upcoming:** the "Upcoming Schedule" sidebar on `https://nobilis.nobles.edu/Athletics/` (HTML) covers about the next 6 days. Each `<div class="ath-row ath-click">` carries `data-date` (MM.dd.yy), `data-team`, `data-opponent` (HTML-escaped), `data-homeaway`, `data-loc`, `data-start`/`data-end` ("4:00 PM"), `data-result` and `data-type`. `calendar.php` has the full season but mixes in practices and weighs 800 KB.
  - Team strings look like "<Sport> [Boys|Girls] <Level>", e.g. "Volleyball Girls JV A", "Soccer Boys 3rd", "Cross Country Middle School".
- Dead: the old XML web service `.../WebServices/gameschedule.php?eventtypes=ContestResults` returns HTTP 500. It was found in a 2022 student app.
- These are undocumented internal endpoints and could change without notice. `api-smoke.yml` checks them weekly. If they break, re-run `capture-fixtures.yml` and adapt the parser.

### Cafe Wrapped's images (licenses)
- `FoilTexture`: cropped from "Crumpled Tin Foil" by Kevin M. Gill (Flickr, via Wikimedia Commons), **CC BY 4.0**. The light was evened out so it reads as flat silver.
- `Products/product-<slug>`: front-of-pack photos from **Open Food Facts** (CC BY-SA 3.0). The brands' own "official" images are copyrighted and can't go in this public repo, so these stand in. Both are credited in Settings → Photo Credits.
- Source barcodes, so a photo can be refreshed from `world.openfoodfacts.org/api/v2/product/<code>`: arnold-palmer 0613008730895, bodyarmor 0858176002584, boxed-water 0858276004068, cheetos-crunchy-hot 0028400589895, cheetos-puffs 0028400242929, cheez-it 0024100106851, chex-mix 0016000159907, chobani-yogurt 0818290011534, core-power 0811620021951, cup-noodles 0070662038031, doritos 0028400090896, fairlife 0856312002795, gatorade-bar 17058599, goldfish 0014100085478, haribo 0042238302815, izze 0836093010974, lays 0028400323826, miss-vickies 0028400168731, naked 0082592660152, nestle-cocoa 0050000140022, oh-snap 0074329123399, oreo 0044000032029, oreo-ice-cream-sandwich 0075856078701, polar 0071537020359, popcorners 0810607020703, powerade 0049000032789, quaker-oatmeal 0030000567296, rice-krispies-treat 0038000265013, rxbar 0193908001764, smartfood 0028400020008, stacys 0028400094405, sunchips 0028400147415, swoon 0858344005591.
- Items with no good photo keep their emoji: the Chobani drink (an explicit no-photo entry, so it doesn't borrow the cup's), Pirate Booty, Chips Galore, King pretzels. A slug with no asset falls back to the emoji in the app too.

### School calendar (estimates)
- Nobles' full calendar requires a family login, so the built-in `SchoolCalendar.nobles2026_27` is **estimated**. Users can edit it in Settings → School Calendar.
- Structure: two semesters, each split into quarters. Grades go home in October, December, March and June.
- High confidence: graduation is the Friday after Memorial Day, so **2027-06-04**.
- Everything else is estimated: first day 2026-09-08, Q1 end 10-30, S1 end 12-18, Q3 2027-01-04…03-12, March break 03-13…03-28, plus the usual Monday holidays. Replace these with real dates if anyone obtains the calendar, or its iCal export from the logged-in Nobles portal.

### School store spending (authenticated; verified 2026-11-09)
- The store pages live under `https://nobilis.nobles.edu/SchoolStoreNew/` and are gated by **Veracross OAuth SSO**. A logged-out request to `parent_limits.php` 302-redirects to `accounts.veracross.com/nobles/oauth/authorize?client_id=…&scope=sso` then the Veracross login (which has a reCAPTCHA). The whole directory requires a logged-in `nobilis` PHP session (`PHPSESSID`).
- **Sign-in is done in-app**, not scraped: `App/Store/StoreLoginView.swift` loads `parent_limits.php` in a `WKWebView`; the user signs in on the real Veracross page; on landing back on the `nobilis.nobles.edu` `SchoolStoreNew` page the app reads the person id/name from the live DOM (`a[href*="person_id="]`) and the `nobles.edu` cookies, and saves a `StoreSession` (cookie + personID + personName) via `StoreSessionStore`. **The password is never read or stored.** For a parent with several children it shows a picker.
- **Data endpoint:** `GET …/SchoolStoreNew/get_charges.php?child_id=<personID>` with the session cookie returns JSON: `charges[]` (`charge_id`, `store_id`, `store_name`, `trans_type`, `description`, `quantity`, `total_cost` "4.00", `sales_tax`, `created` "yyyy-MM-dd HH:mm" **in UTC**, `posted_on` "yyyy-MM-dd" or null = pending), `totals_by_store[]`, `grand_totals`. Money is strings → `Decimal`. The fixture `Fixtures/synthetic-store-charges.json` has the real response's shape with made-up values. The user's own response was the fixture at first; at their request it was replaced with random numbers and generic items. Never commit real charge data: the repo is public.
- Not-signed-in → the endpoint 401/403s or returns the Veracross login wall; `StoreService` classifies those as `.notAuthenticated` (vs `.unavailable` for network/parse) and **caches only a clean parse**, so a login wall is never cached. The widget then shows the last cached figures with "Sign in to refresh" and the app re-connects.
- **Limits and gift-card balance are NOT fetched.** They only appear in `parent_limits.php`'s server HTML (the sample we have is a macOS "Copy", not the real DOM), so the spending limit is entered in the app (`StoreConfiguration.limit`) for the progress bar/ring. To auto-read them later, capture the real View-Source of `parent_limits.php` and parse the Limits table (groups: Athletics = Athletic Store; "Cafe2000 + Gleason Hall Snack Bar" = Cafe 2000 + Cafe at Gleason Hall).
- These are undocumented internal endpoints keyed to the signed-in account; only the user's own data is ever read. No weekly smoke test (it needs a login).
- The sign-in web view uses the persistent `WKWebsiteDataStore.default()`, so a later Connect reconnects without typing anything. Disconnect, or a rejected sign-in, clears that store.
- The sign-in sheet covers `SchoolStoreNew` pages with a "Connecting to Nobles…" panel, then shows "Connected" for a moment before closing. Before this, a Reconnect that needed no typing flashed the spending page and shut. Sign-in pages and any other portal page stay visible. A failed capture, or cancelling the account picker, ends the cover or the sheet.
- **`created` is UTC (verified 2026-11-10).** It was first read as school-local. The real purchases only fall inside the cafes' posted hours when read as UTC, and they move an hour with the November DST change. An athletic-store charge at "21:03" is 5:03 PM, not 9 PM.
- **The cafe menus are public:** `https://nobilis.nobles.edu/SchoolStoreDev/menu_print.php?store_id=5&window_id=3` (Cafe at Gleason Hall, mornings: Mon–Fri 8:30–10:45 AM) and `?store_id=3&window_id=2` (Cafe 2000, afternoons: Mon/Tue/Thu/Fri 2:30–6 PM, Wed 1:30–6 PM). Charge `description`s are the menu item names as printed, without the flavor line. Both samples (`StoreStatement.sample(now:)`, `CafeWrapped.sample`) use only these items, prices and hours; `Tests/…/Support/CafeMenus.swift` holds them for tests.
- **Unknown until tested on a device:** whether `get_charges.php` returns the whole school year or only recent charges. Cafe Wrapped assumes the whole semester; the fixture's shape spans Sep 10 – Nov 9.
- **Unknown until tested on a device:** how long a `nobilis` PHPSESSID stays valid for the widget. PHP's default idle lifetime is 24 minutes; once the session lapses, the widget shows "Sign in to refresh".

## Building and testing

- macOS: pull, then `open NoblesTools.xcodeproj`. It's signed with the user's team, so it runs on a simulator or their iPhone with no setup. Another team can be set on one Mac via the gitignored `Config/Local.xcconfig`. After changing `project.yml` locally, regenerate with `xcodegen generate`, or push and let CI do it.
- **Versions** live in `project.yml`: `MARKETING_VERSION` (1.0) and `CURRENT_PROJECT_VERSION`, the build number (2). Bump them there, never in Xcode, and let CI regenerate the project.
- Package tests: `swift test --package-path NoblesKit`.
- **Linux or cloud sandbox (no Xcode):** NoblesKit can still be built and tested with Docker:
  ```sh
  (nohup dockerd >/tmp/dockerd.log 2>&1 &); sleep 5     # the daemon isn't running by default
  docker pull swift:6.1-noble                            # Docker Hub is reachable
  docker run --rm -v "$PWD/NoblesKit:/pkg" -w /pkg swift:6.1-noble swift test
  ```
  The App, Widgets and Shared targets (SwiftUI/WidgetKit/AppIntents) only compile in CI on macOS.
- CI builds with `xcodebuild build -project NoblesTools.xcodeproj -scheme NoblesTools -destination 'generic/platform=iOS Simulator'`. There's no signing override, so the build proves a fresh clone builds as-is. Then `.github/scripts/commit-xcode-project.sh` commits the regenerated project. When the branch moves mid-run, the script regenerates from the new tip instead of replaying an older project. As of 2026-10-25 the `macos-15` runner's latest stable Xcode is **26.3, with the iOS 26.2 SDK**. A full CI run takes about 3 minutes.
- **Seeing the widgets without Xcode:** push a change under `Shared/`, `App/Previews/`, `Snapshots/`, `NoblesKit/Sources/` or `project.yml`.
  - The "Render widget previews" workflow renders `WidgetGallery` and commits the PNGs to `docs/widgets/` (about 6 minutes). Then `git pull --rebase` and open the PNGs with the Read tool.
  - Renders are @2x, on an opaque backdrop, and quantized with pngquant to keep the repo small. The sample data and the moment are fixed (Tue 2026-10-27 11:30), so a render only changes when the views do.
  - The gallery covers every widget × size, themes in light and dark, compact iPhone sizes (`-compact`), a tinted-mode simulation (`-tinted`, approximate) and stress cases. About 100 widget images, plus about 30 of Cafe Wrapped.
  - Add a variant for any new layout or stress case.
  - Cafe Wrapped's pages render too, as `wrapped-*` (from `WrappedGallery`): phone-sized, at 1× to keep the repo small, with simulated safe-area insets. In snapshots, `\.wrappedIsStatic` is true, so every reveal, counter and foil state draws its finished state on the first body evaluation. No time passes in `ImageRenderer`, and `onAppear`/tasks don't run. The render workflow also triggers on `App/Wrapped/**`.
  - To review many renders at once, tile them into labelled contact sheets with Pillow (installed in the sandbox), about 12 per image, and read those. Review every render of a widget you changed, not a sample.
- **Watching CI from the sandbox:** the repo is public, so `curl https://api.github.com/repos/jabberrr/nobles-tools/actions/runs/<id>` works. Poll it in a background `until` loop rather than sleeping. Read failure logs with `mcp__github__get_job_logs`.
- **Intermediate commits:** add `[skip ci]` to the commit message when pushing work-in-progress that isn't meant to build yet. It skips every push-triggered workflow.

## Environment gotchas (Claude Code cloud sessions)

- The sandbox's network policy blocks `*.flikisdining.com`, `nobles.edu` and most other sites. `WebFetch` fails DNS for nearly every host. `WebSearch`, PyPI, npm, Docker Hub and github.com (git) work.
- **To see live API data, run it in GitHub Actions and read the logs** with `mcp__github__get_job_logs`. Artifact downloads (blob storage) are blocked.
- **To bring outside files into the repo** (photos, menus), push a temporary workflow that downloads them and commits them to the branch, review them, then delete the workflow and the downloads. Open Food Facts' `cgi/search.pl` answers 503 under load; `search.openfoodfacts.org/search?q=…` and the product API by barcode work.
- **To bring real responses into the repo,** dispatch `capture-fixtures.yml`: `mcp__github__actions_run_trigger` with method `run_workflow`, `workflow_id: capture-fixtures.yml` and the branch as `ref`. It commits the responses to that branch; then `git pull`. Re-capturing changes the content the `real-*` tests assert on, so update those tests in the same change.
- If `git push` returns 403 "Claude doesn't have GitHub access", the Claude GitHub App needs to be installed on the repo. Ask the user.
- **Pull before you push.** After a push that changes the project (new or removed files, `project.yml` edits), CI adds a "Regenerate Xcode project" commit to the branch. Run `git pull --rebase` before the next push.

## Conventions

- Swift 6 language mode everywhere; iOS 17 deployment target. Don't use iOS 18+ APIs without an `if #available` guard.
- **Never compare `Date`s with `<=` or `>=`, and never pass them to `max(_:_:)`, which uses `>=`.** Use `Date.isAtOrBefore(_:)` and `Date.later(_:)` (`NoblesKit/Core/DateOrdering.swift`), or `<`, `>` and `==`.
  - Foundation marks `Date.<=`/`>=` `@backDeployed(before: FoundationPreview 6.4.2)`. iOS 27.2 beta claims that version but doesn't ship the symbols, so the call jumps to address 0.
  - TestFlight build 4 crashed this way at launch, in `Game.hasStarted`. `min(_:_:)` uses `<` and is safe.
  - CI runs `.github/scripts/check-date-operators.sh` on the built app. It fails if any binary in it references either operator.
  - The script first compiles a one-line canary to prove the SDK produces the reference at all. With an older SDK it only warns.
  - CI's Xcode 26.3 is such an SDK: the step only warns there. The crashing build came from a newer Xcode on the user's Mac. The check takes effect once CI's Xcode has the back-deployed operators. Moving CI to a newer runner image would make it effective now.
  - `LocalDate` is our own `Comparable` type, so its `<=` is fine.
- In AppIntents types, use computed static properties (`static var title: LocalizedStringResource { "…" }`). Stored `static var` is a Swift 6 concurrency error.
- **New persisted fields must decode with a default** (`container.decode(.key, or: default)` from `LenientDecoding.swift`), so designs saved by older builds keep loading.
- Inside `extension Binding`, a bare `max(...)` or `min(...)` resolves as a dynamic member lookup. Write `Swift.max`. CI caught this once.
- **Widget layout gotchas** (learned from the renders):
  - Stacks can truncate wrapping text even when everything fits. Pin each wrapping `Text` with `.fixedSize(horizontal: false, vertical: true)`.
  - Don't nest `ViewThatFits`: an outer one measures only the inner one's first child. Use `FirstFitting` (`TextFitting.swift`), which takes one flat list of variants (a `ForEach` inside a single `ViewThatFits`).
  - The system `Gauge` renders out of proportion in ImageRenderer, so progress is drawn with `ProgressViews.swift`: `ProgressBar` (home + rectangular lock) and `ProgressRing` (spending's circular lock). A capacity `Gauge` showed the spending ring's fill wrong in the snapshot renders; the drawn ring matches the bar and the centered amount exactly.
  - The preview frame draws a stand-in for `AccessoryWidgetBackground` on circular Lock Screen previews.
  - Never give secondary text `layoutPriority` over a figure on the same line: the figure gets squeezed to a single glyph (the spending rectangular showed "$" this way). Stack lines instead, and let a figure shrink (`minimumScaleFactor`) rather than ever truncate.
  - **`accessibilityFocused` makes `ImageRenderer` draw nothing at all**, not even backgrounds. Every Wrapped page rendered blank until `CafeWrappedView` stopped applying it in static mode. A `.transition` or `.id` is fine.
  - **Inside a `Canvas`, `ImageRenderer` skips `GraphicsContext` filters (`.alphaThreshold`, `.blur`) and some blend modes.** The first item-shaped foil used the "metaball" blur-and-threshold trick. It rendered as a square with the item's silhouette painted on top. It's now plain SwiftUI: the silhouette stamped in a ring inside `.mask {}`, with holes cut by `.blendMode(.destinationOut)` in a `.compositingGroup()`, which renders. It hasn't been seen on a device yet.
  - An `alignmentGuide` set inside a view that `wrappedReveal` (or another modifier) wraps didn't take effect: the bar charts' figures landed inside their bars. Stack a label above its view instead, in a fixed-height slot so it can overhang.
  - **Check every render of a widget you change**, including the default design at each Lock Screen size and the `-compact` ones. The rectangular bug above was visible in its render, but only the limit variant was looked at.
- **Animation under Swift 6:** don't conform a `View`/`ViewModifier` to `Animatable`, because its nonisolated `animatableData` clashes with main-actor isolation. Drive motion with `@State` + `withAnimation`, `TimelineView` (paused or throttled when idle), `PhaseAnimator`/`KeyframeAnimator`, or `Shape`s. Wrapped's particle effects draw in one `Canvas` each, not one view per particle. Every Wrapped effect honors Reduce Motion.
- **Present sheets from a screen's `NavigationStack`, never from inside a `Form`/`List` row** (a `.sheet` on a `Section` lands on its rows). A row-attached sheet is dismissed as soon as the list refreshes that row: the spending sign-in sheet opened and closed at once this way. `SettingsView` owns `StoreAccount` and presents `StoreLoginView`; `StoreAccountSection` only asks to connect.
- Tests use swift-testing (`import Testing`, `@Test`, `#expect`). Never touch the network in tests: inject a fake `HTTPClient` (`Tests/NoblesKitTests/Support/FakeHTTPClient.swift`). Prefer the `real-*` fixtures.
- Model enums expose `displayName` (and `symbolName` where useful) for UI. Keep UI strings in the models only when they are shared between app and widget.
- The committed `NoblesTools.xcodeproj` is generated output. Change `project.yml`, and let CI regenerate the project (or run `xcodegen generate` on a Mac) rather than editing it in Xcode.
- Signing lives in `Config/Signing.xcconfig`, never in the project file. When a push edits generated project files directly, CI regenerates them and then **fails**, listing the replaced lines (`commit-xcode-project.sh`). Port those settings into `project.yml` or the xcconfig. This happened once: the user set the team and bundle ID in Xcode, and a regeneration silently undid them before the guard existed.

## Open questions and next steps

- Get the real 2026–27 calendar (quarter ends, breaks) and update `NoblesCalendar.swift`. Consider supporting an iCal URL import.
- The athletics endpoints are unofficial. Ask Nobles Athletics (athletic_info@nobles.edu) for an official feed or blessing. For a longer upcoming window, consider parsing `calendar.php` games (skip `.is-practice`).
- Confirm meal service end times with the dining hall.
- Cafe Wrapped: on a device, check the foil's feel and performance, whether the charges endpoint covers the whole semester, and the share sheet. The Settings testing buttons are meant to go once it's trusted ("for now").

## Session log

Newest last. Add an entry after each piece of work. Keep each to a few lines: what changed and anything surprising.

- **2026-10-25: initial build.**
  - Researched the data sources and probed the live APIs from CI.
    - Breakfast doesn't exist.
    - The XML athletics feed is dead; results come from JSON and the schedule from HTML.
    - The calendar is login-only.
  - Captured real fixtures and built NoblesKit (103 tests), the app, the three widgets and CI.
  - Ran a critic review: no blockers, 27 findings. Fixed them in a second round (shared API contract in parallel core/UI agents), then a final critic pass verified the fixes.
  - CI is green on Xcode 26.3 with no compiler warnings.
- **2026-10-26: commit the generated Xcode project.**
  - The user asked to "just pull" instead of running XcodeGen.
  - CI's macOS job now builds with the project's real signing settings, as a fresh clone would. That build is verified to succeed for the simulator with no development team.
  - CI then commits `NoblesTools.xcodeproj`, the Info.plists and the entitlements whenever they change.
  - Signing moved to `Config/Signing.xcconfig`, plus the gitignored `Config/Local.xcconfig`.
  - A critic pass hardened the commit step (`.github/scripts/commit-xcode-project.sh`). It regenerates on push races, skips tags and deleted branches, and commits every generated file. Tested against a local bare repo with a fake xcodegen.
- **2026-10-29: widget redesign.**
  - Fixed signing first: the user's team and bundle ID (`app.dabora.noblestools`), edited in Xcode, had been undone by CI's project regeneration. They now live in `project.yml` and `Config/Signing.xcconfig`, and CI fails loudly on hand-edits to the generated project.
  - Built the render pipeline (`WidgetGallery`, the `WidgetSnapshots` target, `render-widgets.yml` → `docs/widgets`) so layouts can be checked by eye.
  - A designer agent iterated against the renders:
    - a shared header and icon style, with station, sport and term icons;
    - all six sizes for every widget;
    - the featured dish (a station picked in the editor, or Automatic), which is the only dish on Lock Screen sizes.
  - A critic pass found a real-device bug the renders couldn't show (the circular disc sized to its content), a featured-dish fallback that ignored the filter, glyphs lost in tinted mode, Sunset contrast, and scores losing gender and level. All fixed and re-rendered.
  - NoblesKit has 118 tests. CI and the renders are green.
- **2026-11-10: Spending widget (4th kind).**
  - The user found the Nobles school-store pages and asked for a widget of their own cafe/store spending. Probed `SchoolStoreNew/` from a throwaway Actions workflow: it's Veracross OAuth; the user confirmed `get_charges.php` 401s for other accounts and supplied a real JSON sample.
  - Built against a fixed contract (`scratchpad/store-contract.md`) with three parallel agents (CORE/NoblesKit, APP, WIDGETUI) + a critic: NoblesKit `Store/` (service, parser, session, preview data, +13 tests → 131), in-app Veracross `WKWebView` sign-in that keeps only the session cookie + person id, and the `spending` widget in all six sizes.
  - CI compiled first try. The critic found no compile/logic/privacy defect; the render pass then caught two UI issues I fixed: medium truncated item names (now the figure sits above full-width charge rows) and the Lock Screen limit read ambiguously (the circular ring + centre and the rectangular figure now agree, via `ProgressRing`).
  - Limits/gift-card balance aren't in the charges endpoint, so the limit is set in the app; auto-reading them needs the real View-Source of `parent_limits.php` (see Data sources). Nothing has been seen on a device; the live auth path can only be tested there.
- **2026-11-10: first device test of Spending.**
  - The user reported two bugs.
    - "Connect Nobles Account" opened the sign-in sheet and closed it at once: the `.sheet` was on the account `Section` inside the Settings `Form`. It now lives on Settings' `NavigationStack` (see Conventions). The web view also gained a `WKUIDelegate`, so identity-provider pages that open a new window load in place.
    - The rectangular Lock Screen widget showed "a weird cut-off character": the latest item had priority beside the amount and squeezed it to "$". It's now three stacked lines (title, figure + "of $300"/"left"/"latest", then a bar or "Last: …").
  - One `StoreContent.Meter` now drives every bar and ring. It measures what the figure says (spent of the limit, or what's left of it), with matching captions: "$163 left of $300" on the Home Screen, "of $300"/"left" on the Lock Screen.
  - The rectangular Lock Screen shows "Sign in to refresh"/"Updated 4h ago" when its data is stale.
  - A critic pass found that Disconnect left the sign-in web view's cookies, so the next Connect silently reused the old session: the sheet opened and closed again, and switching accounts was impossible. `StoreAccount` now clears `WKWebsiteDataStore.default()` on Disconnect and on a rejected sign-in. The sign-in sheet is the app's only web view.
  - Also from that pass:
    - Capture no longer latches onto an intermediate page with no account on it.
    - The sheet can't be swiped away mid sign-in.
  - The gallery gained compact Lock Screen renders for the limit design, a spent-of-limit design, the latest-charge design, four-digit amounts and a signed-out state.
  - Still unverified on a device: whether the Veracross sign-in completes. If Nobles' Veracross sends students to Google sign-in, Google may refuse embedded web views ("this browser may not be secure").
- **2026-11-10: Trello cards, Spending (first board pass).**
  - Limit field: the "$" sits against the amount or "None", and tapping the row edits it.
  - "Remaining" with no limit now says so in the editor and jumps to the limit field. Widgets still fall back to the total spent until a limit is set.
  - Editor previews and list thumbnails show the connected account's own spending (see Architecture). The "sample spending" note appears only when no account is connected, and an expired sign-in says so.
  - The rectangular Lock Screen's latest item gets two lines (see Visual language).
  - The user's real charges are gone from the tree: a seeded-random synthetic fixture and a new `StoreStatement.sample`, with 132 tests. They are still in git history; rewriting that needs a force-push and the user's go-ahead.
  - `Decimal.usd` rounds half-up as documented. `NumberFormatter`'s default half-even showed $222.50 as "$222".
  - The new sample's long newest item exposed a medium-size regression: no charges at all. A row plus "+N more" no longer fit under the figure, and the list hid a bare count.
    - Medium now puts the figure's label beside it.
    - `FittingList(hidesOverflowWhenEmpty:)` falls back to one row without the count, then nothing.
  - All 38 Spending renders were reviewed via a contact sheet (PIL tiling in the scratchpad), which is quicker than opening each PNG.
  - A critic pass found that previews could keep showing a disconnected account's spending, and that list thumbnails never noticed a connect. `PreviewData` now holds an observable `storeSession`, refreshed when Settings closes, and drops stale loads.
  - Follow-ups:
    - Disconnect, and a rejected sign-in, also delete the cached charges (`StoreService.forgetCachedStatement()`). Before, they lingered on the device and could show under the next account.
    - Settings has **Reconnect**, which keeps the web view's Veracross login, so an expired session can be renewed without Disconnect wiping everything. Veracross's own cookie lasted 30 minutes in the probe, so expect to type the password again after that.
    - The editor form dismisses the keyboard on drag. Choosing "Remaining" focuses the limit field a turn later.
    - Medium with a limit labels its figure "left of $300" and drops the bar's caption, so a charge row fits.
    - A latest-charge design leaves that charge out of its list.
    - A rejected session isn't re-sent on every preview.
- **2026-11-10: Cafe Wrapped.**
  - The user asked for a semesterly "Cafe Wrapped" with:
    - stats on favorite items and times, per cafe, with no athletic store;
    - animations on every reveal;
    - a foil "tap to unwrap" of the #1 item's picture;
    - totals;
    - a testing button.
  - Built against a contract (`scratchpad/wrapped-contract.md`) by three parallel agents:
    - CORE: NoblesKit stats, the emoji map and the seeded sample (+27 tests).
    - FX: the foil, built from Canvas-drawn triangular facets that tear away near each tap and tumble off in 3D, plus the reveal, counting, confetti, backdrop and shimmer primitives.
    - STORY: the ten pages, the launcher, the Settings section, the banner and the gallery.
  - CI compiled on the first push. Every page rendered blank, which turned out to be `accessibilityFocused` (see Conventions).
  - A critic pass found five real problems, all fixed:
    - A quick 6th tap after the unwrap fell through and turned the page.
    - A cached statement was recapped as the whole semester.
    - The banner vanished, and the recap showed the empty new semester, on Jan 4–8.
    - The #1 "Iced Vanilla Latte" got a steaming ☕️ (iced drinks are now 🧋).
    - First and biggest purchase showed twice when they were the same charge.
  - Also from that pass:
    - Cafes are matched by whole words.
    - The times headline follows the busiest hour.
    - Each cafe lists its top 3 items.
    - Secondary text on cards is brighter, now ≥ 4.5:1.
    - Shimmers pause between sweeps.
    - VoiceOver can tear the foil.
  - NoblesKit has 166 tests.
- **2026-11-10: Trello cards, Cafe Wrapped (second board pass), and Reconnect.**
  - Fetched the real cafe menus from a temporary Actions workflow; they're public (see Data sources). Their posted hours showed **`created` is UTC**, so it's now parsed that way, with tests across the DST change.
  - Both samples use only real menu items, prices and hours. The Wrapped sample's #1 is the Jumbo Chocolate Chip Cookie.
  - **Foil (#10, #11):** a real foil photo (CC BY 4.0) replaced the drawn shards. The foil is shaped like the item and comes off in five stages. Product photos for branded items (#18) come from Open Food Facts; the brands' official images are copyrighted. Both are credited in Settings.
  - Hidden the #1 before its reveal (#9).
  - **Pages:**
    - Cumulative line graph on Total (#17).
    - Month bars moved to Days, and the biggest day to Records (#13).
    - Tap-to-reveal persona with a charge-up, flip and light burst (#15).
  - **Look:** plain wording (#12); SF Pro only, Expanded for headlines and figures, less bold (#16, #19).
  - **Reconnect (#7)** no longer flashes the spending page.
  - Three parallel agents (core, foil/persona, pages), then a critic. The critic caught three things:
    - the snapshot renderer drew the first item-shaped foil as a square (see Conventions);
    - the sign-in cover could strand a parent who cancels the account picker;
    - the line graph's end label could drift from the total on refund-only days. `CafeWrapped.days` now includes those days.
  - All fixed. NoblesKit has 177 tests.
- **2026-11-10: build number bumped to 2** (`CURRENT_PROJECT_VERSION` in `project.yml`), at the user's request.
- **2026-11-10: launch crash on iOS 27.2 beta (TestFlight build 4).**
  - The crash log showed a jump to address 0 in `Date.<=`, called from `Game.hasStarted` while the first design thumbnails drew.
  - swift-foundation's source shows `Date.<=`/`>=` are back-deployed, and the beta OS lacks the symbols.
  - Replaced the four date `<=`/`>=`/`max` call sites with `Date.isAtOrBefore`/`later` (see Conventions). NoblesKit has 179 tests.
