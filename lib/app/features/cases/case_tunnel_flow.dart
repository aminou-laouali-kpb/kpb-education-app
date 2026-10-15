import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/config/app_config.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/document_upload_service.dart';
import '../../core/services/speech_input_service.dart';
import '../../core/ui/components/kpb_guest_gate.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/country_utils.dart';
import '../../core/utils/whatsapp_utils.dart';

// Couleurs : tokens sémantiques centraux (KpbColors/KpbShadow — architecture §10.2).

/// Les deux gestes que l'étape « Message » emprunte au SYSTÈME avant d'ouvrir
/// une dictée : « faut-il demander la permission micro à l'exécution ? », puis
/// « la demander ».
///
/// Pourquoi une couture. Le code appelait `Platform.isAndroid` et
/// `Permission.microphone.request()` en ligne. Sous `flutter test` sur macOS
/// `Platform.isAndroid` vaut FAUX : la branche « permission refusée », celle qui
/// affiche `case_message_mic_required_*`, n'était jouée par aucun test — ni
/// celui de la dictée, ni un autre. Elle pouvait casser sans qu'une seule
/// assertion bouge.
///
/// Ce que la couture NE change pas. Les valeurs par défaut sont exactement le
/// code qu'elles remplacent : `Platform.isAndroid` et
/// `Permission.microphone.request().isGranted`. Rien n'est dévié tant qu'un test
/// n'a pas posé de remplaçant, donc la production voit le comportement
/// d'aujourd'hui, à l'identique.
///
/// Patron repris du dépôt plutôt qu'inventé : `AppConfig` (champ `_override`
/// nullable + setter `@visibleForTesting`) et `IntakeCalendar.clock`.
/// Piste écartée : injecter les deux fonctions par le constructeur de
/// `_MessageStep` — il faudrait les faire traverser `CaseTunnelFlow` et son
/// appelant, soit élargir l'API publique de l'écran pour les besoins du test.
class CaseDictationPlatform {
  CaseDictationPlatform._();

  static bool Function()? _requiresMicrophonePermissionOverride;
  static Future<bool> Function()? _requestMicrophonePermissionOverride;

  /// Vrai là où la permission micro se demande à l'exécution — Android. Sur iOS
  /// c'est le moteur de reconnaissance qui présente lui-même son dialogue
  /// système, l'app n'a rien à demander avant.
  static bool get requiresMicrophonePermission =>
      _requiresMicrophonePermissionOverride?.call() ?? Platform.isAndroid;

  /// Demande la permission micro. Rend `true` si, et seulement si, elle est
  /// accordée — « refusée définitivement » et « refusée cette fois » se
  /// traitent pareil côté écran : pas de dictée, et on le dit.
  static Future<bool> requestMicrophonePermission() async {
    final override = _requestMicrophonePermissionOverride;
    if (override != null) return override();
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  @visibleForTesting
  static set requiresMicrophonePermissionOverride(bool Function()? value) =>
      _requiresMicrophonePermissionOverride = value;

  @visibleForTesting
  static set requestMicrophonePermissionOverride(
    Future<bool> Function()? value,
  ) =>
      _requestMicrophonePermissionOverride = value;

  /// À appeler en `tearDown`. Une couture laissée armée contaminerait le test
  /// suivant, qui croirait mesurer le défaut de production.
  @visibleForTesting
  static void resetOverrides() {
    _requiresMicrophonePermissionOverride = null;
    _requestMicrophonePermissionOverride = null;
  }
}

class CaseTunnelPrefill {
  const CaseTunnelPrefill({
    required this.title,
    required this.contextLabel,
    this.initialType = CaseType.applicationSupport,
    this.countryId,
    this.institutionId,
    this.programId,
    this.scholarshipId,
  });

  final String title;
  final String contextLabel;
  final CaseType initialType;
  final String? countryId;
  final String? institutionId;
  final String? programId;

  /// La bourse liée (« Être accompagné » du test « Mes 10 bourses »).
  final String? scholarshipId;
}

class CaseTunnelFlow extends StatefulWidget {
  const CaseTunnelFlow({
    super.key,
    required this.prefill,
    this.onClose,
    this.onSubmitted,
  });

  final CaseTunnelPrefill prefill;
  final VoidCallback? onClose;
  final VoidCallback? onSubmitted;

