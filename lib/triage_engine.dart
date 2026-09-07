// Pure triage scoring engine — no Flutter, no backend. Fully unit-testable.
class RoutingRule {
  RoutingRule({
    required this.id,
    required this.title,
    required this.condition,
    required this.pathway,
    required this.nextStep,
    this.enabled = true,
  });

  final String id;
  String title;
  String condition;
  String pathway;
  String nextStep;
  bool enabled;

  RoutingRule copy() => RoutingRule(
        id: id,
        title: title,
        condition: condition,
        pathway: pathway,
        nextStep: nextStep,
        enabled: enabled,
      );
}

class TriageResult {
  TriageResult({
    required this.complexity,
    required this.riskLevel,
    required this.pathway,
    required this.nextStep,
    required this.domainsCount,
    required this.riskScore,
    required this.redFlagYes,
    required this.createdAt,
  });

  final String complexity;
  final String riskLevel;
  final String pathway;
  final String nextStep;
  final int domainsCount;
  final int riskScore;
  final bool redFlagYes;
  final DateTime createdAt;

  String summary(String patient) {
    final who = patient.trim().isEmpty ? 'Patient' : patient.trim();
    return '$who • $complexity complexity • $riskLevel risk • $pathway — $nextStep';
  }
}

List<RoutingRule> defaultRules() => [
      RoutingRule(
        id: 'red',
        title: 'Red flag',
        condition: 'Red flag = Yes (first match wins)',
        pathway: 'Refer Out',
        nextStep: 'Route to appropriate specialist for immediate referral',
      ),
      RoutingRule(
        id: 'single',
        title: 'Single domain',
        condition: '1 domain AND 0 risk flags',
        pathway: 'Single Domain',
        nextStep: 'Route to single-domain assessment',
      ),
      RoutingRule(
        id: 'dual',
        title: 'Moderate / Dual',
        condition: '2 domains OR 1–2 risk flags',
        pathway: 'Moderate / Dual',
        nextStep: 'Route to Physiotherapy / OT assessment',
      ),
      RoutingRule(
        id: 'mdt',
        title: 'Complex / MDT',
        condition: '3+ domains OR 3+ risk flags (fallback)',
        pathway: 'MDT + Risk Screening',
        nextStep: 'Multi-disciplinary team review with risk screening',
      ),
    ];

String complexityFor(int domainsCount) {
  if (domainsCount <= 0) return '—';
  if (domainsCount == 1) return 'Simple';
  if (domainsCount == 2) return 'Moderate';
  return 'Complex';
}

String riskFor(int riskScore) {
  if (riskScore <= 0) return 'Low';
  if (riskScore <= 2) return 'Moderate';
  return 'High';
}

TriageResult computeTriage({
  required int domainsCount,
  required int riskScore,
  required bool redFlagYes,
  required List<RoutingRule> rules,
  DateTime? now,
}) {
  final complexity = complexityFor(domainsCount);
  final risk = riskFor(riskScore);

  String pathway = 'MDT + Risk Screening';
  String nextStep = 'Multi-disciplinary team review with risk screening';

  bool enabled(String id) =>
      rules.where((r) => r.id == id).every((r) => r.enabled);

  // Evaluate in rule order. Disabled rules are skipped.
  if (redFlagYes && enabled('red')) {
    final r = rules.firstWhere((e) => e.id == 'red');
    pathway = r.pathway;
    nextStep = r.nextStep;
  } else if (domainsCount == 1 && riskScore == 0 && enabled('single')) {
    final r = rules.firstWhere((e) => e.id == 'single');
    pathway = r.pathway;
    nextStep = r.nextStep;
  } else if ((domainsCount == 2 || (riskScore >= 1 && riskScore <= 2)) &&
      enabled('dual')) {
    final r = rules.firstWhere((e) => e.id == 'dual');
    pathway = r.pathway;
    nextStep = r.nextStep;
  } else if (enabled('mdt')) {
    final r = rules.firstWhere((e) => e.id == 'mdt');
    // Empty-input guard stays friendly even if rule text was edited.
    if (domainsCount == 0 && riskScore == 0 && !redFlagYes) {
      pathway = r.pathway;
      nextStep = 'Select at least one domain or risk flag to triage';
    } else {
      pathway = r.pathway;
      nextStep = r.nextStep;
    }
  }

  return TriageResult(
    complexity: complexity,
    riskLevel: risk,
    pathway: pathway,
    nextStep: nextStep,
    domainsCount: domainsCount,
    riskScore: riskScore,
    redFlagYes: redFlagYes,
    createdAt: now ?? DateTime.now(),
  );
}
