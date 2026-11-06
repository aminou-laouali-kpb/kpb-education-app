// Validation d'e-mail : permissive, pour les adresses à domaine à deux niveaux
// (audit build 57, T1-18). L'ancienne règle refusait celles des universités
// d'Afrique francophone.

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/features/auth/magic_link_email_screen.dart';

void main() {
  test('accepte les domaines à deux niveaux', () {
    for (final email in const [
      'awa@ucad.edu.sn',
      'moussa@um5.ac.ma',
      'ibrahim@yahoo.co.uk',
      'fatou.diallo+kpb@gmail.com',
      '  aminata@univ-lome.tg  ',
    ]) {
      expect(isPlausibleEmail(email), isTrue, reason: email);
    }
  });

  test('refuse ce qui n\'est visiblement pas une adresse', () {
    for (final email in const [
      '',
      'awa',
      'awa@',
      '@ucad.edu.sn',
      'awa@ucad',
      'awa @ucad.sn',
      'awa@@ucad.sn',
    ]) {
      expect(isPlausibleEmail(email), isFalse, reason: email);
    }
  });
}
