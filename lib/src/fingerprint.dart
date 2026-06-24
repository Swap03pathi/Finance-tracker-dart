import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'mask.dart';

/// Structural fingerprint — sha256 of the masked skeleton (port of TS `fingerprint.ts`). Must equal
/// the TS hash byte-for-byte. Sender-independent; merchant-masked so the same shape shares a hash.
String fingerprint(String body) => sha256.convert(utf8.encode(maskBody(body))).toString();
