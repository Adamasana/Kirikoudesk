import 'package:flutter_test/flutter_test.dart';

import 'package:kirikoubf_desktop/main.dart';

void main() {
  testWidgets('La page de connexion s affiche', (tester) async {
    await tester.pumpWidget(const KirikouBF());

    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Adresse e-mail'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });
}