import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/utils/share_link.dart';

/// Guards KPB-165: the invite link carried by a shared card is a real https URL
/// on the brand domain (a `kpb://` scheme would be dead for the prospects this
/// loop targets), carries the source for per-result share rates, and never emits
/// an empty `ref`.
void main() {
  test('is an https link on the brand domain, not a custom scheme', () {
    final link = buildInviteLink(source: ShareSource.match);
    expect(link, startsWith('https://${AppConfig.brandDomain}/invite.html?'));
    expect(link, isNot(contains('kpb://')));
  });

  test('carries the source as the campaign', () {
    expect(buildInviteLink(source: ShareSource.eligibility),
        contains('s=eligibility'));
    expect(buildInviteLink(source: ShareSource.match), contains('s=match'));
    expect(buildInviteLink(source: ShareSource.budget), contains('s=budget'));
    // Build 57 : le partage depuis l'écran « Compétition ambassadeurs ».
    expect(buildInviteLink(source: ShareSource.competition),
        contains('s=competition'));
  });

  test('includes the referral code when there is one', () {
    final link = buildInviteLink(
      source: ShareSource.match,
      referralCode: 'KTOU-AB-12',
    );
    expect(link, contains('ref=KTOU-AB-12'));
  });

  test('omits ref entirely when the code is missing or blank', () {
    expect(buildInviteLink(source: ShareSource.match), isNot(contains('ref=')));
    expect(
      buildInviteLink(source: ShareSource.match, referralCode: '   '),
      isNot(contains('ref=')),
    );
  });

  test('percent-encodes values so the link survives a paste into WhatsApp', () {
    final link = buildInviteLink(
      source: ShareSource.match,
      deepPath: '/scholarships/a b&c',
    );
    expect(link, isNot(contains(' ')));
    // The raw `&` from the value must not be mistaken for a param separator.
    expect(Uri.parse(link).queryParameters['to'], '/scholarships/a b&c');
  });

  test('the parsed link exposes exactly the attribution we expect', () {
    final uri = Uri.parse(buildInviteLink(
      source: ShareSource.eligibility,
      referralCode: 'CODE1',
      deepPath: '/eligibility',
    ));
    expect(uri.scheme, 'https');
    expect(uri.path, '/invite.html');
    expect(uri.queryParameters, {
      's': 'eligibility',
      'ref': 'CODE1',
      'to': '/eligibility',
    });
  });
}