  @override
  State<CaseTunnelFlow> createState() => _CaseTunnelFlowState();
}

class _CaseTunnelFlowState extends State<CaseTunnelFlow> {
  static List<String> get _stepLabels => [
        'case_tunnel_step_type'.tr,
        'case_tunnel_step_context'.tr,
        'case_section_documents'.tr,
        'case_tunnel_step_message'.tr,
        'case_tunnel_step_confirmation'.tr,
      ];

  var _step = 0;
  late CaseType _type;
  final _messageController = TextEditingController();
  ContactMethod _contactMethod = ContactMethod.inApp;
  final Map<String, String> _attachedDocs = <String, String>{};
  final Map<String, String> _attachedDocSizes = <String, String>{};

  AppController get _controller => Get.find<AppController>();

  @override
  void initState() {
    super.initState();
    _type = widget.prefill.initialType;
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String? get _countryLabel {
    final id = widget.prefill.countryId;
    if (id == null) return null;
    final country = _controller.countryByIdOrNull(id);
    return country != null ? _controller.resolve(country.name) : id;
  }

  String? get _institutionLabel {
    final id = widget.prefill.institutionId;
    if (id == null) return null;
    final inst = _controller.institutionByIdOrNull(id);
    return inst != null ? _controller.resolve(inst.name) : id;
  }

  String? get _programLabel {
    final id = widget.prefill.programId;
    if (id == null) return null;
    final program = _controller.programByIdOrNull(id);
    return program != null ? _controller.resolve(program.name) : id;
  }

  void _next() {
    if (_step < _stepLabels.length - 1) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step == 0) {
      widget.onClose?.call();
      return;
    }
    setState(() => _step--);
  }

  void _submit() {
    final message = _messageController.text.trim();
    final defaultTitle = widget.prefill.title;
    final descriptionParts = <String>[
      if (message.isNotEmpty)
        message
      else
        'case_default_title'.trParams({'title': defaultTitle}),
      if (_attachedDocs.isNotEmpty)
        '${'case_tunnel_attached_documents_prefix'.tr}\n${_attachedDocs.entries.map((e) => '• ${e.key}: ${e.value.split('/').last}').join('\n')}',
    ];

    try {
      _controller.submitCase(
        type: _type,
        title: defaultTitle,
        description: descriptionParts.join('\n\n'),
        contextLabel: widget.prefill.contextLabel,
        contactMethod: _contactMethod,
        scholarshipId: widget.prefill.scholarshipId,
      );
      widget.onSubmitted?.call();
    } on StateError {
      // `submitCase` ne lève un StateError que pour UNE raison — onboarding
      // inachevé ou profil absent — et c'est la seule que ce message décrit.
      //
      // Le `catch (_)` d'avant l'attrapait pour n'importe quoi : une panne de
      // persistance, une exception de plugin, un `TypeError` dans le codec
      // devenaient tous « Profil incomplet ». Un diagnostic faux affiché avec
      // aplomb coûte plus cher qu'une absence de diagnostic — il envoie
      // l'utilisateur ET le développeur chercher au mauvais endroit.
      //
      // Depuis que la garde est posée en tête de `build`, ce chemin est
      // d'ailleurs devenu inatteignable dans l'app : un test l'exige.
      KpbToast.error(
        'case_tunnel_incomplete_profile_body'.tr,
        title: 'case_tunnel_incomplete_profile_title'.tr,
      );
    }
  }

