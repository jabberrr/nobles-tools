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
| `menu` | Flik dining menu for Lunch, Dinner or "Next Meal" (auto-advances as each meal ends). Filters (`MenuFilter`): everything, entrées only, no salads/soups, only chosen stations ("Just…"), everything except chosen stations. Toggle for station headers. "Just Entrées" shows nothing (with a message) when no entrée station exists. | systemSmall/Medium/Large, accessoryRectangular, accessoryInline |
| `countdown` | Days left in the current quarter, semester or school year (`Term.Kind`), counted as school days, weekdays or calendar days. Number, ring or bar style. | systemSmall/Medium/Large, accessoryCircular/Rectangular/Inline |
| `scores` | Recent results and upcoming games for Nobles teams, filtered by sport, with a varsity-only option. | systemSmall/Medium/Large, accessoryRectangular |

All kinds share a `Theme`: palette, font style and background style.

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
  Tests/NoblesKitTests/     swift-testing tests. Fixtures/real-* are REAL captured responses; synthetic-* are hand-written.
Shared/                     SwiftUI widget views, theme mapping and formatting, compiled into BOTH app and widget
App/                        App target: DesignLibrary (state), design list, editor with live previews,
                            PreviewData (loads real data once for previews), Settings (calendar editor).
                            Previews/DesignWidgetContent draws a design from given data (editor + gallery);
                            Previews/WidgetGallery is every widget × size from fixed sample data.
Snapshots/                  WidgetSnapshots test target: renders WidgetGallery to PNGs (when SNAPSHOT_OUTPUT_DIR is set).
docs/widgets/               The rendered PNGs, committed by CI. Look at them to check layouts; the README shows them.
Widgets/                    Widget extension: WidgetBundle, three AppIntentConfiguration widgets and their
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

### School calendar (estimates)
- Nobles' full calendar requires a family login, so the built-in `SchoolCalendar.nobles2026_27` is **estimated**. Users can edit it in Settings → School Calendar.
- Structure: two semesters, each split into quarters. Grades go home in October, December, March and June.
- High confidence: graduation is the Friday after Memorial Day, so **2027-06-04**.
- Everything else is estimated: first day 2026-09-08, Q1 end 10-30, S1 end 12-18, Q3 2027-01-04…03-12, March break 03-13…03-28, plus the usual Monday holidays. Replace these with real dates if anyone obtains the calendar, or its iCal export from the logged-in Nobles portal.

## Building and testing

- macOS: pull, then `open NoblesTools.xcodeproj`. It's signed with the user's team, so it runs on a simulator or their iPhone with no setup. Another team can be set on one Mac via the gitignored `Config/Local.xcconfig`. After changing `project.yml` locally, regenerate with `xcodegen generate`, or push and let CI do it.
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
  - Add a gallery variant for any new layout or stress case.
- **Watching CI from the sandbox:** the repo is public, so `curl https://api.github.com/repos/jabberrr/nobles-tools/actions/runs/<id>` works. Poll it in a background `until` loop rather than sleeping. Read failure logs with `mcp__github__get_job_logs`.
- **Intermediate commits:** add `[skip ci]` to the commit message when pushing work-in-progress that isn't meant to build yet. It skips every push-triggered workflow.

## Environment gotchas (Claude Code cloud sessions)

- The sandbox's network policy blocks `*.flikisdining.com`, `nobles.edu` and most other sites. `WebFetch` fails DNS for nearly every host. `WebSearch`, PyPI, npm, Docker Hub and github.com (git) work.
- **To see live API data, run it in GitHub Actions and read the logs** with `mcp__github__get_job_logs`. Artifact downloads (blob storage) are blocked.
- **To bring real responses into the repo,** dispatch `capture-fixtures.yml`: `mcp__github__actions_run_trigger` with method `run_workflow`, `workflow_id: capture-fixtures.yml` and the branch as `ref`. It commits the responses to that branch; then `git pull`. Re-capturing changes the content the `real-*` tests assert on, so update those tests in the same change.
- If `git push` returns 403 "Claude doesn't have GitHub access", the Claude GitHub App needs to be installed on the repo. Ask the user.
- **Pull before you push.** After a push that changes the project (new or removed files, `project.yml` edits), CI adds a "Regenerate Xcode project" commit to the branch. Run `git pull --rebase` before the next push.

## Conventions

- Swift 6 language mode everywhere; iOS 17 deployment target. Don't use iOS 18+ APIs without an `if #available` guard.
- In AppIntents types, use computed static properties (`static var title: LocalizedStringResource { "…" }`). Stored `static var` is a Swift 6 concurrency error.
- **New persisted fields must decode with a default** (`container.decode(.key, or: default)` from `LenientDecoding.swift`), so designs saved by older builds keep loading.
- Inside `extension Binding`, a bare `max(...)` or `min(...)` resolves as a dynamic member lookup. Write `Swift.max`. CI caught this once.
- Tests use swift-testing (`import Testing`, `@Test`, `#expect`). Never touch the network in tests: inject a fake `HTTPClient` (`Tests/NoblesKitTests/Support/FakeHTTPClient.swift`). Prefer the `real-*` fixtures.
- Model enums expose `displayName` (and `symbolName` where useful) for UI. Keep UI strings in the models only when they are shared between app and widget.
- The committed `NoblesTools.xcodeproj` is generated output. Change `project.yml`, and let CI regenerate the project (or run `xcodegen generate` on a Mac) rather than editing it in Xcode.
- Signing lives in `Config/Signing.xcconfig`, never in the project file. When a push edits generated project files directly, CI regenerates them and then **fails**, listing the replaced lines (`commit-xcode-project.sh`). Port those settings into `project.yml` or the xcconfig. This happened once: the user set the team and bundle ID in Xcode, and a regeneration silently undid them before the guard existed.

## Open questions and next steps

- Get the real 2026–27 calendar (quarter ends, breaks) and update `NoblesCalendar.swift`. Consider supporting an iCal URL import.
- The athletics endpoints are unofficial. Ask Nobles Athletics (athletic_info@nobles.edu) for an official feed or blessing. For a longer upcoming window, consider parsing `calendar.php` games (skip `.is-practice`).
- Confirm meal service end times with the dining hall.

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
