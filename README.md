# Recipes

Authoritative multiplayer recipe-trading MVP with a Node TypeScript server and a GDScript-only Godot client.

`DESCRIPTION.md` is the canonical product/design document. `PLAN.md` tracks implementation phases and known remaining work.

## Current Status

Implemented:

- Server-owned tables, participants, ingredients, vouchers, recipes, platter, offers, dishes, transaction history, timers, bots, filtered snapshots, and WebSocket updates.
- Godot client for `Play Offline`, `Play Online`, joining online tables, taking over prefilled bot seats, pausing/resuming, starting, watching automatic opening offerings, swapping with the platter, creating/responding to offers, preparing dishes, viewing dish totals/transaction history, ending the game, and eating.
- Online host-controlled seats with filtered per-seat views and explicit acting-seat intents.
- Server-enforced round-robin turns. Each active cook keeps the turn until they pass or use `Redeem / Pass`.
- End-game stats distinguish player turns, fractional cycles, successful interactions, Common Basket swaps, direct exchanges, redemptions, settlement swaps, food-piece settlement swaps, and bites eaten.
- Offline pass-and-play rules runtime for one-device local seats and bots, using the same snapshot/intent UI path as online play.
- Deterministic tests for the core game rules.

Not implemented yet:

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

Public remote server, usually behind nginx and HTTPS:

```bash
cd /opt/recipes
npm ci
HOST=127.0.0.1 PORT=3000 ./start-server.sh
```

For production, run the Node process on localhost through a reverse proxy instead of exposing port `3000` directly. Example files are provided at:

```text
deploy/systemd/recipes-server.service
deploy/nginx/recipes-server.example.conf
```

The production server hostname currently expected by the client server list is:

```text
https://recipes-server.grassecon.org
```

Point that DNS name to the remote server once its IP is known, or update `client/data/servers.json` before exporting a release build if the final hostname changes.

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
2. Click `Play Offline` for pass-and-play or `Play Online` to create a hosted table.
3. The table starts with 8 seats: you plus 7 bots.
4. Use the seat grid to edit seat names and switch available bot seats between `Player` and `Bot` before start.
5. Online tables are public by default while joinable. The host can toggle `Public Table` / `Private Table` in the lobby; public joinable tables appear in the server browser below the create/join buttons.
6. Click `Start Cooking`.
7. Watch the automatic opening offerings fill the Common Basket.
8. Test host pause/resume, manual player-to-bot conversion, platter swaps, offers, `Redeem / Pass` with automatic dish preparation, dish totals, transaction history, `End Game`, and dish bites.

To test multiple humans locally on one desktop, run each Godot client with a different local profile. Each profile gets its own saved online seat, so one client can reconnect as the host while the others join as separate players:

```bash
cd /home/wor/src/recipes
godot4 --path client -- --profile host
godot4 --path client -- --profile p2
godot4 --path client -- --profile p3
godot4 --path client -- --profile p4
```

Create the table in the `host` window, then enter the same invite code in the `p2`, `p3`, and `p4` windows, or choose the public table from the online server browser if the host leaves it public. If you run multiple clients without separate profiles, they intentionally share the same saved `user://` session and may show `Reconnect Seat` instead of `Join Table`.

## Tests

```bash
cd /home/wor/src/recipes
npm run typecheck
npm run test:run
npm run test:offline
npm run test:visual
godot4 --headless --log-file /tmp/recipes-godot-headless.log --path client --quit-after 5
```

Full local regression pass:

```bash
npm run test:all
```

Vitest watch mode:

```bash
npm test
```

## Load Simulation

Run an 8-seat game through the real HTTP/WebSocket API:

```bash
cd /home/wor/src/recipes
npm run simulate:game -- --players=8 --dish-goal=3 --profile=local --turn-mode=round_robin
npm run simulate:game -- --players=8 --dish-goal=3 --profile=disconnect
npm run simulate:game -- --players=8 --dish-goal=3 --profile=jitter
npm run simulate:game -- --players=8 --dish-goal=3 --profile=bad
npm run simulate:game -- --games=3 --player-min=8 --player-max=8 --concurrency=2 --dish-goal=3 --profile=local --suite-max-duration-ms=300000
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
Round-robin is the only supported turn mode. The simulator accepts `--turn-mode=round_robin` for compatibility with older scripts.
Use `--suite-max-duration-ms` to bound the entire multi-game run; per-game `--max-duration-ms` still applies inside the suite.

## Recipe Catalog

The recipe catalog generator creates one committed 8-player recipe set using the generalized ingredients Cheese, Flour, Herbs, Vegetables, Rice, Beans, Spices, and Eggs. It creates three short, unique, real-dish-inspired recipes per ingredient: one initial recipe and two followups, for 24 recipes total.

The live server uses the same committed ingredient set when it assigns ingredients during a game. Runtime tables do not randomly choose ingredients. In `docs/recipes-catalog.ods`, the `Player Count Ingredient Sets` sheet shows the committed set, and the recipe, requirement, and validation sheets show the playable catalog.

Rules enforced by tests:

- each recipe includes the owner's ingredient,
- total required quantity is exactly 6,
- distinct ingredient count is 4, 5, or 6,
- quantity shape is `2+2+1+1`, `2+1+1+1+1`, or `1+1+1+1+1+1`,
- every required ingredient belongs to the active ingredient set,
- recipe names are unique within the 8-player set,
- ingredient/quantity requirement signatures are unique within the 8-player set,
- every recipe uses its committed real-dish-inspired name directly,
- every ingredient has image metadata for cards, recipe slots, and inventory.

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
npm run export:web
```

