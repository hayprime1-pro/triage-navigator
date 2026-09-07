import 'package:flutter_test/flutter_test.dart';

import 'package:triage_navigator/report.dart';
import 'package:triage_navigator/triage_engine.dart';

void main() {
  test('buildTriagePdf emits a valid PDF', () async {
    final r = computeTriage(
      domainsCount: 2,
      riskScore: 1,
      redFlagYes: false,
      rules: defaultRules(),
    );
    final bytes = await buildTriagePdf(result: r, patient: 'Test Patient');
    expect(bytes.isNotEmpty, isTrue);
    final header = String.fromCharCodes(bytes.take(5));
    expect(header, '%PDF-');
  });

  test('pdfFileName is slugified', () {
    final n = pdfFileName('Jane D.', DateTime(2026, 9, 7, 12, 30));
    expect(n.startsWith('jane-d-'), isTrue);
    expect(n.endsWith('.pdf'), isTrue);
  });
}
