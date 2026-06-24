# Phase 3 status

## Done + verified (pure Dart, 91 tests pass; live server smoke OK)
- **3.B** classifier + idempotency ports: `lib/src/{modality,money_type,counted,idempotent_id,multipart}.dart`
- **3.C** local SQLite (drift): `lib/data/database.dart` — raw / template-cache / outbox / state
- **3.D** ingestion pipeline + offline queue: `lib/pipeline/{ingest,entry}.dart`
  (gate→fingerprint→match→apply-template→classify→build EntryInput→store+enqueue; novel shape → enqueue
  ONLY the redacted skeleton; idempotent)
- **3.E** sync client: `lib/sync/sync_client.dart` — drain pending_sync → POST /entries, pull /templates,
  drain pending_parse → /templates/induce (skeleton only); retry/backoff. Verified vs mock server +
  live smoke against http://18.206.195.183 (reachable; auth-guarded routes 401 without a token).

Run: `dart test`  (all green)

## BLOCKED on disk space
- **3.A** convert to a Flutter app + **3.F** native Android (READ_SMS BroadcastReceiver, launch
  catch-up sweep, MethodChannel) + **debug APK build**.
- Cause: disk is ~98% full (~4 GB free); `brew install flutter` failed with ENOSPC. A Flutter SDK +
  Android Gradle build needs several GB more headroom.
- To resume: free up disk (several GB), then `brew install flutter`, `flutter create` the app shell
  around this package, add the Kotlin SMS receiver, and `flutter build apk --debug`.
- The on-device exit-test (real SMS, offline→online sync, permission grant) is Phase 4 dogfood on a
  real phone regardless.

## Note
The repo is currently a **pure Dart package** (so `dart test` verifies the whole core without Flutter).
Converting to a Flutter app (3.A) switches tests to `flutter test`; do that step only once Flutter is
installed, to avoid breaking the working test setup.
