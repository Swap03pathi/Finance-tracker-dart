import 'dart:io';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../data/database.dart';

/// Open the device-local SQLite DB (drift). Raw bodies live here (device-local + Drive in Phase 9).
/// Uses a BACKGROUND isolate so sqlite work (and the parse/sync loop's many queries) never blocks the
/// UI thread — without this, re-parsing several messages during a sync ANRs the app.
Future<LocalDb> openDeviceDb() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'finman.sqlite'));
  return LocalDb(NativeDatabase.createInBackground(file));
}
