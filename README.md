# Recipes

Authoritative multiplayer recipe-trading MVP with a Node TypeScript server and a GDScript-only Godot client.

`DESCRIPTION.md` is the canonical product/design document. `PLAN.md` tracks implementation phases and known remaining work.

## Current Status

Implemented:

- Server-owned tables, participants, ingredients, vouchers, recipes, platter, offers, dishes, transaction history, timers, bots, filtered snapshots, and WebSocket updates.
- Godot client for creating/joining a table, adding bots, manually switching selected players to bots, pausing/resuming, starting, depositing, swapping with the platter, creating/responding to offers, preparing dishes, viewing dish totals/transaction history, ending the game, and eating.
- Deterministic tests for the core game rules.

Not implemented yet:

- Offline bot-only mode.
- Host-controlled multi-seat play.
- Explicit `round_robin` turn mode.
- Polished production UI/art pass.

## Requirements

- Node.js `>=24`
- npm
- Godot `4.5.1` available as `godot4`

## Install

```bash
cd /home/wor/src/recipes
npm install
```

## Run The Server

One-command local server:

```bash
/home/wor/src/recipes/start-server.sh
```

Or from the repo root:

```bash
./start-server.sh
```

Development watch mode:

```bash
cd /home/wor/src/recipes
npm run dev
```

Compiled server:

```bash
cd /home/wor/src/recipes
npm run build
HOST=127.0.0.1 PORT=3000 node server/dist/index.js
```

Health check:

```bash
curl -s http://127.0.0.1:3000/health
```

Create a table over HTTP:

```bash
curl -s -X POST http://127.0.0.1:3000/tables \
  -H 'Content-Type: application/json' \
  -d '{"hostName":"","seed":"demo"}'
```

Gameplay intents use WebSocket:

```text
ws://127.0.0.1:3000/tables/:code/socket?seatToken=...
```

## Run The Godot Client

Start the server first, then run:

```bash
cd /home/wor/src/recipes
godot4 --path client
```

Manual smoke path:

1. Leave `Name (auto)` blank or enter a custom name.
2. Click `Create`.
3. Add 6 bots so the table has 7 active seats.
4. Optionally set a timer.
5. Click `Start Game`.
6. Deposit one card from your hand.
7. Test host pause/resume, manual player-to-bot conversion, platter swaps, offers, recipe placement/redeem, dish totals, transaction history, `Prepare Dish`, `End Game`, and dish bites.

To test multiple humans locally, open another Godot client and join using the invite code.

## Tests

```bash
cd /home/wor/src/recipes
npm run typecheck
npm run test:run
godot4 --headless --path client --quit-after 5
```

Vitest watch mode:

```bash
npm test
```

## Load Simulation

Run a seven-seat game through the real HTTP/WebSocket API:

```bash
cd /home/wor/src/recipes
npm run simulate:game -- --dish-goal=4 --profile=local
npm run simulate:game -- --players=20 --dish-goal=1 --profile=local
npm run simulate:game -- --games=100 --player-min=7 --player-max=20 --concurrency=10 --dish-goal=1 --profile=local
npm run simulate:game -- --games=100 --player-min=7 --player-max=20 --concurrency=10 --dish-goal=1 --profile=local --suite-max-duration-ms=300000
```

Profiles:

- `local`: no artificial network delay.
- `jitter`: 100-800 ms delay before intents.
- `disconnect`: periodic socket close/reconnect.
- `bad`: jitter, reconnects, and intentional stale/invalid actions.

Reports are written to:

```text
tmp/simulations/
```

Single-game reports include full per-client frame arrays for debugging. Multi-game suite reports keep compact per-game rows and aggregate frame/byte metrics so 100+ table runs stay readable.
Use `--suite-max-duration-ms` to bound the entire multi-game run; per-game `--max-duration-ms` still applies inside the suite.

## Recipe Catalog

The recipe catalog generator creates named recipe sets for player counts 7 through 20. For each player count it uses one committed ingredient set generated once from the 20 common ingredients, then creates four recipes per ingredient: one initial recipe and three followups.

The live server uses the same committed player-count ingredient sets when it assigns ingredients during a game. Runtime tables do not randomly choose ingredients. In `docs/recipes-catalog.ods`, the `Player Count Ingredient Sets` sheet shows the committed sets, and the recipe, requirement, and validation sheets show the generated playable catalog. A generated recipe only keeps a known dish name such as `Jollof Rice` when its requirements match that dish target; adapted rows get short descriptive names based on their actual required ingredients.

Rules enforced by tests:

- each recipe includes the owner's ingredient,
- total required quantity is exactly 6,
- distinct ingredient count is 3, 4, or 6,
- quantity shape is `2+2+2`, `2+2+1+1`, or `1+1+1+1+1+1`,
- every required ingredient belongs to the active ingredient set,
- recipe names are unique within each player-count set,
- ingredient/quantity requirement signatures are unique within each player-count set,
- generated recipe names do not reuse a known dish name when requirements omit that dish's ingredients,
- every generated recipe has an accurate displayed name for its actual requirements.

Generate the spreadsheet:

```bash
cd /home/wor/src/recipes
npm run generate:recipes
```

Output:

```text
docs/recipes-catalog.ods
```

## Exports

Export presets are configured under `client/export_presets.cfg`.

Web export:

```bash
cd /home/wor/src/recipes
mkdir -p client/web
godot4 --headless --path client --export-debug Web web/index.html
```

Android test APK:

```bash
cd /home/wor/src/recipes
mkdir -p client/build/android
godot4 --headless --path client --export-debug Android-TestAPK build/android/recipes-test.apk
```

Godot export templates must be installed for export commands to work.

## Repository Notes

- Keep the server authoritative. The client sends intents only.
- Keep the Godot client GDScript-only.
- Do not add accounts, wallets, blockchain, borrowing, free chat, or a global leaderboard unless `DESCRIPTION.md` changes first.
- Generated folders such as `node_modules/`, `server/dist/`, `client/.godot/`, `client/build/`, and `client/web/` are ignored.

## First Push Checklist

If this directory does not have a valid Git repository yet:

```bash
cd /home/wor/src/recipes
rmdir .git
git init
git add .
git commit -m "Initial Recipes MVP"
git branch -M main
git remote add origin <repo-url>
git push -u origin main
```

If `.git` is already a valid repository:

```bash
cd /home/wor/src/recipes
git status --short
git add .
git commit -m "Initial Recipes MVP"
git remote add origin <repo-url>
git push -u origin main
```
