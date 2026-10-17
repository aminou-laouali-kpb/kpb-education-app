// ─────────────────────────────────────────────────────────────────────────────
// Attribution links for shared result cards (KPB-165).
//
// A card shared into a WhatsApp group is read mostly by people who do NOT have
// the app — that is the whole point of the loop. So the link must be an https
// URL on the brand domain (served by the `web` container), never a bare `kpb://`
// scheme, which does nothing on a device without the app installed.
//
// The landing page (`web/public/invite.html`) shows the store buttons and the
// referral code. Once App Links / Universal Links association ships (blocked on
// the signing work, KPB-154), the SAME url will open the app directly for people
// who already have it — no link rewriting needed later.
// ─────────────────────────────────────────────────────────────────────────────

import '../config/app_config.dart';

/// Where a shared card came from — becomes the campaign, so PostHog can report
/// the share rate per result type.
///
/// `competition` : le lien partagé depuis l'écran « Compétition ambassadeurs »
/// (build 57). `invite.html` ignore `s` ; seul `ref` y est lu.
enum ShareSource { eligibility, match, budget, competition }

extension ShareSourceName on ShareSource {
  String get wireName => switch (this) {
        ShareSource.eligibility => 'eligibility',
        ShareSource.match => 'match',
        ShareSource.budget => 'budget',
        ShareSource.competition => 'competition',
      };
}

/// Builds the public invite link carried by a shared card.
///
/// [referralCode] is omitted when the user has none yet (never send `ref=`
/// empty — an empty code would look like a broken invite). [deepPath] is the
/// in-app destination the link should resolve to once app-link association is
/// live; it is carried as a query param so the landing page can forward it.
String buildInviteLink({
  required ShareSource source,
  String? referralCode,
  String? deepPath,
}) {
  final params = <String, String>{
    's': source.wireName,
    if ((referralCode ?? '').trim().isNotEmpty) 'ref': referralCode!.trim(),
    if ((deepPath ?? '').trim().isNotEmpty) 'to': deepPath!.trim(),
  };
  final query = params.entries
      .map((e) =>
          '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');
  return 'https://${AppConfig.brandDomain}/invite.html?$query';
}
