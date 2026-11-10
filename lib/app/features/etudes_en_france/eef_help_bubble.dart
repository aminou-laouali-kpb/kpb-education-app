import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/config/support_contact.dart';
import '../../core/services/remote_feature_flags.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/whatsapp_utils.dart';
import 'eef_entry.dart';
import 'eef_help_card.dart';
import 'eef_help_line.dart';
import 'eef_private_schools_sheet.dart';

/// L'écran porteur de la bulle. La valeur de [key] est la propriété `surface` de
/// l'analytique (`hub` ou `catalog`) ; [placeKey] est le texte qui dit, DANS le
/// message WhatsApp, où l'étudiant se trouvait.
///
/// Un enum fermé et non une chaîne : un identifiant se faute à la compilation, et
/// la bulle ne vit pas ailleurs (jamais la vitrine, les outils, l'écran des
/// parents, ni la coque de l'app — voir [EefHelpBubble.shouldShow]).
enum EefBubbleSurface {
  hub(key: 'hub', placeKey: 'eef_help_bubble_place_hub'),
  catalog(key: 'catalog', placeKey: 'eef_help_bubble_place_catalog');

  const EefBubbleSurface({required this.key, required this.placeKey});

  final String key;
  final String placeKey;
}

/// Les sujets du menu de la bulle.
///
/// ## Pourquoi un enum à part de [EefHelpTrigger] et de [EefHelpStep]
///
/// [EefHelpTrigger] exige une `surface` dans `{catalog, tools}` (le garde de
/// `eef_help_line_test.dart`), et ses messages dépendent de ce que l'étudiant
/// regarde (une formation, des filtres). Un sujet de la bulle n'a ni l'un ni
/// l'autre : le message dépend du SUJET choisi et de l'ÉCRAN porteur. Les mêler
/// aurait obligé chaque `switch` existant à connaître une exception qui ne le
/// concerne pas.
///
/// L'[id] sert de valeur analytique (`help_step`) et de racine de la source
/// WhatsApp (`eef_help_<id>`, donc `eef_help_bubble_<sujet>`). Il est le MÊME
/// pour le menu standard et pour le menu d'un compte dont le pays est suspendu :
/// un identifiant qui dirait « suspendu » révélerait le pays, que la mesure ne
/// porte volontairement jamais.
enum EefBubbleOption {
  assistance(
    id: 'bubble_assistance',
    stem: 'assistance',
    neutralLabel: true,
    hasNeutral: true,
  ),
  dossier(
    id: 'bubble_dossier',
    stem: 'dossier',
    neutralLabel: false,
    hasNeutral: false,
  ),
  choose(
    id: 'bubble_choose',
    stem: 'choose',
    neutralLabel: false,
    hasNeutral: false,
  ),

  /// « Je veux en savoir plus sur les écoles privées » : n'ENVOIE rien, ouvre la
  /// feuille d'information (`eef_private_schools_sheet.dart`), qui porte, elle,
  /// le bouton vers WhatsApp. Proposée seulement si l'interrupteur serveur
  /// `eefPrivateSchools` est ouvert ET que le compte n'est pas suspendu ; elle
  /// n'a pas de variante neutre, donc le menu à deux lignes d'un compte suspendu
  /// ne la montre jamais.
  private(
    id: 'bubble_private',
    stem: 'private',
    neutralLabel: false,
    hasNeutral: false,
    opensInfoSheet: true,
  ),
  question(
    id: 'bubble_question',
    stem: 'question',
    neutralLabel: false,
    hasNeutral: true,
  );

  const EefBubbleOption({
    required this.id,
    required this.stem,
    required this.neutralLabel,
    required this.hasNeutral,
    this.opensInfoSheet = false,
  });

  /// Identifiant stable : `help_step` de l'analytique, source du suivi WhatsApp.
  final String id;

  /// Racine des clés de traduction (`eef_help_bubble_<stem>_label`…).
  final String stem;

  /// Le libellé change pour un compte dont le pays est suspendu.
  final bool neutralLabel;

  /// Une variante NEUTRE du message existe. Sans elle, le sujet n'est pas
  /// proposé à un compte suspendu (il parlerait d'un dossier à ouvrir).
  final bool hasNeutral;