  Future<void> _pickDocument(String label) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: Text('case_tunnel_pick_photo'.tr),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text('case_tunnel_pick_gallery'.tr),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: const Text('PDF'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    File? file;
    try {
      switch (choice) {
        case 'camera':
          file = await DocumentUploadService.captureFromCamera();
        case 'gallery':
          file = await DocumentUploadService.pickFromGallery();
        case 'pdf':
          file = await DocumentUploadService.pickPdf();
      }
    } on FileTooLargeException catch (error) {
      if (mounted) {
        KpbToast.error(
          // `error.toString()` partait ici, en anglais brut, sous un titre
          // traduit — sur une app dont tout le public est francophone.
          error.localizedBody(),
          title: 'case_tunnel_file_too_large_title'.tr,
        );
      }
      return;
    } catch (_) {
      if (mounted) {
        KpbToast.error('case_tunnel_add_file_failed'.tr);
      }
      return;
    }

    if (file != null && mounted) {
      final size = await file.length();
      setState(() {
        _attachedDocs[label] = file!.path;
        _attachedDocSizes[label] = DocumentUploadService.formatFileSize(size);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── LE point d'étranglement du tunnel ──────────────────────────────────
    //
    // Le mur invité vivait dans `case_create_screen.dart` et `cases_screen.dart`
    // — deux surfaces — alors que le tunnel a DIX-NEUF entrées mesurées :
    // 17 `CaseComposerSheet(`, plus `case_create_screen.dart` et
    // `program_detail_screen.dart`. Le CTA de héros de l'accueil est de
    // celles-là, il est AFFICHÉ à l'invité, et il ouvrait le tunnel sans
    // rencontrer aucune garde : cinq étapes remplies, « Envoyer », puis un
    // bandeau parlant d'un onboarding jamais commencé, sans bouton pour s'y
    // rendre, et la saisie perdue. L'étape de conversion la plus précieuse de
    // l'app se terminait en cul-de-sac.
    //
    // Poser la garde ICI, et non sur chaque hôte, est ce qui rend le correctif
    // durable : les dix-neuf entrées passent toutes par ce `build`, donc une
    // vingtième sera gardée sans que personne n'ait à y penser. C'est la leçon
    // inverse de PARC-05 lui-même.
    if (_controller.isGuestMode) {
      return const KpbGuestGate(source: 'case_tunnel_gate');
    }

    // Compte réel, profil absent. Le bandeau d'origine lui parlait d'un profil
    // incomplet sans jamais lui donner le chemin pour le compléter ; ici le
    // chemin EST le bouton. On ne redirige pas d'autorité depuis un `build` :
    // une navigation déclenchée par un rendu surprend l'utilisateur et se
    // reproduit à chaque reconstruction.
    if (_controller.profile == null) {
      return KpbGuestGate(
        source: 'case_tunnel_profile',
        icon: Icons.assignment_ind_outlined,
        titleKey: 'case_tunnel_incomplete_profile_title',
        bodyKey: 'case_tunnel_incomplete_profile_body',
        ctaKey: 'case_tunnel_incomplete_profile_cta',
        onConverted: widget.onClose,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(
          step: _step,
          total: _stepLabels.length,
          labels: _stepLabels,
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildStep(context)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _back,
                child: Text(_step == 0 ? 'close'.tr : 'common_back'.tr),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _canContinue ? _next : null,
                child: Text(
                  _step == _stepLabels.length - 1
                      ? 'submit'.tr
                      : 'common_next'.tr,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool get _canContinue {
    switch (_step) {
      case 3:
        return true;
      default:
        return true;
    }
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _TypeStep(
          selected: _type,
          onSelected: (type) => setState(() => _type = type),
        );
      case 1:
        return _ContextStep(
          prefill: widget.prefill,
          countryLabel: _countryLabel,
          institutionLabel: _institutionLabel,
          programLabel: _programLabel,
          countryFlag: widget.prefill.countryId != null
              ? displayCountryFlag(id: widget.prefill.countryId!)
              : null,
        );
      case 2:
        // M2 : l'étape « Documents » ne disparaît pas, elle dit la vérité.
        //
        // Ce que faisait la version à trois sélecteurs : elle gardait un CHEMIN
        // LOCAL de fichier et écrivait son nom dans la description du dossier
        // (« Documents joints: • CV: IMG_1234.jpg »). Pas un octet ne partait —
        // `submitCase` n'a aucun paramètre de pièce jointe. L'étudiant croyait
        // avoir joint son passeport, le conseiller lisait un nom de fichier.
        //
        // Supprimer l'étape aurait été plus simple et moins honnête : l'étudiant
        // a bien des documents à transmettre, et il a droit à ce qu'on lui dise
        // par où.
        if (!AppConfig.documentUploadEnabled) {
          return _DocumentsHandoffStep(caseTitle: widget.prefill.title);
        }
        return _DocumentsStep(
          attached: _attachedDocs,
          sizes: _attachedDocSizes,
          onPick: _pickDocument,
          onRemove: (key) => setState(() {
            _attachedDocs.remove(key);
            _attachedDocSizes.remove(key);
          }),
        );
      case 3:
        return _MessageStep(
          controller: _messageController,
          contactMethod: _contactMethod,
          localeCode: _controller.localeCode,
          onContactChanged: (method) => setState(() => _contactMethod = method),
        );
      case 4:
        return _ConfirmStep(
          type: _type,
          title: widget.prefill.title,
          contextLabel: widget.prefill.contextLabel,
          countryLabel: _countryLabel,
          institutionLabel: _institutionLabel,
          programLabel: _programLabel,
          message: _messageController.text.trim(),
          contactMethod: _contactMethod,
          attachedDocs: _attachedDocs,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.total,
    required this.labels,
  });

  final int step;
  final int total;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'create_case'.tr,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: KpbColors.brandNavy,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '${'step_label'.tr} ${step + 1}/$total · ${labels[step]}',
          style: KpbTextStyles.caption,
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: (step + 1) / total,
            minHeight: 5,
            backgroundColor: KpbColors.surfaceMuted,
            color: KpbColors.actionPrimary,
          ),
        ),
      ],
    );
  }
}

class _TypeStep extends StatelessWidget {
  const _TypeStep({required this.selected, required this.onSelected});

  final CaseType selected;
  final ValueChanged<CaseType> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        CaseType.applicationSupport,
        Icons.school_outlined,
        'case_type_application_support'.tr
      ),
      (
        CaseType.scholarshipSupport,
        Icons.emoji_events_outlined,
        'case_type_scholarship'.tr
      ),
      (
        CaseType.consultation,
        Icons.article_outlined,
        'case_type_consultation'.tr
      ),
      (CaseType.housingSupport, Icons.home_outlined, 'case_type_housing'.tr),
      (CaseType.mentorship, Icons.support_agent_outlined, 'case_type_other'.tr),
    ];

    return ListView(
      children: options.map((option) {
        final (type, icon, label) = option;
        final isSelected = selected == type;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color:
                isSelected ? KpbColors.actionPrimarySoft : context.kpb.cardBg,
            borderRadius: KpbRadius.mdBr,
            child: InkWell(
              onTap: () => onSelected(type),
              borderRadius: KpbRadius.mdBr,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: KpbRadius.mdBr,
                  border: Border.all(
                    color: isSelected
                        ? KpbColors.actionPrimary
                        : context.kpb.gray200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon,
                        color: isSelected
                            ? KpbColors.actionPrimary
                            : context.kpb.gray400),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded,
                          color: KpbColors.actionPrimary, size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ContextStep extends StatelessWidget {
  const _ContextStep({
    required this.prefill,
    required this.countryLabel,
    required this.institutionLabel,
    required this.programLabel,
    required this.countryFlag,
  });

  final CaseTunnelPrefill prefill;
  final String? countryLabel;
  final String? institutionLabel;
  final String? programLabel;
  final String? countryFlag;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(
          'case_context_prefilled'.tr,
          style: KpbTextStyles.bodySm,
        ),
        const SizedBox(height: 12),
        KpbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(prefill.title, style: KpbTextStyles.titleMd),
              const SizedBox(height: 4),
              Text(prefill.contextLabel, style: KpbTextStyles.caption),
              if (countryLabel != null) ...[
                const SizedBox(height: 12),
                _ContextRow(
                  icon: Icons.public_outlined,
                  label: 'case_context_country'.tr,
                  value: countryFlag != null
                      ? '$countryFlag $countryLabel'
                      : countryLabel!,
                ),
              ],
              if (institutionLabel != null) ...[
                const SizedBox(height: 8),
                _ContextRow(
                  icon: Icons.account_balance_outlined,
                  label: 'case_context_school'.tr,
                  value: institutionLabel!,
                ),
              ],
              if (programLabel != null) ...[
                const SizedBox(height: 8),
                _ContextRow(
                  icon: Icons.menu_book_outlined,
                  label: 'case_context_program'.tr,
                  value: programLabel!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: KpbColors.actionPrimary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: KpbTextStyles.caption),
              Text(value, style: KpbTextStyles.bodySm),
            ],
          ),
        ),
      ],
    );
  }
}

/// L'étape « Documents » pendant le masquage M2 : ce qu'il faut préparer, et le
/// seul chemin qui amène réellement un fichier chez un conseiller.
///
/// Le bouton est TOUJOURS actionnable — il ne dépend d'aucune configuration
/// serveur, le numéro du conseiller étant embarqué dans la build. C'est la même
/// règle que celle appliquée à l'écran de mise à jour forcée : on ne laisse pas
/// une étape avec une seule action, et jamais avec une action qui peut être
/// désactivée.
class _DocumentsHandoffStep extends StatelessWidget {
  const _DocumentsHandoffStep({required this.caseTitle});

