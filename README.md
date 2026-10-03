# Whiteboard Scrum Planner

A native macOS app (Swift + SwiftUI) for planning a two-week sprint on a clean,
minimal board: **projects as rows**, **exactly two weeks as columns**, and
**simple white task cards** in the cells. Hay-colored background, hairline
grid, system typography — no decoration.

## Build & run

```sh
swift run                # run from the terminal (debug build)
./make_app.sh            # build a double-clickable build/WhiteboardScrumPlanner.app
open build/WhiteboardScrumPlanner.app
```

Requires macOS 14+ and a Swift toolchain (Xcode or Command Line Tools).

## Features

Only the essential things:

- **Add a task** — hover a cell → `+ Add task` (it stays hidden otherwise), or
  press `a` with the cursor on that cell. The card opens in edit mode.
- **Edit a task** — double-click a card and type, or `e`. Enter commits, Esc
  cancels, multi-line supported.
- **Delete a task** — hover the card and hit ✕, or `d` (cut).
- **Move a task** — drag any card onto another cell, or cut `d` then paste `p`.
- **Done** — click a card, or `x`: red checkmark + strikethrough + a small
  confetti burst.
- **Projects** — rows can be added (`A` or `+ Add project`), renamed
  (double-click the name or `r`), and removed (hover ✕ or `D`).
- **Persistence** — everything auto-saves (debounced while typing) to
  `~/Library/Application Support/WhiteboardScrumPlanner/board.json`.

The board is deliberately fixed at two weeks. The cursor (the highlighted
cell/card) is the target for all vim commands.

## Vim-like keybindings

Normal mode (any time you're not typing in a field) — all hints are shown at
the bottom of the board:

| Key | Action |
| --- | --- |
| `j` `k` `h` `l` | move the cursor (task within cell, then row/column) |
| `a` | add a task in the cursor cell (insert) |
| `e` | edit the task under the cursor (insert) |
| `x` | toggle done |
| `d` | cut the task under the cursor (to the paste register) |
| `p` | paste the cut task into the cursor cell |
| `r` | rename the project row (insert) |
| `A` | add a project row |
| `D` | remove the project row — asks `y` to confirm |
| `s` | save now |
| `R` | reset the demo board — asks `y` to confirm |
| `y` / `n` / `esc` | answer a confirmation prompt |
| `Esc` | exit insert mode / cancel editing |

`⌘N` new task, `⌘S` save, and `Board ▸ Reset Demo Board` remain available.
Closures: none — every shortcut is a single key, vim-style.

## Layout

```
Sources/WhiteboardScrumPlanner/
  App.swift          entry point, window sizing, hidden offscreen-render tool
  Models.swift       TaskCard / Project / Week / BoardState
  Store.swift        @Observable store + JSON persistence + sample data
  Theme.swift        hay palette, hairlines, layout metrics
  BoardActions.swift menu commands (⌘ shortcuts) via @FocusedValue
  BoardView.swift    the grid sheet: headers, rows, cells, drag & drop
  TaskCardView.swift card UI — done toggle + celebration, in-place edit, drag
```

Dev tool: `WBP_RENDER=/path.png make run` renders the board offscreen to a PNG
(headless visual check). `ImageRenderer` has two quirks to know about:
`ScrollView` content is not laid out offscreen (the sheet is rendered
directly), and `.dropDestination` paints an opaque yellow drop-target backdrop
in offscreen renders only — it is invisible in the live app.