  /// Le sujet OUVRE une feuille d'information au lieu d'envoyer un message : la
  /// tuile montre une pastille « Service KPB » à la place du message, et le tap
  /// ne mesure aucun `eef_help_cta_tapped` (lire n'est pas écrire).
  final bool opensInfoSheet;
}

/// Les libellés et les messages du menu : une seule porte vers les textes, pour
/// que le menu, le tap et les tests lisent la même règle.
///
/// ## Ce qu'un message contient, et ne contient pas
///
/// Il nomme l'ÉCRAN (`@place`) et rien d'autre : ni nom, ni e-mail, ni
/// téléphone, ni pays — le profil n'est pas lu. Pour un compte dont le pays est
/// suspendu, il dit que la procédure est suspendue « dans mon pays » SANS le
/// nommer, ne cite aucun pays de remplacement (ce contenu n'est pas validé
/// juridiquement) et ne parle jamais d'ouvrir un dossier.
abstract final class EefBubbleMessages {
  /// Bornes du message entier, en points de code et encodé dans le lien : les
  /// mêmes que celles des lignes d'aide ([EefHelpMessages]). Les messages
  /// statiques de la bulle en sont très loin ; les tests le gardent.
  static const int maxMessageChars = EefHelpMessages.maxMessageChars;
  static const int maxEncodedChars = EefHelpMessages.maxEncodedChars;

  /// Les sujets proposés. Un compte suspendu garde les seuls sujets qui ont une
  /// variante neutre.
  ///
  /// [privateSchools] : l'interrupteur serveur des écoles privées (fermé par
  /// défaut). Sans valeur, il est lu sur [RemoteFeatureFlags] ; le sujet est
  /// alors le 4e du menu, entre « quelle formation choisir » et « une autre
  /// question ».
  static List<EefBubbleOption> optionsFor({
    required bool suspended,
    bool? privateSchools,
  }) {
    final withPrivate =
        privateSchools ?? RemoteFeatureFlags.instance.eefPrivateSchoolsEnabled;
    return EefBubbleOption.values
        .where((option) => withPrivate || option != EefBubbleOption.private)
        .where((option) => !suspended || option.hasNeutral)
        .toList(growable: false);
  }

  /// Le libellé d'un sujet.
  static String labelFor(EefBubbleOption option, {required bool suspended}) {
    // Les textes des écoles privées vivent sous leur propre préfixe
    // (`eef_help_private_*`), avec la feuille qu'ils ouvrent.
    if (option == EefBubbleOption.private) {
      return 'eef_help_private_option_label'.tr;
    }
    final neutral = suspended && option.neutralLabel;
    return 'eef_help_bubble_${option.stem}_label${neutral ? '_neutral' : ''}'
        .tr;
  }

  /// Le sujet qui PART réellement : celui qu'on a tapé, sauf pour un compte
  /// suspendu et un sujet sans variante neutre, où c'est l'assistance.
  ///
  /// Une seule règle pour le message ET la mesure : l'identifiant mesuré
  /// (`help_step`, source WhatsApp) doit désigner le texte qui part, pas la
  /// tuile sur laquelle l'étudiant a tapé.
  static EefBubbleOption effectiveOption(
    EefBubbleOption option, {
    required bool suspended,
  }) =>
      suspended && !option.hasNeutral ? EefBubbleOption.assistance : option;

  /// Le message que WhatsApp ouvre déjà rédigé.
  ///
  /// Pour un compte suspendu, un sujet SANS variante neutre ne rend jamais son
  /// message standard : il rend celui de l'assistance, neutre. Le menu ne le lui
  /// propose pas (voir [optionsFor]) ; ceci couvre la fenêtre où la suspension
  /// arrive entre l'ouverture de la feuille et le tap.
  static String messageFor(
    EefBubbleOption option,
    EefBubbleSurface surface, {
    required bool suspended,
  }) {
    final effective = effectiveOption(option, suspended: suspended);
    // Le message de la feuille des écoles privées (jamais celui d'un envoi direct
    // depuis le menu : le sujet ouvre la feuille, qui le montre sous son bouton).
    final key = effective == EefBubbleOption.private
        ? 'eef_help_private_message'
        : 'eef_help_bubble_${effective.stem}_message'
            '${suspended ? '_neutral' : ''}';
    return key.trParams({'place': surface.placeKey.tr}).trim();
  }
}

