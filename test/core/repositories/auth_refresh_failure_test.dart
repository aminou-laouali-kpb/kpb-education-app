// Garde la règle « seule une vraie révocation déconnecte » : une coupure réseau
// ou une panne du serveur d'auth pendant le rafraîchissement du token ne doit
// jamais déclencher le logout, qui efface les dossiers, favoris et l'outbox
// non synchronisée.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:karatou/app/core/repositories/app_api_client.dart';

void main() {
  group('isPermanentRefreshFailure', () {
    test('a revoked or invalid refresh token is permanent', () {
      expect(
        isPermanentRefreshFailure(
          AuthApiException('Invalid Refresh Token', statusCode: '400'),
        ),
        isTrue,
      );
      expect(
        isPermanentRefreshFailure(
          AuthApiException('Unauthorized', statusCode: '401'),
        ),
        isTrue,
      );
      expect(isPermanentRefreshFailure(AuthSessionMissingException()), isTrue);
    });

    test('network failures are transient', () {
      expect(isPermanentRefreshFailure(AuthRetryableFetchException()), isFalse);
      expect(
        isPermanentRefreshFailure(const SocketException('offline')),
        isFalse,
      );
      expect(isPermanentRefreshFailure(TimeoutException('slow')), isFalse);
    });

    test('auth server outages and rate limits are transient', () {
      for (final status in ['500', '502', '503', '429', '408']) {
        expect(
          isPermanentRefreshFailure(
            AuthApiException('outage', statusCode: status),
          ),
          isFalse,
          reason: 'status $status',
        );
      }
      expect(
        isPermanentRefreshFailure(
          AuthUnknownException(message: 'html', originalError: 'boom'),
        ),
        isFalse,
      );
    });
  });
}
