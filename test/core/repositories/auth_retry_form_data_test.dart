// Le rejeu unique après un refresh 401 doit aussi marcher pour les envois de
// fichiers : un FormData est finalisé au premier envoi, le rejouer tel quel
// levait StateError et l'écran affichait un échec alors que la session était
// saine (audit du 22/11/2026, n° 35).

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/repositories/app_api_client.dart';

/// Lit le corps envoyé (comme le ferait le réseau) et répond 200.
class _ReadingAdapter implements HttpClientAdapter {
  final bodies = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    bodies.add(utf8.decode(bytes, allowMalformed: true));
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('un envoi multipart déjà parti se rejoue avec un formulaire neuf',
      () async {
    final adapter = _ReadingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    final formData = FormData.fromMap(<String, dynamic>{
      'kind': 'passport',
      'file': MultipartFile.fromBytes(
        utf8.encode('contenu-du-fichier'),
        filename: 'passeport.pdf',
      ),
    });

    // Premier envoi (celui qui reçoit le 401) : le formulaire est finalisé.
    final first =
        await dio.post<dynamic>('/cases/c1/documents/upload', data: formData);
    expect(formData.isFinalized, isTrue);

    final retry = prepareAuthRetryOptions(first.requestOptions, 'neuf');
    final response = await dio.fetch<dynamic>(retry);

    expect(response.statusCode, 200);
    expect(retry.headers['Authorization'], 'Bearer neuf');
    expect(retry.extra['authRetried'], isTrue);
    expect(adapter.bodies, hasLength(2));
    // Même fichier, même champ : le serveur reçoit le même formulaire.
    expect(adapter.bodies[1], contains('contenu-du-fichier'));
    expect(adapter.bodies[1], contains('passport'));
    expect(adapter.bodies[1], adapter.bodies[0]);
  });

  test('un corps JSON est rejoué tel quel', () {
    final options = RequestOptions(path: '/x', data: {'a': 1});
    final retry = prepareAuthRetryOptions(options, 't');
    expect(retry.data, {'a': 1});
    expect(retry.headers['Authorization'], 'Bearer t');
  });
}
