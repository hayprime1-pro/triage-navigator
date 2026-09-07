// ignore_for_file: prefer_const_constructors
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'triage_engine.dart';

/// Builds a one-page premium triage report. Pure function of the result.
Future<Uint8List> buildTriagePdf({
  required TriageResult result,
  required String patient,
}) async {
  final who = patient.trim().isEmpty ? 'Unnamed patient' : patient.trim();
  final doc = pw.Document();

  const brand = PdfColor.fromInt(0xFF3B5BFD);
  const ink = PdfColor.fromInt(0xFF111827);
  const muted = PdfColor.fromInt(0xFF6B7280);

  pw.Widget metric(String label, String value) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(fontSize: 10, color: muted)),
            pw.SizedBox(height: 4),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: ink)),
          ],
        ),
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('BACR • Patient Triage',
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: brand)),
          pw.Text('Frontend-only report',
              style: pw.TextStyle(fontSize: 10, color: muted)),
        ],
      ),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated ${result.createdAt.toLocal()}',
              style: pw.TextStyle(fontSize: 9, color: muted)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 9, color: muted)),
        ],
      ),
      build: (ctx) => [
        pw.SizedBox(height: 8),
        pw.Text('Triage Result',
            style: pw.TextStyle(
                fontSize: 26,
                fontWeight: pw.FontWeight.bold,
                color: ink)),
        pw.SizedBox(height: 4),
        pw.Text('$who • ${result.domainsCount} domain(s) • '
            '${result.riskScore} risk flag(s) • Red flag ${result.redFlagYes ? "Yes" : "No"}',
            style: pw.TextStyle(fontSize: 11, color: muted)),
        pw.SizedBox(height: 14),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFEEF2FF),
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('RECOMMENDED PATHWAY',
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: brand)),
              pw.SizedBox(height: 4),
              pw.Text(result.pathway,
                  style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: ink)),
              pw.SizedBox(height: 4),
              pw.Text(result.nextStep,
                  style: pw.TextStyle(fontSize: 11, color: ink)),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.GridView(
          crossAxisCount: 2,
          childAspectRatio: 2.6,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            metric('Complexity', result.complexity),
            metric('Risk Level', result.riskLevel),
            metric('Pathway', result.pathway),
            metric('Next Step', result.nextStep),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Text(
            'Summary: ${result.summary(who)}',
            style: pw.TextStyle(fontSize: 10, color: ink),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Note: frontend-only build. History and routing rules are stored on-device until the backend lands.',
          style: pw.TextStyle(fontSize: 9, color: muted),
        ),
      ],
    ),
  );

  return doc.save();
}

String pdfFileName(String patient, DateTime when) {
  final slug = patient.trim().isEmpty
      ? 'triage'
      : patient.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  final stamp = when.toIso8601String().substring(0, 16).replaceAll(':', '');
  return '$slug-$stamp.pdf';
}
