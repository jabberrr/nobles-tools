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
| `menu` | Flik dining menu for Lunch, Dinner or "Next Meal" (auto-advances as each meal ends). Filters (`MenuFilter`): everything, entrées only, no salads/soups, only chosen stations ("Just…"), everything except chosen stations. Toggles for headers and descriptions. | systemSmall/Medium/Large, accessoryRectangular, accessoryInline |
| `countdown` | Days left in the current quarter, semester or school year (`Term.Kind`), counted as school days, weekdays or calendar days. Number, ring or bar style. | systemSmall/Medium/Large, accessoryCircular/Rectangular/Inline |
| `scores` | Recent results and upcoming games for Nobles teams, filtered by sport, with a varsity-only option. | systemSmall/Medium/Large, accessoryRectangular |

All kinds share a `Theme`: palette, font style and background style.

## Repository map

```
CLAUDE.md                   Imports this file, so Claude Code loads it automatically.
project.yml                 XcodeGen spec. The .xcodeproj, Info.plists and entitlements are generated and gitignored.
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
  Tests/NoblesKitTests/     swift-testing tests. Fixtures/real-* are REAL captured responses; synthetic-* are hand-written.
Shared/                     SwiftUI widget views, theme mapping and formatting, compiled into BOTH app and widget
App/                        App target: DesignLibrary (state), design list, editor with live previews,
                            PreviewData (loads real data once for previews), Settings (calendar editor)
Widgets/                    Widget extension: WidgetBundle, three AppIntentConfiguration widgets and their
                            timeline providers, Intents/ (configuration intents and design entities)
.github/workflows/
  ci.yml                    Linux `swift test` (swift:6.1 container); macOS: XcodeGen → `swift test` → xcodebuild
  api-smoke.yml             Weekly live check of the menu API and the athletics sources (prints response shapes)
  capture-fixtures.yml      Manual: commits real menu and athletics responses into NoblesKit test fixtures
.github/scripts/            Helpers for those workflows (extract-schedule.py cuts the schedule sidebar out)
```

Identifiers: bundle IDs `com.jabberrr.noblestools` and `com.jabberrr.noblestools.widgets`; app group `group.com.jabberrr.noblestools` (`AppGroup.identifier`); URL scheme `noblestools://design/<uuid>`, which opens that design's editor.

## Architecture

- **NoblesKit holds all the logic.** It does networking, decoding, filtering, calendar math and persistence. Keep it free of SwiftUI and WidgetKit so it stays testable on Linux. Use `#if canImport(FoundationNetworking)` for Linux, and guard Darwin-only APIs with `#if canImport(Darwin)`.
- **Shared/ views are the single rendering path.** The widget and the app's live preview use the same views.
  - The widget size is a `family:` parameter, because `\.widgetFamily` can't be set outside WidgetKit.
  - Theme colors are resolved once and passed in: by `WidgetChrome` in the widget, and by `WidgetPreviewFrame`/`DesignPreview` in the app. `WidgetChrome` also applies `containerBackground` and the deep link.
- **Persistence:** `DesignStore` stores JSON in app-group `UserDefaults`, under versioned keys (`designs.v1`, `designs.seeded.v1`, `calendar.v1`).
  - It is a `Sendable` struct, so widget timeline providers use it directly.
  - Every configuration field decodes with a default, and the design list decodes lossily. Old or partially unreadable data never wipes a user's designs.
  - The app wraps the store in a `@MainActor @Observable` `DesignLibrary`. It saves 500 ms after the last edit, and immediately when the app leaves the foreground. It then reloads only the affected widget kind (`WidgetCenter.reloadTimelines(ofKind: kind.timelineKind)`).
- **Widget configuration:** each widget has an `AppIntent` with one optional design parameter. There is one concrete `AppEntity` type per kind, because AppIntents metadata can't handle generic entities. If no design is chosen, or the chosen one was deleted, the widget uses the first saved design of that kind, else `WidgetDesign.makeDefault(kind)`.
- **Timelines:**
  - Menu: entries at now and at the next meal hand-off (`upcomingMenus(limit: 2)`), plus each school midnight for "Today"/"Tomorrow" labels; it reloads at the hand-off, at most 6 h out.
  - Countdown: one entry per school midnight.
  - Scores: refreshes every 2 h, or every 60 min on game days.
- **Offline:** `ResponseCache` keeps the last good raw response per URL in the app-group container. Services fall back to it on network errors, and report the cache time so widgets can show "Updated 3h ago".
- **App previews:** `PreviewData` fetches each data source once and filters locally per design, so toggling settings never re-fetches. It falls back to sample data, labelled as such, when offline.
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
- Dinner is served Monday–Thursday. Friday shows only a "No Dinner Services" header, which becomes a note. A header with no dishes under it is dropped unless the whole day has no dishes.
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

