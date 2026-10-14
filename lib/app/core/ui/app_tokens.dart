import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KPB Education — Design Tokens (palette « KPB Intelligence »)
// ─────────────────────────────────────────────────────────────────────────────
// L0 de l'architecture de thème (docs/fable-global-theme-architecture.md §6) :
// SEUL fichier autorisé à définir des valeurs hexadécimales. Tout le reste
// (ThemeData, context.kpb, primitives, écrans) consomme ces rôles.
// Le test ratchet (test/core/ui/color_audit_test.dart) fait respecter cette
// règle : toute nouvelle couleur en dur ailleurs casse la CI.
// ─────────────────────────────────────────────────────────────────────────────

class KpbColors {
  KpbColors._();

  // ── Rôles sémantiques canoniques ─────────────────────────────────────────
  // Réfléchis pour le WCAG AA (ratios vérifiés par app_tokens_test) : lisible
  // en plein soleil équatorial sur des écrans d'entrée de gamme.
  static const brandNavy = Color(0xFF0F172A); // marque, textes forts, heros
  static const brandBlueLegacy = Color(0xFF004AAD); // héritage (logo, PDF) —
  // ne plus utiliser comme couleur d'action.
  static const actionPrimary = Color(0xFF2563EB); // CTA, liens, sélection
  static const actionPrimaryPressed = Color(0xFF1D4ED8); // état pressed/hover
  static const actionPrimarySoft = Color(0xFFEFF6FF); // fonds soft d'action
  static const actionOnDark = Color(0xFF93C5FD); // action sur fond navy
  static const canvas = Color(0xFFF8FAFC); // fond de page
  static const surface = Colors.white; // cartes, sheets, inputs
  static const surfaceMuted = Color(0xFFF1F5F9); // fonds atténués, tracks
  static const border = Color(0xFFE2E8F0); // bordure par défaut
  static const borderStrong = Color(0xFFCBD5E1); // bordure appuyée
  static const textFaint = Color(0xFF94A3B8); // placeholders/décor —
  // 2,56:1 sur blanc : JAMAIS pour un texte porteur de sens.
  static const textOnDark = Colors.white;
  static const successOnDark = Color(0xFF4ADE80); // succès sur navy — jamais
  // sur fond clair (green-400, 1,9:1 sur blanc).
  static const errorOnDark = Color(0xFFFCA5A5); // erreur sur navy (red-300)
  static const textOnDarkMuted = Color(0xFF94A3B8); // secondaire sur navy
  static const decorSky = Color(0xFF38BDF8); // accent décoratif — jamais texte
  static const decorIndigo = Color(0xFF6366F1); // accent catégoriel (avatars,
  // leaderboard ambassadeur) ; version claire pour texte/icônes sur navy :
  static const decorIndigoLight = Color(0xFFA5B4FC);
  static const whatsapp = Color(0xFF25D366); // marque externe WhatsApp
  static const googleBlue = Color(0xFF4285F4); // marque externe Google (CTA)

  // ── Brand (noms historiques re-pointés sur la palette KPB Intelligence) ──
  // On garde les noms consommés partout dans l'app ; seules les valeurs
  // changent. L'ancien bleu #004AAD reste disponible via brandBlueLegacy.
  static const navy = brandNavy; // était #1E3A6E
  static const blue = actionPrimary; // était #004AAD
  static const blueMid = actionPrimaryPressed; // était #2D5FBA
  static const sky = decorSky; // était #4EADEA
  static const skyLight = actionPrimarySoft; // était #E8F5FD
  static const gold = Color(0xFFF59E0B); // accent premium/bourses —
  // jamais en texte sur fond clair (2,15:1) : le texte ambre = `warning`.
  static const goldLight = Color(0xFFFFF8E7);