The Web client export writes to `client/web/`, copies `CNAME`, and is intended to be served at:

```text
https://recipes.grassecon.org
```

Local Web-client smoke server:

```bash
cd /home/wor/src/recipes
npm run serve:web -- --host 127.0.0.1 --port 8081
```

The local smoke server sends no-cache headers. If an older browser session still
shows stale UI, clear the old Godot service worker once in DevTools:
`Application -> Service Workers -> Unregister`, then
`Application -> Storage -> Clear site data`.

Remote static Web hosting:

```bash
cd /opt/recipes
npm ci
npm run export:web
sudo rsync -a --delete client/web/ /var/www/recipes/
```

Serve `/var/www/recipes` with HTTPS and the Godot Web headers shown in:

```text
deploy/nginx/recipes-web.example.conf
```

The root `CNAME` and generated `client/web/CNAME` both use `recipes.grassecon.org`. The Web build must be served over HTTPS for normal browser security rules; localhost testing can use `scripts/serve-web.py`.

## Remote Deployment Checklist

The production deployment has two independent services:

- Static Godot Web client: `https://recipes.grassecon.org`
- Authoritative game server: `https://recipes-server.grassecon.org`

Before deployment, decide whether those hostnames are final. If the server hostname changes, update `client/data/servers.json` before running `npm run export:web`; the exported Web client embeds that server list in `client/web/index.pck`.

Remote machine prerequisites:

```bash
sudo apt update
sudo apt install -y git nginx certbot python3-certbot-nginx
```

Install Node.js `>=24` and npm on the remote host. Use your preferred Node package source or version manager, then verify:

```bash
node --version
npm --version
```

Install Godot `4.5.1` as `godot4` only if the remote host will build the Web client. If CI or a developer machine exports `client/web/`, the remote host only needs nginx plus the built files.

Clone and build:

```bash
sudo mkdir -p /opt/recipes
sudo chown "$USER":"$USER" /opt/recipes
git clone https://github.com/grassrootseconomics/recipes.git /opt/recipes
cd /opt/recipes
npm ci
npm run build
```

Create a system user for the server process:

```bash
sudo useradd --system --home /opt/recipes --shell /usr/sbin/nologin recipes || true
sudo chown -R recipes:recipes /opt/recipes
```

Install the server service:

```bash
sudo cp deploy/systemd/recipes-server.service /etc/systemd/system/recipes-server.service
sudo systemctl daemon-reload
sudo systemctl enable --now recipes-server
sudo systemctl status recipes-server
```

The service runs Node on `127.0.0.1:3000`. Do not expose port `3000` publicly in production; nginx should terminate HTTPS and proxy HTTP/WebSocket traffic to localhost.

Configure DNS:

```text
recipes.grassecon.org        A/AAAA -> remote server IP
recipes-server.grassecon.org A/AAAA -> remote server IP
```

Install nginx configs and certificates:

```bash
sudo cp deploy/nginx/recipes-server.example.conf /etc/nginx/sites-available/recipes-server
sudo cp deploy/nginx/recipes-web.example.conf /etc/nginx/sites-available/recipes-web
sudo ln -sf /etc/nginx/sites-available/recipes-server /etc/nginx/sites-enabled/recipes-server
sudo ln -sf /etc/nginx/sites-available/recipes-web /etc/nginx/sites-enabled/recipes-web
sudo nginx -t
sudo certbot --nginx -d recipes-server.grassecon.org
sudo certbot --nginx -d recipes.grassecon.org
sudo systemctl reload nginx
```

The web nginx config must keep these headers for Godot Web:

```text
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Build and publish the Web client:

```bash
cd /opt/recipes
sudo chown -R "$USER":"$USER" /opt/recipes
npm run export:web
sudo mkdir -p /var/www/recipes
sudo rsync -a --delete client/web/ /var/www/recipes/
sudo chown -R www-data:www-data /var/www/recipes
sudo systemctl reload nginx
```

If `client/data/servers.json`, Godot scripts, art, or recipes change, rebuild the Web export and copy `client/web/` again. The current export does not intentionally use a PWA service worker; if a tester previously loaded an older build, they may need to unregister the old service worker and clear site data once.

Remote smoke checks:

```bash
curl -s https://recipes-server.grassecon.org/health
curl -I https://recipes.grassecon.org/
sudo journalctl -u recipes-server -n 100 --no-pager
```

Manual online smoke:

1. Open `https://recipes.grassecon.org`.
2. Select `Grassroots Recipes Server`.
3. Create a public table.
4. Open another browser/device and verify the public table appears.
5. Join, rename the joined seat, start cooking, and verify both clients receive live updates.

Common deployment adjustments:

- Change production domains in `CNAME`, `client/web/CNAME`, `deploy/nginx/*.conf`, and `client/data/servers.json` if `recipes.grassecon.org` / `recipes-server.grassecon.org` are not final.
- Change `WorkingDirectory`, `ExecStart`, `User`, and `Group` in `deploy/systemd/recipes-server.service` if the repo is not deployed at `/opt/recipes`.
- Change `/var/www/recipes` in `deploy/nginx/recipes-web.example.conf` if static files are served from a different directory.
- Keep WebSocket upgrade headers in `deploy/nginx/recipes-server.example.conf`; online gameplay depends on them.
- Open firewall ports `80` and `443`; keep `3000` private to localhost.

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
- Commit Godot source resource metadata such as `.import` and `.uid` files; only generated build/editor output is ignored.
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
