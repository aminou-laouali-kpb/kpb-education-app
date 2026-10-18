// L'identifiant d'installation (`X-KPB-Device-Id`) part sur
// `POST /referrals/redeem` SEULEMENT — jamais sur une autre route du
// parrainage, ni sur la compétition.

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/repositories/app_api_client.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockDio dio;
  late AppApiClient client;
  final seen = <String, Options?>{};

  Response<Map<String, dynamic>> ok(Map<String, dynamic> body) =>
      Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/'),
        data: body,
        statusCode: 200,
      );

  setUpAll(() => registerFallbackValue(Options()));

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async => null,
    );
    seen.clear();
    dio = _MockDio();
    when(() => dio.interceptors).thenReturn(Interceptors());
    when(() => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenAnswer((inv) async {
      seen[inv.positionalArguments.single as String] =
          inv.namedArguments[#options] as Options?;
      return ok({'attributed': true, 'alreadyReferred': false});
    });
    when(() => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        )).thenAnswer((inv) async {
      seen[inv.positionalArguments.single as String] =
          inv.namedArguments[#options] as Options?;
      return ok({'participating': false});
    });
    when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer((inv) async {
      seen[inv.positionalArguments.single as String] = null;
      return ok({'participating': false});
    });
    client = AppApiClient(dio: dio);
  });

  test('le nom de l\'en-tête est celui que lit referrals.controller.ts', () {
    expect(referralDeviceIdHeader, 'X-KPB-Device-Id');
  });

  test('redeem porte l\'identifiant d\'installation dans son en-tête',
      () async {
    final res = await client.redeemReferral('K7PQ2MZA', deviceId: 'uuid-1');
    expect(res['attributed'], isTrue);
    final options = seen['/referrals/redeem'];
    expect(options?.headers?[referralDeviceIdHeader], 'uuid-1');
  });

  test('redeem sans identifiant (stockage en panne) : aucun en-tête', () async {
    await client.redeemReferral('K7PQ2MZA');
    expect(seen['/referrals/redeem'], isNull);
    await client.redeemReferral('K7PQ2MZA', deviceId: '  ');
    expect(seen['/referrals/redeem'], isNull);
  });

  test(
      'ni la compétition, ni le classement public, ni /referrals/me ne le '
      'portent', () async {
    await client.getCurrentReferralCampaign();
    await client.getPublicCampaignLeaderboard('ambassadeurs-novembre-2026');
    await client.getMyReferral();
    for (final path in [
      '/referrals/campaigns/current',
      '/public/campaigns/ambassadeurs-novembre-2026/leaderboard',
      '/referrals/me',
    ]) {
      expect(seen.containsKey(path), isTrue, reason: path);
      expect(seen[path]?.headers?[referralDeviceIdHeader], isNull,
          reason: path);
    }
  });

  test('le slug du classement public est encodé dans le chemin', () async {
    await client.getPublicCampaignLeaderboard('a/b c');
    expect(seen.keys, contains('/public/campaigns/a%2Fb%20c/leaderboard'));
  });
}
