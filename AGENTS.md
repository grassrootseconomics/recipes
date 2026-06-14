# Agent Defaults

- `DESCRIPTION.md` is the canonical product/design source for this repository.
- Keep the server authoritative. Clients send intents only; the server validates actions and emits filtered snapshots.
- Keep the Godot client GDScript-only for Web and Android compatibility. Do not introduce C#, .NET, native extensions, or client-owned game rules.
- Prefer deterministic game logic and seedable bot/recipe behavior.
- Preserve hidden-information boundaries: active players and bots must not receive other active hands or recipes.
- Add focused server tests for every rules change before broad client work.
- Do not add blockchain, wallets, accounts, borrowing, free chat, or a global leaderboard unless the design doc is updated first.
