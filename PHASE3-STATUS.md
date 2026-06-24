# Phase 3 status — COMPLETE (build-verified; on-device run is Phase 4)

Now a **Flutter Android app**. Device core built, ported, and verified.

## Done + verified
- **3.A** Flutter app scaffold (Android), engine kept Flutter-free under `lib/src`; tests run via `flutter test`.
- **3.B** classifier + idempotency ports: `lib/src/{modality,money_type,counted,idempotent_id,multipart}.dart`
- **3.C** local SQLite (drift): `lib/data/database.dart` — raw / template-cache / outbox / state
- **3.D** ingestion pipeline + offline queue: `lib/pipeline/{ingest,entry}.dart`
  (gate→fingerprint→match→apply-template→classify→build EntryInput→store+enqueue; novel shape → enqueue
  ONLY the redacted skeleton; idempotent)
- **3.E** sync client: `lib/sync/sync_client.dart` (drain entries / pull templates / induce skeleton; retry/backoff)
- **3.F** native Android SMS: `android/.../MainActivity.kt` (READ_SMS permission + inbox catch-up sweep)
  + `SmsReceiver.kt` (real-time, multipart reassembly) + manifest perms/receiver; Dart glue
  `lib/device/{sms_channel,db_open}.dart`; minimal capture UI `lib/main.dart`; config loaded from
  bundled assets (`primeConfig`).

## Verification
- `flutter test` → **91/91 pass** (golden 62 + classifier 17 + store 4 + pipeline 4 + sync 4).
- `flutter analyze lib` → no errors.
- `flutter build apk --debug` → **✓ Built app-debug.apk (147 MB)** — the whole stack compiles for Android.
- Sync client live smoke vs http://18.206.195.183 (reachable; auth-guarded routes 401 without token).

## Phase 4 (on your phone — the dogfood STOP)
Install the APK, grant READ_SMS, run on the real inbox: catch-up sweep + real-time capture → local
ledger; offline queue → reconnect → sync; Google sign-in for a real session; wire the 3 headline
numbers UI. Drive backup → Phase 9. Real-SMS verification happens here (can't run in the sandbox).