/// Le sujet EFFECTIF choisi dans la feuille (voir
/// [EefBubbleMessages.effectiveOption]), et le message déjà calculé AU TAP.
class _BubblePick {
  const _BubblePick(this.option, this.message);

  /// Le sujet des écoles privées : rien à envoyer, la feuille d'information
  /// s'ouvre à la place du menu.
  const _BubblePick.infoSheet()
      : option = EefBubbleOption.private,
        message = '';

  final EefBubbleOption option;
  final String message;

  bool get opensInfoSheet => option.opensInfoSheet;
}

/// La bulle verte WhatsApp : un cercle de 56 dp dans le hub et le catalogue de
/// l'espace « Études en France », qui ouvre un menu de sujets. Chaque sujet
/// ouvre WhatsApp, vers le numéro officiel de KPB, avec un message déjà écrit.
///
/// ## Quand elle existe
///
/// [shouldShow] : l'espace ouvert (`eefSpace`) ET la bulle ouverte
/// (`eefHelpBubble`, fermée par défaut) ET un compte étudiant ou un invité. Les
/// écrans la montent ou non, et portent la marge de liste correspondante
/// ([listBottomPadding]) ; elle ne se cache pas elle-même, pour que la liste et
/// la bulle ne puissent pas diverger.
///
/// ## Ce qu'elle s'interdit
///
/// - **Envoyer sans un tap.** Le menu dit « rien n'est envoyé sans toi » et le
///   tap sur un sujet ouvre WhatsApp, où l'étudiant lit et modifie le message.
/// - **Un second chemin vers WhatsApp.** Le tap passe par [kpbWhatsAppPrefill]
///   puis [openWhatsAppOrToast], qui journalise `whatsapp_handoff` et affiche le
///   repli quand WhatsApp ne s'ouvre pas ; le lancement est TENTÉ, jamais
///   précédé d'une question « WhatsApp est-il installé ? » (elle ment sur
///   Android 11 et plus).
/// - **Révéler la suspension.** Un compte dont le pays est suspendu a un menu à
///   deux lignes neutres, mesuré sous les MÊMES identifiants.
/// - **Prendre la place d'une liste.** La marge basse passe de 32 à 104 dp
///   (56 + 16 + 32) quand elle est là.
///
/// ## Mesure
///
/// `eef_help_card_shown` (`help_step` = `bubble`, `variant` = `bubble`) part UNE
/// fois par visite de l'écran ; `eef_bubble_opened` (`surface`) à l'ouverture du
/// menu ; `eef_help_cta_tapped` (`help_step` = `bubble_<sujet>`) UNIQUEMENT pour
/// ce qui part vers WhatsApp, avec EXACTEMENT les trois propriétés de la carte
/// d'aide. Fermer la feuille sans choisir ne mesure aucun tap.
class EefHelpBubble extends StatefulWidget {
  const EefHelpBubble({super.key, required this.surface});

  final EefBubbleSurface surface;

  /// Diamètre du cercle.
  static const double size = 56;

  /// La marge qui sépare la bulle du bord de l'écran (ou de la rangée des
  /// sources, dans le catalogue).
  static const double edgeMargin = 16;

  /// La marge basse d'une liste SANS bulle.
  static const double listBottomPlain = KpbSpacing.xl;

  /// La marge basse d'une liste AVEC bulle : la bulle (56) + sa marge (16) + la
  /// marge ordinaire (32), pour que la dernière carte défile jusqu'au-dessus
  /// d'elle.
  static const double listBottomWithBubble =
      size + edgeMargin + listBottomPlain;

  /// La hauteur minimale de l'espace qui porte la bulle (la liste des
  /// résultats du catalogue) : la bulle (56) entre deux marges (16 + 16). En
  /// dessous, le `Stack` la rognerait et elle ne se laisserait plus toucher.
  static const double minHostHeight = size + 2 * edgeMargin;

  /// La marge basse à donner à une liste selon que la bulle est montrée.
  static double listBottomPadding({required bool bubbleShown}) =>
      bubbleShown ? listBottomWithBubble : listBottomPlain;

