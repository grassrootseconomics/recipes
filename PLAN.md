# Recipes MVP Plan

## Current Release Target

- Fixed table shape: 8 seats, one local/host player plus 7 prefilled bot seats.
- Fixed economy: 8 promise cards per ingredient, 2 opening Common Basket offerings per cook, 6 own cards expected back in hand at settlement.
- Fixed cooking goal: 3 dishes per cook, 6 redeemed ingredients per recipe, 10 food pieces per prepared dish.
- Fixed stock default for release: 40 real ingredient units per cook.
- Turn model: round-robin only.
- Modes: offline pass-and-play with local GDScript rules, and online play with the authoritative Node server.
- Release platforms: Android through Google Play first, Web as a companion build, desktop for testing only.

## Phase 1 - Server Rules And Protocol

- [x] Scaffold monorepo docs and Node TypeScript server workspace.
- [x] Define domain models for tables, participants, ingredients, vouchers, recipes, platter, offers, dishes, timers, bots, and snapshots.
- [x] Implement authoritative intent validation and state transitions.
- [x] Implement filtered snapshots for active players, bots, and witnesses.
- [x] Implement HTTP and WebSocket entrypoints.
- [x] Broadcast filtered realtime snapshots to all connected table clients.
- [x] Handle disconnect status, manual host bot conversion, host pause/resume, timer expiry, and invalid-intent rollback.
- [x] Add focused Vitest coverage for the rules in `DESCRIPTION.md`.

## Phase 2 - Godot Client Shell

- [x] Add a GDScript-only Godot project under `client/`.
- [x] Configure Web and Android export presets with `org.grassecon.recipes`.
- [x] Add a minimal connection/table UI that treats server snapshots as authoritative.
- [x] Expand the client into the first playable table, platter, offer, recipe, and eating UI.

## Phase 3 - Playable MVP

- [x] Add offline pass-and-play setup entrypoint for Web and Android.
- [x] Add initial GDScript rules mirror for offline local controlled seats and bot play without requiring the Node server on-device.
- [x] Add host-controlled multi-seat support with participant identity separated from controller identity.
- [x] Use round-robin as the single online/offline turn model and remove market-mode setup controls.
- [x] Add UI controls for switching controlled seats and showing the active round-robin turn.
- [x] Add batch `Redeem / Pass` action for cooking turns in online and offline rules.
- [x] Automatically prepare a completed recipe during `Redeem / Pass` before advancing the turn.
- [x] Align bot cooking turns so non-ending swaps, offers, and preparation happen before one batch turn-ending redemption, with duplicate surplus cards tradable by count.
- [x] Add recipe generation tooling for one committed 8-player ingredient set with three recipes per ingredient.
- [x] Fix the current playable MVP table size at exactly 8 active seats.
- [x] Simplify setup to `Play Offline` / `Play Online` with player plus 7 prefilled bot seats, fixed 3 dishes, fixed 40 stock, and no timer in normal setup.
- [x] Allow offline and online hosts to take over prefilled bot seats before start while preserving filtered per-seat views.
- [x] Add editable pre-start seat grid with ingredient image, name field, and Player/Bot toggle for all 8 seats.
- [x] Arrange the 8 cooks around the Common Basket and align lobby order, visual order, and round-robin turn order clockwise.
- [x] Automatically contribute two opening promise cards from every active player into the Common Basket at start.
- [x] Add public/private hosted table visibility and a server-backed browser for public joinable online tables.
- [x] Add explicit end-game metrics for player turns, cycles, interactions, swaps, exchanges, redemptions, settlement swaps, and food-piece settlement swaps.
- [ ] Add a dedicated analysis package for richer post-game reports and batch simulation comparisons.
- [x] Require full settlement before eating: two own cards in the Common Basket, six own cards in hand, no foreign cards held, and no own cards held by others.
- [ ] Add polished visual assets and table layout inspired by potluck dinners and cooking apps.
- [x] Add structured offer creation/acceptance flows.
- [x] Unify offer popups around asset-card visuals, grouped public hand summaries, and public recipe-help summaries for the other cook.
- [ ] Add mobile touch UX for card placement, platter swaps, settlement swaps, and eating food parts.
- [ ] Add local/manual QA scripts for Web and Android exports.

## Phase 4 - Hardening

- [ ] Decide and document release persistence scope before Play Store submission.
  - Offline release should support local app restart recovery because mobile users will background or close the app during long games.
  - Online release should support reconnecting to the same seat after client restart; server process restart recovery is required only if we want public hosted games to survive deploys or crashes.
  - If server restart recovery is out of scope for the first Play release, make that explicit in `DESCRIPTION.md`, `README.md`, and the store listing support notes.
- [ ] Add offline local persistence if restart recovery is in scope.
  - Autosave the offline table snapshot, lobby seat names/types, random ingredient assignment, recipe order, current turn, pending offers, transaction cursor, and animation-safe resume state to `user://`.
  - Restore the game on app launch with `Resume Game` and `Start New Game` choices.
  - Clear the save only after explicit end game, explicit reset, or successful completed-game archive/export.
  - Add regression tests for app restart during cooking, settlement, eating, and after completion.
- [ ] Add online client session persistence for reconnect.
  - Persist server URL, invite code, seat token, controller/seat ids, and last viewed seat in `user://`.
  - Reconnect silently when possible and fall back to a clear `Reconnect` / `Join as new cook` / `Main Menu` choice when the table is gone.
  - Ensure explicit `Leave Table` is distinct from accidental disconnect and gives up the seat by design.
