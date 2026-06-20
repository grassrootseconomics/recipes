# Recipes MVP Plan

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
- [x] Add batch `Redeem Cards and Pass Turn` action for cooking turns in online and offline rules.
- [x] Align bot cooking turns so non-ending swaps, offers, and preparation happen before one batch turn-ending redemption, with duplicate surplus cards tradable by count.
- [x] Add recipe generation tooling for one committed 8-player ingredient set with four recipes per ingredient.
- [x] Fix the current playable MVP table size at exactly 8 active seats.
- [x] Simplify setup to `Play Offline` / `Play Online` with player plus 7 prefilled bot seats, fixed 4 dishes, fixed 40 stock, and no timer in normal setup.
- [x] Allow offline and online hosts to take over prefilled bot seats before start while preserving filtered per-seat views.
- [x] Add editable pre-start seat grid with ingredient image, name field, and Player/Bot toggle for all 8 seats.
- [x] Automatically contribute one opening promise card from every active player into the Common Basket at start.
- [ ] Add polished visual assets and table layout inspired by potluck dinners and cooking apps.
- [x] Add structured offer creation/acceptance flows.
- [x] Unify offer popups around ingredient-card visuals and public recipe-help summaries for the other cook.
- [ ] Add mobile touch UX for card placement, platter swaps, settlement swaps, and eating food parts.
- [ ] Add local/manual QA scripts for Web and Android exports.

## Phase 4 - Hardening

- [ ] Add persistence if the design requires restart recovery.
- [ ] Add server deployment configuration.
- [x] Add single-table load tests for larger catalog-backed games before fixing the current MVP at 8 seats.
- [x] Complete 8-player, 4-dish release simulations for local, round-robin, disconnect/reconnect, jitter, bad-network, and concurrent local-suite profiles.
- [ ] Add concurrent load and soak tests for 100+ simultaneous 8-seat tables.
- [ ] Revisit variable runtime table sizes only if the fixed 8-seat MVP needs expansion.
- [ ] Optimize live deltas so mature 8-seat game deltas stay near the 4 KB p95 target, with 20-seat budgets reserved for future expansion.
- [ ] Add full golden parity tests so offline rule traces stay aligned with online server rule traces.
- [x] Add tests for host-controlled seats and round-robin turn enforcement.
- [x] Expand offline parity tests beyond smoke coverage to swaps, offers, redemption, preparation, settlement, eating, timers, and invalid rollback.
- [x] Add fixture coverage for the generated 8-player recipe catalog and shared client rule constants.
- [x] Generate and consume shared client rule constants so online/offline validation bounds cannot drift silently.
