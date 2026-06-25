# Agent Defaults

- `DESCRIPTION.md` is the canonical product/design source for this repository.
- Keep the server authoritative. Clients send intents only; the server validates actions and emits filtered snapshots.
- Keep the Godot client GDScript-only for Web and Android compatibility. Do not introduce C#, .NET, native extensions, or client-owned game rules.
- Offline mode is the only client-side rules runtime exception. It is local-only, GDScript-only, and must mirror online server semantics for pass-and-play seats and bots.
- Any gameplay rule change must update both the TypeScript online rules and the GDScript offline mirror, or add/adjust parity coverage that proves the paths still match.
- Prefer deterministic game logic and seedable bot/recipe behavior.
- Add focused server tests for every rules change before broad client work.
- Do not add blockchain, wallets, accounts, borrowing, free chat, or a global leaderboard unless the design doc is updated first.