  /// La bulle doit-elle être montrée ICI, MAINTENANT ?
  ///
  /// À appeler depuis un `build` reconstruit sur `flagsVersion` : les drapeaux
  /// arrivent après le premier cadre. Lit [MediaQuery] — donc à appeler AU-DESSUS
  /// du `Scaffold` : le `Scaffold` consomme le clavier pour son corps, qui ne le
  /// voit plus.
  ///
  /// - l'espace ET la bulle sont ouverts par le serveur (deux interrupteurs, tous
  ///   deux fermés par défaut ; la bulle n'ouvre rien seule) ;
  /// - jamais pour un compte résolu qui n'est pas étudiant (parent, partenaire) :
  ///   la même règle que la porte de l'espace ([EefEntry.isNonStudentAccount]) ;
  ///   l'invité, sans profil, y a droit ;
  /// - jamais clavier ouvert : la bulle masquerait le champ de recherche.
  static bool shouldShow(BuildContext context) {
    final flags = RemoteFeatureFlags.instance;
    if (!flags.eefSpaceEnabled || !flags.eefHelpBubbleEnabled) return false;
    if (EefEntry.isNonStudentAccount) return false;
    return MediaQuery.viewInsetsOf(context).bottom <= 0;
  }

  @override
  State<EefHelpBubble> createState() => _EefHelpBubbleState();
}

class _EefHelpBubbleState extends State<EefHelpBubble> {
  bool _shownLogged = false;

  /// Vrai de l'ouverture du menu jusqu'à l'envoi vers WhatsApp : un second tap
  /// est ignoré. Posé de façon SYNCHRONE — deux taps sans cadre entre eux
  /// tombent tous deux sur la bulle encore là.
  bool _sheetOpen = false;

  void _logShownOnce() {
    if (_shownLogged) return;
    _shownLogged = true;
    if (eefHelpAlreadyCountedThisVisit(context, 'bubble')) return;
    // Après le cadre : une mesure n'a pas à tourner pendant `build`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      EefHelp.analytics.shown(
        step: 'bubble',
        surface: widget.surface.key,
        variant: 'bubble',
      );
    });
  }

  Future<void> _open() async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    try {
      final surface = widget.surface;
      EefHelp.analytics.bubbleOpened(surface: surface.key);

      TransitionRoute<Object?>? route;
      final pick = await showModalBottomSheet<_BubblePick>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        // Un iPad ne tire pas une feuille de 768 dp de large.
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (sheetContext) {
          route ??= ModalRoute.of(sheetContext);
          return _BubbleSheet(surface: surface);
        },
      );
      if (pick == null) return;

      // `showModalBottomSheet` rend la main dès le DÉBUT de la fermeture : on
      // attend qu'elle soit finie. Le toast d'un WhatsApp absent ne doit pas
      // naître sous une feuille encore à l'écran, ni WhatsApp s'ouvrir devant
      // elle.
      await route?.completed;

      // Les écoles privées : le menu est fermé, la feuille d'information
      // s'ouvre à sa place. Rien n'est mesuré comme un envoi (lire n'est pas
      // écrire) : `eef_private_info_opened` part à l'ouverture, et c'est la
      // feuille qui porte, elle, le bouton vers WhatsApp. Le garde `_sheetOpen`
      // reste posé pendant toute la lecture.
      if (pick.opensInfoSheet) {
        if (!mounted) return;
        await showEefPrivateSchoolsSheet(
          context,
          surface: surface,
          entry: EefPrivateInfoEntry.bubble,
        );
        return;
      }

      // Part AVANT l'ouverture de WhatsApp : `whatsapp_handoff` dit ensuite si
      // elle a réussi.
      EefHelp.analytics.tapped(
        step: pick.option.id,
        surface: surface.key,
        variant: 'bubble',
      );
      unawaited(openWhatsAppOrToast(
        // Le point d'entrée commun : on n'ouvre pas un second chemin vers le
        // conseiller.
        prefill: kpbWhatsAppPrefill(custom: pick.message),
        source: 'eef_help_${pick.option.id}',
        contextType: 'eef_help',
      ));
    } finally {
      _sheetOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    _logShownOnce();
    final label = 'eef_help_bubble_tooltip'.tr;
    return Semantics(
      // Un nœud à lui, nommé, avec son indice : « Ouvre une liste de messages
      // prêts à envoyer ».
      container: true,
      button: true,
      enabled: true,
      label: label,
      hint: 'eef_help_bubble_hint'.tr,
      onTap: _open,
      // L'arbre visuel dit la même chose : on ne l'expose pas deux fois.
      excludeSemantics: true,
      child: FloatingActionButton(
        key: const ValueKey('eef-help-bubble'),
        // Nul : sinon une animation Hero relie la bulle du hub à celle du
        // catalogue — et une étiquette fixe collisionnerait avec d'autres FAB.
        heroTag: null,
        tooltip: label,
        onPressed: _open,
        backgroundColor: KpbColors.whatsapp,
        // Le blanc ne fait qu'environ 1,98:1 sur ce vert, le marine environ 9:1
        // (mesuré sur les pixels par le test de la bulle).
        foregroundColor: KpbColors.brandNavy,
        elevation: 4,
        // Le thème donne un carré arrondi aux boutons flottants.
        shape: const CircleBorder(),
        // L'icône générique, jamais le logo de WhatsApp.
        child: const Icon(Icons.chat_rounded, size: 26),
      ),
    );
  }
}

