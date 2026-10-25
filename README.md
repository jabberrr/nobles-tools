# Nobles Tools

An iOS app for designing Home Screen and Lock Screen widgets for Noble and Greenough School.

| Widget | Shows | Sizes |
| --- | --- | --- |
| **Dining Menu** | Breakfast, lunch, dinner, or whichever meal is next, from the Flik dining menus. Styles: Everything, Just Entrées, No Salads or Soups, Just… (stations you pick), Everything Except… | Small, Medium, Large, Lock Screen rectangular & inline |
| **Countdown** | Days left in the current quarter, semester or school year, counted as school days, weekdays or calendar days. Number, ring or bar style. | Small, Medium, Large, Lock Screen circular, rectangular & inline |
| **Scores** | Recent Nobles results and upcoming games, filtered by sport. | Small, Medium, Large, Lock Screen rectangular |

Every widget also has a theme (palette, font and background). Make as many designs as you like in the app, then add a Nobles Tools widget to your Home Screen, long-press it, choose **Edit Widget**, and pick a design.

## Building

Requirements: Xcode 16 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate        # creates NoblesTools.xcodeproj from project.yml
open NoblesTools.xcodeproj
```

To run it on a device, set your development team on both targets (`NoblesTools` and `NoblesWidgets`). If the bundle IDs or the app group `group.com.jabberrr.noblestools` are taken on your team, change them in `project.yml` and in `AppGroup.identifier` (`NoblesKit/Sources/NoblesKit/Core/AppGroup.swift`).

The core logic lives in the `NoblesKit` Swift package and is tested on its own:

```sh
swift test --package-path NoblesKit
```

## Data sources

- **Menus:** Flik Independent School Dining, served by Nutrislice
  (`https://nobleandgreenough.api.flikisdining.com/menu/api/weeks/school/noble-and-greenough-school/menu-type/{breakfast|lunch|dinner}/YYYY/MM/DD/`).
  Menu types are discovered from `/menu/api/schools/`, with the slug names above as a fallback.
- **Scores:** Nobles Athletics (`https://nobilis.nobles.edu/Athletics/`). Results come from the JSON behind its Latest Results page, and upcoming games from its Upcoming Schedule. Both are undocumented and have **final scores only**. No official live, in-game score source exists for Nobles (see `CONTEXT.md`).
- **School calendar:** Nobles' full calendar is only available after logging in, so the built-in 2026–27 quarter, semester and break dates are **estimates**. Graduation (June 4, 2027) is the only date with high confidence. You can correct the dates in the app under **Settings → School Calendar**.

The **Live API smoke test** workflow checks the menu and athletics endpoints every week and can be run manually from the Actions tab.
