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

- [ ] Add offline bot-only mode entrypoint for Web and Android.
- [ ] Mirror online rules for offline bot-only play without requiring the Node server on-device.
- [ ] Add host-controlled multi-seat support with participant identity separated from controller identity.
- [ ] Add setup and server validation for `round_robin` and `market` turn modes.
- [ ] Add UI controls for switching controlled seats and showing the active round-robin turn.
- [x] Add recipe generation tooling for 7-20 active participants with committed ingredient sets and four recipes per ingredient.
- [ ] Add polished visual assets and table layout inspired by potluck dinners and cooking apps.
- [x] Add structured offer creation/acceptance flows.
- [ ] Add mobile touch UX for card placement, platter swaps, and bites.
- [ ] Add local/manual QA scripts for Web and Android exports.

## Phase 4 - Hardening

- [ ] Add persistence if the design requires restart recovery.
- [ ] Add server deployment configuration.
- [ ] Add load and soak tests for 20-player tables with bots.
- [ ] Add parity tests or fixtures so offline bot-only rules stay aligned with online server rules.
- [ ] Add tests for host-controlled seats, round-robin turn enforcement, market-style asynchronous actions, and offline parity.
- [x] Add fixture coverage for generated recipe catalogs across 7-20 player configurations.