/// La feuille de sujets.
///
/// Elle se reconstruit à l'arrivée des drapeaux serveur (la liste des pays
/// suspendus vit dans `/config/app`) et lit la suspension UNE fois par
/// construction ([EefHelp.isSuspended], le point unique). Le MESSAGE, lui, est
/// recalculé AU TAP : un menu construit avant l'arrivée du drapeau ne peut pas
/// envoyer le texte d'un dossier à un compte devenu suspendu entre-temps.
class _BubbleSheet extends StatefulWidget {
  const _BubbleSheet({required this.surface});

  final EefBubbleSurface surface;

  @override
  State<_BubbleSheet> createState() => _BubbleSheetState();
}

class _BubbleSheetState extends State<_BubbleSheet> {
  /// Un seul sujet par feuille : un second tap, avant que la fermeture ne soit
  /// finie, dépilerait l'écran qui est dessous.
  bool _picked = false;

  /// « Copié » a été dit pour le numéro.
  bool _copied = false;

  void _choose(EefBubbleOption option) {
    if (_picked) return;
    _picked = true;
    // Les écoles privées ouvrent une feuille d'information et n'envoient rien :
    // pas d'option « effective » (qui, pour un compte devenu suspendu entre-temps,
    // enverrait le message de l'assistance sans que l'étudiant l'ait demandé).
    // La feuille, elle, ne s'ouvre pas si la suspension est arrivée.
    if (option.opensInfoSheet) {
      Navigator.of(context).pop(const _BubblePick.infoSheet());
      return;
    }
    final suspended = EefHelp.isSuspended();
    // L'option EFFECTIVE, pas la tuile tapée : si la suspension est arrivée
    // entre l'ouverture de la feuille et ce tap, un sujet sans variante neutre
    // envoie le message de l'assistance — et la mesure (`help_step`, source
    // WhatsApp) doit dire `bubble_assistance`, jamais `bubble_dossier` ni
    // `bubble_choose` (le contrat promet qu'un compte suspendu n'en produit pas).
    final effective =
        EefBubbleMessages.effectiveOption(option, suspended: suspended);
    final message = EefBubbleMessages.messageFor(
      option,
      widget.surface,
      suspended: suspended,
    );
    Navigator.of(context).pop(_BubblePick(effective, message));
  }

