import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:study_sleep_tracker/main.dart';

void main() {
  testWidgets('L\'app si avvia e mostra la schermata iniziale',
      (WidgetTester tester) async {
    await tester.pumpWidget(const StudySleepTrackerApp());

    // Alla primissima frame è mostrato l'indicatore di caricamento, in
    // attesa che AppDatabase e AppPrefs vengano inizializzati.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