- [ ] Add durable online server persistence if public restart recovery is in scope.
  - Use a simple versioned table store first, preferably SQLite or append-only JSON snapshots under a configurable data directory.
  - Persist tables, participants, vouchers, food pieces, offers, recipes, current turn, bot seeds, transaction history, and completed-game stats after each successful mutation.
  - Load active tables on server boot, expire old completed tables, and reject incompatible schema versions cleanly.
  - Add tests for restart after offer creation, after `Redeem / Pass`, during settlement, and during eating.
- [ ] Add server deployment configuration.
  - Provide production environment variables for host, port, public URL, persistence data path, CORS/origin policy, logging level, and table expiration.
  - Decide table-list freshness and expiration policy for public hosted tables once persistence is added.
  - Put the server behind HTTPS/WSS before any public Play Store online mode.
  - Add a deployment smoke check for `/health`, table creation, WebSocket connect, reconnect, and CSV export.
- [x] Add single-table load tests for larger catalog-backed games before fixing the current MVP at 8 seats.
- [x] Complete 8-player release simulations for local, round-robin, disconnect/reconnect, jitter, bad-network, and concurrent local-suite profiles before the 3-dish economy change.
- [x] Complete 8-player, 3-dish simulations with all-human clients and mixed human/bot tables through cooking, settlement, eating, and completion.
- [ ] Add concurrent load and soak tests for 100+ simultaneous 8-seat tables.
  - Track CPU, memory, average/p95 WebSocket frame size, total bytes per client, reconnect success, rejected stale intents, table completion rate, and transaction export correctness.
- [ ] Revisit variable runtime table sizes only if the fixed 8-seat MVP needs expansion.
- [ ] Optimize live deltas so mature 8-seat game deltas stay near the 4 KB p95 target, with 20-seat budgets reserved for future expansion.
- [ ] Add full golden parity tests so offline rule traces stay aligned with online server rule traces.
- [x] Add tests for host-controlled seats and round-robin turn enforcement.
- [x] Expand offline parity tests beyond smoke coverage to swaps, offers, redemption, preparation, settlement, eating, timers, and invalid rollback.
- [x] Add fixture coverage for the generated 8-player recipe catalog and shared client rule constants.
- [x] Generate and consume shared client rule constants so online/offline validation bounds cannot drift silently.

## Phase 5 - Google Play Store Release

- [ ] Prepare Play Store graphic assets.
  - High-resolution app icon: 512x512 PNG, based on the cheese ingredient but cleaned up for store scale.
  - Android launcher/adaptive icon assets for the Godot export.
  - Feature graphic: 1024x500 JPEG or PNG without alpha, showing the warm table, cooks, basket, and food economy clearly.
  - Phone screenshots: at least 4 portrait screenshots at 1080x1920 or larger, showing home, lobby, table play, offer/help, settlement/eating, and end-game stats.
  - Tablet screenshots are optional for first release unless tablet support is advertised, but should be captured once the layout is stable.
  - Alt text for every uploaded graphic.
- [ ] Prepare store listing copy.
  - App name: `Recipes`.
  - Short description under 80 characters.
  - Full description covering offline pass-and-play, online table play, trading, cooking, settlement, and sharing food.
  - Release notes for `0.0.1`.
  - Support email and website.
  - Privacy policy URL.
- [ ] Complete Play Console policy/app-content forms.
  - Data safety form aligned with actual behavior: offline data stays local; online mode transmits player names, invite codes, gameplay state, transactions, diagnostics only if implemented, and no ads.
  - Content rating questionnaire.
  - Target audience and children/families declaration.
  - Ads declaration.
  - App access instructions for reviewers, including offline mode and a test server URL if online mode is enabled in the submitted build.
  - Permissions review, currently expected to include Internet for online play.
- [ ] Prepare Android release build.
  - Verify package id `org.grassecon.recipes`, app name, version name `0.0.1`, and monotonically increasing Android version code.
  - Build a signed Android App Bundle (`.aab`) for Play upload.
  - Create and securely store the upload keystore outside the repository; commit only documentation/placeholders.
  - Verify the Godot Android export target SDK meets the current Google Play target API requirement before upload.
  - Test the Play-signed artifact through internal testing before closed testing.
- [ ] Prepare release QA artifacts.
  - Manual Android test script for install, offline game creation, pass-and-play seat naming, 3-dish completion, settlement, eating, stats, transaction history, app background/resume, and quit.
  - Manual online test script for server connect, create table, invite/join, client close/reopen reconnect, lost connection, and hosted completion.
  - Web smoke script for home screen, offline start, online connection, and responsive portrait layout.
  - Screenshot capture checklist using the exact build intended for Play.
- [ ] Plan Play testing track.
  - Use internal testing first for fast install feedback.
  - If the publisher account is subject to Google Play's new personal-account requirements, run closed testing with at least 12 opted-in testers for 14 continuous days before applying for production.
  - Collect tester notes for production-access answers and release-risk triage.

## Release Blockers To Close

- [ ] Decide persistence scope and implement the selected minimum.
- [ ] Remove or document any remaining visual layout deformation during animations, settlement, eating, popups, or transaction history.
- [ ] Verify online and offline bot settlement behavior completes reliably across repeated 3-dish games.
- [ ] Verify controlled-seat handoff works online and offline after bot seats are renamed or toggled to player seats.
- [ ] Verify food-piece offers and swaps render the correct dish name, maker, unit, quantity, and no promise-card frame.
- [ ] Verify final game stats fit the screen, include the agreed economy metrics, and link to transaction history.
- [ ] Generate final Play Store icon, feature graphic, and screenshots.
- [ ] Build and install a signed Android release artifact on at least one real Android phone.
- [ ] Update `README.md`, `DESCRIPTION.md`, `ECONOMICS.md`, and this plan so they describe the same 8-seat, 3-dish, 8-card release.
