import 'dart:convert';
import 'dart:io';

/// Loads the doc 07 §6 rule lists. Data, not code (doc 02).
/// - Tests / CLI: read from `config/*.json` on disk (cwd = package root).
/// - On-device (Flutter): the app loads the files from bundled assets and calls [primeConfig] at
///   startup, so the synchronous getters below return the injected JSON (no filesystem on device).
Map<String, Map<String, dynamic>> _override = {};

/// Inject pre-loaded config (e.g. from Flutter assets) so the engine stays Flutter-free + synchronous.
void primeConfig(Map<String, Map<String, dynamic>> loaded) => _override = loaded;

Map<String, dynamic> _loadJson(String name) =>
    _override[name] ?? jsonDecode(File('config/$name').readAsStringSync()) as Map<String, dynamic>;

class GateRules {
  final List<String> transactionVerbs, failedContext, future, conditional, hold, mandate, refund;
  GateRules._(this.transactionVerbs, this.failedContext, this.future, this.conditional, this.hold,
      this.mandate, this.refund);
  factory GateRules.fromJson(Map<String, dynamic> j) => GateRules._(
        List<String>.from(j['transactionVerbs']),
        List<String>.from(j['failedContext']),
        List<String>.from(j['future']),
        List<String>.from(j['conditional']),
        List<String>.from(j['hold']),
        List<String>.from(j['mandate']),
        List<String>.from(j['refund']),
      );
}

GateRules? _gateRules;
GateRules gateRules() => _gateRules ??= GateRules.fromJson(_loadJson('gate-rules.json'));

class SenderNormConfig {
  final List<String> operatorPrefixes, categorySuffixes;
  SenderNormConfig._(this.operatorPrefixes, this.categorySuffixes);
  factory SenderNormConfig.fromJson(Map<String, dynamic> j) => SenderNormConfig._(
        List<String>.from(j['operatorPrefixes']),
        List<String>.from(j['categorySuffixes']),
      );
}

SenderNormConfig? _senderCfg;
SenderNormConfig senderNormConfig() =>
    _senderCfg ??= SenderNormConfig.fromJson(_loadJson('sender-normalisation.json'));

Set<String>? _ownNodes;
/// Seeded own-node wallet issuers (uppercased) — used to classify TOPUP/TRANSFER vs EXPENSE.
Set<String> ownNodeIssuers() => _ownNodes ??= {
      for (final s in List<String>.from(_loadJson('own-node-senders.json')['ownNodeIssuers']))
        s.toUpperCase()
    };

Map<String, String>? _merchants;
/// Big-merchant dictionary → cold-start category hint (first guess; user confirmation wins).
Map<String, String> merchantDictionary() => _merchants ??= Map<String, String>.from(
    _loadJson('merchant-vpa-dictionary.json')['merchants'] as Map);
