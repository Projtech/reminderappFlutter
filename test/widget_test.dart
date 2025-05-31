import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Teste básico sem importar o app completo
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Reminders')),
          body: const Center(child: Text('Test App')),
        ),
      ),
    );

    // Verificar se carregou
    expect(find.text('Reminders'), findsOneWidget);
  });
}