  final String caseTitle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        KpbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_shared_outlined,
                      color: KpbColors.success, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'case_documents_handoff_title'.tr,
                      style: KpbTextStyles.titleMd,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'case_documents_handoff_body'.tr,
                style: KpbTextStyles.bodySm,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => openWhatsAppOrToast(
                    prefill: kpbWhatsAppPrefill(
                      custom: 'case_documents_handoff_prefill'
                          .trParams({'title': caseTitle}),
                    ),
                    source: 'case_tunnel_documents',
                    contextType: 'case_documents',
                  ),
                  icon: const Icon(Icons.chat_outlined),
                  label: Text('case_documents_handoff_cta'.tr),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'case_documents_handoff_footnote'.tr,
          style: KpbTextStyles.caption,
        ),
      ],
    );
  }
}

class _DocumentsStep extends StatelessWidget {
  const _DocumentsStep({
    required this.attached,
    required this.sizes,
    required this.onPick,
    required this.onRemove,
  });

  final Map<String, String> attached;
  final Map<String, String> sizes;
  final Future<void> Function(String label) onPick;
  final void Function(String label) onRemove;

  static List<String> get _docTypes =>
      ['CV', 'case_doc_transcripts'.tr, 'case_doc_passport'.tr];

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(
          'case_documents_step_hint'.tr,
          style: KpbTextStyles.bodySm,
        ),
        const SizedBox(height: 12),
        ..._docTypes.map((label) {
          final path = attached[label];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: KpbCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: KpbTextStyles.titleMd),
                        if (path != null)
                          Text(
                            [
                              path.split('/').last,
                              if (sizes[label] != null) sizes[label]!,
                            ].join(' · '),
                            style: KpbTextStyles.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (path != null)
                    IconButton(
                      tooltip: 'a11y_remove'.tr,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => onRemove(label),
                    ),
                  OutlinedButton(
                    onPressed: () => onPick(label),
                    child: Text(
                        path == null ? 'common_add'.tr : 'common_replace'.tr),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _MessageStep extends StatefulWidget {
  const _MessageStep({
    required this.controller,
    required this.contactMethod,
    required this.localeCode,
    required this.onContactChanged,
  });

  final TextEditingController controller;
  final ContactMethod contactMethod;
  final String localeCode;
  final ValueChanged<ContactMethod> onContactChanged;

  @override
  State<_MessageStep> createState() => _MessageStepState();
}

class _MessageStepState extends State<_MessageStep> {
  final SpeechInputService _speech = SpeechInputService();
  bool _listening = false;
  String _dictationBase = '';

  @override
  void dispose() {
    _speech.stopListening();
    super.dispose();
  }

  String get _speechLocale =>
      widget.localeCode.startsWith('en') ? 'en_US' : 'fr_FR';

  Future<void> _toggleDictation() async {
    if (_listening) {
      await _speech.stopListening();
      if (mounted) setState(() => _listening = false);
      return;
    }

    // La permission micro passe par `CaseDictationPlatform` — même condition,
    // même appel, mais interceptables par un test : voir la classe.
    if (CaseDictationPlatform.requiresMicrophonePermission) {
      final granted = await CaseDictationPlatform.requestMicrophonePermission();
      if (!granted) {
        if (mounted) {
          KpbToast.error(
            'case_message_mic_required_body'.tr,
            title: 'case_message_mic_required_title'.tr,
          );
        }
        return;
      }
    }

    _dictationBase = widget.controller.text.trim();
    final started = await _listen();

    // Deux échecs qui se ressemblent et qui ne se traitent pas pareil.
    //
    // `SpeechInputService` demande la reconnaissance LOCALE : la voix de
    // l'étudiant ne doit pas partir chez Apple ou Google, parce que c'est ce
    // que la politique de confidentialité promet. Quand l'appareil ne sait pas
    // le faire, le service refuse la session plutôt que de basculer en
    // silence sur le réseau — et c'est à l'écran de dire pourquoi, puis de
    // demander. Sans ce dialogue, la dictée échouerait sans un mot sur les
    // téléphones sans modèle local, et l'étudiant conclurait que l'app est
    // cassée.
    //
    // L'autre échec (micro occupé, greffon absent) n'arme pas
    // `onDeviceUnavailable` : lui proposer un envoi réseau serait absurde,
    // il garde son message d'origine.
    if (!started && mounted && _speech.onDeviceUnavailable) {
      final accepted = await _askForPlatformService();
      if (accepted != true) return;
      // L'étape a pu être quittée pendant que le dialogue était ouvert. On
      // n'ouvre alors AUCUNE session : `dispose` a déjà appelé
      // `stopListening`, un micro allumé après lui ne s'éteindrait plus.
      if (!mounted) return;

      final retried = await _listen(allowPlatformService: true);
      if (!mounted) return;
      setState(() => _listening = retried);

      // La seconde tentative échoue elle aussi, parfois : micro occupé,
      // service de la plateforme indisponible, session refusée. Sans ce
      // retour, l'étudiant accepte, le dialogue se ferme… et rien ne se
      // passe — le silence exact que ce dialogue venait d'éviter.
      //
      // Le message est celui de la SESSION, pas celui de l'appareil. Dire ici
      // « la reconnaissance vocale n'est pas disponible sur cet appareil »
      // serait une cause fausse : l'étudiant vient d'accepter l'envoi au
      // service de la plateforme, la reconnaissance est donc bien disponible,
      // et ce qui a échoué est cet essai-là. Un nouvel essai peut suffire,
      // encore faut-il le lui dire.
      //
      // On ne relit PAS `onDeviceUnavailable` pour choisir le message :
      // `SpeechInputService` ne l'arme que sur un essai `onDevice` et ne le
      // désarme qu'en cas de succès, donc après cet échec-ci il vaut encore
      // `true`, hérité du premier essai. S'en servir reproposerait le dialogue
      // en boucle. Le refus de la reconnaissance locale a déjà eu son message
      // — c'était le dialogue.
      if (!retried) _reportDictationNotStarted();
      return;
    }

    if (!started && mounted) {
      _reportDictationUnavailable();
      return;
    }

    if (mounted) setState(() => _listening = started);
  }

  /// L'appareil ne sait pas reconnaître la voix : greffon absent, plateforme
  /// qui n'initialise pas, aucun moteur. Rien à réessayer, et c'est pour ça que
  /// ce message-là ne propose pas de réessayer.
  ///
  /// Réservé au PREMIER essai. Le message du refus de reconnaissance locale
  /// n'est pas ici : c'est le dialogue.
  void _reportDictationUnavailable() {
    if (!mounted) return;
    KpbToast.error(
      'case_message_dictation_unavailable_body'.tr,
      title: 'case_message_dictation_unavailable_title'.tr,
    );
  }

  /// La reconnaissance est disponible, la SESSION n'a pas démarré — micro
  /// occupé, service de la plateforme qui refuse à cet instant.
  ///
  /// Séparé de [_reportDictationUnavailable] parce que les deux causes
  /// n'appellent pas la même conduite : là, un nouvel essai peut suffire. Les
  /// confondre disait à l'étudiant que son téléphone ne savait pas faire, ce
  /// qu'il venait précisément de démentir en acceptant l'envoi au service de la
  /// plateforme.
  void _reportDictationNotStarted() {
    if (!mounted) return;
    KpbToast.error(
      'case_message_dictation_not_started_body'.tr,
      title: 'case_message_dictation_not_started_title'.tr,
    );
  }

  /// L'accord explicite, jamais présumé : le corps du dialogue nomme le
  /// destinataire (le service du téléphone) et laisse écrire au clavier.
  Future<bool?> _askForPlatformService() => Get.dialog<bool>(
        AlertDialog(
          title: Text('case_message_dictation_on_device_unavailable_title'.tr),
          content: Text('case_message_dictation_on_device_unavailable_body'.tr),
          actions: [
            TextButton(
              onPressed: () => Get.back<bool>(result: false),
              child: Text('cancel'.tr),
            ),
            TextButton(
              onPressed: () => Get.back<bool>(result: true),
              child: Text('case_message_dictation_use_platform_service'.tr),
            ),
          ],
        ),
      );

  Future<bool> _listen({bool allowPlatformService = false}) {
    return _speech.startListening(
      localeId: _speechLocale,
      allowPlatformService: allowPlatformService,
      onResult: (text, isFinal) {
        if (!mounted || text.trim().isEmpty) return;
        final prefix = _dictationBase.isEmpty ? '' : '$_dictationBase ';
        widget.controller.text = '$prefix$text'.trim();
        widget.controller.selection = TextSelection.collapsed(
          offset: widget.controller.text.length,
        );
        if (isFinal && mounted) {
          setState(() => _listening = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        TextField(
          controller: widget.controller,
          minLines: 4,
          maxLines: 8,
          decoration: InputDecoration(
            labelText: 'description'.tr,
            hintText: 'case_description_hint'.tr,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _toggleDictation,
            icon: Icon(
              _listening ? Icons.stop_rounded : Icons.mic_rounded,
              color: _listening ? KpbColors.error : KpbColors.actionPrimary,
            ),
            label: Text(
              _listening
                  ? 'case_message_stop_dictation'.tr
                  : 'case_message_dictate'.tr,
            ),
          ),
        ),
        if (_listening)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'listening_speak_clearly'.tr,
              style: KpbTextStyles.caption
                  .copyWith(color: KpbColors.actionPrimary),
            ),
          ),
        const SizedBox(height: 16),
        Text('contact_method'.tr, style: KpbTextStyles.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ContactMethod.values.map((method) {
            return ChoiceChip(
              label: Text(_contactLabel(method)),
              selected: widget.contactMethod == method,
              onSelected: (_) => widget.onContactChanged(method),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _contactLabel(ContactMethod method) {
    switch (method) {
      case ContactMethod.inApp:
        return 'case_contact_inapp'.tr;
      case ContactMethod.whatsapp:
        return 'whatsapp'.tr;
      case ContactMethod.phone:
        return 'case_contact_phone'.tr;
    }
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.type,
    required this.title,
    required this.contextLabel,
    required this.countryLabel,
    required this.institutionLabel,
    required this.programLabel,
    required this.message,
    required this.contactMethod,
    required this.attachedDocs,
  });

  final CaseType type;
  final String title;
  final String contextLabel;
  final String? countryLabel;
  final String? institutionLabel;
  final String? programLabel;
  final String message;
  final ContactMethod contactMethod;
  final Map<String, String> attachedDocs;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(
          'review_before_send'.tr,
          style: KpbTextStyles.bodySm,
        ),
        const SizedBox(height: 12),
        KpbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: KpbTextStyles.titleMd),
              const SizedBox(height: 4),
              Text(contextLabel, style: KpbTextStyles.caption),
              const KpbDivider(),
              _RecapRow(
                  label: 'case_tunnel_step_type'.tr, value: _typeLabel(type)),
              if (countryLabel != null)
                _RecapRow(
                    label: 'case_context_country'.tr, value: countryLabel!),
              if (institutionLabel != null)
                _RecapRow(
                    label: 'case_context_school'.tr, value: institutionLabel!),
              if (programLabel != null)
                _RecapRow(
                    label: 'case_context_program'.tr, value: programLabel!),
              _RecapRow(
                  label: 'case_recap_contact'.tr,
                  value: _contactLabel(contactMethod)),
              if (message.isNotEmpty)
                _RecapRow(label: 'case_tunnel_step_message'.tr, value: message),
              if (attachedDocs.isNotEmpty)
                _RecapRow(
                  label: 'case_section_documents'.tr,
                  value: 'case_recap_files_count'
                      .trParams({'count': '${attachedDocs.length}'}),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _typeLabel(CaseType type) {
    switch (type) {
      case CaseType.applicationSupport:
        return 'case_type_application_support'.tr;
      case CaseType.scholarshipSupport:
        return 'case_type_scholarship'.tr;
      case CaseType.consultation:
        return 'case_type_consultation'.tr;
      case CaseType.housingSupport:
        return 'case_type_housing'.tr;
      case CaseType.mentorship:
        return 'case_type_other'.tr;
    }
  }

  String _contactLabel(ContactMethod method) {
    switch (method) {
      case ContactMethod.inApp:
        return 'case_contact_inapp'.tr;
      case ContactMethod.whatsapp:
        return 'whatsapp'.tr;
      case ContactMethod.phone:
        return 'case_contact_phone'.tr;
    }
  }
}

class _RecapRow extends StatelessWidget {
  const _RecapRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: KpbTextStyles.caption),
          ),
          Expanded(child: Text(value, style: KpbTextStyles.bodySm)),
        ],
      ),
    );
  }
}