  // ── Semantic ─────────────────────────────────────────────────────────────
  // WCAG AA tuned: each foreground passes 4.5:1 against both its *Light
  // surface and against white — important for outdoor phone use in bright
  // equatorial sun where lighter variants become hard to read.
  static const success = Color(0xFF047857); // emerald-700
  static const successLight = Color(0xFFECFDF5);
  static const warning = Color(0xFFB45309); // amber-700
  static const warningLight = Color(0xFFFFFBEB);
  static const error = Color(0xFFB91C1C); // red-700
  static const errorLight = Color(0xFFFEF2F2);

  // ── Neutrals (échelle slate de la palette KPB Intelligence) ──────────────
  static const gray50 = Color(0xFFF8FAFC); // était #F9FAFB
  static const gray100 = Color(0xFFF1F5F9); // était #F3F4F6
  static const gray200 = Color(0xFFE2E8F0); // était #E5E7EB
  static const gray300 = Color(0xFFCBD5E1); // était #D1D5DB
  static const gray400 = Color(0xFF94A3B8); // était #9CA3AF
  static const gray500 = Color(0xFF64748B); // était #6B7280
  static const gray600 = Color(0xFF475569); // était #4B5563
  static const gray700 = Color(0xFF334155); // était #374151
  static const gray900 = Color(0xFF0F172A); // était #111827

  // ── Text ─────────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFF0F172A); // 17,85:1 sur blanc
  static const textSecondary = Color(0xFF475569); // 7,58:1 sur blanc
  static const textMuted = Color(0xFF64748B); // 4,76:1 — limite basse AA,
  // ne pas éclaircir ; pour du texte ≥ 18 px sur surfaceMuted seulement.

  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const bgPage = canvas; // était #F4F6FB
  static const bgCard = surface;
  static const bgMuted = surfaceMuted; // était #F3F4F6
  static const sand = Color(0xFFFFF4E5);

  // ── Dark UI surfaces (glass nav, immersive screens) ──────────────────────
  static const bgDarkMidnight = Color(0xFF060D1A);
  static const bgDarkCard = Color(0xFF131A2A);
  static const textDarkPrimary = Colors.white;
  static const textDarkSecondary = Color(0xFF94A3B8);
  static const glassBorder = Color(0x33FFFFFF);
  static const glassBg = Color(0x19FFFFFF);

  // ── Field accent colors ───────────────────────────────────────────────────
  static const csBlue = Color(0xFF233F84);
  static const businessSky = Color(0xFF0EA5E9);
  static const engineeringTeal = Color(0xFF0F766E);
  static const medRed = Color(0xFFDB516A);
  static const designOrange = Color(0xFFEA8762);
  static const lawPurple = Color(0xFF7C3AED);
  static const financeGreen = Color(0xFF059669);
  static const marketingPink = Color(0xFFEC4899);

  // ── Gradients ────────────────────────────────────────────────────────────
  /// Fin de dégradé des heros navy (indigo-800) — partagée par Home, pays,
  /// programme et parcours_story.
  static const heroIndigo = Color(0xFF1E3A8A);

