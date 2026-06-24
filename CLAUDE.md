# CLAUDE.md — AI Personal CFO (device side, Dart)

This repo is the **device side**: the Dart port of the parsing core (this phase) and, later, the
Flutter Android app (Phase 3+). The TypeScript `@finman/engine` in the **Finance-tracker-server** repo
is the **reference spec**; this port must match it byte-for-byte via the shared **golden vectors**.

> Authoritative spec: docs 01–10 (in the server repo). Read 05 (screens), 07 (constraints), 10 (plan).

## Stack
- Dart (pure package now; Flutter Android app in Phase 3) · `package:decimal` · `package:crypto` · `package:test`

## Non-negotiable constraints (doc 07 §15)
- **Raw SMS NEVER leaves the device** and never appears in any network payload or log. Only the
  **redacted skeleton** crosses the wire (for template induction). The fingerprint masker and the
  redactor are the SAME code path.
- **Money is integer paise** (Dart `int`, 64-bit) — never a `double`. Parse via `package:decimal`.
- The fingerprint is **sender-independent** and masks the merchant (`§MERCHANT§`) — same shape →
  same hash, regardless of amount/merchant.

## Golden-vector lockstep (doc 10 §3)
- `golden-vectors/*.json` are copied from the server repo and are the contract. Every Dart function
  must reproduce the committed TS output (skeleton, fingerprint hash, paise, gate outcome).
- **Redaction vectors are the highest priority** — a Dart redaction bug is a privacy breach the server
  cannot catch. Never weaken or skip a redaction assertion.
- If a vector and the Dart output disagree, the **port is wrong** — do not edit the vector to pass.

## Workflow
- One phase = one branch = one PR. Current: `phase-2-dart-port`.
- **STOP at Phase 4 (dogfood on the real inbox)** before building Phases 5–9.

## Commands
```bash
dart pub get
dart test            # all golden vectors must pass, especially redaction + fingerprint
```
