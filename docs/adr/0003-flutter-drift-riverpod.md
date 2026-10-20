# 0003. Flutter + Drift + Riverpod as the local-first core

Date: 2026-10-11
Status: Accepted

## Context
We need one codebase that runs well on low-end Android phones, could reach iOS later, and is
familiar to the local developer community. The local database must be reactive (the UI updates
when sync pulls new data) and support tested migrations.

## Decision
- **Flutter** (stable, Dart 3), Android first.
- **Drift** for SQLite: type-safe queries, `watch()` streams, migration tooling.
- **Riverpod** (with code generation) for state and dependency injection, so a backend swap is a
  single provider override.

## Consequences
- Background work and peer-to-peer features depend on plugins (`workmanager`,
  `nearby_connections`) that must be tested on real devices.
- Code generation (`build_runner`) is required after changing models, providers or tables;
  documented in README and CONTRIBUTING.
- The same architecture works in native Kotlin (Room + WorkManager + Hilt) — we say so in docs and
  talks so Kotlin developers can follow.
