import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:triage_navigator/main.dart';
import 'package:triage_navigator/triage_engine.dart';

void main() {
  group('engine', () {
    test('scores Simple / Low / Single Domain', () {
      final r = computeTriage(
        domainsCount: 1,
        riskScore: 0,
        redFlagYes: false,
        rules: defaultRules(),
      );
      expect(r.complexity, 'Simple');
      expect(r.riskLevel, 'Low');
      expect(r.pathway, 'Single Domain');
    });

    test('red flag wins', () {
      final r = computeTriage(
        domainsCount: 1,
        riskScore: 0,
        redFlagYes: true,
        rules: defaultRules(),
      );
      expect(r.pathway, 'Refer Out');
    });

    test('complex MDT fallback', () {
      final r = computeTriage(
        domainsCount: 3,
        riskScore: 3,
        redFlagYes: false,
        rules: defaultRules(),
      );
      expect(r.complexity, 'Complex');
      expect(r.riskLevel, 'High');
      expect(r.pathway, 'MDT + Risk Screening');
    });
  });

  group('full UX flow', () {
    testWidgets('triage -> result -> save -> history', (tester) async {
      await tester.pumpWidget(const TriageApp());
      await tester.pumpAndSettle();

      // 1. Fill form.
      expect(find.text('BACR Patient Triage'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).first,
        'Test Patient',
      );
      await tester.pump();

      // Pick 1 domain via chip.
      await tester.tap(find.text('Cognition'));
      await tester.pump();

      // Answer Red flag = No (scroll into view first for small screens).
      final noSeg = find.text('No');
      await tester.ensureVisible(noSeg);
      await tester.tap(noSeg);
      await tester.pump();

      // 2. Compute -> lands on Result tab.
      final compute = find.text('Review & compute');
      await tester.ensureVisible(compute);
      await tester.tap(compute);
      await tester.pumpAndSettle();

      expect(find.text('Single Domain'), findsWidgets);
      expect(find.textContaining('Test Patient'), findsWidgets);

      // 3. Save -> lands on History tab.
      final save = find.text('Save to history');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.textContaining('Test Patient'), findsWidgets);
      expect(find.text('1 saved'), findsOneWidget);
    });

    testWidgets('result empty state links back to triage', (tester) async {
      await tester.pumpWidget(const TriageApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Result'));
      await tester.pumpAndSettle();
      expect(find.text('No result yet'), findsOneWidget);

      await tester.tap(find.text('Start triage'));
      await tester.pumpAndSettle();
      expect(find.text('BACR Patient Triage'), findsOneWidget);
    });

    testWidgets('settings theme switch renders', (tester) async {
      await tester.pumpWidget(const TriageApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      // Still on settings, no crash = pass.
      expect(find.text('Appearance'), findsOneWidget);
    });
  });
}
