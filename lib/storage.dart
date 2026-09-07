// Local persistence — SharedPreferences only, no backend.
// History, rules, and theme survive reloads on the same device/browser.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'triage_engine.dart';

class StoredHistory {
  StoredHistory({required this.patient, required this.resultJson});
  final String patient;
  final Map<String, dynamic> resultJson;
}

Map<String, dynamic> resultToJson(TriageResult r) => {
      'complexity': r.complexity,
      'riskLevel': r.riskLevel,
      'pathway': r.pathway,
      'nextStep': r.nextStep,
      'domainsCount': r.domainsCount,
      'riskScore': r.riskScore,
      'redFlagYes': r.redFlagYes,
      'createdAt': r.createdAt.toIso8601String(),
    };

TriageResult resultFromJson(Map<String, dynamic> j) => TriageResult(
      complexity: j['complexity'] as String? ?? '—',
      riskLevel: j['riskLevel'] as String? ?? 'Low',
      pathway: j['pathway'] as String? ?? 'MDT + Risk Screening',
      nextStep: j['nextStep'] as String? ?? '',
      domainsCount: (j['domainsCount'] as num?)?.toInt() ?? 0,
      riskScore: (j['riskScore'] as num?)?.toInt() ?? 0,
      redFlagYes: j['redFlagYes'] as bool? ?? false,
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );

Map<String, dynamic> ruleToJson(RoutingRule r) => {
      'id': r.id,
      'title': r.title,
      'condition': r.condition,
      'pathway': r.pathway,
      'nextStep': r.nextStep,
      'enabled': r.enabled,
    };

RoutingRule ruleFromJson(Map<String, dynamic> j, {required String fallbackId}) =>
    RoutingRule(
      id: j['id'] as String? ?? fallbackId,
      title: j['title'] as String? ?? fallbackId,
      condition: j['condition'] as String? ?? '',
      pathway: j['pathway'] as String? ?? '',
      nextStep: j['nextStep'] as String? ?? '',
      enabled: j['enabled'] as bool? ?? true,
    );

class LocalStore {
  static const _kHistory = 'bacr.history.v1';
  static const _kRules = 'bacr.rules.v1';
  static const _kTheme = 'bacr.theme.v1';

  Future<List<StoredHistory>> loadHistory() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kHistory);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => StoredHistory(
                patient: e['patient'] as String? ?? '',
                resultJson:
                    (e['result'] as Map?)?.cast<String, dynamic>() ?? {},
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(
      List<String> patients, List<TriageResult> results) async {
    final p = await SharedPreferences.getInstance();
    final list = List.generate(patients.length, (i) {
      if (i >= results.length) return null;
      return {'patient': patients[i], 'result': resultToJson(results[i])};
    }).whereType<Map<String, dynamic>>().toList();
    await p.setString(_kHistory, jsonEncode(list));
  }

  Future<List<RoutingRule>?> loadRules() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kRules);
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List;
      final parsed = list
          .whereType<Map<String, dynamic>>()
          .map((e) => ruleFromJson(e,
              fallbackId: e['id'] as String? ?? 'custom'))
          .where((r) => r.id.isNotEmpty)
          .toList();
      return parsed.isEmpty ? null : parsed;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveRules(List<RoutingRule> rules) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _kRules, jsonEncode(rules.map(ruleToJson).toList()));
  }

  Future<String?> loadTheme() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kTheme);
  }

  Future<void> saveTheme(String mode) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTheme, mode);
  }
}