### School calendar (estimates)
- Nobles' full calendar requires a family login, so the built-in `SchoolCalendar.nobles2026_27` is **estimated**. Users can edit it in Settings → School Calendar.
- Structure: two semesters, each split into quarters. Grades go home in October, December, March and June.
- High confidence: graduation is the Friday after Memorial Day, so **2027-06-04**.
- Everything else is estimated: first day 2026-09-08, Q1 end 10-30, S1 end 12-18, Q3 2027-01-04…03-12, March break 03-13…03-28, plus the usual Monday holidays. Replace these with real dates if anyone obtains the calendar, or its iCal export from the logged-in Nobles portal.

## Building and testing

- macOS: `brew install xcodegen && xcodegen generate && open NoblesTools.xcodeproj`. To run on a device, set a development team on both targets.
- Package tests: `swift test --package-path NoblesKit`.
- **Linux or cloud sandbox (no Xcode):** NoblesKit can still be built and tested with Docker:
  ```sh
  (nohup dockerd >/tmp/dockerd.log 2>&1 &); sleep 5     # the daemon isn't running by default
  docker pull swift:6.1-noble                            # Docker Hub is reachable
  docker run --rm -v "$PWD/NoblesKit:/pkg" -w /pkg swift:6.1-noble swift test
  ```
  The App, Widgets and Shared targets (SwiftUI/WidgetKit/AppIntents) only compile in CI on macOS.
- CI builds with `xcodebuild -scheme NoblesTools -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`. As of 2026-10-25 the `macos-15` runner's latest stable Xcode is **26.3, with the iOS 26.2 SDK**. A full CI run takes about 3 minutes.
- **Watching CI from the sandbox:** the repo is public, so `curl https://api.github.com/repos/jabberrr/nobles-tools/actions/runs/<id>` works. Poll it in a background `until` loop rather than sleeping. Read failure logs with `mcp__github__get_job_logs`.
- **Intermediate commits:** add `[skip ci]` to the commit message when pushing work-in-progress that isn't meant to build yet. It skips every push-triggered workflow.

## Environment gotchas (Claude Code cloud sessions)

- The sandbox's network policy blocks `*.flikisdining.com`, `nobles.edu` and most other sites. `WebFetch` fails DNS for nearly every host. `WebSearch`, PyPI, npm, Docker Hub and github.com (git) work.
- **To see live API data, run it in GitHub Actions and read the logs** with `mcp__github__get_job_logs`. Artifact downloads (blob storage) are blocked, so to bring real responses into the repo, run `capture-fixtures.yml`: it commits them to the branch, then `git pull`.
- If `git push` returns 403 "Claude doesn't have GitHub access", the Claude GitHub App needs to be installed on the repo. Ask the user.

## Conventions

- Swift 6 language mode everywhere; iOS 17 deployment target. Don't use iOS 18+ APIs without an `if #available` guard.
- In AppIntents types, use computed static properties (`static var title: LocalizedStringResource { "…" }`). Stored `static var` is a Swift 6 concurrency error.
- **New persisted fields must decode with a default** (`container.decode(.key, or: default)` from `LenientDecoding.swift`), so designs saved by older builds keep loading.
- Inside `extension Binding`, a bare `max(...)` or `min(...)` resolves as a dynamic member lookup. Write `Swift.max`. CI caught this once.
- Tests use swift-testing (`import Testing`, `@Test`, `#expect`). Never touch the network in tests: inject a fake `HTTPClient` (`Tests/NoblesKitTests/Support/FakeHTTPClient.swift`). Prefer the `real-*` fixtures.
- Model enums expose `displayName` (and `symbolName` where useful) for UI. Keep UI strings in the models only when they are shared between app and widget.
- Don't commit the generated `.xcodeproj`. Change `project.yml` instead.

## Open questions and next steps

- Get the real 2026–27 calendar (quarter ends, breaks) and update `NoblesCalendar.swift`. Consider supporting an iCal URL import.
- The athletics endpoints are unofficial. Ask Nobles Athletics (athletic_info@nobles.edu) for an official feed or blessing. For a longer upcoming window, consider parsing `calendar.php` games (skip `.is-practice`).
- Confirm meal service end times with the dining hall.

## Session log

- **2026-10-25: initial build.**
  - Researched the data sources; probed the live APIs from CI and captured real fixtures.
  - Built NoblesKit, the app, the three widgets and CI.