  Future<void> _copyNumber(String number) async {
    await Clipboard.setData(ClipboardData(text: number));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final number = SupportContact.whatsappNumber.trim();

    return ValueListenableBuilder<int>(
      valueListenable: RemoteFeatureFlags.instance.flagsVersion,
      builder: (context, _, __) {
        final suspended = EefHelp.isSuspended();
        final options = EefBubbleMessages.optionsFor(suspended: suspended);

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            key: const ValueKey('eef-help-bubble-sheet'),
            padding: const EdgeInsets.fromLTRB(
              KpbSpacing.pagePad,
              0,
              KpbSpacing.pagePad,
              KpbSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'eef_help_bubble_title'.tr,
                  style: KpbTextStyles.title.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: KpbSpacing.xs),
                Text(
                  'eef_help_bubble_subtitle'.tr,
                  style: KpbTextStyles.bodySm.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: KpbSpacing.md),
                for (final option in options) ...[
                  _TopicTile(
                    option: option,
                    label: EefBubbleMessages.labelFor(
                      option,
                      suspended: suspended,
                    ),
                    // Un sujet qui ouvre une feuille n'annonce pas de message :
                    // il montre la pastille « Service KPB ».
                    message: option.opensInfoSheet
                        ? null
                        : EefBubbleMessages.messageFor(
                            option,
                            widget.surface,
                            suspended: suspended,
                          ),
                    onTap: () => _choose(option),
                  ),
                  const SizedBox(height: KpbSpacing.sm),
                ],
                const SizedBox(height: KpbSpacing.xs),
                Divider(color: c.divider, height: 1),
                const SizedBox(height: KpbSpacing.sm),
                // Le repli : le numéro OFFICIEL à reconnaître (l'usurpation de
                // conseillers sur WhatsApp est le danger du marché), à copier,
                // et une adresse pour qui n'a pas WhatsApp.
                Text(
                  'eef_help_bubble_number'.trParams({'number': number}),
                  style: KpbTextStyles.bodySm.copyWith(color: c.textPrimary),
                ),
                _CopyNumberButton(
                  copied: _copied,
                  onTap: () => _copyNumber(number),
                ),
                Text(
                  'eef_help_bubble_email'.tr,
                  style: KpbTextStyles.bodySm.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: KpbSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: KpbColors.warning,
                      ),
                    ),
                    const SizedBox(width: KpbSpacing.sm),
                    Expanded(
                      child: Text(
                        'anti_fraud_body'.tr,
                        style: KpbTextStyles.bodySm
                            .copyWith(color: c.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KpbSpacing.sm),
                Text(
                  'eef_help_fineprint'.tr,
                  style: KpbTextStyles.caption.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Un sujet : son libellé ET, dessous, le message exact qui partira. Au moins
/// 56 dp de haut ; les textes passent à la ligne (jamais coupés) à l'échelle de
/// texte 1,3.
class _TopicTile extends StatelessWidget {
  const _TopicTile({
    required this.option,
    required this.label,
    required this.message,
    required this.onTap,
  });

  final EefBubbleOption option;
  final String label;

  /// Le message exact qui partira ; `null` pour un sujet qui ouvre une feuille.
  final String? message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final message = this.message;
    return Semantics(
      key: ValueKey('eef-help-bubble-option-${option.id}'),
      // Le libellé et le message sont lus ENSEMBLE : le message est ce qui
      // partira, un lecteur d'écran doit le dire avant le tap. Un sujet qui
      // ouvre une feuille dit sa pastille (« Service KPB ») à la place.
      container: true,
      button: true,
      enabled: true,
      label: '$label. ${message ?? 'eef_help_private_chip'.tr}',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: c.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: KpbRadius.mdBr,
          side: BorderSide(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KpbSpacing.md,
                vertical: KpbSpacing.sm + 2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      // Un sujet qui n'envoie rien ne porte pas la bulle de
                      // discussion des sujets qui ouvrent WhatsApp.
                      message == null
                          ? Icons.info_outline_rounded
                          : Icons.chat_rounded,
                      size: 18,
                      color: KpbColors.actionPrimary,
                    ),
                  ),
                  const SizedBox(width: KpbSpacing.sm + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: KpbTextStyles.titleSm
                              .copyWith(color: c.textPrimary),
                        ),
                        const SizedBox(height: KpbSpacing.xs),
                        if (message == null)
                          const Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: EefKpbServiceChip(),
                          )
                        else
                          Text(
                            message,
                            style: KpbTextStyles.bodySm
                                .copyWith(color: c.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// « Copier le numéro », puis « Copié ». Un bouton de texte du thème, sur 48 dp
/// de haut au moins.
class _CopyNumberButton extends StatelessWidget {
  const _CopyNumberButton({required this.copied, required this.onTap});

  final bool copied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        // « Copié » est annoncé quand il apparaît.
        liveRegion: true,
        child: TextButton.icon(
          key: const ValueKey('eef-help-bubble-copy'),
          onPressed: onTap,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            tapTargetSize: MaterialTapTargetSize.padded,
            padding: const EdgeInsets.symmetric(horizontal: KpbSpacing.sm),
          ),
          icon: Icon(
            copied ? Icons.check_rounded : Icons.content_copy_rounded,
            size: 16,
          ),
          label: Text(
            (copied ? 'eef_help_bubble_copied' : 'eef_help_bubble_copy').tr,
          ),
        ),
      ),
    );
  }
}