  static const heroGradient = LinearGradient(
    colors: [brandNavy, heroIndigo],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradientDark = LinearGradient(
    colors: [Color(0xFF0B1120), brandNavy],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const goldGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFEF8C00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Valeurs du mode sombre — NON conçues pour cette livraison (light-only).
// Regroupées ici pour que buildDarkTheme() et KpbThemeColors.dark restent
// compilables sans hexadécimaux hors de ce fichier.
// ─────────────────────────────────────────────────────────────────────────────

class KpbColorsDark {
  KpbColorsDark._();

  static const pageBg = Color(0xFF111827);
  static const cardBg = Color(0xFF1E2535);
  static const mutedBg = Color(0xFF1A2332);
  static const inputBg = cardBg;
  static const surfaceBg = cardBg;
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF9CA3AF);
  static const textMuted = Color(0xFF6B7280);
  static const divider = Color(0xFF2D3748);
  static const border = Color(0xFF374151);
  static const borderLight = divider;
  static const gray50 = Color(0xFF1A2332);
  static const gray100 = Color(0xFF1E2840);
  static const gray200 = Color(0xFF374151);
  static const gray300 = Color(0xFF4B5563);
  static const gray400 = Color(0xFF6B7280);
  static const gray500 = Color(0xFF4B5563);
  static const successLight = Color(0xFF0D3D2E);
  static const warningLight = Color(0xFF3D2F0D);
  static const errorLight = Color(0xFF3D1515);
  static const goldLight = Color(0xFF3D2F0D);
  static const skyLight = Color(0xFF0D2940);
  static const scrim = Color(0x40000000);

  static const cardShadow = [
    BoxShadow(color: scrim, blurRadius: 12, offset: Offset(0, 3)),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────

class KpbSpacing {
  KpbSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double page = 20;
  static const double pagePad = 20;
}

// ─────────────────────────────────────────────────────────────────────────────

class KpbRadius {
  KpbRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 100;

  static const xsBr = BorderRadius.all(Radius.circular(xs));
  static const smBr = BorderRadius.all(Radius.circular(sm));
  static const mdBr = BorderRadius.all(Radius.circular(md));
  static const lgBr = BorderRadius.all(Radius.circular(lg));
  static const xlBr = BorderRadius.all(Radius.circular(xl));
  static const pillBr = BorderRadius.all(Radius.circular(pill));
}

// ─────────────────────────────────────────────────────────────────────────────

class KpbShadow {
  KpbShadow._();

  static const card = [
    BoxShadow(
      color: Color(0x09000000),
      blurRadius: 12,
      offset: Offset(0, 3),
    ),
  ];

  static const float = [
    BoxShadow(
      color: Color(0x18000000),
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
  ];

  static const soft = [
    BoxShadow(
      color: Color(0x06000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  static const blue = [
    BoxShadow(
      color: Color(0x262563EB),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  /// Ombre portée légère (noir 8 %) pour les barres/surfaces flottantes.
  static const scrimLight = Color(0x14000000);

  /// Ombre très douce teintée navy (4 %) — cartes discrètes des listes.
  static const softNavy = Color(0x0A0F172A);

  /// Ombre navy moyenne (12 %) — heros et cartes mises en avant.
  static const mediumNavy = Color(0x1F0F172A);

  /// Scrim navy appuyé (25 %) — bottom sheets et overlays.
  static const scrimNavy = Color(0x400F172A);
}

// ─────────────────────────────────────────────────────────────────────────────
// Mouvement : durées et courbe communes. Pas de durées ad hoc dans les écrans.
//
// Les constantes ci-dessous sont les valeurs NOMINALES. Un widget qui anime
// lit `KpbMotion.of(context)` : il reçoit des durées nulles quand l'utilisateur
// a coupé les animations (réglage d'accessibilité du système, reflété par
// `MediaQuery.disableAnimations`) ou a activé le « Mode données réduites » de
// l'app — sur un Android d'entrée de gamme, chaque animation coûte des trames.

class KpbMotion {
  KpbMotion._();

  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const page = Duration(milliseconds: 280); // = transition GetX
  static const curve = Curves.easeOutCubic;

  /// Apparition d'un élément de liste ou d'un bandeau (fondu + glissé).
  static const reveal = Duration(milliseconds: 550);

  /// Décalage entre deux éléments successifs d'une liste animée.
  static const staggerStep = Duration(milliseconds: 70);

  /// Seuls les N premiers éléments d'une liste sont animés : au-delà, ils
  /// apparaissent tout de suite (pas de délai index × pas sans limite).
  static const staggerMaxItems = 6;

  /// Sonde de l'économiseur de données de l'app, branchée par AppController.
  /// Les tokens ne dépendent ainsi d'aucun contrôleur ; sans sonde (tests de
  /// widget isolés), l'économiseur est considéré comme coupé.
  static ValueGetter<bool>? dataSaverProbe;

  static bool get _dataSaverOn {
    try {
      return dataSaverProbe?.call() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Durées effectives pour [context] : nominales, ou nulles si les
  /// animations sont désactivées (système) ou l'économiseur de données actif.
  static KpbMotionSpec of(BuildContext context) {
    final systemOff = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return (systemOff || _dataSaverOn) ? KpbMotionSpec.off : KpbMotionSpec.on;
  }

  /// Variante sans contexte (bandeaux posés depuis un contrôleur) : ne voit
  /// que l'économiseur de données, plus le réglage système si [context] est
  /// fourni.
  static KpbMotionSpec resolve([BuildContext? context]) {
    if (context != null) return of(context);
    return _dataSaverOn ? KpbMotionSpec.off : KpbMotionSpec.on;
  }
}

/// Jeu de durées résolu par [KpbMotion.of].
@immutable
class KpbMotionSpec {
  const KpbMotionSpec._(this.enabled);

  static const on = KpbMotionSpec._(true);
  static const off = KpbMotionSpec._(false);

  /// Faux quand toute animation doit sauter directement à son état final.
  final bool enabled;

  Duration get fast => enabled ? KpbMotion.fast : Duration.zero;
  Duration get base => enabled ? KpbMotion.base : Duration.zero;
  Duration get page => enabled ? KpbMotion.page : Duration.zero;
  Duration get reveal => enabled ? KpbMotion.reveal : Duration.zero;
  Duration get staggerStep => enabled ? KpbMotion.staggerStep : Duration.zero;
  Curve get curve => KpbMotion.curve;

  /// Une durée propre à un composant, annulée elle aussi quand le mouvement
  /// est coupé.
  Duration scale(Duration nominal) => enabled ? nominal : Duration.zero;
}

// ─────────────────────────────────────────────────────────────────────────────

/// Nom canonique de la typographie (le plan parle de `KpbTypography`) ; la
/// classe historique `KpbTextStyles` reste le nom concret pour ne pas churner
/// les centaines de call-sites.
typedef KpbTypography = KpbTextStyles;

class KpbTextStyles {
  KpbTextStyles._();

  /// Corps/UI (appliquée globalement via `ThemeData.fontFamily`).
  static const bodyFamily = 'Inter';

  /// Heading family from the App-engagement handoff (body text is Inter via
  /// the global theme `fontFamily`).
  static const headingFamily = 'PlusJakartaSans';

  static const display = TextStyle(
    fontFamily: headingFamily,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: KpbColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const displaySm = TextStyle(
    fontFamily: headingFamily,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: KpbColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.4,
  );

  static const displayXs = TextStyle(
    fontFamily: headingFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: KpbColors.textPrimary,
    height: 1.25,
    letterSpacing: -0.35,
  );

  static const headlineLg = TextStyle(
    fontFamily: headingFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: KpbColors.textPrimary,
    height: 1.25,
    letterSpacing: -0.3,
  );

  static const headline = TextStyle(
    fontFamily: headingFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: KpbColors.textPrimary,
    height: 1.25,
    letterSpacing: -0.3,
  );

  static const headlineSm = TextStyle(
    fontFamily: headingFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: KpbColors.textPrimary,
    height: 1.3,
  );

  static const titleLg = TextStyle(
    fontFamily: headingFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: KpbColors.textPrimary,
    height: 1.3,
  );

  static const title = TextStyle(
    fontFamily: headingFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: KpbColors.textPrimary,
    height: 1.3,
  );

  static const titleMd = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: KpbColors.textPrimary,
    height: 1.3,
  );

  static const titleSm = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: KpbColors.textPrimary,
    height: 1.3,
  );

  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: KpbColors.textPrimary,
    height: 1.5,
  );

  static const bodySm = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: KpbColors.textSecondary,
    height: 1.4,
  );

  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: KpbColors.textSecondary,
    letterSpacing: 0.4,
  );

  static const labelSm = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: KpbColors.textMuted,
    height: 1.4,
  );
}
